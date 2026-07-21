const {COLLECTIONS, MATCH_STATUS} = require("./firestore_contract");
const {
  loadCanonicalMatchRoster,
  registeredPlayerIdsForSide,
} = require("./match_roster");
const {SettlementError} = require("./settlement_error");

const DEFAULT_TIEBREAKERS = [
  "points",
  "goalDifference",
  "goalsFor",
  "randomDraw",
];
const MAX_SCORE = 99;

const RATING = {
  winScore: 25,
  drawScore: 10,
  loseScore: -10,
  mvpBonus: 15,
  difficultyMultiplierMin: 0.8,
  difficultyMultiplierMax: 1.5,
  trustWeightNew: 0.5,
  trustWeightActive: 1.0,
  trustWeightVeteran: 1.2,
};

async function approveMatchScoreCore({db, actorId, matchId, now}) {
  const normalizedActorId = requiredString(actorId, "actorId");
  const normalizedMatchId = requiredString(matchId, "matchId");
  const nowMs = normalizeNow(now);
  const matchRef = db.collection(COLLECTIONS.matches).doc(normalizedMatchId);

  return db.runTransaction(async (tx) => {
    const matchSnap = await tx.get(matchRef);
    if (!matchSnap.exists) {
      throw new SettlementError("not-found", "Match not found.");
    }
    const match = withId(matchSnap);
    const tournamentRef = nonEmpty(match.tournamentId)
      ? db.collection(COLLECTIONS.tournaments).doc(match.tournamentId)
      : null;
    const tournamentSnap = tournamentRef ? await tx.get(tournamentRef) : null;
    const tournament = tournamentSnap && tournamentSnap.exists
      ? withId(tournamentSnap)
      : null;
    const assistantSnap = tournamentRef
      ? await tx.get(tournamentRef.collection("assistants").doc(normalizedActorId))
      : null;
    const assistant = assistantSnap && assistantSnap.exists
      ? assistantSnap.data()
      : null;

    assertCanManageScore({
      match,
      tournament,
      assistant,
      actorId: normalizedActorId,
      permissions: ["canApproveScore"],
    });

    const alreadySettled = isSettled(match);
    const knockoutResolution = alreadySettled
      ? knockoutResolutionForMatch(match)
      : assertCanApproveScore(match);
    const settledMatch = matchAsSettled(match, knockoutResolution);

    const roster = await loadRegisteredRoster({tx, db, match});
    const fanVotingRef = db.collection(COLLECTIONS.fanVotingSessions).doc(match.id);
    const fanVotingSnap = await tx.get(fanVotingRef);
    const progressInputs = await loadProgressInputs({
      tx,
      db,
      match: settledMatch,
      tournament,
    });

    let ratingsApplied = Boolean(match.ratingsAppliedAt);
    if (!alreadySettled) {
      const fanWinnerId = resolveFanWinner({
        tx,
        fanVotingRef,
        fanVotingSnap,
        eligiblePlayerIds: new Set(roster.allPlayerIds),
        nowMs,
      });
      ratingsApplied = applyRatingDeltas({
        tx,
        db,
        match,
        roster,
        fanWinnerId,
        nowMs,
      });
      const matchUpdates = {
        status: MATCH_STATUS.settled,
        isAnomaly: false,
        ratingsAppliedAt: nowMs,
      };
      if (knockoutResolution) {
        matchUpdates.knockoutDecision = knockoutResolution.decision;
      }
      tx.update(matchRef, matchUpdates);
      writeApprovalAudit({
        tx,
        db,
        match: settledMatch,
        actorId: normalizedActorId,
        nowMs,
        knockoutResolution,
      });
    }

    writeTournamentProgress({
      tx,
      db,
      match: settledMatch,
      tournament,
      progressInputs,
      nowMs,
    });

    return {
      status: MATCH_STATUS.settled,
      ratingsApplied: alreadySettled ? true : ratingsApplied,
      alreadySettled,
      prideEventsPending: false,
    };
  });
}

function assertCanApproveScore(match) {
  if (match.isFrozen === true || match.status === "frozen") {
    throw new SettlementError(
      "failed-precondition",
      "Frozen matches cannot be approved.",
    );
  }
  if (
    match.status !== MATCH_STATUS.completed &&
    match.status !== MATCH_STATUS.pendingReview
  ) {
    throw new SettlementError(
      "failed-precondition",
      "Match score is not ready for approval.",
    );
  }
  if (!isValidScore(match.scoreTeamA) || !isValidScore(match.scoreTeamB)) {
    throw new SettlementError(
      "failed-precondition",
      "Match score is not ready for approval.",
    );
  }
  return validateKnockoutApproval(match);
}

function validateKnockoutApproval(match) {
  const hasPenaltyA = match.penaltyScoreTeamA != null;
  const hasPenaltyB = match.penaltyScoreTeamB != null;
  if (match.stageType !== "knockoutStage") {
    if (hasPenaltyA || hasPenaltyB || match.knockoutDecision != null) {
      throw new SettlementError(
        "failed-precondition",
        "Knockout decision data is not valid for this match.",
      );
    }
    return null;
  }

  if (match.scoreTeamA !== match.scoreTeamB) {
    if (hasPenaltyA || hasPenaltyB) {
      throw new SettlementError(
        "failed-precondition",
        "Penalty scores are not valid after a regulation-time winner.",
      );
    }
    const decision = match.scoreTeamA > match.scoreTeamB ? "teamA" : "teamB";
    assertStoredDecisionMatches(match.knockoutDecision, decision);
    return {decision, resolutionType: "regularTime"};
  }

  if (
    !isValidPenaltyScore(match.penaltyScoreTeamA) ||
    !isValidPenaltyScore(match.penaltyScoreTeamB) ||
    match.penaltyScoreTeamA === match.penaltyScoreTeamB
  ) {
    throw new SettlementError(
      "failed-precondition",
      "A tied knockout match requires a decisive penalty shootout.",
    );
  }
  const decision = match.penaltyScoreTeamA > match.penaltyScoreTeamB
    ? "teamA"
    : "teamB";
  assertStoredDecisionMatches(match.knockoutDecision, decision);
  return {decision, resolutionType: "penalties"};
}

function assertStoredDecisionMatches(storedDecision, expectedDecision) {
  if (storedDecision != null && storedDecision !== expectedDecision) {
    throw new SettlementError(
      "failed-precondition",
      "Knockout decision does not match the recorded score.",
    );
  }
}

function isValidPenaltyScore(value) {
  return isValidScore(value);
}

function isValidScore(value) {
  return Number.isInteger(value) && value >= 0 && value <= MAX_SCORE;
}

function writeApprovalAudit({
  tx,
  db,
  match,
  actorId,
  nowMs,
  knockoutResolution,
}) {
  const auditRef = db
    .collection(COLLECTIONS.auditEvents)
    .doc(`match-score-approved::${match.id}::${nowMs}`);
  tx.set(auditRef, {
    entityType: "match",
    entityId: match.id,
    action: "matchScoreApproved",
    actorId,
    beforePayload: null,
    afterPayload: {
      status: MATCH_STATUS.settled,
      scoreTeamA: match.scoreTeamA,
      scoreTeamB: match.scoreTeamB,
      penaltyScoreTeamA: match.penaltyScoreTeamA != null
        ? match.penaltyScoreTeamA
        : null,
      penaltyScoreTeamB: match.penaltyScoreTeamB != null
        ? match.penaltyScoreTeamB
        : null,
      knockoutDecision: knockoutResolution
        ? knockoutResolution.decision
        : null,
    },
    metadata: {
      tournamentId: match.tournamentId || null,
      knockoutTieId: match.knockoutTieId || null,
      knockoutResolution: knockoutResolution
        ? knockoutResolution.resolutionType
        : null,
    },
    createdAt: nowMs,
  });
}

function assertCanManageScore({match, tournament, assistant, actorId, permissions}) {
  if (match.organizerId === actorId) {
    return;
  }
  if (tournament && tournament.organizerId === actorId) {
    return;
  }
  if (nonEmpty(match.tournamentId) && !tournament) {
    throw new SettlementError("permission-denied", "Not allowed.");
  }
  const hasPermissions =
    assistant &&
    assistant.status === "active" &&
    assistant.permissions &&
    permissions.every((permission) => assistant.permissions[permission] === true);
  if (!hasPermissions) {
    throw new SettlementError("permission-denied", "Not allowed.");
  }
}

async function loadRegisteredRoster({tx, db, match}) {
  const roster = await loadCanonicalMatchRoster({
    tx,
    db,
    matchId: match.id,
    match,
  });
  const teamAPlayerIds = registeredPlayerIdsForSide(roster, "A");
  const teamBPlayerIds = registeredPlayerIdsForSide(roster, "B");
  const playerIds = [...new Set([...teamAPlayerIds, ...teamBPlayerIds])];
  const playersById = {};
  for (const playerId of playerIds) {
    const snapshot = await tx.get(db.collection(COLLECTIONS.players).doc(playerId));
    if (snapshot.exists) {
      playersById[playerId] = withId(snapshot);
    }
  }
  return {
    teamAPlayerIds,
    teamBPlayerIds,
    teamAPlayers: teamAPlayerIds.map((id) => playersById[id]).filter(Boolean),
    teamBPlayers: teamBPlayerIds.map((id) => playersById[id]).filter(Boolean),
    allPlayerIds: playerIds,
  };
}

function resolveFanWinner({tx, fanVotingRef, fanVotingSnap, eligiblePlayerIds, nowMs}) {
  if (!fanVotingSnap.exists || !fanVotingSnap.data()) {
    return null;
  }
  const session = fanVotingSnap.data();
  if (nonEmpty(session.winnerPlayerId)) {
    return session.winnerPlayerId;
  }
  const playerVotes = session.playerVotes || {};
  let winnerId = null;
  let maxVotes = -1;
  for (const [playerId, rawVotes] of Object.entries(playerVotes)) {
    if (!eligiblePlayerIds.has(playerId)) {
      continue;
    }
    const votes = Number(rawVotes);
    if (Number.isInteger(votes) && votes > maxVotes) {
      winnerId = playerId;
      maxVotes = votes;
    }
  }
  if (winnerId) {
    tx.update(fanVotingRef, {closesAt: nowMs, winnerPlayerId: winnerId});
    return winnerId;
  }
  tx.update(fanVotingRef, {closesAt: nowMs});
  return null;
}

function applyRatingDeltas({tx, db, match, roster, fanWinnerId, nowMs}) {
  const teamAPlayers = roster.teamAPlayers;
  const teamBPlayers = roster.teamBPlayers;
  if (teamAPlayers.length === 0 || teamBPlayers.length === 0) {
    return false;
  }
  const avgA = averageRating(teamAPlayers);
  const avgB = averageRating(teamBPlayers);
  const winner = matchWinner(match);
  for (const player of teamAPlayers) {
    const delta = calculateMatchDelta({
      player,
      match: {...match, isAnomaly: false},
      isWinner: winner === "A",
      isDraw: winner === "draw",
      isMvp: match.mvpPlayerId === player.id,
      difficultyMultiplier: computeDifficultyMultiplier(avgA, avgB),
      isFanMvp: fanWinnerId === player.id,
    });
    if (!delta.isBlocked) {
      updatePlayerAggregate({
        tx,
        db,
        player,
        isWin: winner === "A",
        isDraw: winner === "draw",
        isMvp: match.mvpPlayerId === player.id,
        ratingDelta: delta.delta,
        nowMs,
      });
    }
  }
  for (const player of teamBPlayers) {
    const delta = calculateMatchDelta({
      player,
      match: {...match, isAnomaly: false},
      isWinner: winner === "B",
      isDraw: winner === "draw",
      isMvp: match.mvpPlayerId === player.id,
      difficultyMultiplier: computeDifficultyMultiplier(avgB, avgA),
      isFanMvp: fanWinnerId === player.id,
    });
    if (!delta.isBlocked) {
      updatePlayerAggregate({
        tx,
        db,
        player,
        isWin: winner === "B",
        isDraw: winner === "draw",
        isMvp: match.mvpPlayerId === player.id,
        ratingDelta: delta.delta,
        nowMs,
      });
    }
  }
  return true;
}

function calculateMatchDelta({
  player,
  match,
  isWinner,
  isDraw,
  isMvp,
  difficultyMultiplier,
  isFanMvp,
}) {
  if (match.isAnomaly === true) {
    return {delta: 0, isBlocked: true};
  }
  const baseScore = isDraw
    ? RATING.drawScore
    : isWinner
      ? RATING.winScore
      : RATING.loseScore;
  let mvpBonus = isMvp ? RATING.mvpBonus : 0;
  if (isMvp && isFanMvp) {
    mvpBonus += 45;
  } else if (isFanMvp) {
    mvpBonus += 15;
  }
  const difficulty = clamp(
    difficultyMultiplier,
    RATING.difficultyMultiplierMin,
    RATING.difficultyMultiplierMax,
  );
  const raw =
    (baseScore + mvpBonus) *
    difficulty *
    trustWeight(player.trustLevel) *
    (match.isGoldenRating === true ? 2.0 : 1.0);
  return {delta: dartRound(raw), isBlocked: false};
}

function updatePlayerAggregate({
  tx,
  db,
  player,
  isWin,
  isDraw,
  isMvp,
  ratingDelta,
  nowMs,
}) {
  const updates = {
    rating: clampInt((Number(player.rating) || 1000) + ratingDelta, 0, 9999),
    totalMatches: (Number(player.totalMatches) || 0) + 1,
    lastActiveAt: nowMs,
  };
  if (isWin) {
    updates.wins = (Number(player.wins) || 0) + 1;
  } else if (isDraw) {
    updates.draws = (Number(player.draws) || 0) + 1;
  } else {
    updates.losses = (Number(player.losses) || 0) + 1;
  }
  if (isMvp) {
    updates.mvpCount = (Number(player.mvpCount) || 0) + 1;
  }
  tx.update(db.collection(COLLECTIONS.players).doc(player.id), updates);
}

async function loadProgressInputs({tx, db, match, tournament}) {
  if (!shouldRefreshTournamentProgress(match, tournament)) {
    return null;
  }
  if (match.stageType === "groupStage") {
    const groupsSnap = await tx.get(
      db
        .collection(COLLECTIONS.tournamentGroups)
        .where("tournamentId", "==", match.tournamentId)
        .where("groupStageId", "==", match.groupStageId),
    );
    const participantsSnap = await tx.get(
      db.collection(COLLECTIONS.tournamentParticipants)
        .where("tournamentId", "==", match.tournamentId),
    );
    const matchesSnap = await tx.get(
      db
        .collection(COLLECTIONS.matches)
        .where("tournamentId", "==", match.tournamentId)
        .where("stageType", "==", "groupStage")
        .where("groupStageId", "==", match.groupStageId),
    );
    const standingsSnap = await tx.get(
      db.collection(COLLECTIONS.groupStandingSnapshots)
        .where("groupStageId", "==", match.groupStageId),
    );
    return {
      kind: "groupStage",
      groups: queryToEntities(groupsSnap),
      participants: queryToEntities(participantsSnap),
      matches: replaceMatch(queryToEntities(matchesSnap), match),
      standings: queryToEntities(standingsSnap),
    };
  }
  if (match.stageType === "knockoutStage") {
    const bracketId = nonEmpty(tournament.currentKnockoutBracketId);
    if (!bracketId) {
      return null;
    }
    const bracketSnap = await tx.get(
      db.collection(COLLECTIONS.knockoutBrackets).doc(bracketId),
    );
    const tiesSnap = await tx.get(
      db.collection(COLLECTIONS.knockoutTies)
        .where("bracketId", "==", bracketId),
    );
    const matchesSnap = await tx.get(
      db
        .collection(COLLECTIONS.matches)
        .where("tournamentId", "==", match.tournamentId)
        .where("stageType", "==", "knockoutStage"),
    );
    const participantsSnap = await tx.get(
      db.collection(COLLECTIONS.tournamentParticipants)
        .where("tournamentId", "==", match.tournamentId),
    );
    return {
      kind: "knockoutStage",
      bracket: bracketSnap.exists ? withId(bracketSnap) : null,
      ties: queryToEntities(tiesSnap),
      matches: replaceMatch(queryToEntities(matchesSnap), match),
      participants: queryToEntities(participantsSnap),
    };
  }
  return null;
}

function writeTournamentProgress({tx, db, match, tournament, progressInputs, nowMs}) {
  if (!shouldRefreshTournamentProgress(match, tournament) || !progressInputs) {
    return;
  }
  if (progressInputs.kind === "groupStage") {
    writeGroupStandings({tx, db, tournament, progressInputs, nowMs});
    return;
  }
  if (progressInputs.kind === "knockoutStage") {
    writeKnockoutProgress({tx, db, progressInputs, nowMs});
  }
}

function writeGroupStandings({tx, db, tournament, progressInputs, nowMs}) {
  const participantsById = Object.fromEntries(
    progressInputs.participants.map((participant) => [participant.id, participant]),
  );
  const existingById = Object.fromEntries(
    progressInputs.standings.map((standing) => [standing.id, standing]),
  );
  const groups = [...progressInputs.groups].sort((left, right) => {
    return (Number(left.order) || 0) - (Number(right.order) || 0);
  });
  for (const group of groups) {
    const standing = recalculateStanding({
      tournament,
      group,
      participantsById,
      matches: progressInputs.matches.filter((entry) => entry.groupId === group.id),
      nowMs,
    });
    const existing = existingById[standing.id];
    if (existing && standingsEquivalent(existing, standing)) {
      continue;
    }
    tx.set(db.collection(COLLECTIONS.groupStandingSnapshots).doc(standing.id), {
      tournamentId: standing.tournamentId,
      groupStageId: standing.groupStageId,
      groupId: standing.groupId,
      tiebreakerOrder: standing.tiebreakerOrder,
      entries: standing.entries,
      qualifierParticipantIds: standing.qualifierParticipantIds,
      createdAt: existing && existing.createdAt ? existing.createdAt : nowMs,
      updatedAt: nowMs,
    });
  }
}

function recalculateStanding({tournament, group, participantsById, matches, nowMs}) {
  const baseline = {};
  const participantIds = Array.isArray(group.participantIds) ? group.participantIds : [];
  participantIds.forEach((participantId, index) => {
    const participant = participantsById[participantId];
    if (!participant) {
      return;
    }
    baseline[participant.id] = {
      participantId: participant.id,
      displayName: participant.displayName || "",
      played: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goalsFor: 0,
      goalsAgainst: 0,
      rank: 0,
      randomDrawOrder: Number.isInteger(participant.seed) ? participant.seed : index,
    };
  });
  for (const match of matches) {
    if (!isOfficialTournamentResult(match) || !match.teamAParticipantId || !match.teamBParticipantId) {
      continue;
    }
    const home = baseline[match.teamAParticipantId];
    const away = baseline[match.teamBParticipantId];
    if (!home || !away) {
      continue;
    }
    if (match.scoreTeamA > match.scoreTeamB) {
      applyStandingResult(home, true, false, match.scoreTeamA, match.scoreTeamB);
      applyStandingResult(away, false, false, match.scoreTeamB, match.scoreTeamA);
    } else if (match.scoreTeamB > match.scoreTeamA) {
      applyStandingResult(home, false, false, match.scoreTeamA, match.scoreTeamB);
      applyStandingResult(away, true, false, match.scoreTeamB, match.scoreTeamA);
    } else {
      applyStandingResult(home, false, true, match.scoreTeamA, match.scoreTeamB);
      applyStandingResult(away, false, true, match.scoreTeamB, match.scoreTeamA);
    }
  }
  const tiebreakerOrder = tiebreakerOrderFor(tournament);
  const entries = rankEntries(Object.values(baseline), tiebreakerOrder);
  const qualifiersPerGroup = tournament.format === "groupsThenKnockout" ? 2 : 0;
  return {
    id: `standing::${group.groupStageId}::${group.id}`,
    tournamentId: group.tournamentId,
    groupStageId: group.groupStageId,
    groupId: group.id,
    tiebreakerOrder,
    entries,
    qualifierParticipantIds:
      qualifiersPerGroup === 0
        ? []
        : entries.slice(0, qualifiersPerGroup).map((entry) => entry.participantId),
    createdAt: nowMs,
    updatedAt: nowMs,
  };
}

function writeKnockoutProgress({tx, db, progressInputs, nowMs}) {
  const bracket = progressInputs.bracket;
  if (!bracket) {
    return;
  }
  const progress = synchronizeKnockoutProgress({
    bracket,
    ties: progressInputs.ties,
    matches: progressInputs.matches,
    participants: progressInputs.participants,
    nowMs,
  });
  if (!bracketsEquivalent(bracket, progress.bracket)) {
    tx.update(db.collection(COLLECTIONS.knockoutBrackets).doc(bracket.id), {
      championParticipantId: progress.bracket.championParticipantId || null,
      updatedAt: nowMs,
    });
  }
  const existingTiesById = Object.fromEntries(
    progressInputs.ties.map((tie) => [tie.id, tie]),
  );
  for (const tie of progress.ties) {
    if (tiesEquivalent(existingTiesById[tie.id], tie)) {
      continue;
    }
    tx.set(db.collection(COLLECTIONS.knockoutTies).doc(tie.id), serializeTie(tie));
  }
  const existingMatchesById = Object.fromEntries(
    progressInputs.matches.map((match) => [match.id, match]),
  );
  for (const match of progress.matches) {
    const existing = existingMatchesById[match.id];
    if (matchesEquivalent(existing, match)) {
      continue;
    }
    tx.update(db.collection(COLLECTIONS.matches).doc(match.id), {
      teamAId: match.teamAId || null,
      teamBId: match.teamBId || null,
      teamAParticipantId: match.teamAParticipantId || null,
      teamBParticipantId: match.teamBParticipantId || null,
    });
  }
}

function synchronizeKnockoutProgress({bracket, ties, matches, participants, nowMs}) {
  const tieById = Object.fromEntries(ties.map((tie) => [tie.id, {...tie}]));
  const matchById = Object.fromEntries(matches.map((match) => [match.id, {...match}]));
  const participantsById = Object.fromEntries(
    participants.map((participant) => [participant.id, participant]),
  );
  const sortedTies = [...ties].sort((left, right) => {
    if (left.roundIndex !== right.roundIndex) {
      return (Number(left.roundIndex) || 0) - (Number(right.roundIndex) || 0);
    }
    return (Number(left.slotNumber) || 0) - (Number(right.slotNumber) || 0);
  });

  for (const originalTie of sortedTies) {
    let tie = tieById[originalTie.id];
    const match = tie.matchId ? matchById[tie.matchId] : null;
    const resolution = match ? knockoutResolutionForMatch(match) : null;
    if (
      match &&
      !tie.winnerParticipantId &&
      isOfficialTournamentResult(match) &&
      match.teamAParticipantId &&
      match.teamBParticipantId &&
      resolution
    ) {
      tie = {
        ...tie,
        winnerParticipantId: resolution.decision === "teamA"
          ? match.teamAParticipantId
          : match.teamBParticipantId,
        resolutionType: resolution.resolutionType,
        updatedAt: nowMs,
      };
      tieById[tie.id] = tie;
    } else if (
      match &&
      tie.winnerParticipantId &&
      (!tie.resolutionType || tie.resolutionType === "pending") &&
      isOfficialTournamentResult(match) &&
      resolution
    ) {
      const resolvedWinner = resolution.decision === "teamA"
        ? match.teamAParticipantId
        : match.teamBParticipantId;
      if (resolvedWinner === tie.winnerParticipantId) {
        tie = {
          ...tie,
          resolutionType: resolution.resolutionType,
          updatedAt: nowMs,
        };
        tieById[tie.id] = tie;
      }
    }
    if (!tie.winnerParticipantId || !tie.nextTieId) {
      continue;
    }
    const nextTie = tieById[tie.nextTieId];
    if (!nextTie) {
      continue;
    }
    const isFirstChild = (Number(tie.slotNumber) || 0) % 2 === 0;
    const patchedNextTie = {
      ...nextTie,
      participantAId: isFirstChild ? tie.winnerParticipantId : nextTie.participantAId,
      participantBId: isFirstChild ? nextTie.participantBId : tie.winnerParticipantId,
      updatedAt: nowMs,
    };
    tieById[nextTie.id] = patchedNextTie;
    if (patchedNextTie.matchId && matchById[patchedNextTie.matchId]) {
      const downstreamMatch = matchById[patchedNextTie.matchId];
      matchById[patchedNextTie.matchId] = {
        ...downstreamMatch,
        teamAParticipantId: patchedNextTie.participantAId || null,
        teamBParticipantId: patchedNextTie.participantBId || null,
        teamAId: patchedNextTie.participantAId
          ? (participantsById[patchedNextTie.participantAId] || {}).sourceEntityId || null
          : null,
        teamBId: patchedNextTie.participantBId
          ? (participantsById[patchedNextTie.participantBId] || {}).sourceEntityId || null
          : null,
      };
    }
  }

  const finalTie = Object.values(tieById).reduce((current, tie) => {
    if (!current) {
      return tie;
    }
    if ((Number(tie.roundIndex) || 0) > (Number(current.roundIndex) || 0)) {
      return tie;
    }
    if (
      tie.roundIndex === current.roundIndex &&
      (Number(tie.slotNumber) || 0) > (Number(current.slotNumber) || 0)
    ) {
      return tie;
    }
    return current;
  }, null);
  return {
    bracket: finalTie && finalTie.winnerParticipantId
      ? {...bracket, championParticipantId: finalTie.winnerParticipantId, updatedAt: nowMs}
      : bracket,
    ties: Object.values(tieById),
    matches: Object.values(matchById),
  };
}

function applyStandingResult(entry, isWin, isDraw, goalsFor, goalsAgainst) {
  entry.played += 1;
  entry.wins += isWin ? 1 : 0;
  entry.draws += isDraw ? 1 : 0;
  entry.losses += !isWin && !isDraw ? 1 : 0;
  entry.goalsFor += goalsFor;
  entry.goalsAgainst += goalsAgainst;
}

function rankEntries(entries, tiebreakers) {
  const ranked = [...entries].sort((left, right) => {
    for (const metric of tiebreakers) {
      const comparison = compareStandingMetric(left, right, metric);
      if (comparison !== 0) {
        return comparison;
      }
    }
    return String(left.displayName).localeCompare(String(right.displayName));
  });
  return ranked.map((entry, index) => ({...entry, rank: index + 1}));
}

function compareStandingMetric(left, right, metric) {
  switch (metric) {
    case "points":
      return standingPoints(right) - standingPoints(left);
    case "goalDifference":
      return standingGoalDifference(right) - standingGoalDifference(left);
    case "goalsFor":
      return right.goalsFor - left.goalsFor;
    case "randomDraw":
      return left.randomDrawOrder - right.randomDrawOrder;
    default:
      return 0;
  }
}

function tiebreakerOrderFor(tournament) {
  const encoded =
    tournament &&
    tournament.groupStandingsConfig &&
    Array.isArray(tournament.groupStandingsConfig.tiebreakerOrder)
      ? tournament.groupStandingsConfig.tiebreakerOrder
      : [];
  return encoded.length > 0 ? encoded : DEFAULT_TIEBREAKERS;
}

function isSettled(match) {
  return match.status === MATCH_STATUS.settled || match.ratingsAppliedAt != null;
}

function isOfficialTournamentResult(match) {
  return (
    match.status === MATCH_STATUS.settled &&
    isValidScore(match.scoreTeamA) &&
    isValidScore(match.scoreTeamB)
  );
}

function shouldRefreshTournamentProgress(match, tournament) {
  return (
    tournament &&
    nonEmpty(match.tournamentId) &&
    isOfficialTournamentResult(match) &&
    (match.stageType === "groupStage" || match.stageType === "knockoutStage")
  );
}

function matchAsSettled(match, knockoutResolution = null) {
  return {
    ...match,
    status: MATCH_STATUS.settled,
    isAnomaly: false,
    knockoutDecision: knockoutResolution
      ? knockoutResolution.decision
      : match.knockoutDecision || null,
  };
}

function knockoutResolutionForMatch(match) {
  if (
    match.stageType !== "knockoutStage" ||
    !isValidScore(match.scoreTeamA) ||
    !isValidScore(match.scoreTeamB)
  ) {
    return null;
  }
  let decision;
  let resolutionType;
  if (match.scoreTeamA !== match.scoreTeamB) {
    if (match.penaltyScoreTeamA != null || match.penaltyScoreTeamB != null) {
      return null;
    }
    decision = match.scoreTeamA > match.scoreTeamB ? "teamA" : "teamB";
    resolutionType = "regularTime";
  } else {
    if (
      !isValidPenaltyScore(match.penaltyScoreTeamA) ||
      !isValidPenaltyScore(match.penaltyScoreTeamB) ||
      match.penaltyScoreTeamA === match.penaltyScoreTeamB
    ) {
      return null;
    }
    decision = match.penaltyScoreTeamA > match.penaltyScoreTeamB
      ? "teamA"
      : "teamB";
    resolutionType = "penalties";
  }
  if (match.knockoutDecision != null && match.knockoutDecision !== decision) {
    return null;
  }
  return {decision, resolutionType};
}

function matchWinner(match) {
  if (match.scoreTeamA > match.scoreTeamB) {
    return "A";
  }
  if (match.scoreTeamB > match.scoreTeamA) {
    return "B";
  }
  const knockoutResolution = knockoutResolutionForMatch(match);
  if (knockoutResolution) {
    return knockoutResolution.decision === "teamA" ? "A" : "B";
  }
  return "draw";
}

function computeDifficultyMultiplier(myTeamAvgRating, opponentAvgRating) {
  if (myTeamAvgRating <= 0) {
    return 1.0;
  }
  return clamp(
    opponentAvgRating / myTeamAvgRating,
    RATING.difficultyMultiplierMin,
    RATING.difficultyMultiplierMax,
  );
}

function averageRating(players) {
  if (!players || players.length === 0) {
    return 1000;
  }
  return players.reduce((total, player) => total + (Number(player.rating) || 1000), 0) / players.length;
}

function trustWeight(level) {
  switch (level) {
    case "veteran":
      return RATING.trustWeightVeteran;
    case "active":
      return RATING.trustWeightActive;
    case "suspended":
      return 0.0;
    case "newPlayer":
    default:
      return RATING.trustWeightNew;
  }
}

function replaceMatch(matches, match) {
  let replaced = false;
  const result = matches.map((entry) => {
    if (entry.id !== match.id) {
      return entry;
    }
    replaced = true;
    return {...entry, ...match};
  });
  if (!replaced) {
    result.push(match);
  }
  return result;
}

function queryToEntities(snapshot) {
  const entities = [];
  snapshot.forEach((doc) => entities.push(withId(doc)));
  return entities;
}

function withId(snapshot) {
  return {...snapshot.data(), id: snapshot.id};
}

function standingsEquivalent(left, right) {
  return (
    left.tournamentId === right.tournamentId &&
    left.groupStageId === right.groupStageId &&
    left.groupId === right.groupId &&
    arraysEqual(left.tiebreakerOrder || [], right.tiebreakerOrder || []) &&
    arraysEqual(left.qualifierParticipantIds || [], right.qualifierParticipantIds || []) &&
    JSON.stringify(left.entries || []) === JSON.stringify(right.entries || [])
  );
}

function bracketsEquivalent(left, right) {
  return (
    left &&
    right &&
    left.tournamentId === right.tournamentId &&
    left.format === right.format &&
    left.championParticipantId === right.championParticipantId &&
    arraysEqual(left.qualifierParticipantIds || [], right.qualifierParticipantIds || [])
  );
}

function tiesEquivalent(left, right) {
  return (
    left &&
    right &&
    left.tournamentId === right.tournamentId &&
    left.bracketId === right.bracketId &&
    left.roundIndex === right.roundIndex &&
    left.slotNumber === right.slotNumber &&
    left.participantAId === right.participantAId &&
    left.participantBId === right.participantBId &&
    left.winnerParticipantId === right.winnerParticipantId &&
    left.matchId === right.matchId &&
    left.nextTieId === right.nextTieId &&
    (left.resolutionType || "pending") ===
      (right.resolutionType || "pending")
  );
}

function matchesEquivalent(left, right) {
  return (
    left &&
    right &&
    left.teamAId === right.teamAId &&
    left.teamBId === right.teamBId &&
    left.teamAParticipantId === right.teamAParticipantId &&
    left.teamBParticipantId === right.teamBParticipantId
  );
}

function serializeTie(tie) {
  return {
    tournamentId: tie.tournamentId,
    bracketId: tie.bracketId,
    roundIndex: tie.roundIndex,
    slotNumber: tie.slotNumber,
    participantAId: tie.participantAId || null,
    participantBId: tie.participantBId || null,
    winnerParticipantId: tie.winnerParticipantId || null,
    matchId: tie.matchId || null,
    nextTieId: tie.nextTieId || null,
    resolutionType: tie.resolutionType || "pending",
    createdAt: tie.createdAt,
    updatedAt: tie.updatedAt,
  };
}

function standingPoints(entry) {
  return entry.wins * 3 + entry.draws;
}

function standingGoalDifference(entry) {
  return entry.goalsFor - entry.goalsAgainst;
}

function arraysEqual(left, right) {
  if (left.length !== right.length) {
    return false;
  }
  return left.every((value, index) => value === right[index]);
}

function requiredString(value, fieldName) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    throw new SettlementError("invalid-argument", `${fieldName} is required.`);
  }
  return normalized;
}

function nonEmpty(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function normalizeNow(now) {
  const value = typeof now === "function" ? now() : now;
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : Date.now();
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function clampInt(value, min, max) {
  return Math.min(Math.max(Math.round(value), min), max);
}

function dartRound(value) {
  return value < 0 ? -Math.round(Math.abs(value)) : Math.round(value);
}

module.exports = {
  SettlementError,
  approveMatchScoreCore,
  calculateMatchDelta,
  computeDifficultyMultiplier,
};
