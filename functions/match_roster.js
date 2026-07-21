const {COLLECTIONS, SIDE_KEYS} = require("./firestore_contract");

const ACTIVE_MEMBERSHIP_STATUSES = new Set(["starter", "bench"]);
const ROSTER_READ_LIMITS = Object.freeze({
  lineupSnapshots: 4,
  matchSidePlayers: 50,
  sideRoster: 50,
});

function nonEmpty(value) {
  const normalized = String(value || "").trim();
  return normalized || null;
}

function snapshotEntries(snapshot) {
  const starters = Array.isArray(snapshot.starters) ? snapshot.starters : [];
  const bench = Array.isArray(snapshot.bench) ? snapshot.bench : [];
  const legacyEntries = Array.isArray(snapshot.entries) ? snapshot.entries : [];
  return [...starters, ...bench, ...legacyEntries];
}

function participantKey(kind, id) {
  const normalizedId = nonEmpty(id);
  return normalizedId ? `${kind}:${normalizedId}` : null;
}

function matchSideForKey(matchSides, sideKey) {
  return matchSides.find(
    (side) => nonEmpty(side.sideKey)?.toUpperCase() === sideKey,
  ) || null;
}

function snapshotForSide({snapshots, matchSides, sideKey, sideEntityId}) {
  const bySideKey = snapshots.find(
    (snapshot) => nonEmpty(snapshot.sideKey)?.toUpperCase() === sideKey,
  );
  if (bySideKey) {
    return bySideKey;
  }

  const matchSideId = nonEmpty(matchSideForKey(matchSides, sideKey)?._id);
  return snapshots.find((snapshot) => {
    const matchesEntity = sideEntityId && (
      nonEmpty(snapshot.teamId) === sideEntityId ||
      nonEmpty(snapshot.guestTeamId) === sideEntityId
    );
    const matchesSide = matchSideId && nonEmpty(snapshot.matchSideId) === matchSideId;
    return matchesEntity || matchesSide;
  }) || null;
}

function candidateFromMatchSidePlayer(player) {
  const playerId = nonEmpty(player.playerId);
  if (playerId) {
    return participantKey("player", playerId);
  }
  return participantKey("matchSidePlayer", player._id);
}

function candidatesFromSnapshot(snapshot, sidePlayers) {
  const sidePlayersById = new Map(
    sidePlayers.map((player) => [nonEmpty(player._id), player]),
  );
  return snapshotEntries(snapshot).map((entry) => {
    const playerId = nonEmpty(entry && entry.playerId);
    if (playerId) {
      return participantKey("player", playerId);
    }
    const guestPlayerId = nonEmpty(entry && entry.guestPlayerId);
    if (guestPlayerId) {
      return participantKey("guestPlayer", guestPlayerId);
    }
    const matchSidePlayerId = nonEmpty(entry && entry.matchSidePlayerId);
    if (!matchSidePlayerId) {
      return null;
    }
    const sidePlayer = sidePlayersById.get(matchSidePlayerId);
    return candidateFromMatchSidePlayer(sidePlayer || {_id: matchSidePlayerId});
  }).filter(Boolean);
}

function candidatesFromOfficialRoster({
  sideEntityId,
  participantId,
  participantsById,
  membershipsByTeamId,
  guestPlayersByGuestTeamId,
}) {
  if (!sideEntityId) {
    return [];
  }
  const participant = participantId ? participantsById.get(participantId) : null;
  if (participant && participant.sourceType === "guestTeam") {
    return (guestPlayersByGuestTeamId.get(sideEntityId) || [])
      .map((guestPlayer) => participantKey("guestPlayer", guestPlayer._id))
      .filter(Boolean);
  }
  return (membershipsByTeamId.get(sideEntityId) || [])
    .filter((membership) => ACTIVE_MEMBERSHIP_STATUSES.has(membership.status))
    .map((membership) => {
      const playerId = nonEmpty(membership.playerId);
      if (playerId) {
        return participantKey("player", playerId);
      }
      return participantKey("guestPlayer", membership.guestPlayerId);
    })
    .filter(Boolean);
}

function resolveCanonicalMatchRoster({
  match,
  snapshots = [],
  matchSides = [],
  matchSidePlayers = [],
  participantsById = new Map(),
  membershipsByTeamId = new Map(),
  guestPlayersByGuestTeamId = new Map(),
}) {
  const keysBySide = {A: new Set(), B: new Set()};

  for (const sideKey of SIDE_KEYS) {
    const sideEntityId = nonEmpty(
      sideKey === "A" ? match.teamAId : match.teamBId,
    );
    const participantId = nonEmpty(
      sideKey === "A" ? match.teamAParticipantId : match.teamBParticipantId,
    );
    const fallbackPlayerIds = Array.isArray(
      sideKey === "A" ? match.teamAPlayerIds : match.teamBPlayerIds,
    ) ? (sideKey === "A" ? match.teamAPlayerIds : match.teamBPlayerIds) : [];
    const sidePlayers = matchSidePlayers.filter(
      (player) => nonEmpty(player.sideKey)?.toUpperCase() === sideKey,
    );
    const snapshot = snapshotForSide({
      snapshots,
      matchSides,
      sideKey,
      sideEntityId,
    });
    const candidates = snapshot
      ? candidatesFromSnapshot(snapshot, sidePlayers)
      : [
        ...fallbackPlayerIds
          .map((playerId) => participantKey("player", playerId))
          .filter(Boolean),
        ...candidatesFromOfficialRoster({
          sideEntityId,
          participantId,
          participantsById,
          membershipsByTeamId,
          guestPlayersByGuestTeamId,
        }),
      ];

    for (const key of [
      ...candidates,
      ...sidePlayers.map(candidateFromMatchSidePlayer).filter(Boolean),
    ]) {
      keysBySide[sideKey].add(key);
    }
  }

  return {
    keysBySide,
    allKeys: new Set([...keysBySide.A, ...keysBySide.B]),
  };
}

function registeredPlayerIdsForSide(roster, sideKey) {
  const playerPrefix = "player:";
  return [...roster.keysBySide[sideKey]]
    .filter((key) => key.startsWith(playerPrefix))
    .map((key) => key.substring(playerPrefix.length));
}

function docsFromSnapshot(snapshot) {
  const docs = [];
  snapshot.forEach((doc) => docs.push({...doc.data(), _id: doc.id}));
  return docs;
}

async function loadOptionalDocument(tx, reference) {
  const snapshot = await tx.get(reference);
  return snapshot.exists ? {...snapshot.data(), _id: snapshot.id} : null;
}

async function loadCanonicalMatchRoster({db, tx, matchId, match}) {
  const snapshots = docsFromSnapshot(await tx.get(
    db.collection(COLLECTIONS.matchLineupSnapshots)
      .where("matchId", "==", matchId)
      .limit(ROSTER_READ_LIMITS.lineupSnapshots),
  ));
  const matchSidePlayers = docsFromSnapshot(await tx.get(
    db.collection(COLLECTIONS.matchSidePlayers)
      .where("matchId", "==", matchId)
      .limit(ROSTER_READ_LIMITS.matchSidePlayers),
  ));
  const matchSides = (
    await Promise.all(SIDE_KEYS.map((sideKey) => loadOptionalDocument(
      tx,
      db.collection(COLLECTIONS.matchSides).doc(`${matchId}_${sideKey}`),
    )))
  ).filter(Boolean);

  const participantsById = new Map();
  for (const participantId of [match.teamAParticipantId, match.teamBParticipantId]) {
    const normalizedId = nonEmpty(participantId);
    if (!normalizedId || participantsById.has(normalizedId)) {
      continue;
    }
    const participant = await loadOptionalDocument(
      tx,
      db.collection(COLLECTIONS.tournamentParticipants).doc(normalizedId),
    );
    if (participant) {
      participantsById.set(normalizedId, participant);
    }
  }

  const membershipsByTeamId = new Map();
  const guestPlayersByGuestTeamId = new Map();
  for (const sideKey of SIDE_KEYS) {
    const sideEntityId = nonEmpty(
      sideKey === "A" ? match.teamAId : match.teamBId,
    );
    if (!sideEntityId) {
      continue;
    }
    const snapshot = snapshotForSide({
      snapshots,
      matchSides,
      sideKey,
      sideEntityId,
    });
    if (snapshot) {
      continue;
    }
    const participantId = nonEmpty(
      sideKey === "A" ? match.teamAParticipantId : match.teamBParticipantId,
    );
    const participant = participantId ? participantsById.get(participantId) : null;
    if (participant && participant.sourceType === "guestTeam") {
      if (!guestPlayersByGuestTeamId.has(sideEntityId)) {
        guestPlayersByGuestTeamId.set(
          sideEntityId,
          docsFromSnapshot(await tx.get(
            db.collection(COLLECTIONS.guestPlayers)
              .where("guestTeamId", "==", sideEntityId)
              .limit(ROSTER_READ_LIMITS.sideRoster),
          )),
        );
      }
    } else if (!membershipsByTeamId.has(sideEntityId)) {
      membershipsByTeamId.set(
        sideEntityId,
        docsFromSnapshot(await tx.get(
          db.collection(COLLECTIONS.teamMemberships)
            .where("teamId", "==", sideEntityId)
            .limit(ROSTER_READ_LIMITS.sideRoster),
        )),
      );
    }
  }

  return resolveCanonicalMatchRoster({
    match,
    snapshots,
    matchSides,
    matchSidePlayers,
    participantsById,
    membershipsByTeamId,
    guestPlayersByGuestTeamId,
  });
}

module.exports = {
  loadCanonicalMatchRoster,
  ROSTER_READ_LIMITS,
  registeredPlayerIdsForSide,
  resolveCanonicalMatchRoster,
};
