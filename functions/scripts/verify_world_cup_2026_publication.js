"use strict";

const admin = require("firebase-admin");
const {TOURNAMENT_ID} = require("../imports/world_cup_2026");
const {verify} = require("./verify_world_cup_2026_import");
const {
  PLATFORM_ORGANIZER_UID,
  PRODUCTION_PROJECT_ID,
  assertProductionEnvironment,
} = require("./publish_world_cup_2026");

function parseOptions(argumentsList) {
  const options = {projectId: null, confirmedProjectId: null, operatorUid: null};
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (["--project", "--confirm-project", "--operator-uid"].includes(argument)) {
      const value = argumentsList[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`${argument} requires a value.`);
      if (argument === "--project") options.projectId = value;
      if (argument === "--confirm-project") options.confirmedProjectId = value;
      if (argument === "--operator-uid") options.operatorUid = value;
      index += 1;
      continue;
    }
    throw new Error(`Unknown option: ${argument}`);
  }
  if (
    options.projectId !== PRODUCTION_PROJECT_ID ||
    options.confirmedProjectId !== PRODUCTION_PROJECT_ID ||
    !options.operatorUid
  ) {
    throw new Error(`Verification requires confirmed project ${PRODUCTION_PROJECT_ID} and operator UID.`);
  }
  return options;
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  assertProductionEnvironment(process.env);
  admin.initializeApp({projectId: options.projectId});
  const db = admin.firestore();
  const baseVerification = await verify(db, PLATFORM_ORGANIZER_UID);
  const [tournament, assistant] = await Promise.all([
    db.doc(`tournaments/${TOURNAMENT_ID}`).get(),
    db.doc(`tournaments/${TOURNAMENT_ID}/assistants/${options.operatorUid}`).get(),
  ]);
  const tournamentData = tournament.data();
  if (
    tournamentData.name !== "كأس العالم 2026" ||
    tournamentData.visibility !== "public" ||
    tournamentData.discoverable !== true ||
    tournamentData.isFeatured !== true ||
    tournamentData.featuredPriority !== 0
  ) {
    throw new Error("World Cup catalog metadata is not public and featured.");
  }
  if (!assistant.exists || assistant.get("status") !== "active") {
    throw new Error("World Cup operator assistant permission is missing or inactive.");
  }
  console.log(JSON.stringify({
    ...baseVerification,
    public: true,
    featured: true,
    operatorAssistant: true,
  }, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {parseOptions};
