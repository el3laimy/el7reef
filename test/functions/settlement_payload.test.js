const assert = require('assert');

const {
  SettlementPayloadError,
  assertSettlementParticipantsInRoster,
  goalEventId,
  normalizeDetailedStats,
  normalizeGoalDrafts,
  normalizeMvpDraft,
  normalizeParticipantRef,
  participantKey,
} = require('../../functions/settlement_payload');
const participantContract = require('../fixtures/participant_identity_contract.json');

function roster({sideA = [], sideB = []} = {}) {
  return {
    keysBySide: {A: new Set(sideA), B: new Set(sideB)},
    allKeys: new Set([...sideA, ...sideB]),
  };
}

describe('settlement payload helpers', () => {
  it('matches the shared participant identity contract', () => {
    for (const fixture of participantContract.validParticipants) {
      const actor = normalizeParticipantRef(fixture);
      assert.strictEqual(participantKey(actor), fixture.identityKey);
      assert.strictEqual(actor.kind, fixture.kind);
      assert.strictEqual(actor.id, fixture.id);
      assert.strictEqual(actor.linkedPlayerId, fixture.linkedPlayerId);
    }
  });

  it('rejects every invalid participant in the shared contract', () => {
    for (const fixture of participantContract.invalidParticipants) {
      assert.throws(
        () => normalizeParticipantRef(fixture.actor),
        SettlementPayloadError,
        fixture.label,
      );
    }
  });

  it('builds deterministic goal event ids for guest scorers', () => {
    const [goal] = normalizeGoalDrafts([
      {
        sideKey: 'a',
        actor: {
          kind: 'guestPlayer',
          id: 'guest scorer',
          displayName: 'ضيف هداف',
          linkedPlayerId: 'player-1',
        },
        goals: 2,
      },
    ]);

    assert.strictEqual(goal.sideKey, 'A');
    assert.strictEqual(goal.minute, null);
    assert.deepStrictEqual(goal.actor, {
      kind: 'guestPlayer',
      id: 'guest scorer',
      displayName: 'ضيف هداف',
      linkedPlayerId: 'player-1',
    });
    assert.strictEqual(
      goalEventId({
        matchId: 'match-1',
        sideKey: goal.sideKey,
        actor: goal.actor,
        index: 1,
      }),
      'goal-match-1-A-guestPlayer-guest%20scorer-1',
    );
  });

  it('normalizes the complete registered-player stats schema', () => {
    const [stats] = normalizeDetailedStats([
      {
        playerId: 'player-1',
        matchId: 'match-1',
        teamId: 'untrusted-team',
        played: true,
        position: 'goalkeeper',
        goals: 0,
        assists: 1,
        saves: 8,
        tackles: 2,
        cleanSheet: true,
        yellowCard: false,
        redCard: false,
        rating: 9.25,
      },
    ], 'match-1');

    assert.deepStrictEqual(stats, {
      playerId: 'player-1',
      played: true,
      position: 'goalkeeper',
      goals: 0,
      assists: 1,
      saves: 8,
      tackles: 2,
      cleanSheet: true,
      yellowCard: false,
      redCard: false,
      rating: 9.25,
    });
  });

  for (const [scenario, rawStats] of [
    [
      'duplicate player ids',
      [{playerId: 'p1'}, {playerId: 'p1'}],
    ],
    [
      'negative counts',
      [{playerId: 'p1', goals: -1}],
    ],
    [
      'unknown fields',
      [{playerId: 'p1', bonusPoints: 5}],
    ],
    [
      'a different match id',
      [{playerId: 'p1', matchId: 'match-2'}],
    ],
    [
      'an invalid position',
      [{playerId: 'p1', position: 'striker'}],
    ],
  ]) {
    it(`rejects detailed stats with ${scenario}`, () => {
      assert.throws(
        () => normalizeDetailedStats(rawStats, 'match-1'),
        SettlementPayloadError,
      );
    });
  }

  it('rejects duplicate scorer identities before event ids can collide', () => {
    assert.throws(
      () => normalizeGoalDrafts([
        {
          sideKey: 'A',
          actor: {
            kind: 'player',
            id: 'p1',
            displayName: 'Player One',
          },
          goals: 1,
        },
        {
          sideKey: 'A',
          actor: {
            kind: 'player',
            id: 'p1',
            displayName: 'Player One',
          },
          goals: 1,
        },
      ]),
      /duplicate goal actor/,
    );
  });

  for (const [fieldName, normalizeInvalidField] of [
    ['goals', () => normalizeGoalDrafts({})],
    ['detailedStats', () => normalizeDetailedStats({}, 'match-1')],
    ['mvp', () => normalizeMvpDraft([])],
  ]) {
    it(`rejects a non-structured ${fieldName} payload`, () => {
      assert.throws(normalizeInvalidField, SettlementPayloadError);
    });
  }

  it('rejects goal and MVP actors outside the roster', () => {
    const goals = normalizeGoalDrafts([
      {
        sideKey: 'A',
        actor: {
          kind: 'guestPlayer',
          id: 'guest-1',
          displayName: 'Guest One',
        },
        goals: 1,
      },
    ]);
    const mvp = normalizeMvpDraft({
      sideKey: 'A',
      actor: {
        kind: 'guestPlayer',
        id: 'guest-1',
        displayName: 'Guest One',
      },
    });

    assert.throws(() => {
      assertSettlementParticipantsInRoster({
        goals,
        mvp,
        roster: roster({sideA: ['player:player-1']}),
      });
    }, SettlementPayloadError);
  });

  it('accepts guest goal and MVP actors that match the roster identity key', () => {
    const goals = normalizeGoalDrafts([
      {
        sideKey: 'B',
        actor: {
          kind: 'guestPlayer',
          id: 'guest-1',
          displayName: 'Guest One',
        },
        goals: 1,
      },
    ]);
    const mvp = normalizeMvpDraft({
      sideKey: 'B',
      actor: {
        kind: 'guestPlayer',
        id: 'guest-1',
        displayName: 'Guest One',
      },
    });

    assert.doesNotThrow(() => {
      assertSettlementParticipantsInRoster({
        goals,
        mvp,
        roster: roster({sideB: ['guestPlayer:guest-1']}),
      });
    });
  });

  it('does not bypass validation when a pride actor is submitted to an empty roster', () => {
    const goals = normalizeGoalDrafts([
      {
        sideKey: 'A',
        actor: {
          kind: 'player',
          id: 'outsider',
          displayName: 'Outsider',
        },
        goals: 1,
      },
    ]);

    assert.throws(
      () => assertSettlementParticipantsInRoster({
        goals,
        roster: roster(),
      }),
      /outside the submitted match side roster/,
    );
  });

  it('rejects an actor assigned to the opposite match side', () => {
    const mvp = normalizeMvpDraft({
      sideKey: 'A',
      actor: {
        kind: 'guestPlayer',
        id: 'guest-b',
        displayName: 'Guest B',
      },
    });

    assert.throws(
      () => assertSettlementParticipantsInRoster({
        mvp,
        roster: roster({sideB: ['guestPlayer:guest-b']}),
      }),
      /outside the submitted match side roster/,
    );
  });

  it('rejects detailed stats for a registered player outside the roster', () => {
    assert.throws(
      () => assertSettlementParticipantsInRoster({
        detailedStats: [{playerId: 'outsider'}],
        roster: roster({sideA: ['player:player-a']}),
      }),
      /detailed stats player is outside match roster/,
    );
  });

  it('accepts a legacy MVP id for any participant identity kind in the roster', () => {
    assert.doesNotThrow(() => assertSettlementParticipantsInRoster({
      mvpPlayerId: 'guest-a',
      roster: roster({sideA: ['guestPlayer:guest-a']}),
    }));
  });
});
