const crypto = require("crypto");

const ALLOWED_REASONS = new Set([
  "harassment",
  "impersonation",
  "inappropriate",
  "spam",
  "other",
]);
const ALLOWED_TARGET_KINDS = new Set(["registeredPlayer", "guestPlayer"]);

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
  const reportRef = db.collection("userReports").doc(report.id);
  const existing = await reportRef.get();
  if (existing.exists) {
    return {accepted: true, reportId: report.id, duplicate: true};
  }
  try {
    await reportRef.create({
      ...report,
      createdAt,
      updatedAt: createdAt,
    });
  } catch (error) {
    if (error && (error.code === 6 || error.code === "already-exists")) {
      return {accepted: true, reportId: report.id, duplicate: true};
    }
    throw error;
  }
  return {accepted: true, reportId: report.id, duplicate: false};
}

async function blockUserCore({db, blockerId, blockedId, fieldValue, now}) {
  const normalizedBlockedId = requiredText(blockedId, "blockedId", 160);
  if (normalizedBlockedId === blockerId) {
    throw new UserSafetyError("invalid-argument", "Cannot block yourself.");
  }
  const blockerRef = db.collection("players").doc(blockerId);
  const blockedRef = db.collection("players").doc(normalizedBlockedId);
  const [blocker, blocked] = await Promise.all([
    blockerRef.get(),
    blockedRef.get(),
  ]);
  if (!blocker.exists || !blocked.exists) {
    throw new UserSafetyError("not-found", "Player not found.");
  }

  const ids = [blockerId, normalizedBlockedId].sort();
  const friendshipRef = db.collection("friendships").doc(ids.join("_"));
  const batch = db.batch();
  batch.set(friendshipRef, {
    userId1: ids[0],
    userId2: ids[1],
    participants: ids,
    status: "blocked",
    lastActionBy: blockerId,
    createdAt: now,
    updatedAt: now,
  });
  batch.update(blockerRef, {
    friendIds: fieldValue.arrayRemove(normalizedBlockedId),
    blockedIds: fieldValue.arrayUnion(normalizedBlockedId),
  });
  batch.update(blockedRef, {
    friendIds: fieldValue.arrayRemove(blockerId),
  });
  await batch.commit();
  return {blocked: true};
}

function requiredEnum(value, fieldName, allowed) {
  const normalized = requiredText(value, fieldName, 64);
  if (!allowed.has(normalized)) {
    throw new UserSafetyError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function requiredText(value, fieldName, maxLength) {
  const normalized = String(value || "").trim();
  if (!normalized || normalized.length > maxLength) {
    throw new UserSafetyError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function optionalText(value, maxLength) {
  const normalized = String(value || "").trim();
  return normalized.slice(0, maxLength);
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
  UserSafetyError,
};
