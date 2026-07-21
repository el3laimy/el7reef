const assert = require('assert');

const {
  ROSTER_READ_LIMITS,
  resolveCanonicalMatchRoster,
} = require('../../functions/match_roster');

function resolve(overrides = {}) {
  return resolveCanonicalMatchRoster({
    match: {
      teamAId: 'team-a',
      teamBId: 'team-b',
      teamAPlayerIds: [],
      teamBPlayerIds: [],
      ...overrides.match,
    },
    snapshots: overrides.snapshots,
    matchSides: overrides.matchSides,
    matchSidePlayers: overrides.matchSidePlayers,
    participantsById: overrides.participantsById,
    membershipsByTeamId: overrides.membershipsByTeamId,
    guestPlayersByGuestTeamId: overrides.guestPlayersByGuestTeamId,
  });
}

describe('canonical match roster resolver', () => {
  it('keeps every roster query within the settlement read budget', () => {
    assert.deepStrictEqual(ROSTER_READ_LIMITS, {
      lineupSnapshots: 4,
      matchSidePlayers: 50,
      sideRoster: 50,
    });
  });

  it('uses current starters and bench snapshots before mutable team membership', () => {
    const result = resolve({
      snapshots: [{
        sideKey: 'A',
        starters: [
          {playerId: 'player-a'},
          {guestPlayerId: 'guest-a'},
        ],
        bench: [{matchSidePlayerId: 'temporary-a'}],
      }],
      matchSidePlayers: [{
        _id: 'temporary-a',
        sideKey: 'A',
        displayName: 'Temporary A',
      }],
      membershipsByTeamId: new Map([
        ['team-a', [{status: 'starter', playerId: 'late-member'}]],
      ]),
    });

    assert.deepStrictEqual(
      [...result.keysBySide.A].sort(),
      [
        'guestPlayer:guest-a',
        'matchSidePlayer:temporary-a',
        'player:player-a',
      ],
    );
    assert.strictEqual(result.allKeys.has('player:late-member'), false);
  });

  it('falls back to legacy match ids and active registered-team memberships without a lineup', () => {
    const result = resolve({
      match: {teamAPlayerIds: ['legacy-a']},
      membershipsByTeamId: new Map([
        ['team-a', [
          {status: 'starter', playerId: 'starter-a'},
          {status: 'bench', guestPlayerId: 'guest-bench-a'},
          {status: 'inactive', playerId: 'inactive-a'},
          {playerId: 'missing-status-a'},
        ]],
      ]),
    });

    assert.deepStrictEqual(
      [...result.keysBySide.A].sort(),
      [
        'guestPlayer:guest-bench-a',
        'player:legacy-a',
        'player:starter-a',
      ],
    );
  });

  it('loads guest-team players when the tournament participant identifies a guest team', () => {
    const result = resolve({
      match: {
        teamAId: 'guest-team-a',
        teamAParticipantId: 'participant-a',
      },
      participantsById: new Map([
        ['participant-a', {sourceType: 'guestTeam'}],
      ]),
      guestPlayersByGuestTeamId: new Map([
        ['guest-team-a', [{_id: 'guest-1'}, {_id: 'guest-2'}]],
      ]),
    });

    assert.deepStrictEqual(
      [...result.keysBySide.A].sort(),
      ['guestPlayer:guest-1', 'guestPlayer:guest-2'],
    );
  });

  it('keeps registered and temporary match-side players first class without a lineup', () => {
    const result = resolve({
      matchSidePlayers: [
        {_id: 'side-player-a', sideKey: 'A', playerId: 'registered-a'},
        {_id: 'temporary-b', sideKey: 'B'},
      ],
    });

    assert.strictEqual(result.keysBySide.A.has('player:registered-a'), true);
    assert.strictEqual(
      result.keysBySide.B.has('matchSidePlayer:temporary-b'),
      true,
    );
  });

  it('supports legacy snapshot entries during migration', () => {
    const result = resolve({
      snapshots: [{
        teamId: 'team-b',
        entries: [{playerId: 'legacy-snapshot-b'}],
      }],
    });

    assert.strictEqual(
      result.keysBySide.B.has('player:legacy-snapshot-b'),
      true,
    );
  });
});
