const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldValue,
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const functions = require("firebase-functions/v1");
const {defineSecret} = require("firebase-functions/params");

const {
  approveMatchScoreCore,
} = require("./approval_core");
const {SettlementError} = require("./settlement_error");
const {submitMatchSettlementCore} = require("./settlement_core");
const {
  accountDeletionEventShouldRun,
  createAccountDeletionStages,
  processAccountDeletionRequestCore,
  requestAccountDeletionCore,
} = require("./account_deletion");
const {
  blockUserCore,
  reportUserContentCore,
  unblockUserCore,
  UserSafetyError,
} = require("./user_safety");
const {
  claimGuestPlayerCore,
  claimGuestTeamCore,
  inspectGuestClaimCore,
  issueGuestClaimCodeCore,
  GuestClaimError,
} = require("./guest_claim");
const app = initializeApp();

const db = getFirestore(app);
const guestClaimTokenSecret = defineSecret("GUEST_CLAIM_TOKEN_SECRET");

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

exports.deleteAccountData = functions.https.onCall(async (_data, context) => {
  const uid = requireAuth(context);
  return requestAccountDeletionCore({
    db,
    uid,
    now: () => Timestamp.now().toMillis(),
  });
});

exports.processAccountDeletionRequest = functions
  .runWith({timeoutSeconds: 540, memory: "1GB", failurePolicy: true})
  .firestore.document("accountDeletionRequests/{requestId}")
  .onWrite(async (change, context) => {
    if (!accountDeletionEventShouldRun(change)) return null;
    return processAccountDeletionRequestCore({
      db,
      requestId: context.params.requestId,
      stages: createAccountDeletionStages({
        db,
        auth: getAuth(app),
        bucket: getStorage(app).bucket(),
        fieldValue: FieldValue,
      }),
      now: () => Timestamp.now().toMillis(),
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
      now: () => Timestamp.now().toMillis(),
    });
  } catch (error) {
    if (error instanceof UserSafetyError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.unblockUser = functions.https.onCall(async (data, context) => {
  const blockerId = requireAuth(context);
  try {
    return await unblockUserCore({
      db,
      blockerId,
      blockedId: data && data.blockedId,
      now: () => Timestamp.now().toMillis(),
    });
  } catch (error) {
    if (error instanceof UserSafetyError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
});

exports.issueGuestClaimCode = functions
  .runWith({secrets: [guestClaimTokenSecret]})
  .https.onCall(async (data, context) => {
    const actorId = requireAuth(context);
    return invokeGuestClaim(() => issueGuestClaimCodeCore({
      db,
      actorId,
      payload: data,
      now: () => Timestamp.now().toMillis(),
      tokenSecret: guestClaimTokenSecret.value(),
    }));
  });

exports.inspectGuestClaim = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  return invokeGuestClaim(() => inspectGuestClaimCore({
    db,
    actorId,
    payload: data,
    now: () => Timestamp.now().toMillis(),
  }));
});

exports.claimGuestPlayer = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  return invokeGuestClaim(() => claimGuestPlayerCore({
    db,
    actorId,
    payload: data,
    now: () => Timestamp.now().toMillis(),
  }));
});

exports.claimGuestTeam = functions.https.onCall(async (data, context) => {
  const actorId = requireAuth(context);
  return invokeGuestClaim(() => claimGuestTeamCore({
    db,
    actorId,
    payload: data,
    now: () => Timestamp.now().toMillis(),
  }));
});

async function invokeGuestClaim(operation) {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof GuestClaimError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    throw error;
  }
}

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
