const assert = require('assert');

const {
  SettlementError,
  approveMatchScoreCore,
} = require('../../functions/approval_core');
const {
  ACTIVE_EVENT_READ_LIMIT,
  submitMatchSettlementCore,
} = require('../../functions/settlement_core');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = 1770000000000;

describe('submitMatchSettlementCore', () => {
  it('caps active event reads above the maximum valid settlement fan-out', () => {
    assert.strictEqual(ACTIVE_EVENT_READ_LIMIT, 205);
  });

  it('writes trusted stats, pride events, and full registered voting eligibility', async () => {
    const db = settlementDatabase();

    const response = await submit(db, validPayload());

    assert.deepStrictEqual(response, {
      status: 'completed',
      ratingsApplied: false,
      alreadySettled: false,
      prideEventsPending: false,
    });
    const settledMatch = db.docData('matches/match-1');
    assert.strictEqual(settledMatch.status, 'completed');
    assert.strictEqual(settledMatch.settlementSubmissionFingerprint.length, 64);
    assert.strictEqual(settledMatch.settlementSubmittedBy, 'organizer-1');
    assert.deepStrictEqual(
      db.docData('matches/match-1/player_stats/p1'),
      {
        playerId: 'p1',
        matchId: 'match-1',
        teamId: 'A',
        played: true,
        position: 'forward',
        goals: 1,
        assists: 0,
        saves: 0,
        tackles: 3,
        cleanSheet: false,
        yellowCard: false,
        redCard: false,
        rating: 8.5,
      },
    );
    assert.strictEqual(db.collectionData('matchEvents').length, 2);
    assert.deepStrictEqual(
      db.docData('fanVotingSessions/match-1').eligiblePlayerIds,
      ['p1', 'p2'],
    );
    const audit = db.collectionData('auditEvents');
    assert.strictEqual(audit.length, 1);
    assert.strictEqual(audit[0].action, 'matchScoreSubmitted');
    assert.strictEqual(audit[0].actorId, 'organizer-1');
    assert.strictEqual(audit[0].source, 'trustedOperation');
    assert.strictEqual(audit[0].verificationVersion, 1);
    assert.ok(audit[0].requestId.startsWith('match-settlement:'));
  });

  it('returns an idempotent retry without duplicating settlement writes', async () => {
    const db = settlementDatabase();
    const payload = validPayload();
    await submit(db, payload);
    const originalEvents = db.collectionData('matchEvents');

    const retry = await submit(db, payload);

    assert.strictEqual(retry.alreadySettled, true);
    assert.deepStrictEqual(db.collectionData('matchEvents'), originalEvents);
    assert.strictEqual(
      db.collectionData('matches/match-1/player_stats').length,
      1,
    );
    assert.strictEqual(db.collectionData('auditEvents').length, 1);
  });

  it('stores a decisive knockout penalty result separately from match goals', async () => {
    const db = settlementDatabase({stageType: 'knockoutStage'});

    await submit(db, validPayload({
      scoreA: 1,
      scoreB: 1,
      penaltyScoreTeamA: 5,
      penaltyScoreTeamB: 4,
    }));

    const storedMatch = db.docData('matches/match-1');
    assert.strictEqual(storedMatch.scoreTeamA, 1);
    assert.strictEqual(storedMatch.scoreTeamB, 1);
    assert.strictEqual(storedMatch.penaltyScoreTeamA, 5);
    assert.strictEqual(storedMatch.penaltyScoreTeamB, 4);
    assert.strictEqual(storedMatch.knockoutDecision, 'teamA');
  });

  for (const scenario of [
    {
      name: 'tied knockout without penalties',
      match: {stageType: 'knockoutStage'},
      payload: validPayload({scoreA: 1, scoreB: 1}),
    },
    {
      name: 'tied knockout with tied penalties',
      match: {stageType: 'knockoutStage'},
      payload: validPayload({
        scoreA: 1,
        scoreB: 1,
        penaltyScoreTeamA: 4,
        penaltyScoreTeamB: 4,
      }),
    },
    {
      name: 'decided knockout with penalty data',
      match: {stageType: 'knockoutStage'},
      payload: validPayload({penaltyScoreTeamA: 5, penaltyScoreTeamB: 4}),
    },
    {
      name: 'group match with penalty data',
      match: {stageType: 'groupStage'},
      payload: validPayload({penaltyScoreTeamA: 5, penaltyScoreTeamB: 4}),
    },
  ]) {
    it(`rejects ${scenario.name}`, async () => {
      const db = settlementDatabase(scenario.match);

      await assert.rejects(
        () => submit(db, scenario.payload),
        (error) => error instanceof SettlementError && error.code === 'invalid-argument',
      );

      assert.strictEqual(db.docData('matches/match-1').status, 'live');
      assert.strictEqual(db.docData('matches/match-1').knockoutDecision, undefined);
    });
  }

  it('rejects a different retry after settlement without changing stored data', async () => {
    const db = settlementDatabase();
    await submit(db, validPayload());
    const storedMatch = db.docData('matches/match-1');

    await assert.rejects(
      () => submit(db, {...validPayload(), scoreA: 2}),
      (error) => (
        error instanceof SettlementError &&
        error.code === 'failed-precondition'
      ),
    );

    assert.deepStrictEqual(db.docData('matches/match-1'), storedMatch);
    assert.strictEqual(db.collectionData('matchEvents').length, 2);
  });

  for (const scenario of [
    {
      name: 'unauthorized actor',
      match: {organizerId: 'another-organizer'},
      payload: validPayload(),
      code: 'permission-denied',
    },
    {
      name: 'frozen match',
      match: {isFrozen: true},
      payload: validPayload(),
      code: 'failed-precondition',
    },
    {
      name: 'outside-roster scorer',
      match: {},
      payload: validPayload({
        goals: [goalDraft({id: 'outsider', displayName: 'Outsider'})],
      }),
      code: 'invalid-argument',
    },
    {
      name: 'attributed goals above the score',
      match: {},
      payload: validPayload({scoreA: 0}),
      code: 'invalid-argument',
    },
    {
      name: 'an excessive score that could fan out writes',
      match: {},
      payload: validPayload({scoreA: 100}),
      code: 'invalid-argument',
    },
  ]) {
    it(`does not write settlement data for ${scenario.name}`, async () => {
      const db = settlementDatabase(scenario.match);

      await assert.rejects(
        () => submit(db, scenario.payload),
        (error) => error instanceof SettlementError && error.code === scenario.code,
      );

      assert.strictEqual(db.docData('matches/match-1').status, 'live');
      assert.strictEqual(db.docData('matches/match-1').scoreTeamA, undefined);
      assert.deepStrictEqual(db.collectionData('matchEvents'), []);
      assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    });
  }

  it('rolls back every settlement write when the audit write fails', async () => {
    const db = new FakeFirestore(
      settlementSeed(),
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => submit(db, validPayload()),
      /Injected write failure/,
    );

    assert.strictEqual(db.docData('matches/match-1').status, 'live');
    assert.deepStrictEqual(db.collectionData('matchEvents'), []);
    assert.deepStrictEqual(db.collectionData('fanVotingSessions'), []);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('uses the same registered roster contract for submit and approve', async () => {
    const db = settlementDatabase({}, {
      'players/p1': player('p1'),
      'players/p2': player('p2'),
    });
    await submit(db, validPayload());

    const approval = await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW + 1000,
    });

    assert.strictEqual(approval.status, 'settled');
    assert.strictEqual(approval.ratingsApplied, true);
    assert.strictEqual(db.docData('players/p1').rating, 1040);
    assert.strictEqual(db.docData('players/p2').rating, 990);
  });

  it('voids a stale active MVP event when the new settlement has no typed MVP', async () => {
    const db = settlementDatabase({}, {
      'matchEvents/mvp-match-1': {
        matchId: 'match-1',
        eventType: 'mvp',
        status: 'active',
        actor: participant(),
      },
    });

    await submit(db, validPayload({
      scoreA: 0,
      mvpPlayerId: null,
      detailedStats: [],
      goals: [],
      mvp: null,
    }));

    assert.strictEqual(
      db.docData('matchEvents/mvp-match-1').status,
      'voided',
    );
  });
});

function settlementDatabase(matchOverrides = {}, additionalSeed = {}) {
  return new FakeFirestore(settlementSeed(matchOverrides, additionalSeed));
}

function settlementSeed(matchOverrides = {}, additionalSeed = {}) {
  return {
    'matches/match-1': {
      organizerId: 'organizer-1',
      teamAId: null,
      teamBId: null,
      teamAPlayerIds: ['p1'],
      teamBPlayerIds: ['p2'],
      teamAParticipantId: null,
      teamBParticipantId: null,
      status: 'live',
      isFrozen: false,
      tournamentId: null,
      isGoldenRating: false,
      ...matchOverrides,
    },
    ...additionalSeed,
  };
}

function submit(db, payload, actorId = 'organizer-1') {
  return submitMatchSettlementCore({
    db,
    actorId,
    payload,
    now: NOW,
  });
}

function validPayload(overrides = {}) {
  return {
    matchId: 'match-1',
    scoreA: 1,
    scoreB: 0,
    mvpPlayerId: 'p1',
    detailedStats: [{
      playerId: 'p1',
      matchId: 'match-1',
      teamId: 'spoofed-team',
      played: true,
      position: 'forward',
      goals: 1,
      tackles: 3,
      rating: 8.5,
    }],
    goals: [goalDraft()],
    mvp: {
      sideKey: 'A',
      actor: participant(),
    },
    ...overrides,
  };
}

function goalDraft(actorOverrides = {}) {
  return {
    sideKey: 'A',
    actor: participant(actorOverrides),
    goals: 1,
    minute: null,
  };
}

function participant(overrides = {}) {
  return {
    kind: 'player',
    id: 'p1',
    displayName: 'Player One',
    linkedPlayerId: null,
    ...overrides,
  };
}

function player(id) {
  return {
    name: id,
    rating: 1000,
    totalMatches: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    mvpCount: 0,
    trustLevel: 'active',
  };
}
