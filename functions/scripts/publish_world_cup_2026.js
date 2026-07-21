"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {
  TOURNAMENT_ID,
  buildWorldCupImportDocuments,
  writeImportDocuments,
} = require("../imports/world_cup_2026");

const PRODUCTION_PROJECT_ID = "el7reef-app";
const PLATFORM_ORGANIZER_UID = "el7reef-official";
const PLATFORM_ORGANIZER_EMAIL = "tournaments@el7reef.app";
const PLATFORM_ORGANIZER_NAME = "الحريف";

function parseOptions(argumentsList) {
  const options = {
    apply: false,
    catalogOnly: false,
    projectId: null,
    confirmedProjectId: null,
    operatorUid: null,
  };
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--apply") {
      options.apply = true;
      continue;
    }
    if (argument === "--catalog-only") {
      options.catalogOnly = true;
      continue;
    }
    if (["--project", "--confirm-project", "--operator-uid"].includes(argument)) {
      const value = argumentsList[index + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`${argument} requires a value.`);
      }
      if (argument === "--project") options.projectId = value;
      if (argument === "--confirm-project") options.confirmedProjectId = value;
      if (argument === "--operator-uid") options.operatorUid = value;
      index += 1;
      continue;
    }
    throw new Error(`Unknown option: ${argument}`);
  }
  if (!options.projectId || !options.operatorUid) {
    throw new Error("Pass --project <project-id> and --operator-uid <uid> explicitly.");
  }
  if (options.apply && options.confirmedProjectId !== options.projectId) {
    throw new Error("Apply mode requires --confirm-project to match --project.");
  }
  if (options.projectId !== PRODUCTION_PROJECT_ID) {
    throw new Error(`Publisher is restricted to ${PRODUCTION_PROJECT_ID}.`);
  }
  return options;
}

function assertProductionEnvironment(environment) {
  if (environment.FIRESTORE_EMULATOR_HOST || environment.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error("Production publisher refuses emulator environment variables.");
  }
}

function loadWorldCupData() {
  const dataRoot = path.join(__dirname, "../data");
  return {
    squads: JSON.parse(fs.readFileSync(path.join(dataRoot, "world_cup_2026_squads.json"))),
    matches: JSON.parse(fs.readFileSync(path.join(dataRoot, "world_cup_2026_matches.json"))),
  };
}

function assistantPermissionDocument(operatorUid) {
  const createdAt = Date.parse("2026-07-21T12:00:00Z");
  return {
    path: `tournaments/${TOURNAMENT_ID}/assistants/${operatorUid}`,
    data: {
      tournamentId: TOURNAMENT_ID,
      userId: operatorUid,
      addedBy: PLATFORM_ORGANIZER_UID,
      status: "active",
      preset: "customLimited",
      permissions: {
        canViewMatchday: true,
        canStartMatch: true,
        canSubmitScore: true,
        canRecordGoalsAndMvp: true,
        canApproveScore: true,
        canDeclareForfeit: true,
        canManageGuestRoster: false,
      },
      createdAt,
      updatedAt: createdAt,
      revokedAt: null,
    },
  };
}

function buildPublicationDocuments({operatorUid, squads, matches}) {
  const documents = buildWorldCupImportDocuments({
    organizerId: PLATFORM_ORGANIZER_UID,
    squads,
    matches,
  });
  const organizer = documents.find(
    (document) => document.path === `players/${PLATFORM_ORGANIZER_UID}`,
  );
  organizer.data.name = PLATFORM_ORGANIZER_NAME;
  organizer.data.nameLower = PLATFORM_ORGANIZER_NAME;
  documents.push(assistantPermissionDocument(operatorUid));
  return documents;
}

async function findDocumentCollisions(db, documents, chunkSize = 200) {
  const collisions = [];
  for (let offset = 0; offset < documents.length; offset += chunkSize) {
    const references = documents
      .slice(offset, offset + chunkSize)
      .map((document) => db.doc(document.path));
    const snapshots = await db.getAll(...references);
    collisions.push(...snapshots.filter((snapshot) => snapshot.exists).map((snapshot) => snapshot.ref.path));
  }
  return collisions;
}

async function ensurePlatformAuthUser(auth) {
  try {
    const existing = await auth.getUser(PLATFORM_ORGANIZER_UID);
    if (existing.email !== PLATFORM_ORGANIZER_EMAIL) {
      throw new Error("Platform organizer UID already belongs to another email.");
    }
    await auth.updateUser(PLATFORM_ORGANIZER_UID, {
      displayName: PLATFORM_ORGANIZER_NAME,
      disabled: true,
      emailVerified: true,
    });
    return "updated";
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid: PLATFORM_ORGANIZER_UID,
      email: PLATFORM_ORGANIZER_EMAIL,
      displayName: PLATFORM_ORGANIZER_NAME,
      disabled: true,
      emailVerified: true,
    });
    return "created";
  }
}

function publicationCatalogPatch() {
  return {
    name: "كأس العالم 2026",
    description: "محاكاة داخل الحريف تضم المنتخبات والقوائم والنتائج الموثقة حتى 17 يوليو 2026.",
    visibility: "public",
    discoverable: true,
    isFeatured: true,
    featuredPriority: 0,
  };
}

function assertCatalogUpdateTarget(tournamentSnapshot) {
  if (!tournamentSnapshot.exists) {
    throw new Error("Catalog-only mode requires an existing World Cup tournament.");
  }
  if (tournamentSnapshot.get("organizerId") !== PLATFORM_ORGANIZER_UID) {
    throw new Error("Catalog-only mode refuses a tournament owned by another account.");
  }
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  const documents = buildPublicationDocuments({
    operatorUid: options.operatorUid,
    ...loadWorldCupData(),
  });
  if (!options.apply) {
    printDryRun(options, documents.length);
    return;
  }

  assertProductionEnvironment(process.env);
  const admin = require("firebase-admin");
  admin.initializeApp({projectId: options.projectId});
  if (options.catalogOnly) {
    await updateCatalogOnly(admin.firestore());
    return;
  }
  await publishNewTournament(admin, documents);
}

function printDryRun(options, documentCount) {
  console.log(JSON.stringify({
    mode: "dry-run",
    projectId: options.projectId,
    catalogOnly: options.catalogOnly,
    documents: options.catalogOnly ? 1 : documentCount,
    tournamentId: TOURNAMENT_ID,
    organizerUid: PLATFORM_ORGANIZER_UID,
    operatorUid: options.operatorUid,
  }, null, 2));
}

async function updateCatalogOnly(db) {
  const tournamentReference = db.doc(`tournaments/${TOURNAMENT_ID}`);
  const tournament = await tournamentReference.get();
  assertCatalogUpdateTarget(tournament);
  await tournamentReference.update(publicationCatalogPatch());
  console.log(JSON.stringify({mode: "catalog-only", updated: 1}, null, 2));
}

async function publishNewTournament(admin, documents) {
  const db = admin.firestore();
  const collisions = await findDocumentCollisions(db, documents);
  if (collisions.length > 0) {
    throw new Error(`Publication aborted; existing documents: ${collisions.slice(0, 10).join(", ")}`);
  }
  const authUser = await ensurePlatformAuthUser(admin.auth());
  const written = await writeImportDocuments(db, documents);
  console.log(JSON.stringify({mode: "published", written, authUser}, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  PLATFORM_ORGANIZER_EMAIL,
  PLATFORM_ORGANIZER_UID,
  PRODUCTION_PROJECT_ID,
  assertCatalogUpdateTarget,
  assertProductionEnvironment,
  buildPublicationDocuments,
  findDocumentCollisions,
  parseOptions,
  publicationCatalogPatch,
};
