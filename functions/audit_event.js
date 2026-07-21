const MAX_PAYLOAD_BYTES = 20_000;

function normalizeAuditEventPayload(data, actorId, createdAt) {
  const source = isPlainObject(data) ? data : {};
  return {
    entityType: requiredText(source.entityType, "entityType", 64),
    entityId: requiredText(source.entityId, "entityId", 160),
    action: requiredText(source.action, "action", 64),
    actorId,
    beforePayload: optionalPayload(source.beforePayload, "beforePayload"),
    afterPayload: optionalPayload(source.afterPayload, "afterPayload"),
    metadata: optionalPayload(source.metadata, "metadata"),
    createdAt,
  };
}

function requiredText(value, fieldName, maxLength) {
  const normalized = String(value || "").trim();
  if (!normalized || normalized.length > maxLength) {
    throw new AuditEventError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function optionalPayload(value, fieldName) {
  if (value == null) return null;
  if (!isPlainObject(value)) {
    throw new AuditEventError("invalid-argument", `${fieldName} is invalid.`);
  }
  const bytes = Buffer.byteLength(JSON.stringify(value), "utf8");
  if (bytes > MAX_PAYLOAD_BYTES) {
    throw new AuditEventError("invalid-argument", `${fieldName} is too large.`);
  }
  return value;
}

function isPlainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

class AuditEventError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

module.exports = {
  AuditEventError,
  normalizeAuditEventPayload,
};
