"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  BRACKET_ID,
  TOURNAMENT_ID,
  assertLocalFirestoreEmulator,
} = require("../imports/world_cup_2026");

async function countWhere(db, collectionName, field, value, operator = "==") {
  const snapshot = await db.collection(collectionName).where(field, operator, value).get();
  return snapshot.size;
}

async function verify(db, organizerId) {
  const [organizer, tournament, membership, bracket, matches] = await Promise.all([
    db.doc(`players/${organizerId}`).get(),
    db.doc(`tournaments/${TOURNAMENT_ID}`).get(),
    db.doc(`tournamentMemberships/${organizerId}_${TOURNAMENT_ID}`).get(),
    db.doc(`knockoutBrackets/${BRACKET_ID}`).get(),
    db.collection("matches").where("tournamentId", "==", TOURNAMENT_ID).get(),
  ]);
  const counts = {
    guestTeams: await countWhere(
      db,
      "guestTeams",
      "tournamentIds",
      TOURNAMENT_ID,
      "array-contains",
    ),
    guestPlayers: await countWhere(db, "guestPlayers", "tournamentId", TOURNAMENT_ID),
    publicRosterEntries: await countWhere(
      db,
      "publicTournamentRosterEntries",
      "tournamentId",
      TOURNAMENT_ID,
    ),
    participants: await countWhere(db, "tournamentParticipants", "tournamentId", TOURNAMENT_ID),
    groups: await countWhere(db, "tournamentGroups", "tournamentId", TOURNAMENT_ID),
    standings: await countWhere(db, "groupStandingSnapshots", "tournamentId", TOURNAMENT_ID),
    matches: matches.size,
    ties: await countWhere(db, "knockoutTies", "tournamentId", TOURNAMENT_ID),
  };
  const expected = {
    guestTeams: 48,
    guestPlayers: 1248,
    publicRosterEntries: 1248,
    participants: 48,
    groups: 12,
    standings: 12,
    matches: 104,
    ties: 31,
  };
  if (!organizer.exists || !tournament.exists || !membership.exists || !bracket.exists) {
    throw new Error("Organizer, tournament, membership, or bracket is missing.");
  }
  if (JSON.stringify(counts) !== JSON.stringify(expected)) {
    throw new Error(`Import counts differ: ${JSON.stringify(counts)}.`);
  }
  const settledMatches = matches.docs.filter((document) => document.get("status") === "settled");
  const openMatches = matches.docs.filter((document) => document.get("status") === "open");
  if (settledMatches.length !== 102 || openMatches.length !== 2) {
    throw new Error(`Expected 102 settled and 2 open matches, got ${settledMatches.length}/${openMatches.length}.`);
  }
  const guestTeams = await db
    .collection("guestTeams")
    .where("tournamentIds", "array-contains", TOURNAMENT_ID)
    .get();
  const rosterSizes = new Map();
  for (const teamDocument of guestTeams.docs) {
    const roster = await db
      .collection("guestPlayers")
      .where("guestTeamId", "==", teamDocument.id)
      .orderBy("createdAt")
      .get();
    rosterSizes.set(teamDocument.id, roster.size);
  }
  const invalidRosters = [...rosterSizes.entries()].filter(
    ([, rosterSize]) => rosterSize !== 26,
  );
  if (rosterSizes.size !== 48 || invalidRosters.length > 0) {
    throw new Error(
      `Expected 48 queryable rosters of 26 players: ${JSON.stringify(invalidRosters)}.`,
    );
  }
  const thirdPlace = matches.docs.find((document) => document.id === "wc2026-match-103");
  const final = matches.docs.find((document) => document.id === "wc2026-match-104");
  if (
    thirdPlace?.get("knockoutMatchRole") !== "thirdPlace" ||
    final?.get("knockoutMatchRole") !== "championship"
  ) {
    throw new Error("Third-place and final match roles are not persisted correctly.");
  }
  return {
    ...counts,
    queryableRosters: rosterSizes.size,
    settledMatches: settledMatches.length,
    openMatches: openMatches.length,
  };
}

async function main() {
  const organizerId = process.argv[2];
  const projectId = process.argv[3];
  if (!organizerId || !projectId) {
    throw new Error("Usage: node verify_world_cup_2026_import.js <organizer-id> <project-id>");
  }
  assertLocalFirestoreEmulator(process.env);
  const app = initializeApp({projectId});
  console.log(JSON.stringify(await verify(getFirestore(app), organizerId), null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {verify};
