const {createHash} = require("crypto");

const {COLLECTIONS} = require("./firestore_contract");

const TRUSTED_AUDIT_SOURCE = "trustedOperation";
const TRUSTED_AUDIT_VERSION = 1;
const MAX_AUDIT_MAP_BYTES = 8 * 1024;
const MAX_AUDIT_MAP_KEYS = 24;
const MAX_AUDIT_DEPTH = 4;
const MAX_AUDIT_STRING_LENGTH = 512;

const ALLOWED_ENTITY_TYPES = new Set([
  "match",
  "moderationReport",
  "safetyRelationship",
  "guestPlayer",
  "guestTeam",
  "claimCode",
  "accountDeletion",
]);
const ALLOWED_ACTIONS = new Set([
  "matchScoreSubmitted",
  "matchScoreApproved",
  "profileReported",
  "playerBlocked",
  "playerUnblocked",
  "guestPlayerClaimed",
  "guestTeamClaimed",
  "claimCodeConsumed",
  "accountDeletionRequested",
  "accountDeletionProcessing",
  "accountDeletionCompleted",
  "accountDeletionFailed",
]);
const ACTION_ENTITY_TYPES = new Map([
  ["matchScoreSubmitted", new Set(["match"])],
  ["matchScoreApproved", new Set(["match"])],
  ["profileReported", new Set(["moderationReport"])],
  ["playerBlocked", new Set(["safetyRelationship"])],
  ["playerUnblocked", new Set(["safetyRelationship"])],
  ["guestPlayerClaimed", new Set(["guestPlayer"])],
  ["guestTeamClaimed", new Set(["guestTeam"])],
  ["claimCodeConsumed", new Set(["claimCode"])],
  ["accountDeletionRequested", new Set(["accountDeletion"])],
  ["accountDeletionProcessing", new Set(["accountDeletion"])],
  ["accountDeletionCompleted", new Set(["accountDeletion"])],
  ["accountDeletionFailed", new Set(["accountDeletion"])],
]);

/**
 * Stages one immutable, trusted audit event in the caller's transaction.
 *
 * This is deliberately an internal module, not a callable. The operation core
 * supplies actorId from authenticated context and supplies the remaining
 * fields from documents and values already validated inside the transaction.
 */
function appendAuditEvent(auditWriteRequest) {
  const {transaction, db} = auditWriteRequest;
  assertAuditWriterDependencies({transaction, db});
  const identity = normalizedAuditIdentity(auditWriteRequest);
  assertAuditMap(auditWriteRequest.beforePayload, "beforePayload");
  assertAuditMap(auditWriteRequest.afterPayload, "afterPayload");
  assertAuditMap(auditWriteRequest.metadata, "metadata");
  const eventId = trustedAuditEventId(identity);
  transaction.create(
    db.collection(COLLECTIONS.auditEvents).doc(eventId),
    trustedAuditDocument(auditWriteRequest, identity),
  );
}

function assertAuditWriterDependencies({transaction, db}) {
  if (!transaction || typeof transaction.create !== "function") {
    throw new TrustedAuditError("A transaction with create() is required.");
  }
  if (!db || typeof db.collection !== "function") {
    throw new TrustedAuditError("Firestore is required.");
  }
}

function normalizedAuditIdentity(auditWriteRequest) {
  const entityType = allowedValue(
    auditWriteRequest.entityType,
    "entityType",
    ALLOWED_ENTITY_TYPES,
  );
  const action = allowedValue(
    auditWriteRequest.action,
    "action",
    ALLOWED_ACTIONS,
  );
  assertActionEntityType({action, entityType});
  return {
    entityType,
    entityId: boundedString(auditWriteRequest.entityId, "entityId", 256),
    action,
    actorId: boundedString(auditWriteRequest.actorId, "actorId", 128),
    requestId: boundedString(auditWriteRequest.requestId, "requestId", 256),
    createdAt: finiteTimestamp(auditWriteRequest.createdAt),
  };
}

function assertActionEntityType({action, entityType}) {
  if (!ACTION_ENTITY_TYPES.get(action).has(entityType)) {
    throw new TrustedAuditError("action is invalid for entityType.");
  }
}

function trustedAuditDocument(auditWriteRequest, identity) {
  return {
    entityType: identity.entityType,
    entityId: identity.entityId,
    action: identity.action,
    actorId: identity.actorId,
    beforePayload: auditWriteRequest.beforePayload,
    afterPayload: auditWriteRequest.afterPayload,
    metadata: auditWriteRequest.metadata,
    source: TRUSTED_AUDIT_SOURCE,
    verificationVersion: TRUSTED_AUDIT_VERSION,
    requestId: identity.requestId,
    createdAt: identity.createdAt,
  };
}

function trustedAuditEventId({entityType, entityId, action, requestId}) {
  const fingerprint = createHash("sha256")
    .update(JSON.stringify([entityType, entityId, action, requestId]))
    .digest("hex")
    .slice(0, 40);
  return `trusted-audit-${fingerprint}`;
}

function allowedValue(candidate, fieldName, allowed) {
  const normalized = boundedString(candidate, fieldName, 64);
  if (!allowed.has(normalized)) {
    throw new TrustedAuditError(`${fieldName} is not allowed.`);
  }
  return normalized;
}

function boundedString(candidate, fieldName, maxLength) {
  if (typeof candidate !== "string") {
    throw new TrustedAuditError(`${fieldName} must be a string.`);
  }
  const normalized = candidate.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new TrustedAuditError(`${fieldName} is invalid.`);
  }
  return normalized;
}

function finiteTimestamp(candidate) {
  const normalized = Number(candidate);
  if (!Number.isFinite(normalized) || normalized < 0) {
    throw new TrustedAuditError("createdAt must be a finite server timestamp.");
  }
  return normalized;
}

function assertAuditMap(auditMap, fieldName) {
  if (auditMap == null) {
    return;
  }
  if (!isPlainObject(auditMap)) {
    throw new TrustedAuditError(`${fieldName} must be a plain map or null.`);
  }
  if (Object.keys(auditMap).length > MAX_AUDIT_MAP_KEYS) {
    throw new TrustedAuditError(`${fieldName} has too many keys.`);
  }
  assertAuditValue(auditMap, fieldName, 0);
  if (Buffer.byteLength(JSON.stringify(auditMap), "utf8") > MAX_AUDIT_MAP_BYTES) {
    throw new TrustedAuditError(`${fieldName} is too large.`);
  }
}

function assertAuditValue(auditValue, fieldName, depth) {
  if (depth > MAX_AUDIT_DEPTH) {
    throw new TrustedAuditError(`${fieldName} is too deeply nested.`);
  }
  if (auditValue == null || typeof auditValue === "boolean") {
    return;
  }
  if (typeof auditValue === "number") {
    if (!Number.isFinite(auditValue)) {
      throw new TrustedAuditError(`${fieldName} contains a non-finite number.`);
    }
    return;
  }
  if (typeof auditValue === "string") {
    if (auditValue.length > MAX_AUDIT_STRING_LENGTH) {
      throw new TrustedAuditError(`${fieldName} contains an oversized string.`);
    }
    return;
  }
  if (Array.isArray(auditValue)) {
    if (auditValue.length > MAX_AUDIT_MAP_KEYS) {
      throw new TrustedAuditError(`${fieldName} contains an oversized list.`);
    }
    auditValue.forEach((entry) => assertAuditValue(entry, fieldName, depth + 1));
    return;
  }
  if (isPlainObject(auditValue)) {
    if (Object.keys(auditValue).length > MAX_AUDIT_MAP_KEYS) {
      throw new TrustedAuditError(`${fieldName} has too many nested keys.`);
    }
    Object.values(auditValue).forEach((entry) => {
      assertAuditValue(entry, fieldName, depth + 1);
    });
    return;
  }
  throw new TrustedAuditError(`${fieldName} contains an unsupported value.`);
}

function isPlainObject(candidate) {
  if (!candidate || typeof candidate !== "object") {
    return false;
  }
  const prototype = Object.getPrototypeOf(candidate);
  return prototype === Object.prototype || prototype === null;
}

class TrustedAuditError extends Error {}

module.exports = {
  appendAuditEvent,
  trustedAuditEventId,
  TrustedAuditError,
  TRUSTED_AUDIT_SOURCE,
  TRUSTED_AUDIT_VERSION,
};
