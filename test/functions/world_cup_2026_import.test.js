"use strict";

const assert = require("node:assert/strict");
const squads = require("../../functions/data/world_cup_2026_squads.json");
const matches = require("../../functions/data/world_cup_2026_matches.json");
const {
  assertLocalFirestoreEmulator,
  buildWorldCupImportDocuments,
} = require("../../functions/imports/world_cup_2026");
const {
  assertLocalAuthEmulator,
} = require("../../functions/scripts/seed_world_cup_organizer_auth");
const {
  PLATFORM_ORGANIZER_UID,
  assertCatalogUpdateTarget,
  assertProductionEnvironment,
  buildPublicationDocuments,
  findDocumentCollisions,
  parseOptions,
  publicationCatalogPatch,
} = require("../../functions/scripts/publish_world_cup_2026");

describe("World Cup 2026 emulator import", () => {
  it("builds the complete deterministic organizer simulation without invented match events", () => {
    const first = buildWorldCupImportDocuments({organizerId: "organizer-1", squads, matches});
    const second = buildWorldCupImportDocuments({organizerId: "organizer-1", squads, matches});
    assert.deepStrictEqual(first, second);
    assert.strictEqual(first.length, 2756);

    const paths = new Set(first.map((document) => document.path));
    assert.strictEqual(paths.size, first.length);
    assert.ok(paths.has("players/organizer-1"));
    assert.strictEqual([...paths].filter((path) => path.startsWith("guestTeams/")).length, 48);
    assert.strictEqual([...paths].filter((path) => path.startsWith("guestPlayers/")).length, 1248);
    assert.strictEqual(
      [...paths].filter((path) => path.startsWith("publicTournamentRosterEntries/")).length,
      1248,
    );
    const publicRosterEntries = first.filter((document) =>
      document.path.startsWith("publicTournamentRosterEntries/"),
    );
    assert.ok(
      publicRosterEntries.every(
        (document) =>
          !("phoneNumber" in document.data) &&
          !("claimCode" in document.data) &&
          !("notes" in document.data),
      ),
    );
    assert.strictEqual([...paths].filter((path) => path.startsWith("matches/")).length, 104);
    assert.strictEqual([...paths].filter((path) => path.startsWith("knockoutTies/")).length, 31);
    assert.strictEqual([...paths].filter((path) => path.startsWith("matchEvents/")).length, 0);
    const tournament = first.find(
      (document) => document.path === "tournaments/world-cup-2026-simulation",
    ).data;
    assert.strictEqual(tournament.name, "كأس العالم 2026");
    assert.strictEqual(tournament.visibility, "public");
    assert.strictEqual(tournament.discoverable, true);
    assert.strictEqual(tournament.isFeatured, true);
    assert.strictEqual(tournament.featuredPriority, 0);
    assert.ok(paths.has("knockoutTies/wc2026-tie-104"));
    assert.ok(!paths.has("knockoutTies/wc2026-tie-103"));
    assert.strictEqual(
      first.find((document) => document.path === "matches/wc2026-match-103").data
        .knockoutMatchRole,
      "thirdPlace",
    );
    assert.strictEqual(
      first.find((document) => document.path === "matches/wc2026-match-104").data
        .knockoutMatchRole,
      "championship",
    );
    for (const team of squads.teams) {
      const importedTeamId = `wc2026-team-${team.code.toLowerCase()}`;
      const roster = first.filter(
        (document) =>
          document.path.startsWith("guestPlayers/") &&
          document.data.guestTeamId === importedTeamId,
      );
      assert.strictEqual(roster.length, 26, importedTeamId);
    }
  });

  it("keeps all 48 participants in one four-team group and publishes real standings", () => {
    const documents = buildWorldCupImportDocuments({organizerId: "organizer-1", squads, matches});
    const groups = documents.filter((document) => document.path.startsWith("tournamentGroups/"));
    const standings = documents.filter((document) =>
      document.path.startsWith("groupStandingSnapshots/"),
    );
    assert.strictEqual(groups.length, 12);
    assert.strictEqual(standings.length, 12);
    for (const group of groups) {
      assert.strictEqual(group.data.participantIds.length, 4);
      assert.ok(group.data.qualifierParticipantIds.length === 2 || group.data.qualifierParticipantIds.length === 3);
    }
    for (const standing of standings) {
      assert.strictEqual(standing.data.entries.length, 4);
      assert.ok(standing.data.entries.every((entry) => entry.played === 3));
    }
    assert.strictEqual(
      new Set(groups.flatMap((group) => group.data.qualifierParticipantIds)).size,
      32,
    );
  });

  it("propagates every settled knockout winner into the recorded next tie", () => {
    const documents = buildWorldCupImportDocuments({organizerId: "organizer-1", squads, matches});
    const ties = new Map(
      documents
        .filter((document) => document.path.startsWith("knockoutTies/"))
        .map((document) => [document.path.split("/")[1], document.data]),
    );
    for (const tie of ties.values()) {
      if (!tie.winnerParticipantId || !tie.nextTieId) continue;
      const nextTie = ties.get(tie.nextTieId);
      assert.ok(nextTie, tie.nextTieId);
      assert.ok(
        nextTie.participantAId === tie.winnerParticipantId ||
          nextTie.participantBId === tie.winnerParticipantId,
        `${tie.winnerParticipantId} was dropped before ${tie.nextTieId}`,
      );
    }
  });

  it("refuses apply mode unless Firestore points to a local emulator", () => {
    assert.throws(() => assertLocalFirestoreEmulator({}), /Refusing import/);
    assert.throws(
      () => assertLocalFirestoreEmulator({FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443"}),
      /Refusing import/,
    );
    assert.doesNotThrow(() =>
      assertLocalFirestoreEmulator({FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080"}),
    );
  });

  it("refuses organizer seeding unless Auth points to a local emulator", () => {
    assert.throws(() => assertLocalAuthEmulator({}), /Refusing seed/);
    assert.throws(
      () =>
        assertLocalAuthEmulator({
          FIREBASE_AUTH_EMULATOR_HOST: "identitytoolkit.googleapis.com:443",
        }),
      /Refusing seed/,
    );
    assert.doesNotThrow(() =>
      assertLocalAuthEmulator({FIREBASE_AUTH_EMULATOR_HOST: "localhost:9099"}),
    );
  });

  it("builds a platform-owned publication with one limited operator assistant", () => {
    const documents = buildPublicationDocuments({
      operatorUid: "operator-1",
      squads,
      matches,
    });

    assert.strictEqual(documents.length, 2757);
    assert.ok(
      documents.some(
        (document) => document.path === `players/${PLATFORM_ORGANIZER_UID}` &&
          document.data.name === "الحريف",
      ),
    );
    const tournament = documents.find(
      (document) => document.path === "tournaments/world-cup-2026-simulation",
    );
    assert.strictEqual(tournament.data.organizerId, PLATFORM_ORGANIZER_UID);
    const assistant = documents.find(
      (document) =>
        document.path ===
        "tournaments/world-cup-2026-simulation/assistants/operator-1",
    );
    assert.strictEqual(assistant.data.status, "active");
    assert.strictEqual(assistant.data.permissions.canApproveScore, true);
    assert.strictEqual(assistant.data.permissions.canManageGuestRoster, false);
  });

  it("keeps the production publisher in dry-run unless project and confirmation are explicit", () => {
    assert.deepStrictEqual(
      parseOptions(["--project", "el7reef-app", "--operator-uid", "operator-1"]),
      {
        apply: false,
        catalogOnly: false,
        projectId: "el7reef-app",
        confirmedProjectId: null,
        operatorUid: "operator-1",
      },
    );
    assert.throws(
      () => parseOptions(["--project", "other-project", "--operator-uid", "operator-1"]),
      /restricted to el7reef-app/,
    );
    assert.throws(
      () => parseOptions([
        "--project",
        "el7reef-app",
        "--operator-uid",
        "operator-1",
        "--apply",
      ]),
      /requires --confirm-project/,
    );
  });

  it("refuses production writes while emulator variables are present", () => {
    assert.throws(
      () => assertProductionEnvironment({FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080"}),
      /refuses emulator/,
    );
    assert.doesNotThrow(() => assertProductionEnvironment({}));
  });

  it("detects document collisions before a full publication", async () => {
    const references = new Map();
    const fakeDb = {
      doc(documentPath) {
        const reference = {path: documentPath};
        references.set(documentPath, reference);
        return reference;
      },
      async getAll(...requestedReferences) {
        return requestedReferences.map((reference) => ({
          exists: reference.path === "tournaments/world-cup-2026-simulation",
          ref: reference,
        }));
      },
    };

    const collisions = await findDocumentCollisions(fakeDb, [
      {path: "players/el7reef-official", data: {}},
      {path: "tournaments/world-cup-2026-simulation", data: {}},
    ]);

    assert.deepStrictEqual(collisions, ["tournaments/world-cup-2026-simulation"]);
    assert.strictEqual(references.size, 2);
  });

  it("catalog-only mode changes presentation metadata and verifies platform ownership", () => {
    assert.deepStrictEqual(Object.keys(publicationCatalogPatch()).sort(), [
      "description",
      "discoverable",
      "featuredPriority",
      "isFeatured",
      "name",
      "visibility",
    ]);
    assert.doesNotThrow(() =>
      assertCatalogUpdateTarget({
        exists: true,
        get: (field) => field === "organizerId" ? PLATFORM_ORGANIZER_UID : null,
      }),
    );
    assert.throws(
      () => assertCatalogUpdateTarget({exists: false, get: () => null}),
      /requires an existing World Cup tournament/,
    );
    assert.throws(
      () => assertCatalogUpdateTarget({exists: true, get: () => "another-owner"}),
      /owned by another account/,
    );
  });
});
