"use strict";

const TOURNAMENT_ID = "world-cup-2026-simulation";
const GROUP_STAGE_ID = "wc2026-group-stage";
const BRACKET_ID = "wc2026-knockout-bracket";
const CREATED_AT = Date.parse("2026-06-01T12:00:00Z");
const UPDATED_AT = Date.parse("2026-07-17T12:00:00Z");

const paddedMatchNumber = (matchNumber) => String(matchNumber).padStart(3, "0");
const teamId = (code) => `wc2026-team-${code.toLowerCase()}`;
const participantId = (code) => `wc2026-participant-${code.toLowerCase()}`;
const playerId = (code, shirtNumber) =>
  `wc2026-player-${code.toLowerCase()}-${String(shirtNumber).padStart(2, "0")}`;
const matchId = (matchNumber) => `wc2026-match-${paddedMatchNumber(matchNumber)}`;
const tieId = (matchNumber) => `wc2026-tie-${paddedMatchNumber(matchNumber)}`;
const groupId = (groupCode) => `wc2026-group-${groupCode.toLowerCase()}`;

function normalizedName(value) {
  return value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function matchWinnerCode(match) {
  if (match.status !== "settled") return null;
  if (match.penaltyScoreTeamA != null) {
    return match.penaltyScoreTeamA > match.penaltyScoreTeamB
      ? match.teamA
      : match.teamB;
  }
  return match.scoreTeamA > match.scoreTeamB ? match.teamA : match.teamB;
}

function buildStandingEntries(groupTeams, groupMatches) {
  const statsByCode = new Map(
    groupTeams.map((team) => [
      team.code,
      {played: 0, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0},
    ]),
  );
  for (const match of groupMatches) {
    const teamA = statsByCode.get(match.teamA);
    const teamB = statsByCode.get(match.teamB);
    teamA.played += 1;
    teamB.played += 1;
    teamA.goalsFor += match.scoreTeamA;
    teamA.goalsAgainst += match.scoreTeamB;
    teamB.goalsFor += match.scoreTeamB;
    teamB.goalsAgainst += match.scoreTeamA;
    if (match.scoreTeamA > match.scoreTeamB) {
      teamA.wins += 1;
      teamB.losses += 1;
    } else if (match.scoreTeamB > match.scoreTeamA) {
      teamB.wins += 1;
      teamA.losses += 1;
    } else {
      teamA.draws += 1;
      teamB.draws += 1;
    }
  }
  return groupTeams
    .map((team) => ({team, ...statsByCode.get(team.code)}))
    .sort((left, right) => {
      const pointsDifference =
        right.wins * 3 + right.draws - (left.wins * 3 + left.draws);
      const goalDifference =
        right.goalsFor - right.goalsAgainst - (left.goalsFor - left.goalsAgainst);
      return (
        pointsDifference ||
        goalDifference ||
        right.goalsFor - left.goalsFor ||
        left.team.code.localeCompare(right.team.code)
      );
    })
    .map((standing, index) => ({
      code: standing.team.code,
      participantId: participantId(standing.team.code),
      displayName: standing.team.displayNameAr,
      played: standing.played,
      wins: standing.wins,
      draws: standing.draws,
      losses: standing.losses,
      goalsFor: standing.goalsFor,
      goalsAgainst: standing.goalsAgainst,
      rank: index + 1,
      randomDrawOrder: index + 1,
    }));
}

function buildTournamentDocument(organizerId) {
  return {
    organizerId,
    name: "كأس العالم 2026",
    description: "محاكاة داخل الحريف تضم المنتخبات والقوائم والنتائج الموثقة حتى 17 يوليو 2026.",
    location: "كندا والمكسيك والولايات المتحدة",
    format: "groupsThenKnockout",
    teamSize: 11,
    maxTeams: 48,
    visibility: "public",
    discoverable: true,
    isFeatured: true,
    featuredPriority: 0,
    participantViewerIds: [],
    prizePool: null,
    prizeDescription: null,
    status: "knockoutStage",
    registeredTeamIds: [],
    assistants: [],
    isFantasyEnabled: false,
    registrationDeadline: Date.parse("2026-06-01T23:59:59Z"),
    startDate: Date.parse("2026-06-11T00:00:00Z"),
    endDate: Date.parse("2026-07-19T23:59:59Z"),
    participantListFinalizedAt: CREATED_AT,
    activeParticipantCount: 48,
    currentGroupStageId: GROUP_STAGE_ID,
    currentKnockoutBracketId: BRACKET_ID,
    winnerParticipantId: null,
    needsManualOpsMigration: false,
    groupAdvancementConfig: {
      groupCount: 12,
      automaticQualifiersPerGroup: 2,
      bestRankedAdditionalQualifiers: 8,
    },
    groupStandingsConfig: {
      tiebreakerOrder: ["points", "goalDifference", "goalsFor", "randomDraw"],
    },
    createdAt: CREATED_AT,
  };
}

function buildOrganizerProfileDocument(organizerId) {
  return {
    name: "منظم كأس العالم",
    nameLower: "منظم كأس العالم",
    username: null,
    usernameLower: null,
    photoUrl: null,
    photoThumbUrl: null,
    photoFrame: "newcomer",
    qrCode: `7reef://player/${organizerId}`,
    phone: null,
    position: null,
    rating: 1000,
    totalMatches: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    mvpCount: 0,
    trustWeight: 0.5,
    trustLevel: "newPlayer",
    role: "player",
    achievementIds: [],
    teamIds: [],
    friendIds: [],
    followingIds: [],
    blockedIds: [],
    privacySetting: "public",
    isGuest: false,
    createdAt: CREATED_AT,
    lastActiveAt: UPDATED_AT,
  };
}

function buildTeamDocuments(team, organizerId) {
  const guestTeamId = teamId(team.code);
  const displayName = `${team.displayNameAr} (${team.code})`;
  const documents = [
    {
      path: `guestTeams/${guestTeamId}`,
      data: {
        name: displayName,
        normalizedName: normalizedName(displayName),
        creatorId: organizerId,
        contactName: null,
        contactPhone: null,
        logoUrl: null,
        tournamentIds: [TOURNAMENT_ID],
        captainGuestPlayerId: null,
        claimStatus: "guest",
        claimCode: null,
        linkedTeamId: null,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
      },
    },
    {
      path: `tournamentParticipants/${participantId(team.code)}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        sourceType: "guestTeam",
        sourceEntityId: guestTeamId,
        displayName,
        status: "finalized",
        seed: null,
        groupId: groupId(team.group),
        sourceRegistrationId: null,
        replacementForParticipantId: null,
        replacedByParticipantId: null,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
        approvedAt: CREATED_AT,
        finalizedAt: CREATED_AT,
        withdrawnAt: null,
        replacedAt: null,
      },
    },
  ];
  for (const player of team.players) {
    const importedPlayerId = playerId(team.code, player.shirtNumber);
    documents.push({
      path: `guestPlayers/${importedPlayerId}`,
      data: {
        displayName: player.displayName,
        normalizedName: normalizedName(player.displayName),
        phoneNumber: null,
        jerseyNumber: player.shirtNumber,
        preferredPosition: player.position,
        teamId: null,
        guestTeamId,
        tournamentId: TOURNAMENT_ID,
        createdBy: organizerId,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
        claimStatus: "guest",
        claimCode: null,
        linkedPlayerId: null,
        notes: `${player.birthDate} • ${player.clubName} (${player.clubCountryCode})`,
      },
    });
    documents.push({
      path: `publicTournamentRosterEntries/${TOURNAMENT_ID}_${importedPlayerId}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        guestTeamId,
        playerId: importedPlayerId,
        displayName: player.displayName,
        normalizedName: normalizedName(player.displayName),
        jerseyNumber: player.shirtNumber,
        preferredPosition: player.position,
        createdBy: organizerId,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
        claimStatus: "guest",
      },
    });
  }
  return documents;
}

function buildGroupDocuments(squads, matches) {
  const roundOf32Codes = new Set(
    matches
      .filter((match) => match.matchNumber >= 73 && match.matchNumber <= 88)
      .flatMap((match) => [match.teamA, match.teamB]),
  );
  const documents = [];
  for (const groupCode of "ABCDEFGHIJKL") {
    const groupTeams = squads.teams.filter((team) => team.group === groupCode);
    const entries = buildStandingEntries(
      groupTeams,
      matches.filter((match) => match.groupCode === groupCode),
    );
    const qualifierParticipantIds = entries
      .filter((entry) => roundOf32Codes.has(entry.code))
      .map((entry) => entry.participantId);
    documents.push({
      path: `tournamentGroups/${groupId(groupCode)}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        groupStageId: GROUP_STAGE_ID,
        name: `المجموعة ${groupCode}`,
        order: groupCode.charCodeAt(0) - 65,
        participantIds: groupTeams.map((team) => participantId(team.code)),
        qualifierParticipantIds,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
      },
    });
    documents.push({
      path: `groupStandingSnapshots/wc2026-standing-${groupCode.toLowerCase()}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        groupStageId: GROUP_STAGE_ID,
        groupId: groupId(groupCode),
        tiebreakerOrder: ["points", "goalDifference", "goalsFor", "randomDraw"],
        entries: entries.map(({code, ...entry}) => entry),
        qualifierParticipantIds,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
      },
    });
  }
  return documents;
}

function buildMatchDocument(match, organizerId) {
  const settled = match.status === "settled";
  const winnerCode = matchWinnerCode(match);
  const knockoutDecision =
    match.stageType === "knockoutStage" && winnerCode
      ? winnerCode === match.teamA
        ? "teamA"
        : "teamB"
      : null;
  const championshipTie =
    match.stageType === "knockoutStage" && match.bracketRole === "championship";
  const scheduledAt = Date.parse(match.scheduledAt);
  return {
    organizerId,
    teamAId: teamId(match.teamA),
    teamBId: teamId(match.teamB),
    teamAPlayerIds: [],
    teamBPlayerIds: [],
    teamAParticipantId: participantId(match.teamA),
    teamBParticipantId: participantId(match.teamB),
    status: settled ? "settled" : "open",
    scoreTeamA: match.scoreTeamA,
    scoreTeamB: match.scoreTeamB,
    penaltyScoreTeamA: match.penaltyScoreTeamA,
    penaltyScoreTeamB: match.penaltyScoreTeamB,
    knockoutDecision,
    mvpPlayerId: null,
    prideEventsPending: false,
    location: match.venue,
    latitude: null,
    longitude: null,
    teamSize: 11,
    isOrganized: true,
    tournamentId: TOURNAMENT_ID,
    challengeId: null,
    isGoldenRating: false,
    isAnomaly: false,
    isFrozen: false,
    stageType: match.stageType,
    groupId: match.groupCode ? groupId(match.groupCode) : null,
    groupStageId: match.groupCode ? GROUP_STAGE_ID : null,
    knockoutTieId: championshipTie ? tieId(match.matchNumber) : null,
    knockoutMatchRole: match.bracketRole,
    roundIndex: match.roundIndex,
    slotNumber: match.matchNumber,
    scheduledAt,
    publishedAt: CREATED_AT,
    venueId: null,
    fixtureStatus: settled ? "completed" : "published",
    lineupRequirement: "none",
    createdAt: CREATED_AT,
    startedAt: settled ? scheduledAt : null,
    completedAt: settled ? scheduledAt + 2 * 60 * 60 * 1000 : null,
    cancelledAt: null,
    cancelledBy: null,
    cancelReason: null,
  };
}

function buildBracketDocuments(matches) {
  const championshipMatches = matches.filter(
    (match) => match.bracketRole === "championship",
  );
  const firstRound = championshipMatches.filter((match) => match.roundIndex === 0);
  const documents = [
    {
      path: `knockoutBrackets/${BRACKET_ID}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        format: "singleElimination",
        qualifierParticipantIds: firstRound.flatMap((match) => [
          participantId(match.teamA),
          participantId(match.teamB),
        ]),
        seedingMethod: "groupCrossPairing",
        byeParticipantIds: [],
        championParticipantId: null,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
      },
    },
  ];
  const slotByRound = new Map();
  for (const match of championshipMatches) {
    const winnerCode = matchWinnerCode(match);
    const nextMatch = winnerCode
      ? championshipMatches.find(
          (candidate) =>
            candidate.roundIndex === match.roundIndex + 1 &&
            (candidate.teamA === winnerCode || candidate.teamB === winnerCode),
        )
      : null;
    documents.push({
      path: `knockoutTies/${tieId(match.matchNumber)}`,
      data: {
        tournamentId: TOURNAMENT_ID,
        bracketId: BRACKET_ID,
        roundIndex: match.roundIndex,
        slotNumber: slotByRound.get(match.roundIndex) ?? 0,
        participantAId: participantId(match.teamA),
        participantBId: participantId(match.teamB),
        winnerParticipantId: winnerCode ? participantId(winnerCode) : null,
        matchId: matchId(match.matchNumber),
        nextTieId: nextMatch ? tieId(nextMatch.matchNumber) : null,
        resolutionType: match.resolutionType,
        createdAt: CREATED_AT,
        updatedAt: UPDATED_AT,
      },
    });
    slotByRound.set(match.roundIndex, (slotByRound.get(match.roundIndex) ?? 0) + 1);
  }
  return documents;
}

function buildWorldCupImportDocuments({organizerId, squads, matches}) {
  if (!organizerId || !organizerId.trim()) throw new Error("organizerId is required.");
  const documents = [
    {
      path: `players/${organizerId}`,
      data: buildOrganizerProfileDocument(organizerId),
    },
    {path: `tournaments/${TOURNAMENT_ID}`, data: buildTournamentDocument(organizerId)},
    {
      path: `tournamentMemberships/${organizerId}_${TOURNAMENT_ID}`,
      data: {tournamentId: TOURNAMENT_ID, userId: organizerId, role: "organizer", createdAt: CREATED_AT},
    },
  ];
  for (const team of squads.teams) documents.push(...buildTeamDocuments(team, organizerId));
  documents.push(...buildGroupDocuments(squads, matches.matches));
  for (const match of matches.matches) {
    documents.push({
      path: `matches/${matchId(match.matchNumber)}`,
      data: buildMatchDocument(match, organizerId),
    });
  }
  documents.push(...buildBracketDocuments(matches.matches));
  documents.push({
    path: "auditEvents/wc2026-simulation-import",
    data: {
      entityType: "tournament",
      entityId: TOURNAMENT_ID,
      action: "worldCupSimulationImported",
      actorId: organizerId,
      beforePayload: null,
      afterPayload: null,
      metadata: {asOf: matches.asOf, teams: 48, players: 1248, matches: 104},
      createdAt: UPDATED_AT,
    },
  });
  return documents;
}

function assertLocalFirestoreEmulator(environment) {
  const host = environment.FIRESTORE_EMULATOR_HOST ?? "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error("Refusing import: FIRESTORE_EMULATOR_HOST must target localhost.");
  }
}

async function writeImportDocuments(db, documents, batchSize = 400) {
  let written = 0;
  for (let offset = 0; offset < documents.length; offset += batchSize) {
    const batch = db.batch();
    for (const document of documents.slice(offset, offset + batchSize)) {
      batch.set(db.doc(document.path), document.data, {merge: false});
      written += 1;
    }
    await batch.commit();
  }
  return written;
}

module.exports = {
  BRACKET_ID,
  TOURNAMENT_ID,
  assertLocalFirestoreEmulator,
  buildStandingEntries,
  buildWorldCupImportDocuments,
  matchWinnerCode,
  writeImportDocuments,
};
