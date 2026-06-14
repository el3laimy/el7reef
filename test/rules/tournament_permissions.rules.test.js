const fs = require('fs');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-no-project';
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
    participantViewerIds: [],
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

function teamData(overrides = {}) {
  return {
    name: 'Red Wolves',
    ownerId: 'team-owner-1',
    viceCaptainIds: [],
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
    createdBy: 'organizer-1',
    createdAt: now,
    status: 'active',
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

function groupStandingSnapshotData(overrides = {}) {
  return {
    tournamentId: 'tournament-1',
    groupStageId: 'group-stage-1',
    groupId: 'group-1',
    tiebreakerOrder: ['points', 'goalDifference', 'goalsFor'],
    entries: [
      {
        participantId: 'participant-1',
        displayName: 'Red Wolves',
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        rank: 1,
        randomDrawOrder: 1,
      },
    ],
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

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function seedTournamentFixture() {
  await seed('tournaments/tournament-1', tournamentData());
  await seed('matches/match-1', matchData());
}

async function seedOtherOrganizerFixture() {
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
}

async function seedTeamRegistrationFixture() {
  await seed('tournaments/tournament-1', tournamentData());
  await seed('teams/team-1', teamData());
  await seed('teams/team-2', teamData({ownerId: 'other-team-owner'}));
}

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

const operationCollectionSpecs = [
  {
    collectionName: 'tournamentParticipants',
    docId: 'participant-1',
    data: tournamentParticipantData,
    safeUpdate: {seed: 2, updatedAt: now + 1},
    immutableUpdate: {sourceEntityId: 'team-2', updatedAt: now + 1},
    otherOwnerData: () => tournamentParticipantData({tournamentId: 'tournament-2'}),
    deleteAllowed: true,
  },
  {
    collectionName: 'tournamentGroups',
    docId: 'group-1',
    data: tournamentGroupData,
    safeUpdate: {name: 'Group Alpha', updatedAt: now + 1},
    immutableUpdate: {groupStageId: 'group-stage-2', updatedAt: now + 1},
    otherOwnerData: () => tournamentGroupData({tournamentId: 'tournament-2'}),
    deleteAllowed: true,
  },
  {
    collectionName: 'groupStandingSnapshots',
    docId: 'standing-1',
    data: groupStandingSnapshotData,
    safeUpdate: {
      qualifierParticipantIds: ['participant-1'],
      updatedAt: now + 1,
    },
    immutableUpdate: {groupId: 'group-2', updatedAt: now + 1},
    otherOwnerData: () =>
      groupStandingSnapshotData({tournamentId: 'tournament-2'}),
    deleteAllowed: true,
  },
  {
    collectionName: 'knockoutBrackets',
    docId: 'bracket-1',
    data: knockoutBracketData,
    safeUpdate: {championParticipantId: 'participant-1', updatedAt: now + 1},
    immutableUpdate: {tournamentId: 'tournament-2', updatedAt: now + 1},
    otherOwnerData: () => knockoutBracketData({tournamentId: 'tournament-2'}),
    deleteAllowed: false,
  },
  {
    collectionName: 'knockoutTies',
    docId: 'tie-1',
    data: knockoutTieData,
    safeUpdate: {winnerParticipantId: 'participant-1', updatedAt: now + 1},
    immutableUpdate: {bracketId: 'bracket-2', updatedAt: now + 1},
    otherOwnerData: () => knockoutTieData({tournamentId: 'tournament-2'}),
    deleteAllowed: false,
  },
  {
    collectionName: 'matchSides',
    docId: 'match-1_A',
    data: matchSideData,
    safeUpdate: {displayName: 'Red Wolves Updated', updatedAt: now + 1},
    immutableUpdate: {matchId: 'match-2', updatedAt: now + 1},
    otherOwnerData: () =>
      matchSideData({matchId: 'match-2', sideKey: 'A', officialTeamId: 'team-2'}),
    deleteAllowed: false,
  },
  {
    collectionName: 'matchSidePlayers',
    docId: 'side-player-1',
    data: matchSidePlayerData,
    safeUpdate: {
      displayName: 'Temporary Player Updated',
      shirtNumber: 9,
    },
    immutableUpdate: {matchId: 'match-2'},
    otherOwnerData: () =>
      matchSidePlayerData({matchId: 'match-2', sideId: 'match-2_A'}),
    deleteAllowed: true,
  },
];

describe('tournament permission Firestore rules', () => {
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

  describe('tournament ownership', () => {
    it('allows organizer to create a tournament with own organizerId', async () => {
      const db = authedDb('organizer-1');

      await assertSucceeds(
        setDoc(doc(db, 'tournaments', 'tournament-1'), tournamentData()),
      );
    });

    it('denies authenticated user creating a tournament for another organizerId', async () => {
      const db = authedDb('account-b');

      await assertFails(
        setDoc(doc(db, 'tournaments', 'forged-tournament'), tournamentData()),
      );
    });

    it('allows organizer to update own tournament', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('organizer-1');

      await assertSucceeds(
        updateDoc(doc(db, 'tournaments', 'tournament-1'), {
          status: 'active',
          updatedAt: now + 1,
        }),
      );
    });

    it('denies non-organizer updating another user tournament', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('account-b');

      await assertFails(
        updateDoc(doc(db, 'tournaments', 'tournament-1'), {
          status: 'active',
          updatedAt: now + 1,
        }),
      );
    });

    it('denies tournament delete', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('organizer-1');

      await assertFails(deleteDoc(doc(db, 'tournaments', 'tournament-1')));
    });

    it('allows authenticated users to read public discoverable tournaments', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('player-1');

      await assertSucceeds(getDoc(doc(db, 'tournaments/tournament-1')));
    });

    it('denies outsiders reading private tournaments', async () => {
      await seed(
        'tournaments/tournament-1',
        tournamentData({
          visibility: 'private',
          discoverable: false,
        }),
      );
      const db = authedDb('player-1');

      await assertFails(getDoc(doc(db, 'tournaments/tournament-1')));
    });

    it('allows organizer to read own private tournament', async () => {
      await seed(
        'tournaments/tournament-1',
        tournamentData({
          visibility: 'private',
          discoverable: false,
        }),
      );
      const db = authedDb('organizer-1');

      await assertSucceeds(getDoc(doc(db, 'tournaments/tournament-1')));
    });

    it('allows active assistants to read private tournament details', async () => {
      await seed(
        'tournaments/tournament-1',
        tournamentData({
          visibility: 'private',
          discoverable: false,
        }),
      );
      await seed('tournaments/tournament-1/assistants/assistant-1', {
        tournamentId: 'tournament-1',
        userId: 'assistant-1',
        addedBy: 'organizer-1',
        status: 'active',
        preset: 'customLimited',
        permissions: {
          canViewMatchday: true,
          canStartMatch: false,
          canSubmitScore: false,
          canRecordGoalsAndMvp: false,
          canApproveScore: false,
          canDeclareForfeit: false,
          canManageGuestRoster: false,
        },
        createdAt: now,
        updatedAt: now,
        revokedAt: null,
      });
      const db = authedDb('assistant-1');

      await assertSucceeds(getDoc(doc(db, 'tournaments/tournament-1')));
    });

    it('allows listed participant viewers to read private tournament details', async () => {
      await seed(
        'tournaments/tournament-1',
        tournamentData({
          visibility: 'private',
          discoverable: false,
          participantViewerIds: ['player-1'],
        }),
      );
      const db = authedDb('player-1');

      await assertSucceeds(getDoc(doc(db, 'tournaments/tournament-1')));
    });

    it('allows public discovery queries and rejects private tournament lists', async () => {
      await seed(
        'tournaments/tournament-1',
        tournamentData({
          visibility: 'public',
          discoverable: true,
        }),
      );
      await seed(
        'tournaments/tournament-2',
        tournamentData({
          organizerId: 'organizer-2',
          visibility: 'private',
          discoverable: false,
        }),
      );
      const db = authedDb('player-1');

      await assertSucceeds(
        getDocs(
          query(
            collection(db, 'tournaments'),
            where('visibility', '==', 'public'),
            where('discoverable', '==', true),
          ),
        ),
      );
      await assertFails(
        getDocs(
          query(
            collection(db, 'tournaments'),
            where('visibility', '==', 'private'),
          ),
        ),
      );
    });

    it('allows a player to follow and unfollow a tournament as self', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('player-1');
      const followerRef = doc(
        db,
        'tournaments/tournament-1/followers/player-1',
      );

      await assertSucceeds(
        setDoc(followerRef, {
          tournamentId: 'tournament-1',
          userId: 'player-1',
          createdAt: now,
        }),
      );
      await assertSucceeds(deleteDoc(followerRef));
    });

    it('denies forged follower identity and organizer self-follow', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const playerDb = authedDb('player-1');
      const organizerDb = authedDb('organizer-1');

      await assertFails(
        setDoc(doc(playerDb, 'tournaments/tournament-1/followers/player-2'), {
          tournamentId: 'tournament-1',
          userId: 'player-2',
          createdAt: now,
        }),
      );
      await assertFails(
        setDoc(
          doc(organizerDb, 'tournaments/tournament-1/followers/organizer-1'),
          {
            tournamentId: 'tournament-1',
            userId: 'organizer-1',
            createdAt: now,
          },
        ),
      );
    });

    it('denies malformed follower documents and cross-user follower access', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      await seed('tournaments/tournament-1/followers/player-2', {
        tournamentId: 'tournament-1',
        userId: 'player-2',
        createdAt: now,
      });
      const playerDb = authedDb('player-1');

      await assertFails(
        setDoc(doc(playerDb, 'tournaments/tournament-1/followers/player-1'), {
          tournamentId: 'tournament-1',
          userId: 'player-1',
          createdAt: now,
          role: 'admin',
        }),
      );
      await assertFails(
        getDoc(doc(playerDb, 'tournaments/tournament-1/followers/player-2')),
      );
      await assertFails(
        deleteDoc(doc(playerDb, 'tournaments/tournament-1/followers/player-2')),
      );
    });

    it('allows a player to query only their own followed tournaments', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      await seed(
        'tournaments/tournament-2',
        tournamentData({organizerId: 'organizer-2'}),
      );
      await seed('tournaments/tournament-1/followers/player-1', {
        tournamentId: 'tournament-1',
        userId: 'player-1',
        createdAt: now,
      });
      await seed('tournaments/tournament-2/followers/player-2', {
        tournamentId: 'tournament-2',
        userId: 'player-2',
        createdAt: now,
      });
      const playerDb = authedDb('player-1');

      await assertSucceeds(
        getDocs(
          query(
            collectionGroup(playerDb, 'followers'),
            where('userId', '==', 'player-1'),
          ),
        ),
      );
      await assertFails(
        getDocs(
          query(
            collectionGroup(playerDb, 'followers'),
            where('userId', '==', 'player-2'),
          ),
        ),
      );
    });
  });

  describe('match and fixture ownership', () => {
    it('allows organizer to create a match fixture with own organizerId', async () => {
      const db = authedDb('organizer-1');

      await assertSucceeds(
        setDoc(doc(db, 'matches', 'match-1'), matchData()),
      );
    });

    it('denies authenticated user creating a match for another organizerId', async () => {
      const db = authedDb('account-b');

      await assertFails(
        setDoc(doc(db, 'matches', 'forged-match'), matchData()),
      );
    });

    it('allows organizer to update own match fixture', async () => {
      await seed('matches/match-1', matchData());
      const db = authedDb('organizer-1');

      await assertSucceeds(
        updateDoc(doc(db, 'matches', 'match-1'), {
          fixtureStatus: 'published',
          scheduledAt: now + 172800000,
          updatedAt: now + 1,
        }),
      );
    });

    it('denies non-organizer updating another organizer match', async () => {
      await seed('matches/match-1', matchData());
      const db = authedDb('account-b');

      await assertFails(
        updateDoc(doc(db, 'matches', 'match-1'), {
          fixtureStatus: 'published',
          updatedAt: now + 1,
        }),
      );
    });

    it('denies match delete', async () => {
      await seed('matches/match-1', matchData());
      const db = authedDb('organizer-1');

      await assertFails(deleteDoc(doc(db, 'matches', 'match-1')));
    });
  });

  describe('tournament registrations', () => {
    it('allows team owner to submit registration for own team', async () => {
      await seedTeamRegistrationFixture();
      const db = authedDb('team-owner-1');

      await assertSucceeds(
        setDoc(
          doc(db, 'tournamentRegistrations', 'registration-1'),
          registrationData(),
        ),
      );
    });

    it('denies team owner creating an already approved registration', async () => {
      await seedTeamRegistrationFixture();
      const db = authedDb('team-owner-1');

      await assertFails(
        setDoc(
          doc(db, 'tournamentRegistrations', 'registration-1'),
          registrationData({
            status: 'approved',
            verifiedBy: 'team-owner-1',
            verifiedAt: now,
          }),
        ),
      );
    });

    it('denies non-team-owner creating registration for another team', async () => {
      await seedTeamRegistrationFixture();
      const db = authedDb('account-b');

      await assertFails(
        setDoc(
          doc(db, 'tournamentRegistrations', 'registration-1'),
          registrationData(),
        ),
      );
    });

    it('allows tournament organizer to approve registration', async () => {
      await seedTeamRegistrationFixture();
      await seed(
        'tournamentRegistrations/registration-1',
        registrationData(),
      );
      const db = authedDb('organizer-1');

      await assertSucceeds(
        updateDoc(doc(db, 'tournamentRegistrations', 'registration-1'), {
          status: 'approved',
          verifiedBy: 'organizer-1',
          verifiedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
    });

    it('allows team owner to edit safe pending registration fields', async () => {
      await seedTeamRegistrationFixture();
      await seed(
        'tournamentRegistrations/registration-1',
        registrationData(),
      );
      const db = authedDb('team-owner-1');

      await assertSucceeds(
        updateDoc(doc(db, 'tournamentRegistrations', 'registration-1'), {
          notes: 'Need the late slot if possible.',
          updatedAt: now + 1,
        }),
      );
    });

    it('denies team owner self-approving by changing status to approved', async () => {
      await seedTeamRegistrationFixture();
      await seed(
        'tournamentRegistrations/registration-1',
        registrationData(),
      );
      const db = authedDb('team-owner-1');

      await assertFails(
        updateDoc(doc(db, 'tournamentRegistrations', 'registration-1'), {
          status: 'approved',
          verifiedBy: 'team-owner-1',
          verifiedAt: now + 1,
          updatedAt: now + 1,
        }),
      );
    });

    it('denies team owner changing source identity fields', async () => {
      await seedTeamRegistrationFixture();
      await seed(
        'tournamentRegistrations/registration-1',
        registrationData(),
      );
      const db = authedDb('team-owner-1');

      await assertFails(
        updateDoc(doc(db, 'tournamentRegistrations', 'registration-1'), {
          teamId: 'team-2',
          updatedAt: now + 1,
        }),
      );
    });
  });

  describe('matchEvents', () => {
    it('allows organizer to create a valid goal event fixture', async () => {
      await seedTournamentFixture();
      const db = authedDb('organizer-1');

      await assertSucceeds(
        setDoc(doc(db, 'matchEvents', 'goal-1'), matchEventData()),
      );
    });

    it('allows organizer to create a valid MVP event fixture', async () => {
      await seedTournamentFixture();
      const db = authedDb('organizer-1');

      await assertSucceeds(
        setDoc(
          doc(db, 'matchEvents', 'mvp-1'),
          matchEventData({
            eventType: 'mvp',
            minute: null,
          }),
        ),
      );
    });

    it('denies createdBy spoofing for match event create', async () => {
      await seedTournamentFixture();
      const db = authedDb('account-b');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'spoofed-goal-1'),
          matchEventData({createdBy: 'organizer-1'}),
        ),
      );
    });

    it('denies random auth user creating goal event in another organizer tournament', async () => {
      await seedTournamentFixture();
      const db = authedDb('account-b');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'forged-goal-1'),
          matchEventData({createdBy: 'account-b'}),
        ),
      );
    });

    it('denies random auth user creating MVP event in another organizer tournament', async () => {
      await seedTournamentFixture();
      const db = authedDb('account-b');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'forged-mvp-1'),
          matchEventData({
            eventType: 'mvp',
            minute: null,
            createdBy: 'account-b',
          }),
        ),
      );
    });

    it('denies event tournamentId mismatch with match tournamentId', async () => {
      await seedTournamentFixture();
      const db = authedDb('organizer-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'mismatch-goal-1'),
          matchEventData({tournamentId: 'other-tournament'}),
        ),
      );
    });

    it('denies event for missing or nonexistent matchId', async () => {
      await seed('tournaments/tournament-1', tournamentData());
      const db = authedDb('organizer-1');

      await assertFails(
        setDoc(
          doc(db, 'matchEvents', 'missing-match-goal-1'),
          matchEventData({matchId: 'missing-match'}),
        ),
      );
    });
  });

  describe('tournament operation collections', () => {
    for (const spec of operationCollectionSpecs) {
      it(`allows organizer create for own ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        const db = authedDb('organizer-1');

        await assertSucceeds(
          setDoc(
            doc(db, spec.collectionName, spec.docId),
            spec.data(),
          ),
        );
      });

      it(`denies non-organizer create for ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        const db = authedDb('account-b');

        await assertFails(
          setDoc(
            doc(db, spec.collectionName, spec.docId),
            spec.data(),
          ),
        );
      });

      it(`denies organizer create for another organizer ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        await seedOtherOrganizerFixture();
        const db = authedDb('organizer-1');

        await assertFails(
          setDoc(
            doc(db, spec.collectionName, `${spec.docId}-other`),
            spec.otherOwnerData(),
          ),
        );
      });

      it(`allows organizer safe update for own ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        await seed(`${spec.collectionName}/${spec.docId}`, spec.data());
        const db = authedDb('organizer-1');

        await assertSucceeds(
          updateDoc(
            doc(db, spec.collectionName, spec.docId),
            spec.safeUpdate,
          ),
        );
      });

      it(`denies non-organizer update for ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        await seed(`${spec.collectionName}/${spec.docId}`, spec.data());
        const db = authedDb('account-b');

        await assertFails(
          updateDoc(
            doc(db, spec.collectionName, spec.docId),
            spec.safeUpdate,
          ),
        );
      });

      it(`denies immutable ref update for ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        await seedOtherOrganizerFixture();
        await seed(`${spec.collectionName}/${spec.docId}`, spec.data());
        const db = authedDb('organizer-1');

        await assertFails(
          updateDoc(
            doc(db, spec.collectionName, spec.docId),
            spec.immutableUpdate,
          ),
        );
      });

      it(`enforces delete policy for ${spec.collectionName}`, async () => {
        await seedTournamentFixture();
        await seed(`${spec.collectionName}/${spec.docId}`, spec.data());
        const db = authedDb('organizer-1');
        const expectation = spec.deleteAllowed ? assertSucceeds : assertFails;

        await expectation(deleteDoc(doc(db, spec.collectionName, spec.docId)));
      });
    }
  });
});
