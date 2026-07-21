const assert = require('assert');

const {
  buildOrganizerMembershipCandidate,
  runTournamentMembershipMigration,
} = require('../../functions/migrations/tournament_memberships');

const NOW = 1770000000000;

describe('tournament membership migration', () => {
  it('builds the canonical organizer membership without adding migration fields', () => {
    const candidate = buildOrganizerMembershipCandidate({
      tournamentId: 'cup-1',
      tournament: {
        organizerId: 'organizer-1',
        createdAt: 1760000000000,
      },
      fallbackTimestamp: NOW,
    });

    assert.deepStrictEqual(candidate, {
      kind: 'candidate',
      tournamentId: 'cup-1',
      membershipId: 'organizer-1_cup-1',
      usedFallbackCreatedAt: false,
      data: {
        tournamentId: 'cup-1',
        userId: 'organizer-1',
        role: 'organizer',
        createdAt: 1760000000000,
      },
    });
  });

  it('reports planned memberships without writes in dry-run mode', async () => {
    const store = new FakeMigrationStore({
      tournaments: [
        {
          id: 'legacy-a',
          data: {organizerId: 'organizer-a', createdAt: 1760000000000},
        },
        {
          id: 'legacy-b',
          data: {organizerId: 'organizer-b'},
        },
      ],
    });

    const dryRun = await runTournamentMembershipMigration({
      store,
      now: () => NOW,
      pageSize: 2,
    });

    assert.strictEqual(dryRun.dryRun, true);
    assert.strictEqual(dryRun.scanned, 2);
    assert.strictEqual(dryRun.wouldCreate, 2);
    assert.strictEqual(dryRun.created, 0);
    assert.strictEqual(dryRun.invalidSources, 0);
    assert.strictEqual(dryRun.conflicts, 0);
    assert.strictEqual(dryRun.fallbackCreatedAt, 1);
    assert.strictEqual(store.membership('organizer-a_legacy-a'), null);
  });

  it('creates missing memberships once and recognizes them on rerun', async () => {
    const store = new FakeMigrationStore({
      tournaments: [
        {
          id: 'legacy-a',
          data: {organizerId: 'organizer-a', createdAt: 1760000000000},
        },
        {
          id: 'legacy-b',
          data: {organizerId: 'organizer-b'},
        },
      ],
    });

    const apply = await runTournamentMembershipMigration({
      store,
      dryRun: false,
      now: () => NOW,
      pageSize: 2,
    });

    assert.strictEqual(apply.created, 2);
    assert.deepStrictEqual(store.membership('organizer-a_legacy-a'), {
      tournamentId: 'legacy-a',
      userId: 'organizer-a',
      role: 'organizer',
      createdAt: 1760000000000,
    });
    assert.deepStrictEqual(store.membership('organizer-b_legacy-b'), {
      tournamentId: 'legacy-b',
      userId: 'organizer-b',
      role: 'organizer',
      createdAt: NOW,
    });

    const rerun = await runTournamentMembershipMigration({
      store,
      dryRun: false,
      now: () => NOW,
      pageSize: 2,
    });

    assert.strictEqual(rerun.created, 0);
    assert.strictEqual(rerun.existingCompatible, 2);
  });

  it('reports invalid source documents and conflicts without changing them', async () => {
    const store = new FakeMigrationStore({
      tournaments: [
        {
          id: 'missing-owner',
          data: {createdAt: 1760000000200},
        },
        {
          id: 'conflict',
          data: {organizerId: 'organizer-c', createdAt: 1760000000300},
        },
      ],
      memberships: {
        'organizer-c_conflict': {
          tournamentId: 'conflict',
          userId: 'different-organizer',
          role: 'organizer',
          createdAt: 1760000000300,
        },
      },
    });

    const summary = await runTournamentMembershipMigration({
      store,
      dryRun: false,
      now: () => NOW,
    });

    assert.strictEqual(summary.created, 0);
    assert.strictEqual(summary.conflicts, 1);
    assert.strictEqual(summary.invalidSources, 1);
    assert.deepStrictEqual(store.membership('organizer-c_conflict'), {
      tournamentId: 'conflict',
      userId: 'different-organizer',
      role: 'organizer',
      createdAt: 1760000000300,
    });
  });

  it('treats a concurrent membership as existing instead of overwriting it', async () => {
    const store = new FakeMigrationStore({
      tournaments: [
        {
          id: 'cup-1',
          data: {organizerId: 'organizer-1', createdAt: 1760000000000},
        },
      ],
      onCreateAttempt: ({membershipId}) => {
        store.setMembership(membershipId, {
          tournamentId: 'cup-1',
          userId: 'organizer-1',
          role: 'organizer',
          createdAt: 1750000000000,
        });
      },
    });

    const summary = await runTournamentMembershipMigration({
      store,
      dryRun: false,
      now: () => NOW,
    });

    assert.strictEqual(summary.created, 0);
    assert.strictEqual(summary.existingCompatible, 1);
    assert.deepStrictEqual(store.membership('organizer-1_cup-1'), {
      tournamentId: 'cup-1',
      userId: 'organizer-1',
      role: 'organizer',
      createdAt: 1750000000000,
    });
  });
});

class FakeMigrationStore {
  constructor({tournaments, memberships = {}, onCreateAttempt = null}) {
    this._tournaments = tournaments.map((tournament) => ({
      id: tournament.id,
      data: clone(tournament.data),
    }));
    this._memberships = new Map(
      Object.entries(memberships).map(([membershipId, membership]) => [
        membershipId,
        clone(membership),
      ]),
    );
    this._onCreateAttempt = onCreateAttempt;
  }

  async listTournaments({after, limit}) {
    const startIndex = after == null
      ? 0
      : this._tournaments.findIndex((tournament) => tournament.id === after) + 1;
    const documents = this._tournaments.slice(startIndex, startIndex + limit);
    return {
      documents: documents.map((tournament) => ({
        id: tournament.id,
        data: clone(tournament.data),
      })),
      nextCursor: documents.at(-1)?.id ?? null,
    };
  }

  async getMembership(membershipId) {
    return this.membership(membershipId);
  }

  async createMembershipIfMissing(candidate) {
    this._onCreateAttempt?.({
      membershipId: candidate.membershipId,
      candidate: clone(candidate),
    });
    const tournament = this._tournaments.find(
      (source) => source.id === candidate.tournamentId,
    );
    if (tournament?.data.organizerId !== candidate.data.userId) {
      return {status: 'sourceChanged'};
    }

    const existing = this.membership(candidate.membershipId);
    if (existing != null) {
      return {status: 'existing', data: existing};
    }

    this.setMembership(candidate.membershipId, candidate.data);
    return {status: 'created'};
  }

  membership(membershipId) {
    const membership = this._memberships.get(membershipId);
    return membership == null ? null : clone(membership);
  }

  setMembership(membershipId, membership) {
    this._memberships.set(membershipId, clone(membership));
  }
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}
