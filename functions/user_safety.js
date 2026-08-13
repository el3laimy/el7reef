const crypto = require("crypto");

const {deletedAccountId} = require("./account_deletion");
const {COLLECTIONS} = require("./firestore_contract");
const {appendAuditEvent} = require("./trusted_audit");

const ALLOWED_REASONS = new Set([
  "harassment",
  "impersonation",
  "inappropriate",
  "spam",
  "other",
]);
const ALLOWED_TARGET_KINDS = new Set(["registeredPlayer", "guestPlayer"]);
const REPORT_RATE_LIMIT = Object.freeze({
  scope: "profileReport",
  maxOperations: 20,
  windowMs: 24 * 60 * 60 * 1000,
});
const RELATIONSHIP_RATE_LIMIT = Object.freeze({
  scope: "safetyRelationship",
  maxOperations: 30,
  windowMs: 60 * 60 * 1000,
});

function normalizeUserReport(reportPayload, reporterId, now = Date.now()) {
  const targetKind = requiredEnum(
    reportPayload && reportPayload.targetKind,
    "targetKind",
    ALLOWED_TARGET_KINDS,
  );
  const targetId = requiredText(
    reportPayload && reportPayload.targetId,
    "targetId",
    160,
  );
  const reason = requiredEnum(
    reportPayload && reportPayload.reason,
    "reason",
    ALLOWED_REASONS,
  );
  const details = optionalText(reportPayload && reportPayload.details, 500);
  if (targetKind === "registeredPlayer" && targetId === reporterId) {
    throw new UserSafetyError("invalid-argument", "Cannot report yourself.");
  }

  const day = new Date(now).toISOString().slice(0, 10);
  const digest = crypto
    .createHash("sha256")
    .update(`${reporterId}|${targetKind}|${targetId}|profile|${day}`)
    .digest("hex")
    .slice(0, 32);
  return {
    id: `report-${digest}`,
    reporterId,
    targetKind,
    targetId,
    contentType: "profile",
    reason,
    details,
    status: "open",
  };
}

async function reportUserContentCore({db, reportPayload, reporterId, now}) {
  const createdAt = now();
  const report = normalizeUserReport(reportPayload, reporterId, createdAt);
  return db.runTransaction(async (transaction) => {
    const reportRef = db.collection(COLLECTIONS.userReports).doc(report.id);
    const targetRef = reportTargetRef(db, report);
    const actorRefs = safetyActorRefs(db, reporterId);
    const [existingReport, target, actor, actorDeletion] = await Promise.all([
      transaction.get(reportRef),
      transaction.get(targetRef),
      transaction.get(actorRefs.profile),
      transaction.get(actorRefs.deletion),
    ]);
    assertActiveSafetyActor({actor, actorDeletion});
    if (existingReport.exists) {
      return reportResponse(report, true);
    }
    if (!target.exists) {
      throw new UserSafetyError("not-found", "Reported profile not found.");
    }
    await consumeRateLimit({
      transaction,
      db,
      actorId: reporterId,
      changedAt: createdAt,
      ...REPORT_RATE_LIMIT,
    });
    transaction.create(reportRef, {...report, createdAt, updatedAt: createdAt});
    appendReportAudit({transaction, db, report, createdAt});
    return reportResponse(report, false);
  });
}

function reportTargetRef(db, report) {
  const collection = report.targetKind === "registeredPlayer" ?
    COLLECTIONS.players :
    COLLECTIONS.guestPlayers;
  return db.collection(collection).doc(report.targetId);
}

function safetyActorRefs(db, actorId) {
  return {
    profile: db.collection(COLLECTIONS.players).doc(actorId),
    deletion: db
      .collection(COLLECTIONS.accountDeletionRequests)
      .doc(deletedAccountId(actorId)),
  };
}

function assertActiveSafetyActor({actor, actorDeletion}) {
  if (!actor.exists || actorDeletion.exists) {
    throw new UserSafetyError(
      "permission-denied",
      "An active player profile is required.",
    );
  }
}

function appendReportAudit({transaction, db, report, createdAt}) {
  appendAuditEvent({
    transaction,
    db,
    entityType: "moderationReport",
    entityId: report.id,
    action: "profileReported",
    actorId: report.reporterId,
    beforePayload: null,
    afterPayload: {
      targetKind: report.targetKind,
      status: report.status,
    },
    metadata: null,
    requestId: `profile-report:${report.id}`,
    createdAt,
  });
}

function reportResponse(report, duplicate) {
  return {accepted: true, reportId: report.id, duplicate};
}

async function blockUserCore({db, blockerId, blockedId, now}) {
  const normalizedBlockedId = otherPlayerId(blockedId, "blockedId", blockerId);
  const blockedAt = now();
  const refs = blockDocumentRefs(db, blockerId, normalizedBlockedId);
  return db.runTransaction(async (transaction) => {
    const snapshots = await blockSnapshots(transaction, refs);
    assertBlockPlayersExist(snapshots);
    const documents = blockDocuments(snapshots);
    assertFriendshipPairMatches(documents.friendship, refs.participantIds);
    const blockRequest = {
      transaction,
      refs,
      db,
      documents,
      blockerId,
      blockedId: normalizedBlockedId,
      changedAt: blockedAt,
    };
    if (normalizedBlockedIds(documents.blocker).includes(normalizedBlockedId)) {
      if (!isCanonicalBlockState({
        documents,
        blockerId,
        blockedId: normalizedBlockedId,
      })) {
        stageBlockState(blockRequest);
      }
      return {blocked: true, duplicate: true};
    }
    const auditSequence = await consumeRateLimit({
      transaction,
      db,
      actorId: blockerId,
      changedAt: blockedAt,
      ...RELATIONSHIP_RATE_LIMIT,
    });
    const auditedBlockRequest = {...blockRequest, auditSequence};
    stageBlockState(auditedBlockRequest);
    appendSafetyRelationshipAudit({
      ...auditedBlockRequest,
      action: "playerBlocked",
    });
    return {blocked: true, duplicate: false};
  });
}

async function unblockUserCore({db, blockerId, blockedId, now}) {
  const normalizedBlockedId = otherPlayerId(blockedId, "blockedId", blockerId);
  const unblockedAt = now();
  const refs = blockDocumentRefs(db, blockerId, normalizedBlockedId);
  return db.runTransaction(async (transaction) => {
    const snapshots = await blockSnapshots(transaction, refs);
    assertBlockPlayersExist(snapshots);
    const documents = blockDocuments(snapshots);
    assertFriendshipPairMatches(documents.friendship, refs.participantIds);
    const unblockRequest = {
      transaction,
      refs,
      db,
      documents,
      blockerId,
      blockedId: normalizedBlockedId,
      changedAt: unblockedAt,
    };
    if (!normalizedBlockedIds(documents.blocker)
      .includes(normalizedBlockedId)) {
      stageDuplicateUnblockRepair(unblockRequest);
      return {unblocked: true, duplicate: true};
    }
    const auditSequence = await consumeRateLimit({
      transaction,
      db,
      actorId: blockerId,
      changedAt: unblockedAt,
      ...RELATIONSHIP_RATE_LIMIT,
    });
    const auditedUnblockRequest = {...unblockRequest, auditSequence};
    stageUnblockState(auditedUnblockRequest);
    appendSafetyRelationshipAudit({
      ...auditedUnblockRequest,
      action: "playerUnblocked",
    });
    return {unblocked: true, duplicate: false};
  });
}

function blockDocumentRefs(db, blockerId, blockedId) {
  const ids = [blockerId, blockedId].sort();
  return {
    blocker: db.collection(COLLECTIONS.players).doc(blockerId),
    blocked: db.collection(COLLECTIONS.players).doc(blockedId),
    friendship: db.collection(COLLECTIONS.friendships).doc(ids.join("_")),
    actorDeletion: db
      .collection(COLLECTIONS.accountDeletionRequests)
      .doc(deletedAccountId(blockerId)),
    participantIds: ids,
  };
}

async function blockSnapshots(transaction, refs) {
  const [blocker, blocked, friendship, actorDeletion] = await Promise.all([
    transaction.get(refs.blocker),
    transaction.get(refs.blocked),
    transaction.get(refs.friendship),
    transaction.get(refs.actorDeletion),
  ]);
  return {blocker, blocked, friendship, actorDeletion};
}

function assertBlockPlayersExist({blocker, blocked, actorDeletion}) {
  assertActiveSafetyActor({actor: blocker, actorDeletion});
  if (!blocked.exists) {
    throw new UserSafetyError("not-found", "Player not found.");
  }
}

function blockDocuments({blocker, blocked, friendship}) {
  return {
    blocker: blocker.data(),
    blocked: blocked.data(),
    friendship: friendship.exists ? friendship.data() : null,
  };
}

function assertFriendshipPairMatches(friendship, canonicalParticipants) {
  if (friendship == null) {
    return;
  }
  const participantFields = [friendship.userId1, friendship.userId2];
  if (!isSameParticipantPair(friendship.participants, canonicalParticipants) ||
      !isSameParticipantPair(participantFields, canonicalParticipants)) {
    throw new UserSafetyError(
      "failed-precondition",
      "Friendship identity does not match its document path.",
    );
  }
}

function isSameParticipantPair(candidateIds, canonicalParticipants) {
  return Array.isArray(candidateIds) &&
    candidateIds.length === 2 &&
    new Set(candidateIds).size === 2 &&
    canonicalParticipants.every((participantId) => (
      candidateIds.includes(participantId)
    ));
}

function isCanonicalBlockState({documents, blockerId, blockedId}) {
  const blockerFriendIds = normalizedFriendIds(documents.blocker);
  const blockerBlockedIds = normalizedBlockedIds(documents.blocker);
  const blockedFriendIds = normalizedFriendIds(documents.blocked);
  const friendship = documents.friendship;
  const canonicalParticipants = [blockerId, blockedId].sort();
  return hasCanonicalFriendIds(documents.blocker) &&
    hasCanonicalFriendIds(documents.blocked) &&
    hasCanonicalBlockedIds(documents.blocker) &&
    hasCanonicalBlockedIds(documents.blocked) &&
    blockerBlockedIds.includes(blockedId) &&
    !blockerFriendIds.includes(blockedId) &&
    !blockedFriendIds.includes(blockerId) &&
    friendship != null &&
    friendship.userId1 === canonicalParticipants[0] &&
    friendship.userId2 === canonicalParticipants[1] &&
    friendship.participants[0] === canonicalParticipants[0] &&
    friendship.participants[1] === canonicalParticipants[1] &&
    friendship.status === "blocked" &&
    canonicalParticipants.includes(friendship.lastActionBy);
}

function stageBlockState(blockWriteRequest) {
  const {transaction, refs, documents, blockerId, blockedId, changedAt} =
    blockWriteRequest;
  transaction.set(
    refs.friendship,
    blockedFriendshipDocument({refs, documents, blockerId, changedAt}),
  );
  transaction.update(refs.blocker, {
    friendIds: withoutFriendId(documents.blocker, blockedId),
    blockedIds: withBlockedId(documents.blocker, blockedId),
  });
  transaction.update(refs.blocked, {
    friendIds: withoutFriendId(documents.blocked, blockerId),
    blockedIds: normalizedBlockedIds(documents.blocked),
  });
}

function stageUnblockState(unblockWriteRequest) {
  const {transaction, refs, documents, blockerId, blockedId, changedAt} =
    unblockWriteRequest;
  transaction.update(refs.blocker, {
    friendIds: withoutFriendId(documents.blocker, blockedId),
    blockedIds: withoutBlockedId(documents.blocker, blockedId),
  });
  transaction.update(refs.blocked, {
    friendIds: withoutFriendId(documents.blocked, blockerId),
    blockedIds: normalizedBlockedIds(documents.blocked),
  });
  if (normalizedBlockedIds(documents.blocked).includes(blockerId)) {
    transaction.set(
      refs.friendship,
      blockedFriendshipDocument({
        refs,
        documents,
        blockerId: blockedId,
        changedAt,
      }),
    );
    return;
  }
  transaction.delete(refs.friendship);
}

function stageDuplicateUnblockRepair(unblockWriteRequest) {
  const {documents, blockerId, blockedId} = unblockWriteRequest;
  if (normalizedBlockedIds(documents.blocked).includes(blockerId)) {
    const oppositeDocuments = {
      blocker: documents.blocked,
      blocked: documents.blocker,
      friendship: documents.friendship,
    };
    if (!isCanonicalBlockState({
      documents: oppositeDocuments,
      blockerId: blockedId,
      blockedId: blockerId,
    })) {
      stageUnblockState(unblockWriteRequest);
    }
    return;
  }
  if (documents.friendship?.status === "blocked") {
    stageUnblockState(unblockWriteRequest);
    return;
  }
  stageBlockedIdNormalization(unblockWriteRequest);
}

function stageBlockedIdNormalization({transaction, refs, documents}) {
  if (!hasCanonicalBlockedIds(documents.blocker)) {
    transaction.update(refs.blocker, {
      blockedIds: normalizedBlockedIds(documents.blocker),
    });
  }
  if (!hasCanonicalBlockedIds(documents.blocked)) {
    transaction.update(refs.blocked, {
      blockedIds: normalizedBlockedIds(documents.blocked),
    });
  }
}

function blockedFriendshipDocument({refs, documents, blockerId, changedAt}) {
  return {
    userId1: refs.participantIds[0],
    userId2: refs.participantIds[1],
    participants: refs.participantIds,
    status: "blocked",
    lastActionBy: blockerId,
    createdAt: documents.friendship?.createdAt ?? new Date(changedAt),
    updatedAt: new Date(changedAt),
  };
}

function appendSafetyRelationshipAudit(safetyAuditRequest) {
  const {
    transaction,
    db,
    blockerId,
    blockedId,
    changedAt,
    action,
    auditSequence,
  } =
    safetyAuditRequest;
  const blockState = action === "playerBlocked";
  appendAuditEvent({
    transaction,
    db,
    entityType: "safetyRelationship",
    entityId: safetyRelationshipId(blockerId, blockedId),
    action,
    actorId: blockerId,
    beforePayload: {blocked: !blockState},
    afterPayload: {blocked: blockState},
    metadata: null,
    requestId: safetyActionRequestId({
      action,
      blockerId,
      blockedId,
      windowKey: auditSequence.windowKey,
      revision: auditSequence.revision,
    }),
    createdAt: changedAt,
  });
}

function safetyRelationshipId(blockerId, blockedId) {
  return opaqueSafetyId("relationship", [blockerId, blockedId]);
}

function safetyActionRequestId({
  action,
  blockerId,
  blockedId,
  windowKey,
  revision,
}) {
  return opaqueSafetyId(action, [
    blockerId,
    blockedId,
    windowKey,
    revision,
  ]);
}

async function consumeRateLimit({
  transaction,
  db,
  actorId,
  scope,
  maxOperations,
  windowMs,
  changedAt,
}) {
  const windowStart = Math.floor(changedAt / windowMs) * windowMs;
  const windowKey = String(windowStart);
  const limitRef = db.collection(COLLECTIONS.safetyActionQuotas).doc(actorId);
  const limitSnapshot = await transaction.get(limitRef);
  const current = limitSnapshot.exists ? limitSnapshot.data() : null;
  const count = rateLimitCount(current?.[scope], {windowKey, maxOperations});
  if (count >= maxOperations) {
    throw new UserSafetyError(
      "resource-exhausted",
      "Too many user safety actions. Try again later.",
    );
  }
  const revision = count + 1;
  transaction.set(limitRef, {
    ...current,
    schemaVersion: 1,
    [scope]: {windowKey, count: revision, revision},
    createdAt: current?.createdAt ?? new Date(changedAt),
    updatedAt: new Date(changedAt),
  });
  return {windowKey, revision};
}

function rateLimitCount(current, {windowKey, maxOperations}) {
  if (current == null) {
    return 0;
  }
  if (typeof current !== "object" || Array.isArray(current) ||
      typeof current.windowKey !== "string" ||
      !Number.isInteger(current.count) || current.count < 0 ||
      current.revision !== current.count) {
    throw new UserSafetyError(
      "failed-precondition",
      "User safety rate limit state is invalid.",
    );
  }
  if (current.windowKey !== windowKey) {
    return 0;
  }
  if (current.count > maxOperations) {
    throw new UserSafetyError(
      "failed-precondition",
      "User safety rate limit state is invalid.",
    );
  }
  return current.count;
}

function opaqueSafetyId(prefix, identityParts) {
  const digest = crypto.createHash("sha256")
    .update(JSON.stringify(identityParts))
    .digest("hex")
    .slice(0, 32);
  return `${prefix}-${digest}`;
}

function withoutFriendId(document, removedId) {
  return normalizedFriendIds(document)
    .filter((candidateId) => candidateId !== removedId);
}

function withBlockedId(document, addedId) {
  return [...new Set([...normalizedBlockedIds(document), addedId])];
}

function withoutBlockedId(document, removedId) {
  return normalizedBlockedIds(document)
    .filter((candidateId) => candidateId !== removedId);
}

function normalizedFriendIds(document) {
  const identifiers = document.friendIds;
  if (!Array.isArray(identifiers)) {
    return [];
  }
  return [...new Set(identifiers.filter(isValidRelationshipId))];
}

function hasCanonicalFriendIds(document) {
  const identifiers = document.friendIds;
  const normalized = normalizedFriendIds(document);
  return Array.isArray(identifiers) &&
    identifiers.length === normalized.length &&
    identifiers.every((identifier, index) => identifier === normalized[index]);
}

function normalizedBlockedIds(document) {
  const identifiers = document.blockedIds;
  const candidates = Array.isArray(identifiers) ? identifiers : [identifiers];
  return [...new Set(candidates.filter(isValidRelationshipId))];
}

function hasCanonicalBlockedIds(document) {
  const identifiers = document.blockedIds;
  const normalized = normalizedBlockedIds(document);
  return Array.isArray(identifiers) &&
    identifiers.length === normalized.length &&
    identifiers.every((identifier, index) => identifier === normalized[index]);
}

function isValidRelationshipId(identifier) {
  return typeof identifier === "string" &&
    identifier.length > 0 &&
    identifier.length <= 160 &&
    identifier.trim() === identifier;
}

function requiredEnum(value, fieldName, allowed) {
  const normalized = requiredText(value, fieldName, 64);
  if (!allowed.has(normalized)) {
    throw new UserSafetyError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function otherPlayerId(candidate, fieldName, actorId) {
  const normalized = requiredText(candidate, fieldName, 160);
  if (normalized === actorId) {
    throw new UserSafetyError("invalid-argument", "Cannot target yourself.");
  }
  return normalized;
}

function requiredText(candidate, fieldName, maxLength) {
  if (typeof candidate !== "string") {
    throw new UserSafetyError("invalid-argument", `${fieldName} is invalid.`);
  }
  const normalized = candidate.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new UserSafetyError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function optionalText(candidate, maxLength) {
  if (candidate == null) {
    return "";
  }
  if (typeof candidate !== "string") {
    throw new UserSafetyError("invalid-argument", "details is invalid.");
  }
  const normalized = candidate.trim();
  if (normalized.length > maxLength) {
    throw new UserSafetyError("invalid-argument", "details is invalid.");
  }
  return normalized;
}

class UserSafetyError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

module.exports = {
  blockUserCore,
  normalizeUserReport,
  reportUserContentCore,
  unblockUserCore,
  UserSafetyError,
};
