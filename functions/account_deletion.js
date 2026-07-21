const crypto = require("crypto");

function deletedAccountId(uid) {
  const digest = crypto.createHash("sha256").update(uid).digest("hex");
  return `deleted-${digest.slice(0, 24)}`;
}

function accountDeletionPlan(uid) {
  const anonymizedId = deletedAccountId(uid);
  return {
    uid,
    anonymizedId,
    recursiveDocuments: [
      ["players", uid],
      ["playerFantasyValues", uid],
    ],
    deleteQueries: [
      ["teamMemberships", "playerId", "==", uid],
      ["tournamentMemberships", "userId", "==", uid],
      ["friendships", "participants", "array-contains", uid],
      ["matchInvitations", "senderId", "==", uid],
      ["matchInvitations", "receiverId", "==", uid],
      ["matchAttendances", "playerId", "==", uid],
      ["userVotes", "userId", "==", uid],
      ["notifications", "userId", "==", uid],
      ["reservedUsernames", "ownerId", "==", uid],
      ["claimCodes", "createdBy", "==", uid],
      ["disputes", "raisedBy", "==", uid],
    ],
    deleteCollectionGroupQueries: [
      ["assistants", "userId", "==", uid],
      ["followers", "userId", "==", uid],
    ],
    anonymizeQueries: [
      ["teams", "ownerId", uid, {ownerId: anonymizedId, ownerDeleted: true}],
      [
        "tournaments",
        "organizerId",
        uid,
        {organizerId: anonymizedId, organizerDeleted: true},
      ],
      [
        "matches",
        "organizerId",
        uid,
        {organizerId: anonymizedId, organizerDeleted: true},
      ],
      ["guestTeams", "creatorId", uid, {creatorId: anonymizedId}],
      ["guestPlayers", "createdBy", uid, {createdBy: anonymizedId}],
      ["matchEvents", "createdBy", uid, {createdBy: anonymizedId}],
      ["matchSides", "createdBy", uid, {createdBy: anonymizedId}],
      ["matchCheckIns", "createdBy", uid, {createdBy: anonymizedId}],
      ["matchSubstitutions", "createdBy", uid, {createdBy: anonymizedId}],
      [
        "tournamentRegistrations",
        "createdBy",
        uid,
        {createdBy: anonymizedId},
      ],
      ["auditEvents", "actorId", uid, {actorId: anonymizedId}],
      ["analyticsEvents", "actorId", uid, {actorId: anonymizedId}],
      ["matches", "mvpPlayerId", uid, {mvpPlayerId: anonymizedId}],
      ["userReports", "reporterId", uid, {reporterId: anonymizedId}],
      ["userReports", "targetId", uid, {targetId: anonymizedId}],
    ],
    arrayRemovalQueries: [
      ["teams", "playerIds", uid, ["playerIds", "viceCaptainIds"]],
      ["matches", "teamAPlayerIds", uid, ["teamAPlayerIds"]],
      ["matches", "teamBPlayerIds", uid, ["teamBPlayerIds"]],
    ],
    nestedIdentityCollections: [
      "matchEvents",
      "matchLineupSnapshots",
      "matchSidePlayers",
      "matchSubstitutions",
      "teamFormationTemplates",
      "teamRosterSnapshots",
      "ratingEvents",
      "encounterLogs",
    ],
    nestedIdentityCollectionGroups: ["player_stats"],
  };
}

async function deleteAccountDataCore({db, auth, bucket, uid, fieldValue}) {
  const plan = accountDeletionPlan(uid);
  const requestRef = db
    .collection("accountDeletionRequests")
    .doc(plan.anonymizedId);
  await requestRef.set(
    {
      status: "processing",
      anonymizedId: plan.anonymizedId,
      updatedAt: Date.now(),
    },
    {merge: true},
  );

  await bucket.deleteFiles({prefix: `profiles/${uid}/`});
  for (const [collection, documentId] of plan.recursiveDocuments) {
    await db.recursiveDelete(db.collection(collection).doc(documentId));
  }

  const writer = db.bulkWriter();
  await deleteQueries(db, writer, plan.deleteQueries, false);
  await deleteQueries(db, writer, plan.deleteCollectionGroupQueries, true);
  await anonymizeQueries(db, writer, plan.anonymizeQueries);
  await removeArrayMemberships(
    db,
    writer,
    plan.arrayRemovalQueries,
    fieldValue,
  );
  await scrubNestedIdentityCollectionGroups({
    db,
    writer,
    collections: plan.nestedIdentityCollections,
    uid,
    anonymizedId: plan.anonymizedId,
  });
  await scrubNestedIdentityCollections({
    db,
    writer,
    collections: plan.nestedIdentityCollectionGroups,
    uid,
    anonymizedId: plan.anonymizedId,
  });
  await writer.close();

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  await requestRef.set(
    {
      status: "completed",
      anonymizedId: plan.anonymizedId,
      completedAt: Date.now(),
      updatedAt: Date.now(),
    },
    {merge: true},
  );
  return {deleted: true, requestId: plan.anonymizedId};
}

async function scrubNestedIdentityCollections({
  db,
  writer,
  collections,
  uid,
  anonymizedId,
}) {
  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    scrubNestedIdentitySnapshot({writer, snapshot, uid, anonymizedId});
  }
}

async function scrubNestedIdentityCollectionGroups({
  db,
  writer,
  collections,
  uid,
  anonymizedId,
}) {
  for (const collection of collections) {
    const snapshot = await db.collectionGroup(collection).get();
    scrubNestedIdentitySnapshot({writer, snapshot, uid, anonymizedId});
  }
}

function scrubNestedIdentitySnapshot({writer, snapshot, uid, anonymizedId}) {
  for (const document of snapshot.docs) {
    const scrubbed = scrubNestedIdentity(document.data(), uid, anonymizedId);
    if (scrubbed.changed) {
      writer.update(document.ref, scrubbed.value);
    }
  }
}

function scrubNestedIdentity(value, uid, anonymizedId) {
  if (value === uid) {
    return {value: anonymizedId, changed: true};
  }
  if (Array.isArray(value)) {
    let changed = false;
    const items = value.map((item) => {
      const scrubbed = scrubNestedIdentity(item, uid, anonymizedId);
      changed = changed || scrubbed.changed;
      return scrubbed.value;
    });
    return {value: items, changed};
  }
  if (!isPlainObject(value)) {
    return {value, changed: false};
  }

  const representsDeletedPlayer =
    value.playerId === uid ||
    ((value.kind === "player" || value.kind === "registeredPlayer") &&
      value.id === uid);
  let changed = false;
  const result = {};
  for (const [key, child] of Object.entries(value)) {
    const scrubbed = scrubNestedIdentity(child, uid, anonymizedId);
    result[key] = scrubbed.value;
    changed = changed || scrubbed.changed;
  }
  if (representsDeletedPlayer) {
    for (const nameField of ["displayName", "name"]) {
      if (typeof result[nameField] === "string") {
        result[nameField] = "حساب محذوف";
        changed = true;
      }
    }
  }
  return {value: result, changed};
}

function isPlainObject(value) {
  if (!value || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

async function deleteQueries(db, writer, descriptors, collectionGroup) {
  for (const [collection, field, operator, value] of descriptors) {
    const source = collectionGroup
      ? db.collectionGroup(collection)
      : db.collection(collection);
    const snapshot = await source.where(field, operator, value).get();
    for (const document of snapshot.docs) {
      writer.delete(document.ref);
    }
  }
}

async function anonymizeQueries(db, writer, descriptors) {
  for (const [collection, field, value, replacement] of descriptors) {
    const snapshot = await db.collection(collection).where(field, "==", value).get();
    for (const document of snapshot.docs) {
      writer.update(document.ref, replacement);
    }
  }
}

async function removeArrayMemberships(db, writer, descriptors, fieldValue) {
  for (const [collection, queryField, uid, fields] of descriptors) {
    const snapshot = await db
      .collection(collection)
      .where(queryField, "array-contains", uid)
      .get();
    for (const document of snapshot.docs) {
      writer.update(document.ref, {
        ...Object.fromEntries(
          fields.map((field) => [field, fieldValue.arrayRemove(uid)]),
        ),
      });
    }
  }
}

module.exports = {
  accountDeletionPlan,
  deleteAccountDataCore,
  deletedAccountId,
  scrubNestedIdentity,
};
