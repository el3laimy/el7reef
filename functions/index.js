const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const functions = require("firebase-functions/v1");

const {
  approveMatchScoreCore,
} = require("./approval_core");
const {SettlementError} = require("./settlement_error");
const {submitMatchSettlementCore} = require("./settlement_core");
const {deleteAccountDataCore} = require("./account_deletion");
const {
  blockUserCore,
  reportUserContentCore,
  UserSafetyError,
} = require("./user_safety");
const {
  AuditEventError,
  normalizeAuditEventPayload,
} = require("./audit_event");

admin.initializeApp();

const db = admin.firestore();

exports.submitMatchSettlement = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  try {
    return await submitMatchSettlementCore({
      db,
      actorId,
      payload: data,
      now: () => Timestamp.now().toMillis(),
    });
  } catch (error) {
    if (error instanceof SettlementError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.approveMatchScore = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  const matchId = requiredString(data && data.matchId, "matchId");
  try {
    return await approveMatchScoreCore({
      db,
      actorId,
      matchId,
      now: () => Timestamp.now().toMillis(),
    });
  } catch (error) {
    if (error instanceof SettlementError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.recordAuditEvent = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  const createdAt = Timestamp.now().toMillis();
  try {
    const event = normalizeAuditEventPayload(data, actorId, createdAt);
    const eventRef = db.collection("auditEvents").doc();
    await eventRef.set(event);
    return {id: eventRef.id};
  } catch (error) {
    if (error instanceof AuditEventError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.deleteAccountData = functions
  .runWith({timeoutSeconds: 540, memory: "1GB"})
  .https.onCall(async (_data, context) => {
    const uid = requireAuth(context);
    return deleteAccountDataCore({
      db,
      auth: admin.auth(),
      bucket: admin.storage().bucket(),
      uid,
      fieldValue: FieldValue,
    });
  });

exports.reportUserContent = functions.https.onCall(async (data, context) => {
  const reporterId = requireAuth(context);
  try {
    return await reportUserContentCore({
      db,
      reportPayload: data,
      reporterId,
      now: () => Timestamp.now().toMillis(),
    });
  } catch (error) {
    if (error instanceof UserSafetyError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.blockUser = functions.https.onCall(async (data, context) => {
  const blockerId = requireAuth(context);
  try {
    return await blockUserCore({
      db,
      blockerId,
      blockedId: data && data.blockedId,
      fieldValue: FieldValue,
      now: Timestamp.now(),
    });
  } catch (error) {
    if (error instanceof UserSafetyError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

function requireAuth(context) {
  const uid = context && context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }
  return uid;
}

function requiredString(value, fieldName) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${fieldName} is required.`,
    );
  }
  return normalized;
}
