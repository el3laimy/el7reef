"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {
  assertLocalFirestoreEmulator,
  buildWorldCupImportDocuments,
  writeImportDocuments,
} = require("../imports/world_cup_2026");

function parseOptions(argumentsList) {
  const options = {apply: false, organizerId: null, projectId: null};
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--apply") {
      options.apply = true;
      continue;
    }
    if (argument === "--organizer-id" || argument === "--project") {
      const value = argumentsList[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`${argument} requires a value.`);
      options[argument === "--organizer-id" ? "organizerId" : "projectId"] = value;
      index += 1;
      continue;
    }
    throw new Error(`Unknown option: ${argument}`);
  }
  if (!options.organizerId || !options.projectId) {
    throw new Error("Pass --organizer-id <uid> and --project <project-id> explicitly.");
  }
  return options;
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  const dataRoot = path.join(__dirname, "../data");
  const documents = buildWorldCupImportDocuments({
    organizerId: options.organizerId,
    squads: JSON.parse(fs.readFileSync(path.join(dataRoot, "world_cup_2026_squads.json"))),
    matches: JSON.parse(fs.readFileSync(path.join(dataRoot, "world_cup_2026_matches.json"))),
  });
  if (!options.apply) {
    console.log(JSON.stringify({mode: "dry-run", documents: documents.length}, null, 2));
    return;
  }

  assertLocalFirestoreEmulator(process.env);
  const admin = require("firebase-admin");
  admin.initializeApp({projectId: options.projectId});
  const written = await writeImportDocuments(admin.firestore(), documents);
  console.log(JSON.stringify({mode: "applied", written}, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {parseOptions};
