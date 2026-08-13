const {createHash} = require("crypto");

const {
  COLLECTIONS,
  EVENT_STATUS,
  EVENT_TYPE,
  MATCH_STATUS,
  SIDE_KEYS,
} = require("./firestore_contract");
const {
  loadCanonicalMatchRoster,
  registeredPlayerIdsForSide,
} = require("./match_roster");
const {SettlementError} = require("./settlement_error");
const {appendAuditEvent} = require("./trusted_audit");
const {
  SettlementPayloadError,
  assertSettlementParticipantsInRoster,
  goalEventId,
  mvpEventId,
  normalizeDetailedStats,
  normalizeGoalDrafts,
  normalizeMvpDraft,
} = require("./settlement_payload");

const MAX_SCORE = 99;
const ACTIVE_EVENT_READ_LIMIT = MAX_SCORE * 2 + 7;
const SUBMIT_PERMISSIONS = ["canSubmitScore", "canRecordGoalsAndMvp"];
const FINAL_SETTLEMENT_STATUSES = new Set([
  MATCH_STATUS.completed,
  MATCH_STATUS.pendingReview,
  MATCH_STATUS.settled,
]);

async function submitMatchSettlementCore({db, actorId, payload, now}) {
  const normalizedActorId = requiredString(actorId, "actorId");
  const request = normalizeSubmitRequest(payload);
  const fingerprint = settlementFingerprint(request);
  const submittedAt = normalizeNow(now);

  return db.runTransaction((tx) => settleMatchTransaction({
    db,
    tx,
    actorId: normalizedActorId,
    request,
    fingerprint,
    submittedAt,
  }));
}

async function settleMatchTransaction({
  db,
  tx,
  actorId,
  request,
  fingerprint,
  submittedAt,
}) {
  const {matchRef, match} = await loadAuthorizedMatch({
    db,
    tx,
    matchId: request.matchId,
    actorId,
  });
  const retryResponse = settlementRetryResponse(match, fingerprint);
  if (retryResponse) {
    return retryResponse;
  }
  assertMatchAcceptsSubmission(match);
  const submissionData = await validatedSubmissionData({
    db,
    tx,
    match,
    request,
  });
  const storedDocuments = await loadStoredSettlementDocuments({
    db,
    tx,
    matchId: request.matchId,
  });
  const status = resultStatus(request.scoreA, request.scoreB);
  const knockoutDecision = resolveKnockoutSubmission({match, request});

  writeSettlement({
    tx,
    db,
    matchRef,
    match,
    request,
    ...submissionData,
    ...storedDocuments,
    actorId,
    fingerprint,
    submittedAt,
    status,
    knockoutDecision,
  });
  return settlementResponse(status, false);
}

async function loadAuthorizedMatch({db, tx, matchId, actorId}) {
  const matchRef = db.collection(COLLECTIONS.matches).doc(matchId);
  const matchSnapshot = await tx.get(matchRef);
  if (!matchSnapshot.exists) {
    throw new SettlementError("not-found", "Match not found.");
  }
  const match = matchSnapshot.data();
  await assertCanManageSubmission({tx, db, match, actorId});
  return {matchRef, match};
}

async function validatedSubmissionData({db, tx, match, request}) {
  const roster = await loadCanonicalMatchRoster({
    db,
    tx,
    matchId: request.matchId,
    match,
  });
  assertSettlementParticipantsInRoster({...request, roster});
  assertGoalTotalsWithinScore(request);
  return {
    detailedStats: bindDetailedStatsToRoster({
      detailedStats: request.detailedStats,
      roster,
      match,
      matchId: request.matchId,
    }),
    eligiblePlayerIds: registeredEligibility(roster),
  };
}

async function loadStoredSettlementDocuments({db, tx, matchId}) {
  const activeEvents = await tx.get(activeEventsQuery(db, matchId));
  const fanVotingRef = db
    .collection(COLLECTIONS.fanVotingSessions)
    .doc(matchId);
  const fanVotingSnapshot = await tx.get(fanVotingRef);
  return {activeEvents, fanVotingRef, fanVotingSnapshot};
}

function normalizeSubmitRequest(payload) {
  const matchId = requiredString(payload && payload.matchId, "matchId");
  const request = {
    matchId,
    scoreA: requiredScore(payload && payload.scoreA, "scoreA"),
    scoreB: requiredScore(payload && payload.scoreB, "scoreB"),
    penaltyScoreTeamA: optionalScore(
      payload && payload.penaltyScoreTeamA,
      "penaltyScoreTeamA",
    ),
    penaltyScoreTeamB: optionalScore(
      payload && payload.penaltyScoreTeamB,
      "penaltyScoreTeamB",
    ),
    mvpPlayerId: optionalId(payload && payload.mvpPlayerId, "mvpPlayerId"),
    detailedStats: normalizeDetailedStats(payload && payload.detailedStats, matchId),
    goals: normalizeGoalDrafts(payload && payload.goals),
    mvp: normalizeMvpDraft(payload && payload.mvp),
  };
  if (
    request.mvp &&
    request.mvpPlayerId &&
    request.mvp.actor.id !== request.mvpPlayerId
  ) {
    throw new SettlementPayloadError("mvp and mvpPlayerId must match");
  }
  return request;
}

function settlementFingerprint(request) {
  const canonicalPayload = {
    ...request,
    goals: [...request.goals].sort(compareCanonicalValues),
    detailedStats: [...request.detailedStats].sort(compareCanonicalValues),
  };
  return createHash("sha256")
    .update(JSON.stringify(canonicalPayload))
    .digest("hex");
}

function compareCanonicalValues(left, right) {
  const encodedLeft = JSON.stringify(left);
  const encodedRight = JSON.stringify(right);
  if (encodedLeft === encodedRight) {
    return 0;
  }
  return encodedLeft < encodedRight ? -1 : 1;
}

async function assertCanManageSubmission({tx, db, match, actorId}) {
  if (match.organizerId === actorId) {
    return;
  }
  const tournamentId = optionalId(match.tournamentId, "tournamentId");
  if (!tournamentId) {
    throw new SettlementError("permission-denied", "Not allowed.");
  }
  const tournamentRef = db.collection(COLLECTIONS.tournaments).doc(tournamentId);
  const tournamentSnapshot = await tx.get(tournamentRef);
  if (
    tournamentSnapshot.exists &&
    tournamentSnapshot.data().organizerId === actorId
  ) {
    return;
  }
  const assistantSnapshot = await tx.get(
    tournamentRef.collection("assistants").doc(actorId),
  );
  if (!assistantCanSubmit(assistantSnapshot)) {
    throw new SettlementError("permission-denied", "Not allowed.");
  }
}

function assistantCanSubmit(snapshot) {
  if (!snapshot.exists) {
    return false;
  }
  const assistant = snapshot.data();
  return (
    assistant.status === "active" &&
    assistant.permissions &&
    SUBMIT_PERMISSIONS.every(
      (permission) => assistant.permissions[permission] === true,
    )
  );
}

function settlementRetryResponse(match, fingerprint) {
  if (!FINAL_SETTLEMENT_STATUSES.has(match.status)) {
    return null;
  }
  if (match.settlementSubmissionFingerprint !== fingerprint) {
    throw new SettlementError(
      "failed-precondition",
      "Match already has a different settlement.",
    );
  }
  return {
    status: match.status,
    ratingsApplied: match.ratingsAppliedAt != null,
    alreadySettled: true,
    prideEventsPending: match.prideEventsPending === true,
  };
}

function assertMatchAcceptsSubmission(match) {
  if (match.isFrozen === true || match.status === MATCH_STATUS.frozen) {
    throw new SettlementError(
      "failed-precondition",
      "Frozen matches cannot accept score submissions.",
    );
  }
  if (match.status !== MATCH_STATUS.live) {
    throw new SettlementError(
      "failed-precondition",
      "Match is not open for score submission.",
    );
  }
}

function assertGoalTotalsWithinScore(request) {
  const totals = {A: 0, B: 0};
  for (const goal of request.goals) {
    totals[goal.sideKey] += goal.goals;
  }
  if (totals.A > request.scoreA || totals.B > request.scoreB) {
    throw new SettlementPayloadError(
      "attributed goals cannot exceed the submitted score",
    );
  }
}

function resolveKnockoutSubmission({match, request}) {
  const hasPenaltyA = request.penaltyScoreTeamA != null;
  const hasPenaltyB = request.penaltyScoreTeamB != null;
  if (hasPenaltyA !== hasPenaltyB) {
    throw new SettlementPayloadError(
      "both penalty shootout scores are required",
    );
  }

  if (match.stageType !== "knockoutStage") {
    if (hasPenaltyA) {
      throw new SettlementPayloadError(
        "penalty shootouts are only valid for knockout matches",
      );
    }
    return null;
  }
  if (request.scoreA !== request.scoreB) {
    if (hasPenaltyA) {
      throw new SettlementPayloadError(
        "penalty shootouts are not valid after a regulation-time winner",
      );
    }
    return request.scoreA > request.scoreB ? "teamA" : "teamB";
  }
  if (!hasPenaltyA || request.penaltyScoreTeamA === request.penaltyScoreTeamB) {
    throw new SettlementPayloadError(
      "a tied knockout match requires a decisive penalty shootout",
    );
  }
  return request.penaltyScoreTeamA > request.penaltyScoreTeamB
    ? "teamA"
    : "teamB";
}

function bindDetailedStatsToRoster({detailedStats, roster, match, matchId}) {
  return detailedStats.map((stats) => {
    const sideKey = registeredPlayerSide(roster, stats.playerId);
    const teamId = sideKey === "A" ? match.teamAId || "A" : match.teamBId || "B";
    return {...stats, matchId, teamId};
  });
}

function registeredPlayerSide(roster, playerId) {
  const playerKey = `player:${playerId}`;
  const sides = SIDE_KEYS.filter((sideKey) => roster.keysBySide[sideKey].has(playerKey));
  if (sides.length !== 1) {
    throw new SettlementError(
      "failed-precondition",
      "Registered player must belong to exactly one match side.",
    );
  }
  return sides[0];
}

function registeredEligibility(roster) {
  return [...new Set(SIDE_KEYS.flatMap(
    (sideKey) => registeredPlayerIdsForSide(roster, sideKey),
  ))];
}

function activeEventsQuery(db, matchId) {
  return db
    .collection(COLLECTIONS.matchEvents)
    .where("matchId", "==", matchId)
    .where("status", "==", EVENT_STATUS.active)
    .limit(ACTIVE_EVENT_READ_LIMIT);
}

function writeSettlement({
  tx,
  db,
  matchRef,
  match,
  request,
  detailedStats,
  eligiblePlayerIds,
  fanVotingRef,
  fanVotingSnapshot,
  activeEvents,
  actorId,
  fingerprint,
  submittedAt,
  status,
  knockoutDecision,
}) {
  writeMatchSettlement({
    tx,
    matchRef,
    request,
    actorId,
    fingerprint,
    submittedAt,
    status,
    knockoutDecision,
  });
  writeDetailedStats({tx, db, matchId: request.matchId, detailedStats});
  writePrideEvents({
    tx,
    db,
    match,
    request,
    activeEvents,
    actorId,
    submittedAt,
  });
  ensureFanVotingSession({
    tx,
    fanVotingRef,
    fanVotingSnapshot,
    matchId: request.matchId,
    eligiblePlayerIds,
    openedAt: submittedAt,
  });
  appendAuditEvent({
    transaction: tx,
    db,
    entityType: "match",
    entityId: request.matchId,
    action: "matchScoreSubmitted",
    actorId,
    beforePayload: {
      status: match.status,
      scoreTeamA: match.scoreTeamA == null ? null : match.scoreTeamA,
      scoreTeamB: match.scoreTeamB == null ? null : match.scoreTeamB,
      penaltyScoreTeamA: match.penaltyScoreTeamA == null
        ? null
        : match.penaltyScoreTeamA,
      penaltyScoreTeamB: match.penaltyScoreTeamB == null
        ? null
        : match.penaltyScoreTeamB,
    },
    afterPayload: {
      status,
      scoreTeamA: request.scoreA,
      scoreTeamB: request.scoreB,
      penaltyScoreTeamA: request.penaltyScoreTeamA,
      penaltyScoreTeamB: request.penaltyScoreTeamB,
      knockoutDecision,
    },
    metadata: {
      tournamentId: match.tournamentId || null,
      stageType: match.stageType || null,
    },
    requestId: `match-settlement:${fingerprint}`,
    createdAt: submittedAt,
  });
}

function writeMatchSettlement({
  tx,
  matchRef,
  request,
  actorId,
  fingerprint,
  submittedAt,
  status,
  knockoutDecision,
}) {
  tx.update(matchRef, {
    scoreTeamA: request.scoreA,
    scoreTeamB: request.scoreB,
    penaltyScoreTeamA: request.penaltyScoreTeamA,
    penaltyScoreTeamB: request.penaltyScoreTeamB,
    knockoutDecision,
    mvpPlayerId: request.mvp ? request.mvp.actor.id : request.mvpPlayerId,
    prideEventsPending: false,
    completedAt: submittedAt,
    isAnomaly: status === MATCH_STATUS.pendingReview,
    status,
    settlementSubmissionFingerprint: fingerprint,
    settlementSubmittedAt: submittedAt,
    settlementSubmittedBy: actorId,
  });
}

function writeDetailedStats({tx, db, matchId, detailedStats}) {
  for (const stats of detailedStats) {
    tx.set(
      db
        .collection(COLLECTIONS.matches)
        .doc(matchId)
        .collection(COLLECTIONS.playerStats)
        .doc(stats.playerId),
      stats,
    );
  }
}

function writePrideEvents({
  tx,
  db,
  match,
  request,
  activeEvents,
  actorId,
  submittedAt,
}) {
  voidReplacedPrideEvents({
    tx,
    activeEvents,
    matchId: request.matchId,
    hasMvp: request.mvp != null,
  });
  writeGoalEvents({tx, db, match, request, actorId, submittedAt});
  writeMvpEvent({tx, db, match, request, actorId, submittedAt});
}

function voidReplacedPrideEvents({tx, activeEvents, matchId, hasMvp}) {
  activeEvents.forEach((snapshot) => {
    const eventType = snapshot.data().eventType;
    const isReplacedGoal = eventType === EVENT_TYPE.goal;
    const isReplacedMvp = eventType === EVENT_TYPE.mvp && (
      !hasMvp || snapshot.id !== mvpEventId(matchId)
    );
    if (isReplacedGoal || isReplacedMvp) {
      tx.update(snapshot.ref, {status: EVENT_STATUS.voided});
    }
  });
}

function writeGoalEvents({tx, db, match, request, actorId, submittedAt}) {
  for (const goal of request.goals) {
    for (let index = 1; index <= goal.goals; index += 1) {
      const eventRef = db.collection(COLLECTIONS.matchEvents).doc(goalEventId({
        matchId: request.matchId,
        sideKey: goal.sideKey,
        actor: goal.actor,
        index,
      }));
      tx.set(eventRef, prideEventData({
        match,
        matchId: request.matchId,
        eventType: EVENT_TYPE.goal,
        sideKey: goal.sideKey,
        actor: goal.actor,
        minute: goal.minute,
        actorId,
        submittedAt,
      }));
    }
  }
}

function writeMvpEvent({tx, db, match, request, actorId, submittedAt}) {
  if (!request.mvp) {
    return;
  }
  const eventRef = db
    .collection(COLLECTIONS.matchEvents)
    .doc(mvpEventId(request.matchId));
  tx.set(eventRef, prideEventData({
    match,
    matchId: request.matchId,
    eventType: EVENT_TYPE.mvp,
    sideKey: request.mvp.sideKey,
    actor: request.mvp.actor,
    minute: null,
    actorId,
    submittedAt,
  }));
}

function prideEventData({
  match,
  matchId,
  eventType,
  sideKey,
  actor,
  minute,
  actorId,
  submittedAt,
}) {
  return {
    matchId,
    tournamentId: match.tournamentId || null,
    eventType,
    sideKey,
    actor,
    minute,
    createdBy: actorId,
    createdAt: submittedAt,
    status: EVENT_STATUS.active,
  };
}

function ensureFanVotingSession({
  tx,
  fanVotingRef,
  fanVotingSnapshot,
  matchId,
  eligiblePlayerIds,
  openedAt,
}) {
  if (fanVotingSnapshot.exists || eligiblePlayerIds.length === 0) {
    return;
  }
  tx.set(fanVotingRef, {
    matchId,
    opensAt: openedAt,
    closesAt: openedAt + 90 * 60 * 1000,
    totalVotes: 0,
    playerVotes: {},
    eligiblePlayerIds,
    winnerPlayerId: null,
  });
}

function resultStatus(scoreA, scoreB) {
  const isAnomaly = (
    Math.abs(scoreA - scoreB) >= 10 ||
    scoreA >= 20 ||
    scoreB >= 20
  );
  return isAnomaly ? MATCH_STATUS.pendingReview : MATCH_STATUS.completed;
}

function settlementResponse(status, alreadySettled) {
  return {
    status,
    ratingsApplied: false,
    alreadySettled,
    prideEventsPending: false,
  };
}

function requiredString(rawValue, fieldName) {
  const normalized = String(rawValue || "").trim();
  if (!normalized) {
    throw new SettlementPayloadError(`${fieldName} is required.`);
  }
  if (normalized.length > 128) {
    throw new SettlementPayloadError(`${fieldName} is too long.`);
  }
  return normalized;
}

function optionalId(rawValue, fieldName) {
  if (rawValue == null) {
    return null;
  }
  if (typeof rawValue !== "string") {
    throw new SettlementPayloadError(`${fieldName} is invalid.`);
  }
  const normalized = rawValue.trim();
  if (normalized.length > 128) {
    throw new SettlementPayloadError(`${fieldName} is too long.`);
  }
  return normalized || null;
}

function requiredScore(rawValue, fieldName) {
  if (!Number.isInteger(rawValue) || rawValue < 0 || rawValue > MAX_SCORE) {
    throw new SettlementPayloadError(
      `${fieldName} must be an integer between 0 and ${MAX_SCORE}.`,
    );
  }
  return rawValue;
}

function optionalScore(rawValue, fieldName) {
  if (rawValue == null) {
    return null;
  }
  return requiredScore(rawValue, fieldName);
}

function normalizeNow(now) {
  const rawValue = typeof now === "function" ? now() : now;
  if (rawValue && typeof rawValue.toMillis === "function") {
    return rawValue.toMillis();
  }
  const normalized = Number(rawValue);
  if (!Number.isFinite(normalized)) {
    throw new SettlementError("internal", "Settlement clock is invalid.");
  }
  return normalized;
}

module.exports = {
  ACTIVE_EVENT_READ_LIMIT,
  normalizeSubmitRequest,
  settlementFingerprint,
  submitMatchSettlementCore,
};
