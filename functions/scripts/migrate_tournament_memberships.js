"use strict";

const admin = require("firebase-admin");

const {
  DEFAULT_PAGE_SIZE,
  hasBlockingFindings,
  runTournamentMembershipMigration,
} = require("../migrations/tournament_memberships");

function parsePositiveInteger(value, optionName) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${optionName} must be a positive integer.`);
  }
  return parsed;
}

function requireOptionValue(argumentsList, index, optionName) {
  const value = argumentsList[index + 1];
  if (value == null || value.startsWith("--")) {
    throw new Error(`${optionName} requires a value.`);
  }
  return value;
}

function parseCliArgs(argumentsList) {
  const options = {
    dryRun: true,
    help: false,
    maxDocuments: null,
    pageSize: DEFAULT_PAGE_SIZE,
    projectId: null,
  };

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--apply") {
      options.dryRun = false;
      continue;
    }
    if (argument === "--dry-run") {
      options.dryRun = true;
      continue;
    }
    if (argument === "--help" || argument === "-h") {
      options.help = true;
      continue;
    }
    if (argument === "--project") {
      options.projectId = requireOptionValue(argumentsList, index, argument).trim();
      index += 1;
      continue;
    }
    if (argument.startsWith("--project=")) {
      options.projectId = argument.slice("--project=".length).trim();
      continue;
    }
    if (argument === "--page-size") {
      options.pageSize = parsePositiveInteger(
        requireOptionValue(argumentsList, index, argument),
        argument,
      );
      index += 1;
      continue;
    }
    if (argument.startsWith("--page-size=")) {
      options.pageSize = parsePositiveInteger(
        argument.slice("--page-size=".length),
        "--page-size",
      );
      continue;
    }
    if (argument === "--max-documents") {
      options.maxDocuments = parsePositiveInteger(
        requireOptionValue(argumentsList, index, argument),
        argument,
      );
      index += 1;
      continue;
    }
    if (argument.startsWith("--max-documents=")) {
      options.maxDocuments = parsePositiveInteger(
        argument.slice("--max-documents=".length),
        "--max-documents",
      );
      continue;
    }

    throw new Error(`Unknown option: ${argument}`);
  }

  if (!options.help && !options.projectId) {
    throw new Error("Pass --project <firebase-project-id> explicitly.");
  }
  return options;
}

function createFirestoreStore(db) {
  const tournaments = db.collection("tournaments");
  const memberships = db.collection("tournamentMemberships");

  return {
    async listTournaments({after, limit}) {
      let query = tournaments
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
      if (after != null) {
        query = query.startAfter(after);
      }
      const snapshot = await query.get();
      const lastDocument = snapshot.docs.at(-1) ?? null;
      return {
        documents: snapshot.docs.map((document) => ({
          id: document.id,
          data: document.data(),
        })),
        nextCursor: lastDocument,
      };
    },

    async getMembership(membershipId) {
      const snapshot = await memberships.doc(membershipId).get();
      return snapshot.exists ? snapshot.data() : null;
    },

    async createMembershipIfMissing(candidate) {
      return db.runTransaction(async (transaction) => {
        const tournamentReference = tournaments.doc(candidate.tournamentId);
        const membershipReference = memberships.doc(candidate.membershipId);
        const tournamentSnapshot = await transaction.get(tournamentReference);
        const membershipSnapshot = await transaction.get(membershipReference);

        if (!tournamentSnapshot.exists) {
          return {status: "sourceChanged"};
        }
        if (tournamentSnapshot.data()?.organizerId !== candidate.data.userId) {
          return {status: "sourceChanged"};
        }
        if (membershipSnapshot.exists) {
          return {status: "existing", data: membershipSnapshot.data()};
        }

        transaction.create(membershipReference, candidate.data);
        return {status: "created"};
      });
    },
  };
}

function printHelp() {
  console.log(`Usage:
  npm --prefix functions run migration:tournament-memberships -- --project <firebase-project-id> [--dry-run|--apply] [--page-size <1-500>] [--max-documents <count>]

The default mode is --dry-run. --apply creates only missing deterministic organizer memberships and never overwrites an existing membership.`);
}

async function main() {
  const options = parseCliArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  admin.initializeApp({projectId: options.projectId});
  const summary = await runTournamentMembershipMigration({
    store: createFirestoreStore(admin.firestore()),
    dryRun: options.dryRun,
    pageSize: options.pageSize,
    maxDocuments: options.maxDocuments,
  });
  console.log(
    JSON.stringify(
      {
        projectId: options.projectId,
        ...summary,
      },
      null,
      2,
    ),
  );

  if (hasBlockingFindings(summary)) {
    process.exitCode = 2;
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  createFirestoreStore,
  parseCliArgs,
};
