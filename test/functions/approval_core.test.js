const assert = require('assert');

const {
  SettlementError,
  approveMatchScoreCore,
} = require('../../functions/approval_core');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = 1770000000000;

describe('approveMatchScoreCore', () => {
  it('organizer approval applies ratings, fan winner, and group standings', async () => {
    const db = new FakeFirestore({
      'tournaments/tournament-1': tournament(),
      'tournamentParticipants/part-a': participant({
        id: 'part-a',
        sourceEntityId: 'team-a',
        displayName: 'Team A',
        seed: 1,
      }),
      'tournamentParticipants/part-b': participant({
        id: 'part-b',
        sourceEntityId: 'team-b',
        displayName: 'Team B',
        seed: 2,
      }),
      'tournamentGroups/group-1': group({
        participantIds: ['part-a', 'part-b'],
      }),
      'matches/match-1': match({
        status: 'completed',
        scoreTeamA: 2,
        scoreTeamB: 1,
        mvpPlayerId: 'p1',
      }),
      'matchLineupSnapshots/snap-a': lineupSnapshot({
        teamId: 'team-a',
        starters: [{playerId: 'p1'}, {playerId: 'p2'}],
      }),
      'matchLineupSnapshots/snap-b': lineupSnapshot({
        teamId: 'team-b',
        starters: [{playerId: 'p3'}, {playerId: 'p4'}],
      }),
      'players/p1': player({id: 'p1'}),
      'players/p2': player({id: 'p2'}),
      'players/p3': player({id: 'p3'}),
      'players/p4': player({id: 'p4'}),
      'fanVotingSessions/match-1': {
        matchId: 'match-1',
        playerVotes: {p2: 3, p1: 1, guest: 99},
        winnerPlayerId: null,
      },
    });

    const result = await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW,
    });

    assert.deepStrictEqual(result, {
      status: 'settled',
      ratingsApplied: true,
      alreadySettled: false,
      prideEventsPending: false,
    });
    assert.strictEqual(db.docData('matches/match-1').status, 'settled');
    assert.strictEqual(
      db.docData('fanVotingSessions/match-1').winnerPlayerId,
      'p2',
    );
    assert.strictEqual(db.docData('players/p1').rating, 1040);
    assert.strictEqual(db.docData('players/p2').rating, 1040);
    assert.strictEqual(db.docData('players/p3').rating, 990);
    assert.strictEqual(db.docData('players/p4').rating, 990);
    assert.strictEqual(db.docData('players/p1').mvpCount, 1);
    assert.strictEqual(db.collectionData('auditEvents').length, 1);
    assert.strictEqual(
      db.collectionData('auditEvents')[0].action,
      'matchScoreApproved',
    );
    assert.strictEqual(
      db.collectionData('auditEvents')[0].source,
      'trustedOperation',
    );
    assert.strictEqual(
      db.collectionData('auditEvents')[0].verificationVersion,
      1,
    );
    assert.ok(db.collectionData('auditEvents')[0].requestId);
    assert.strictEqual(
      db.collectionData('auditEvents')[0].beforePayload.status,
      'completed',
    );

    const standing = db.docData(
      'groupStandingSnapshots/standing::group-stage::tournament-1::group-1',
    );
    assert.deepStrictEqual(
      standing.entries.map((entry) => ({
        id: entry.participantId,
        played: entry.played,
        wins: entry.wins,
        losses: entry.losses,
        goalsFor: entry.goalsFor,
        goalsAgainst: entry.goalsAgainst,
        rank: entry.rank,
      })),
      [
        {
          id: 'part-a',
          played: 1,
          wins: 1,
          losses: 0,
          goalsFor: 2,
          goalsAgainst: 1,
          rank: 1,
        },
        {
          id: 'part-b',
          played: 1,
          wins: 0,
          losses: 1,
          goalsFor: 1,
          goalsAgainst: 2,
          rank: 2,
        },
      ],
    );
  });

  it('allows only assistants with canApproveScore to approve tournament scores', async () => {
    const allowedDb = new FakeFirestore({
      'tournaments/tournament-1': tournament(),
      'tournaments/tournament-1/assistants/assistant-1': {
        status: 'active',
        permissions: {canApproveScore: true},
      },
      'matches/match-1': match({status: 'completed', scoreTeamA: 1, scoreTeamB: 0}),
    });

    await approveMatchScoreCore({
      db: allowedDb,
      actorId: 'assistant-1',
      matchId: 'match-1',
      now: NOW,
    });
    assert.strictEqual(allowedDb.docData('matches/match-1').status, 'settled');

    const deniedDb = new FakeFirestore({
      'tournaments/tournament-1': tournament(),
      'tournaments/tournament-1/assistants/assistant-1': {
        status: 'active',
        permissions: {canApproveScore: false},
      },
      'matches/match-1': match({status: 'completed', scoreTeamA: 1, scoreTeamB: 0}),
    });

    await assert.rejects(
      () =>
        approveMatchScoreCore({
          db: deniedDb,
          actorId: 'assistant-1',
          matchId: 'match-1',
          now: NOW,
        }),
      (error) => error instanceof SettlementError && error.code === 'permission-denied',
    );
  });

  it('keeps guest MVPs out of registered-player rating bonuses', async () => {
    const db = new FakeFirestore({
      'matches/match-1': match({
        tournamentId: null,
        status: 'completed',
        scoreTeamA: 1,
        scoreTeamB: 0,
        mvpPlayerId: 'guest-mvp',
        teamAPlayerIds: ['p1'],
        teamBPlayerIds: ['p2'],
      }),
      'players/p1': player({id: 'p1'}),
      'players/p2': player({id: 'p2'}),
    });

    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW,
    });

    assert.strictEqual(db.docData('players/p1').rating, 1025);
    assert.strictEqual(db.docData('players/p1').mvpCount, 0);
    assert.strictEqual(db.docData('players/p2').rating, 990);
    assert.strictEqual(db.docData('matches/match-1').mvpPlayerId, 'guest-mvp');
  });

  it('refreshes stale group standings on settled retry without doubling ratings', async () => {
    const db = new FakeFirestore({
      'tournaments/tournament-1': tournament(),
      'tournamentParticipants/part-a': participant({
        id: 'part-a',
        sourceEntityId: 'team-a',
        displayName: 'Team A',
        seed: 1,
      }),
      'tournamentParticipants/part-b': participant({
        id: 'part-b',
        sourceEntityId: 'team-b',
        displayName: 'Team B',
        seed: 2,
      }),
      'tournamentGroups/group-1': group({
        participantIds: ['part-a', 'part-b'],
      }),
      'matches/match-1': match({
        status: 'settled',
        scoreTeamA: 1,
        scoreTeamB: 0,
        ratingsAppliedAt: NOW - 1000,
      }),
      'players/p1': player({id: 'p1', rating: 1025, totalMatches: 1, wins: 1}),
      'groupStandingSnapshots/standing::group-stage::tournament-1::group-1': {
        tournamentId: 'tournament-1',
        groupStageId: 'group-stage::tournament-1',
        groupId: 'group-1',
        tiebreakerOrder: ['points', 'goalDifference', 'goalsFor', 'randomDraw'],
        entries: [],
        qualifierParticipantIds: [],
        createdAt: NOW - 5000,
        updatedAt: NOW - 5000,
      },
    });

    const result = await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW,
    });

    assert.strictEqual(result.alreadySettled, true);
    assert.strictEqual(result.ratingsApplied, true);
    assert.strictEqual(db.docData('players/p1').rating, 1025);
    assert.strictEqual(db.docData('players/p1').totalMatches, 1);
    const standing = db.docData(
      'groupStandingSnapshots/standing::group-stage::tournament-1::group-1',
    );
    assert.strictEqual(standing.entries[0].participantId, 'part-a');
    assert.strictEqual(standing.entries[0].played, 1);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('keeps one approval audit event across an idempotent retry', async () => {
    const db = new FakeFirestore({
      'matches/match-1': match({
        status: 'completed',
        scoreTeamA: 1,
        scoreTeamB: 0,
        settlementSubmittedAt: NOW - 500,
        settlementSubmissionFingerprint: 'fingerprint-1',
      }),
    });

    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW,
    });
    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'match-1',
      now: NOW + 1000,
    });

    assert.strictEqual(db.collectionData('auditEvents').length, 1);
    assert.strictEqual(
      db.collectionData('auditEvents')[0].requestId,
      `match-approval:${NOW - 500}:fingerprint-1`,
    );
  });

  it('rolls back approval when the audit write fails', async () => {
    const db = new FakeFirestore(
      {
        'matches/match-1': match({
          status: 'completed',
          scoreTeamA: 1,
          scoreTeamB: 0,
        }),
      },
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => approveMatchScoreCore({
        db,
        actorId: 'organizer-1',
        matchId: 'match-1',
        now: NOW,
      }),
      /Injected write failure/,
    );

    assert.strictEqual(db.docData('matches/match-1').status, 'completed');
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('advances knockout winners and marks champion after final approval', async () => {
    const db = new FakeFirestore({
      'tournaments/tournament-1': tournament({
        currentGroupStageId: null,
        currentKnockoutBracketId: 'bracket-1',
      }),
      'tournamentParticipants/part-a': participant({
        id: 'part-a',
        sourceEntityId: 'team-a',
        displayName: 'Team A',
      }),
      'tournamentParticipants/part-b': participant({
        id: 'part-b',
        sourceEntityId: 'team-b',
        displayName: 'Team B',
      }),
      'tournamentParticipants/part-c': participant({
        id: 'part-c',
        sourceEntityId: 'team-c',
        displayName: 'Team C',
      }),
      'knockoutBrackets/bracket-1': {
        tournamentId: 'tournament-1',
        format: 'singleElimination',
        qualifierParticipantIds: ['part-a', 'part-b', 'part-c', 'part-d'],
        championParticipantId: null,
        createdAt: NOW - 10000,
        updatedAt: NOW - 10000,
      },
      'knockoutTies/tie-0': knockoutTie({
        id: 'tie-0',
        roundIndex: 0,
        slotNumber: 0,
        participantAId: 'part-a',
        participantBId: 'part-b',
        matchId: 'semi-0',
        nextTieId: 'tie-final',
      }),
      'knockoutTies/tie-1': knockoutTie({
        id: 'tie-1',
        roundIndex: 0,
        slotNumber: 1,
        participantAId: 'part-c',
        participantBId: 'part-d',
        winnerParticipantId: 'part-c',
        matchId: 'semi-1',
        nextTieId: 'tie-final',
      }),
      'knockoutTies/tie-final': knockoutTie({
        id: 'tie-final',
        roundIndex: 1,
        slotNumber: 0,
        matchId: 'final',
      }),
      'matches/semi-0': match({
        id: 'semi-0',
        status: 'completed',
        stageType: 'knockoutStage',
        groupId: null,
        groupStageId: null,
        knockoutTieId: 'tie-0',
        teamAParticipantId: 'part-a',
        teamBParticipantId: 'part-b',
        teamAId: 'team-a',
        teamBId: 'team-b',
        scoreTeamA: 2,
        scoreTeamB: 0,
      }),
      'matches/final': match({
        id: 'final',
        status: 'completed',
        stageType: 'knockoutStage',
        groupId: null,
        groupStageId: null,
        knockoutTieId: 'tie-final',
        teamAParticipantId: null,
        teamBParticipantId: null,
        teamAId: null,
        teamBId: null,
        scoreTeamA: 3,
        scoreTeamB: 2,
      }),
    });

    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'semi-0',
      now: NOW,
    });

    assert.strictEqual(db.docData('knockoutTies/tie-0').winnerParticipantId, 'part-a');
    assert.strictEqual(db.docData('knockoutTies/tie-final').participantAId, 'part-a');
    assert.strictEqual(db.docData('knockoutTies/tie-final').participantBId, 'part-c');
    assert.strictEqual(db.docData('matches/final').teamAId, 'team-a');
    assert.strictEqual(db.docData('matches/final').teamBId, 'team-c');

    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'final',
      now: NOW + 1000,
    });

    assert.strictEqual(
      db.docData('knockoutBrackets/bracket-1').championParticipantId,
      'part-a',
    );
  });

  it('advances a tied knockout by penalties and records the resolution atomically', async () => {
    const db = new FakeFirestore({
      'tournaments/tournament-1': tournament({
        currentGroupStageId: null,
        currentKnockoutBracketId: 'bracket-1',
      }),
      'tournamentParticipants/part-a': participant({
        id: 'part-a',
        sourceEntityId: 'team-a',
        displayName: 'Team A',
      }),
      'tournamentParticipants/part-b': participant({
        id: 'part-b',
        sourceEntityId: 'team-b',
        displayName: 'Team B',
      }),
      'knockoutBrackets/bracket-1': {
        tournamentId: 'tournament-1',
        format: 'singleElimination',
        qualifierParticipantIds: ['part-a', 'part-b'],
        championParticipantId: null,
        createdAt: NOW - 10000,
        updatedAt: NOW - 10000,
      },
      'knockoutTies/tie-final': knockoutTie({
        id: 'tie-final',
        participantAId: 'part-a',
        participantBId: 'part-b',
        matchId: 'final',
      }),
      'matches/final': match({
        id: 'final',
        status: 'completed',
        stageType: 'knockoutStage',
        groupId: null,
        groupStageId: null,
        knockoutTieId: 'tie-final',
        teamAParticipantId: 'part-a',
        teamBParticipantId: 'part-b',
        scoreTeamA: 1,
        scoreTeamB: 1,
        penaltyScoreTeamA: 4,
        penaltyScoreTeamB: 5,
        knockoutDecision: 'teamB',
      }),
    });

    await approveMatchScoreCore({
      db,
      actorId: 'organizer-1',
      matchId: 'final',
      now: NOW,
    });

    assert.strictEqual(db.docData('matches/final').scoreTeamA, 1);
    assert.strictEqual(db.docData('matches/final').scoreTeamB, 1);
    assert.strictEqual(
      db.docData('knockoutTies/tie-final').winnerParticipantId,
      'part-b',
    );
    assert.strictEqual(
      db.docData('knockoutTies/tie-final').resolutionType,
      'penalties',
    );
    assert.strictEqual(
      db.docData('knockoutBrackets/bracket-1').championParticipantId,
      'part-b',
    );
    const audit = db.collectionData('auditEvents')[0];
    assert.strictEqual(audit.afterPayload.penaltyScoreTeamA, 4);
    assert.strictEqual(audit.afterPayload.penaltyScoreTeamB, 5);
    assert.strictEqual(audit.metadata.knockoutResolution, 'penalties');
  });

  for (const [name, overrides] of [
    ['frozen match', {isFrozen: true, status: 'completed', scoreTeamA: 1, scoreTeamB: 0}],
    ['missing score', {status: 'completed', scoreTeamA: null, scoreTeamB: 0}],
    ['negative score', {status: 'completed', scoreTeamA: -1, scoreTeamB: 0}],
    ['score above limit', {status: 'completed', scoreTeamA: 100, scoreTeamB: 0}],
    ['wrong status', {status: 'live', scoreTeamA: 1, scoreTeamB: 0}],
    ['tied knockout without penalties', {
      status: 'completed',
      stageType: 'knockoutStage',
      scoreTeamA: 1,
      scoreTeamB: 1,
    }],
    ['decided knockout with penalty data', {
      status: 'completed',
      stageType: 'knockoutStage',
      scoreTeamA: 2,
      scoreTeamB: 1,
      penaltyScoreTeamA: 5,
      penaltyScoreTeamB: 4,
    }],
  ]) {
    it(`rejects ${name} before approval writes`, async () => {
      const db = new FakeFirestore({
        'matches/match-1': match(overrides),
      });

      await assert.rejects(
        () =>
          approveMatchScoreCore({
            db,
            actorId: 'organizer-1',
            matchId: 'match-1',
            now: NOW,
          }),
        (error) => error instanceof SettlementError && error.code === 'failed-precondition',
      );
      assert.strictEqual(db.docData('matches/match-1').status, overrides.status);
      assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    });
  }
});

function tournament(overrides = {}) {
  return {
    organizerId: 'organizer-1',
    format: 'groupsOnly',
    currentGroupStageId: 'group-stage::tournament-1',
    currentKnockoutBracketId: null,
    groupStandingsConfig: {
      tiebreakerOrder: ['points', 'goalDifference', 'goalsFor', 'randomDraw'],
    },
    ...overrides,
  };
}

function participant({id, sourceEntityId, displayName, seed = null}) {
  return {
    tournamentId: 'tournament-1',
    sourceType: 'registeredTeam',
    sourceEntityId,
    displayName,
    status: 'finalized',
    seed,
    groupId: null,
    createdAt: NOW - 10000,
    updatedAt: NOW - 10000,
    id,
  };
}

function group(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    groupStageId: 'group-stage::tournament-1',
    name: 'Group A',
    order: 0,
    participantIds: [],
    qualifierParticipantIds: [],
    createdAt: NOW - 10000,
    updatedAt: NOW - 10000,
    ...overrides,
  };
}

function match(overrides = {}) {
  return {
    organizerId: 'organizer-1',
    teamAId: 'team-a',
    teamBId: 'team-b',
    teamAPlayerIds: [],
    teamBPlayerIds: [],
    teamAParticipantId: 'part-a',
    teamBParticipantId: 'part-b',
    status: 'completed',
    scoreTeamA: 1,
    scoreTeamB: 0,
    mvpPlayerId: null,
    prideEventsPending: false,
    teamSize: 5,
    isOrganized: true,
    tournamentId: 'tournament-1',
    isGoldenRating: false,
    isAnomaly: false,
    isFrozen: false,
    stageType: 'groupStage',
    groupId: 'group-1',
    groupStageId: 'group-stage::tournament-1',
    knockoutTieId: null,
    fixtureStatus: 'published',
    createdAt: NOW - 10000,
    completedAt: NOW - 5000,
    ...overrides,
  };
}

function lineupSnapshot(overrides = {}) {
  return {
    matchId: 'match-1',
    teamId: null,
    guestTeamId: null,
    starters: [],
    bench: [],
    ...overrides,
  };
}

function player(overrides = {}) {
  return {
    name: overrides.id || 'player',
    rating: 1000,
    totalMatches: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    mvpCount: 0,
    trustLevel: 'active',
    createdAt: NOW - 10000,
    lastActiveAt: NOW - 10000,
    ...overrides,
  };
}

function knockoutTie(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    bracketId: 'bracket-1',
    roundIndex: 0,
    slotNumber: 0,
    participantAId: null,
    participantBId: null,
    winnerParticipantId: null,
    matchId: null,
    nextTieId: null,
    createdAt: NOW - 10000,
    updatedAt: NOW - 10000,
    ...overrides,
  };
}
