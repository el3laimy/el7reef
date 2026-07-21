const fs = require('fs');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-assistant-permissions';
const now = 1770000000000;

let testEnv;

function tournamentData(overrides = {}) {
  return {
    name: 'Street Cup',
    organizerId: 'organizer-1',
    status: 'registration',
    format: 'groups',
    teamSize: 5,
    maxTeams: 8,
    registeredTeamCount: 0,
    guestTeamCount: 0,
    approvedParticipantCount: 0,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function matchData(overrides = {}) {
  return {
    organizerId: 'organizer-1',
    title: 'Street Cup - Round 1',
    type: 'tournament',
    status: 'open',
    isFrozen: false,
    tournamentId: 'tournament-1',
    teamAId: 'team-1',
    teamBId: 'team-2',
    scoreTeamA: null,
    scoreTeamB: null,
    roundIndex: 0,
    order: 0,
    scheduledAt: now + 86400000,
    fixtureStatus: 'draft',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function lineupSnapshotData(overrides = {}) {
  return {
    matchId: 'match-1',
    teamId: 'team-1',
    guestTeamId: null,
    matchSideId: null,
    tournamentRegistrationId: null,
    starters: [],
    bench: [],
    lockedBy: 'assistant-1',
    lockedAt: now,
    playerCount: 5,
    formationCode: null,
    formationLabel: null,
    notes: null,
    ...overrides,
  };
}

function matchEventData(overrides = {}) {
  return {
    matchId: 'match-1',
    tournamentId: 'tournament-1',
    eventType: 'goal',
    sideKey: 'A',
    actor: {
      kind: 'guestPlayer',
      id: 'guest-player-1',
      displayName: 'Guest One',
    },
    minute: 7,
    createdBy: 'assistant-1',
    createdAt: now,
    status: 'active',
    ...overrides,
  };
}

function pendingPridePayloadData(overrides = {}) {
  return {
    version: 1,
    matchId: 'match-1',
    scoreTeamA: 2,
    scoreTeamB: 1,
    goals: [
      {
        sideKey: 'A',
        actor: {
          kind: 'guestPlayer',
          id: 'guest-player-1',
          displayName: 'Guest One',
          linkedPlayerId: null,
        },
        goals: 1,
        minute: null,
      },
    ],
    mvp: null,
    createdBy: 'assistant-1',
    createdAt: now,
    ...overrides,
  };
}

function tournamentParticipantData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    sourceType: 'registeredTeam',
    sourceEntityId: 'team-1',
    displayName: 'Red Wolves',
    status: 'approved',
    seed: null,
    groupId: null,
    sourceRegistrationId: 'registration-1',
    replacementForParticipantId: null,
    replacedByParticipantId: null,
    createdAt: now,
    updatedAt: now,
    approvedAt: now,
    finalizedAt: null,
    withdrawnAt: null,
    replacedAt: null,
    ...overrides,
  };
}

function tournamentGroupData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    groupStageId: 'group-stage-1',
    name: 'Group A',
    order: 0,
    participantIds: ['participant-1', 'participant-2'],
    qualifierParticipantIds: [],
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function knockoutBracketData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    format: 'singleElimination',
    qualifierParticipantIds: ['participant-1', 'participant-2'],
    championParticipantId: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function knockoutTieData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    bracketId: 'bracket-1',
    roundIndex: 0,
    slotNumber: 0,
    participantAId: 'participant-1',
    participantBId: 'participant-2',
    winnerParticipantId: null,
    matchId: 'match-1',
    nextTieId: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function registrationData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    teamId: 'team-1',
    status: 'pending',
    mode: 'hybrid',
    createdBy: 'team-owner-1',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function matchSideData(overrides = {}) {
  return {
    matchId: 'match-1',
    sideKey: 'A',
    type: 'officialTeam',
    displayName: 'Red Wolves',
    officialTeamId: 'team-1',
    captainUserId: null,
    managedByUserIds: ['organizer-1'],
    createdBy: 'organizer-1',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function matchSidePlayerData(overrides = {}) {
  return {
    matchId: 'match-1',
    sideKey: 'A',
    sideId: 'match-1_A',
    kind: 'temporary',
    playerId: null,
    displayName: 'Temporary Player',
    position: null,
    shirtNumber: null,
    ratingEligible: false,
    addedBy: 'organizer-1',
    createdAt: now,
    ...overrides,
  };
}

function guestTeamData(overrides = {}) {
  return {
    name: 'Guest Team',
    normalizedName: 'guest team',
    creatorId: 'guest-creator-1',
    contactName: 'Guest Captain',
    contactPhone: '01111111111',
    logoUrl: null,
    tournamentIds: ['tournament-1'],
    captainGuestPlayerId: null,
    claimCode: null,
    createdAt: now,
    updatedAt: now,
    claimStatus: 'guest',
    linkedTeamId: null,
    ...overrides,
  };
}

function guestPlayerData(overrides = {}) {
  return {
    displayName: 'Guest Player',
    normalizedName: 'guest player',
    phoneNumber: null,
    jerseyNumber: 7,
    preferredPosition: 'مهاجم',
    teamId: null,
    guestTeamId: 'guest-team-1',
    tournamentId: 'tournament-1',
    createdBy: 'assistant-1',
    createdAt: now,
    updatedAt: now,
    claimStatus: 'guest',
    claimCode: null,
    linkedPlayerId: null,
    notes: null,
    ...overrides,
  };
}

function permissionMap(overrides = {}) {
  return {
    canViewMatchday: true,
    canStartMatch: false,
    canSubmitScore: true,
    canRecordGoalsAndMvp: true,
    canApproveScore: false,
    canDeclareForfeit: false,
    canManageGuestRoster: false,
    ...overrides,
  };
}

function assistantPermissionData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    userId: 'assistant-1',
    addedBy: 'organizer-1',
    status: 'active',
    preset: 'resultsAssistant',
    createdAt: now,
    updatedAt: now,
    revokedAt: null,
    ...overrides,
    permissions: permissionMap(overrides.permissions),
  };
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function seedTournament(overrides = {}) {
  await seed('tournaments/tournament-1', tournamentData(overrides));
}

async function seedTournamentFixture() {
  await seedTournament();
  await seed('matches/match-1', matchData());
}

async function seedAssistant(overrides = {}) {
  const data = assistantPermissionData(overrides);
  await seed(
    `tournaments/${data.tournamentId}/assistants/${data.userId}`,
    data,
  );
}

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthenticatedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

describe('tournament assistant permission Firestore rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it('allows organizer to create a valid assistant doc', async () => {
    await seedTournament();
    const db = authedDb('organizer-1');

    await assertSucceeds(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData(),
      ),
    );
  });

  it('denies non-organizer assistant doc creation', async () => {
    await seedTournament();
    const db = authedDb('outsider-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData({addedBy: 'outsider-1'}),
      ),
    );
  });

  it('denies assistant self-creation', async () => {
    await seedTournament();
    const db = authedDb('assistant-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData({addedBy: 'assistant-1'}),
      ),
    );
  });

  it('denies organizer creating assistants for another organizer tournament', async () => {
    await seed(
      'tournaments/tournament-2',
      tournamentData({organizerId: 'organizer-2'}),
    );
    const db = authedDb('organizer-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-2/assistants/assistant-1'),
        assistantPermissionData({tournamentId: 'tournament-2'}),
      ),
    );
  });

  it('denies structural permission keys', async () => {
    await seedTournament();
    const db = authedDb('organizer-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData({
          permissions: {canGenerateFixtures: true},
        }),
      ),
    );
  });

  it('denies non-bool permission values', async () => {
    await seedTournament();
    const db = authedDb('organizer-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData({
          permissions: {canSubmitScore: 'yes'},
        }),
      ),
    );
  });

  it('denies unsupported presets', async () => {
    await seedTournament();
    const db = authedDb('organizer-1');

    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-1'),
        assistantPermissionData({preset: 'fixtureManager'}),
      ),
    );
  });

  it('allows organizer to update allowed permissions', async () => {
    await seedTournament();
    await seedAssistant();
    const db = authedDb('organizer-1');

    await assertSucceeds(
      updateDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1'), {
        preset: 'customLimited',
        permissions: permissionMap({canApproveScore: true}),
        updatedAt: now + 1,
      }),
    );
  });

  it('allows organizer to revoke assistant', async () => {
    await seedTournament();
    await seedAssistant();
    const db = authedDb('organizer-1');

    await assertSucceeds(
      updateDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1'), {
        status: 'revoked',
        updatedAt: now + 1,
        revokedAt: now + 1,
      }),
    );
  });

  it('denies immutable field changes', async () => {
    await seedTournament();
    await seedAssistant();
    const db = authedDb('organizer-1');

    await assertFails(
      updateDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1'), {
        addedBy: 'organizer-2',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies assistant updating own permissions', async () => {
    await seedTournament();
    await seedAssistant();
    const db = authedDb('assistant-1');

    await assertFails(
      updateDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1'), {
        permissions: permissionMap({canApproveScore: true}),
        updatedAt: now + 1,
      }),
    );
  });

  it('denies hard delete', async () => {
    await seedTournament();
    await seedAssistant();
    const db = authedDb('organizer-1');

    await assertFails(
      deleteDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1')),
    );
  });

  it('limits reads to organizer and assistant own doc', async () => {
    await seedTournament();
    await seedAssistant({status: 'revoked', revokedAt: now + 1});
    const organizerDb = authedDb('organizer-1');
    const assistantDb = authedDb('assistant-1');
    const outsiderDb = authedDb('outsider-1');

    await assertSucceeds(
      getDocs(collection(organizerDb, 'tournaments/tournament-1/assistants')),
    );
    await assertSucceeds(
      getDoc(doc(assistantDb, 'tournaments/tournament-1/assistants/assistant-1')),
    );
    await assertFails(
      getDoc(doc(outsiderDb, 'tournaments/tournament-1/assistants/assistant-1')),
    );
    await assertFails(
      getDocs(collection(outsiderDb, 'tournaments/tournament-1/assistants')),
    );
  });

  it('denies non-authenticated access', async () => {
    await seedTournament();
    await seedAssistant();
    const db = unauthenticatedDb();

    await assertFails(
      getDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1')),
    );
    await assertFails(
      setDoc(
        doc(db, 'tournaments/tournament-1/assistants/assistant-2'),
        assistantPermissionData({userId: 'assistant-2'}),
      ),
    );
  });

  describe('assistant MatchEvent writes', () => {
    it('denies assistant direct goal event writes after backend hardening', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(doc(db, 'matchEvents', 'assistant-goal-1'), matchEventData()),
      );
    });

    it('denies assistant direct MVP event writes after backend hardening', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-mvp-1'),
          matchEventData({eventType: 'mvp', minute: null}),
        ),
      );
    });

    it('denies assistant without canRecordGoalsAndMvp', async () => {
      await seedTournamentFixture();
      await seedAssistant({
        permissions: {canRecordGoalsAndMvp: false},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(doc(db, 'matchEvents', 'assistant-goal-denied-1'), matchEventData()),
      );
      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-mvp-denied-1'),
          matchEventData({eventType: 'mvp', minute: null}),
        ),
      );
    });

    it('denies revoked assistant goal and MVP events', async () => {
      await seedTournamentFixture();
      await seedAssistant({status: 'revoked', revokedAt: now + 1});
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(doc(db, 'matchEvents', 'revoked-goal-1'), matchEventData()),
      );
      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'revoked-mvp-1'),
          matchEventData({eventType: 'mvp', minute: null}),
        ),
      );
    });

    it('denies assistant for tournament A creating event for tournament B', async () => {
      await seedTournamentFixture();
      await seed(
        'tournaments/tournament-2',
        tournamentData({organizerId: 'organizer-2'}),
      );
      await seed(
        'matches/match-2',
        matchData({
          organizerId: 'organizer-2',
          tournamentId: 'tournament-2',
        }),
      );
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'wrong-tournament-goal-1'),
          matchEventData({matchId: 'match-2', tournamentId: 'tournament-2'}),
        ),
      );
    });

    it('denies createdBy spoofing', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-spoofed-goal-1'),
          matchEventData({createdBy: 'organizer-1'}),
        ),
      );
    });

    it('denies event tournamentId mismatch', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-mismatch-goal-1'),
          matchEventData({tournamentId: 'other-tournament'}),
        ),
      );
    });

    it('denies nonexistent match', async () => {
      await seedTournament();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-missing-match-goal-1'),
          matchEventData({matchId: 'missing-match'}),
        ),
      );
    });

    it('denies unsupported event type', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'assistant-unsupported-event-1'),
          matchEventData({eventType: 'yellowCard'}),
        ),
      );
    });

    it('denies organizer direct goal and MVP event creation', async () => {
      await seedTournamentFixture();
      const db = authedDb('organizer-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'organizer-goal-1'),
          matchEventData({createdBy: 'organizer-1'}),
        ),
      );
      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'organizer-mvp-1'),
          matchEventData({
            eventType: 'mvp',
            minute: null,
            createdBy: 'organizer-1',
          }),
        ),
      );
    });

    it('still denies random users creating goal and MVP events', async () => {
      await seedTournamentFixture();
      const db = authedDb('random-user-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'random-goal-1'),
          matchEventData({createdBy: 'random-user-1'}),
        ),
      );
      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'random-mvp-1'),
          matchEventData({
            eventType: 'mvp',
            minute: null,
            createdBy: 'random-user-1',
          }),
        ),
      );
    });
  });

  describe('assistant limited match updates', () => {
    it('allows canStartMatch assistant lineup reference updates and snapshot delete before kickoff', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canStartMatch: true}});
      const db = authedDb('assistant-1');

      await assertSucceeds(
        setDoc(
          doc(db, 'matchLineupSnapshots', 'snapshot-1'),
          lineupSnapshotData(),
        ),
      );
      await assertSucceeds(
        updateDoc(doc(db, 'matches', 'match-1'), {
          lineupSnapshotIds: {'team-1': 'snapshot-1'},
        }),
      );
      await assertSucceeds(
        deleteDoc(doc(db, 'matchLineupSnapshots', 'snapshot-1')),
      );
    });

    it('denies canStartMatch assistant arbitrary match updates', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canStartMatch: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          status: 'live',
          startedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
    });

    it('denies canStartMatch assistant lineup reference updates after kickoff', async () => {
      await seedTournament();
      await seed('matches/match-1', matchData({status: 'live'}));
      await seedAssistant({permissions: {canStartMatch: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          lineupSnapshotIds: {'team-1': 'snapshot-1'},
        }),
      );
    });

    it('denies assistant direct live score submission after backend hardening', async () => {
      await seedTournament();
      await seed('matches/match-1', matchData({status: 'live'}));
      await seedAssistant({
        permissions: {canSubmitScore: true, canRecordGoalsAndMvp: true},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          scoreTeamA: 2,
          scoreTeamB: 1,
          mvpPlayerId: null,
          prideEventsPending: true,
          completedAt: now + 1,
          isAnomaly: false,
          status: 'completed',
        }),
      );
    });

    it('denies assistant direct pride retry state updates after backend hardening', async () => {
      await seedTournament();
      await seed(
        'matches/match-1',
        matchData({
          status: 'completed',
          scoreTeamA: 2,
          scoreTeamB: 1,
          mvpPlayerId: null,
          prideEventsPending: true,
          completedAt: now + 1,
          isAnomaly: false,
        }),
      );
      await seedAssistant({
        permissions: {canRecordGoalsAndMvp: true},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          prideEventsPending: false,
        }),
      );
      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          prideEventsPending: true,
          scoreTeamA: 5,
        }),
      );
    });

    it('denies score assistant direct pending pride payload writes', async () => {
      await seedTournament();
      await seed('matches/match-1', matchData({status: 'live'}));
      await seedAssistant({
        permissions: {canSubmitScore: true, canRecordGoalsAndMvp: true},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matches/match-1/pendingPrideEvents/current'),
          pendingPridePayloadData(),
        ),
      );
    });

    it('denies pending pride payload writes without score and event permissions', async () => {
      await seedTournament();
      await seed('matches/match-1', matchData({status: 'live'}));
      await seedAssistant({
        permissions: {canSubmitScore: true, canRecordGoalsAndMvp: false},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'matches/match-1/pendingPrideEvents/current'),
          pendingPridePayloadData(),
        ),
      );
    });

    it('denies score submission when assistant cannot record goals and MVP', async () => {
      await seedTournament();
      await seed('matches/match-1', matchData({status: 'live'}));
      await seedAssistant({
        permissions: {canSubmitScore: true, canRecordGoalsAndMvp: false},
      });
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          scoreTeamA: 2,
          scoreTeamB: 1,
          mvpPlayerId: null,
          completedAt: now + 1,
          isAnomaly: false,
          status: 'completed',
        }),
      );
    });

    it('denies canSubmitScore assistant valid-looking score submission before live status', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canSubmitScore: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          scoreTeamA: 2,
          scoreTeamB: 1,
          mvpPlayerId: null,
          completedAt: now + 1,
          isAnomaly: false,
          status: 'completed',
        }),
      );
    });

    it('denies canSubmitScore assistant match updates', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canSubmitScore: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          scoreTeamA: 2,
          scoreTeamB: 1,
          status: 'submitted',
          submittedBy: 'assistant-1',
          submittedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
    });

    it('denies canApproveScore assistant direct settlement update', async () => {
      await seedTournament();
      await seed(
        'matches/match-1',
        matchData({
          status: 'completed',
          scoreTeamA: 2,
          scoreTeamB: 1,
          completedAt: now + 1,
          isAnomaly: false,
        }),
      );
      await seedAssistant({permissions: {canApproveScore: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          status: 'settled',
          isAnomaly: false,
          ratingsAppliedAt: now + 2,
        }),
      );
    });

    it('denies canApproveScore assistant match updates', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canApproveScore: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          status: 'approved',
          approvedBy: 'assistant-1',
          approvedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
    });

    it('denies canDeclareForfeit assistant match updates', async () => {
      await seedTournamentFixture();
      await seedAssistant({permissions: {canDeclareForfeit: true}});
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          status: 'forfeit',
          forfeitWinnerSide: 'A',
          updatedAt: now + 1,
        }),
      );
    });

    it('preserves organizer match update access', async () => {
      await seedTournamentFixture();
      const db = authedDb('organizer-1');

      await assertSucceeds(
        updateDoc(doc(db, 'matches', 'match-1'), {
          status: 'live',
          updatedAt: now + 1,
        }),
      );
    });
  });

  describe('assistant guest roster permissions', () => {
    it('allows canManageGuestRoster assistant to manage guest players and captain only', async () => {
      await seedTournament();
      await seed('guestTeams/guest-team-1', guestTeamData());
      await seedAssistant({
        permissions: {
          canViewMatchday: false,
          canSubmitScore: false,
          canRecordGoalsAndMvp: false,
          canManageGuestRoster: true,
        },
      });
      const db = authedDb('assistant-1');

      await assertSucceeds(getDoc(doc(db, 'guestTeams', 'guest-team-1')));
      await assertSucceeds(
        setDoc(
          doc(db, 'guestPlayers', 'guest-player-1'),
          guestPlayerData(),
        ),
      );
      await assertSucceeds(
        updateDoc(doc(db, 'guestTeams', 'guest-team-1'), {
          captainGuestPlayerId: 'guest-player-1',
          updatedAt: now + 1,
        }),
      );
      await assertFails(
        updateDoc(doc(db, 'guestTeams', 'guest-team-1'), {
          contactPhone: '01999999999',
          updatedAt: now + 2,
        }),
      );
    });

    it('denies guest roster writes without canManageGuestRoster', async () => {
      await seedTournament();
      await seed('guestTeams/guest-team-1', guestTeamData());
      await seedAssistant({
        permissions: {
          canViewMatchday: true,
          canSubmitScore: true,
          canRecordGoalsAndMvp: true,
          canManageGuestRoster: false,
        },
      });
      const db = authedDb('assistant-1');

      await assertFails(getDoc(doc(db, 'guestTeams', 'guest-team-1')));
      await assertFails(
        setDoc(
          doc(db, 'guestPlayers', 'guest-player-denied-1'),
          guestPlayerData({displayName: 'Denied Guest'}),
        ),
      );
    });
  });

  describe('assistant structural writes remain denied', () => {
    it('denies structural tournament operation writes', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(
          doc(db, 'tournamentParticipants', 'participant-1'),
          tournamentParticipantData(),
        ),
      );
      await assertFails(
        setDoc(doc(db, 'tournamentGroups', 'group-1'), tournamentGroupData()),
      );
      await assertFails(
        setDoc(
          doc(db, 'knockoutBrackets', 'bracket-1'),
          knockoutBracketData(),
        ),
      );
      await assertFails(
        setDoc(doc(db, 'knockoutTies', 'tie-1'), knockoutTieData()),
      );
    });

    it('denies structural match operation writes', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      const db = authedDb('assistant-1');

      await assertFails(
        setDoc(doc(db, 'matchSides', 'match-1_A'), matchSideData()),
      );
      await assertFails(
        setDoc(
          doc(db, 'matchSidePlayers', 'side-player-1'),
          matchSidePlayerData(),
        ),
      );
    });

    it('denies tournament registration approval, settings, and assistant management', async () => {
      await seedTournamentFixture();
      await seedAssistant();
      await seed('tournamentRegistrations/registration-1', registrationData());
      const db = authedDb('assistant-1');

      await assertFails(
        updateDoc(doc(db, 'tournamentRegistrations', 'registration-1'), {
          status: 'approved',
          verifiedBy: 'assistant-1',
          verifiedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
      await assertFails(
        updateDoc(doc(db, 'tournaments', 'tournament-1'), {
          name: 'Assistant Edited Cup',
          updatedAt: now + 1,
        }),
      );
      await assertFails(
        updateDoc(doc(db, 'tournaments/tournament-1/assistants/assistant-1'), {
          permissions: permissionMap({canApproveScore: true}),
          updatedAt: now + 1,
        }),
      );
    });
  });
});
