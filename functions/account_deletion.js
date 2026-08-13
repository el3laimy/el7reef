const crypto = require("crypto");

const {COLLECTIONS} = require("./firestore_contract");
const {appendAuditEvent} = require("./trusted_audit");

const DELETION_STAGE_ORDER = Object.freeze([
  "storage",
  "privateDocuments",
  "references",
  "nestedIdentities",
  "auth",
]);
const DELETION_STATUSES = new Set([
  "requested",
  "processing",
  "completed",
  "failed",
]);
const DELETION_AUDIT_ACTIONS = Object.freeze({
  requested: "accountDeletionRequested",
  processing: "accountDeletionProcessing",
  completed: "accountDeletionCompleted",
  failed: "accountDeletionFailed",
});

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
      ["safetyActionQuotas", uid],
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

async function requestAccountDeletionCore({db, uid, now}) {
  const requestedAt = normalizedTimestamp(now);
  const plan = accountDeletionPlan(uid);
  const requestRef = deletionRequestRef(db, plan.anonymizedId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    if (!snapshot.exists) {
      const request = initialDeletionRequest(plan, requestedAt);
      transaction.create(requestRef, request);
      appendDeletionAudit({
        transaction,
        db,
        requestId: plan.anonymizedId,
        status: "requested",
        stage: "requested",
        sequence: request.requestRevision,
        createdAt: requestedAt,
      });
      return deletionResponse(plan.anonymizedId, "requested");
    }

    const request = snapshot.data();
    assertDeletionRequestIdentity(request, plan);
    if (request.status === "completed") {
      return deletionResponse(plan.anonymizedId, "completed");
    }
    if (request.status === "requested" && request.userId === uid) {
      return deletionResponse(plan.anonymizedId, "requested");
    }
    if (request.status === "processing" && request.userId === uid) {
      return deletionResponse(plan.anonymizedId, "processing");
    }

    const requestRevision = positiveInteger(request.requestRevision) + 1;
    transaction.update(requestRef, {
      userId: uid,
      status: "requested",
      stage: "requested",
      attempts: 0,
      requestRevision,
      completedSteps: normalizedCompletedSteps(request.completedSteps),
      requestedAt,
      retryRequestedAt: requestedAt,
      updatedAt: requestedAt,
      failedAt: null,
      failedStage: null,
      failureCode: null,
    });
    appendDeletionAudit({
      transaction,
      db,
      requestId: plan.anonymizedId,
      status: "requested",
      stage: "requested",
      sequence: requestRevision,
      createdAt: requestedAt,
    });
    return deletionResponse(plan.anonymizedId, "requested");
  });
}

async function processAccountDeletionRequestCore({
  db,
  requestId,
  stages,
  now,
}) {
  const processing = await markDeletionProcessing({db, requestId, now});
  if (processing.status === "completed") {
    return deletionResponse(requestId, "completed");
  }

  const plan = accountDeletionPlan(processing.userId);
  const completedSteps = new Set(processing.completedSteps);
  let activeStage = firstIncompleteStage(completedSteps);
  try {
    for (const stage of DELETION_STAGE_ORDER) {
      if (completedSteps.has(stage)) continue;
      activeStage = stage;
      await setDeletionStage({db, requestId, stage, now});
      await runDeletionStage(stages, stage, plan);
      await markDeletionStageCompleted({db, requestId, stage, now});
      completedSteps.add(stage);
    }
    return completeDeletionRequest({db, requestId, now});
  } catch (error) {
    await markDeletionFailed({db, requestId, stage: activeStage, now});
    throw error;
  }
}

function createAccountDeletionStages({db, auth, bucket, fieldValue}) {
  return Object.freeze({
    storage: async ({uid}) => {
      await bucket.deleteFiles({prefix: `profiles/${uid}/`});
    },
    privateDocuments: async ({recursiveDocuments}) => {
      for (const [collection, documentId] of recursiveDocuments) {
        await db.recursiveDelete(db.collection(collection).doc(documentId));
      }
    },
    references: async (plan) => {
      await rewriteAccountReferences({db, fieldValue, plan});
    },
    nestedIdentities: async (plan) => {
      await rewriteNestedIdentities({db, plan});
    },
    auth: async ({uid}) => {
      await deleteAuthUser(auth, uid);
    },
  });
}

async function markDeletionProcessing({db, requestId, now}) {
  const processedAt = normalizedTimestamp(now);
  const requestRef = deletionRequestRef(db, requestId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    const request = requiredDeletionRequest(snapshot, requestId);
    if (request.status === "completed") return request;
    const attempt = positiveInteger(request.attempts) + 1;
    const stage = firstIncompleteStage(
      new Set(normalizedCompletedSteps(request.completedSteps)),
    );
    transaction.update(requestRef, {
      status: "processing",
      stage,
      attempts: attempt,
      processingAt: processedAt,
      updatedAt: processedAt,
      failedAt: null,
      failedStage: null,
      failureCode: null,
    });
    appendDeletionAudit({
      transaction,
      db,
      requestId,
      status: "processing",
      stage,
      sequence: attempt,
      createdAt: processedAt,
    });
    return {
      ...request,
      status: "processing",
      stage,
      attempts: attempt,
      completedSteps: normalizedCompletedSteps(request.completedSteps),
    };
  });
}

async function setDeletionStage({db, requestId, stage, now}) {
  const updatedAt = normalizedTimestamp(now);
  await updateActiveDeletionRequest({
    db,
    requestId,
    update: {stage, updatedAt},
  });
}

async function markDeletionStageCompleted({db, requestId, stage, now}) {
  const updatedAt = normalizedTimestamp(now);
  const requestRef = deletionRequestRef(db, requestId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    const request = requiredDeletionRequest(snapshot, requestId);
    if (request.status === "completed") return;
    const completedSteps = new Set(
      normalizedCompletedSteps(request.completedSteps),
    );
    completedSteps.add(stage);
    transaction.update(requestRef, {
      completedSteps: [...completedSteps],
      stage: firstIncompleteStage(completedSteps),
      updatedAt,
    });
  });
}

async function completeDeletionRequest({db, requestId, now}) {
  const completedAt = normalizedTimestamp(now);
  const requestRef = deletionRequestRef(db, requestId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    const request = requiredDeletionRequest(snapshot, requestId);
    if (request.status === "completed") {
      return deletionResponse(requestId, "completed");
    }
    const completedSteps = normalizedCompletedSteps(request.completedSteps);
    if (completedSteps.length !== DELETION_STAGE_ORDER.length) {
      throw new Error("Account deletion stages are incomplete.");
    }
    const attempt = positiveInteger(request.attempts);
    transaction.set(requestRef, {
      status: "completed",
      stage: "completed",
      anonymizedId: requestId,
      attempts: attempt,
      requestRevision: positiveInteger(request.requestRevision),
      completedSteps,
      createdAt: finiteOrFallback(request.createdAt, completedAt),
      requestedAt: finiteOrFallback(request.requestedAt, completedAt),
      completedAt,
      updatedAt: completedAt,
    });
    appendDeletionAudit({
      transaction,
      db,
      requestId,
      status: "completed",
      stage: "completed",
      sequence: attempt,
      createdAt: completedAt,
    });
    return deletionResponse(requestId, "completed");
  });
}

async function markDeletionFailed({db, requestId, stage, now}) {
  const failedAt = normalizedTimestamp(now);
  const requestRef = deletionRequestRef(db, requestId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    const request = requiredDeletionRequest(snapshot, requestId);
    if (request.status === "completed") return;
    const attempt = positiveInteger(request.attempts);
    transaction.update(requestRef, {
      status: "failed",
      stage,
      failedStage: stage,
      failureCode: "stage-failed",
      failedAt,
      updatedAt: failedAt,
    });
    appendDeletionAudit({
      transaction,
      db,
      requestId,
      status: "failed",
      stage,
      sequence: attempt,
      createdAt: failedAt,
    });
  });
}

async function updateActiveDeletionRequest({db, requestId, update}) {
  const requestRef = deletionRequestRef(db, requestId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    const request = requiredDeletionRequest(snapshot, requestId);
    if (request.status !== "completed") transaction.update(requestRef, update);
  });
}

async function rewriteAccountReferences({db, fieldValue, plan}) {
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
  await writer.close();
}

async function rewriteNestedIdentities({db, plan}) {
  const writer = db.bulkWriter();
  await scrubTopLevelIdentityCollections({
    db,
    writer,
    collections: plan.nestedIdentityCollections,
    uid: plan.uid,
    anonymizedId: plan.anonymizedId,
  });
  await scrubIdentityCollectionGroups({
    db,
    writer,
    collections: plan.nestedIdentityCollectionGroups,
    uid: plan.uid,
    anonymizedId: plan.anonymizedId,
  });
  await writer.close();
}

async function deleteAuthUser(auth, uid) {
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") throw error;
  }
}

function initialDeletionRequest(plan, requestedAt) {
  return {
    status: "requested",
    stage: "requested",
    anonymizedId: plan.anonymizedId,
    userId: plan.uid,
    attempts: 0,
    requestRevision: 1,
    completedSteps: [],
    createdAt: requestedAt,
    requestedAt,
    updatedAt: requestedAt,
    processingAt: null,
    completedAt: null,
    failedAt: null,
    failedStage: null,
    failureCode: null,
  };
}

function deletionRequestRef(db, requestId) {
  return db.collection(COLLECTIONS.accountDeletionRequests).doc(requestId);
}

function assertDeletionRequestIdentity(request, plan) {
  if (!request || !DELETION_STATUSES.has(request.status)) {
    throw new Error("Account deletion request has an invalid status.");
  }
  if (request.anonymizedId !== plan.anonymizedId) {
    throw new Error("Account deletion request identity does not match.");
  }
  if (request.userId != null && request.userId !== plan.uid) {
    throw new Error("Account deletion request owner does not match.");
  }
}

function requiredDeletionRequest(snapshot, requestId) {
  if (!snapshot.exists) {
    throw new Error("Account deletion request does not exist.");
  }
  const request = snapshot.data();
  if (!request || !DELETION_STATUSES.has(request.status)) {
    throw new Error("Account deletion request has an invalid status.");
  }
  if (request.anonymizedId !== requestId) {
    throw new Error("Account deletion request identity does not match.");
  }
  if (request.status !== "completed") {
    if (typeof request.userId !== "string" ||
        deletedAccountId(request.userId) !== requestId) {
      throw new Error("Account deletion request owner is invalid.");
    }
  }
  return request;
}

function accountDeletionEventShouldRun(change) {
  if (!change.after.exists) return false;
  const afterStatus = change.after.data().status;
  const beforeStatus = change.before.exists ? change.before.data().status : null;
  return afterStatus === "requested" && beforeStatus !== "requested";
}

function appendDeletionAudit({
  transaction,
  db,
  requestId,
  status,
  stage,
  sequence,
  createdAt,
}) {
  appendAuditEvent({
    transaction,
    db,
    entityType: "accountDeletion",
    entityId: requestId,
    action: DELETION_AUDIT_ACTIONS[status],
    actorId: requestId,
    beforePayload: null,
    afterPayload: null,
    metadata: {status, stage, attempt: sequence},
    requestId: `${requestId}:${status}:${sequence}`,
    createdAt,
  });
}

async function runDeletionStage(stages, stage, plan) {
  const operation = stages && stages[stage];
  if (typeof operation !== "function") {
    throw new Error(`Account deletion stage is unavailable: ${stage}.`);
  }
  await operation(plan);
}

function normalizedCompletedSteps(candidate) {
  if (!Array.isArray(candidate)) return [];
  return DELETION_STAGE_ORDER.filter((stage) => candidate.includes(stage));
}

function firstIncompleteStage(completedSteps) {
  return DELETION_STAGE_ORDER.find((stage) => !completedSteps.has(stage)) ||
    "completed";
}

function positiveInteger(candidate) {
  return Number.isSafeInteger(candidate) && candidate >= 0 ? candidate : 0;
}

function normalizedTimestamp(now) {
  const candidate = typeof now === "function" ? now() : now;
  const timestamp = Number(candidate);
  if (!Number.isFinite(timestamp) || timestamp < 0) {
    throw new Error("Account deletion timestamp is invalid.");
  }
  return timestamp;
}

function finiteOrFallback(candidate, fallback) {
  const value = Number(candidate);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

function deletionResponse(requestId, status) {
  return {
    accepted: true,
    deleted: status === "completed",
    requestId,
    status,
  };
}

async function scrubIdentityCollectionGroups({
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

async function scrubTopLevelIdentityCollections({
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
  accountDeletionEventShouldRun,
  accountDeletionPlan,
  createAccountDeletionStages,
  DELETION_STAGE_ORDER,
  deletedAccountId,
  processAccountDeletionRequestCore,
  requestAccountDeletionCore,
  scrubNestedIdentity,
};
