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
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-no-project';
const now = Date.now();
const day = 86400000;

let testEnv;

function challengeData(overrides = {}) {
  return {
    challengerId: 'challenger-1',
    challengedId: 'challenged-1',
    challengerTeamId: null,
    challengedTeamId: null,
    matchId: null,
    status: 'pending',
    message: 'ready?',
    location: 'main pitch',
    teamSize: 5,
    createdAt: Timestamp.fromMillis(now),
    respondedAt: null,
    expiresAt: Timestamp.fromMillis(now + 3 * day),
    ...overrides,
  };
}

function matchInvitationData(overrides = {}) {
  return {
    matchId: 'match-1',
    senderId: 'sender-1',
    receiverId: 'receiver-1',
    side: 'A',
    status: 'pending',
    createdAt: Timestamp.fromMillis(now),
    respondedAt: null,
    ...overrides,
  };
}

function challengeMatchData(overrides = {}) {
  return {
    organizerId: 'challenger-1',
    challengeId: 'challenge-1',
    teamAId: null,
    teamBId: null,
    teamAPlayerIds: ['challenger-1'],
    teamBPlayerIds: ['challenged-1'],
    teamAParticipantId: null,
    teamBParticipantId: null,
    status: 'open',
    scoreTeamA: null,
    scoreTeamB: null,
    mvpPlayerId: null,
    location: null,
    latitude: null,
    longitude: null,
    teamSize: 5,
    isOrganized: false,
    tournamentId: null,
    isGoldenRating: false,
    isAnomaly: false,
    isFrozen: false,
    stageType: null,
    groupId: null,
    groupStageId: null,
    knockoutTieId: null,
    roundIndex: null,
    slotNumber: null,
    scheduledAt: null,
    publishedAt: null,
    venueId: null,
    fixtureStatus: null,
    lineupRequirement: null,
    createdAt: now,
    startedAt: null,
    completedAt: null,
    cancelledAt: null,
    cancelledBy: null,
    cancelReason: null,
    ...overrides,
  };
}

function analyticsEventData(overrides = {}) {
  return {
    eventName: 'invite_sent',
    actorId: 'actor-1',
    parameters: {
      type: 'team_invite',
      targetId: 'target-1',
      actorId: 'actor-1',
    },
    createdAt: now,
    ...overrides,
  };
}

function auditEventData(overrides = {}) {
  return {
    entityType: 'tournament',
    entityId: 'tournament-1',
    action: 'fixtureStarted',
    actorId: 'organizer-1',
    metadata: { tournamentId: 'tournament-1' },
    createdAt: now,
    ...overrides,
  };
}

function initialPlayerData(uid, overrides = {}) {
  return {
    name: 'لاعب جديد',
    nameLower: 'لاعب جديد',
    username: null,
    usernameLower: null,
    photoUrl: 'https://example.test/avatar.png',
    photoThumbUrl: null,
    photoFrame: 'newcomer',
    qrCode: `7reef://player/${uid}`,
    phone: null,
    position: null,
    rating: 1000,
    totalMatches: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    mvpCount: 0,
    trustWeight: 0.5,
    trustLevel: 'newPlayer',
    role: 'player',
    achievementIds: [],
    teamIds: [],
    friendIds: [],
    followingIds: [],
    blockedIds: [],
    privacySetting: 'public',
    isGuest: false,
    createdAt: now,
    lastActiveAt: now,
    ...overrides,
  };
}

function friendshipData(userId1, userId2, overrides = {}) {
  return {
    userId1,
    userId2,
    participants: [userId1, userId2],
    status: 'pending',
    lastActionBy: userId1,
    createdAt: Timestamp.fromMillis(now),
    updatedAt: Timestamp.fromMillis(now),
    ...overrides,
  };
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

describe('backend security Firestore rules', () => {
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

  it('allows challenge creation only by the challenger', async () => {
    const challengerDb = testEnv.authenticatedContext('challenger-1').firestore();
    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();

    await assertSucceeds(
      setDoc(doc(challengerDb, 'challenges', 'challenge-1'), challengeData()),
    );
    await assertFails(
      setDoc(doc(challengedDb, 'challenges', 'challenge-2'), challengeData()),
    );
  });

  it('limits challenge reads to the challenger and challenged user', async () => {
    await seed('challenges/challenge-1', challengeData());

    const challengerDb = testEnv.authenticatedContext('challenger-1').firestore();
    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();
    const strangerDb = testEnv.authenticatedContext('stranger-1').firestore();

    await assertSucceeds(getDoc(doc(challengerDb, 'challenges', 'challenge-1')));
    await assertSucceeds(getDoc(doc(challengedDb, 'challenges', 'challenge-1')));
    await assertFails(getDoc(doc(strangerDb, 'challenges', 'challenge-1')));
  });

  it('protects challenge immutable fields on update', async () => {
    await seed('challenges/challenge-1', challengeData());

    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();

    await assertFails(
      updateDoc(doc(challengedDb, 'challenges', 'challenge-1'), {
        challengerId: 'attacker-1',
        status: 'accepted',
        respondedAt: Timestamp.fromMillis(now + 1000),
        matchId: 'challenge-1',
      }),
    );
  });

  it('allows the challenged user to accept a pending challenge', async () => {
    await seed('challenges/challenge-1', challengeData());
    await seed('matches/challenge-1', challengeMatchData());

    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();

    await assertSucceeds(
      updateDoc(doc(challengedDb, 'challenges', 'challenge-1'), {
        status: 'accepted',
        respondedAt: Timestamp.fromMillis(now + 1000),
        matchId: 'challenge-1',
      }),
    );
  });

  it('allows challenge-backed match creation only for the challenged user', async () => {
    await seed('challenges/challenge-1', challengeData());

    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();
    const strangerDb = testEnv.authenticatedContext('stranger-1').firestore();

    await assertSucceeds(
      setDoc(doc(challengedDb, 'matches', 'challenge-1'), challengeMatchData()),
    );
    await assertFails(
      setDoc(doc(strangerDb, 'matches', 'challenge-2'), {
        ...challengeMatchData({ challengeId: 'challenge-1' }),
      }),
    );
  });

  it('keeps ordinary organizer match creation valid', async () => {
    const organizerDb = testEnv.authenticatedContext('organizer-1').firestore();

    await assertSucceeds(
      setDoc(doc(organizerDb, 'matches', 'match-1'), {
        organizerId: 'organizer-1',
        status: 'open',
        createdAt: now,
      }),
    );
  });

  it('allows match invitation creation by sender and participant updates only', async () => {
    const senderDb = testEnv.authenticatedContext('sender-1').firestore();
    const receiverDb = testEnv.authenticatedContext('receiver-1').firestore();

    await assertSucceeds(
      setDoc(
        doc(senderDb, 'matchInvitations', 'invitation-1'),
        matchInvitationData(),
      ),
    );
    await assertSucceeds(
      updateDoc(doc(receiverDb, 'matchInvitations', 'invitation-1'), {
        status: 'accepted',
        respondedAt: Timestamp.fromMillis(now + 1000),
      }),
    );
  });

  it('protects match invitation immutable fields', async () => {
    await seed('matchInvitations/invitation-1', matchInvitationData());

    const receiverDb = testEnv.authenticatedContext('receiver-1').firestore();

    await assertFails(
      updateDoc(doc(receiverDb, 'matchInvitations', 'invitation-1'), {
        matchId: 'match-2',
        status: 'accepted',
        respondedAt: Timestamp.fromMillis(now + 1000),
      }),
    );
  });

  it('denies reserved username theft through previousOwnerId spoofing', async () => {
    await seed('reservedUsernames/captain', {
      username: 'captain',
      ownerId: 'owner-1',
      status: 'active',
      claimedAt: now,
      expiresAt: null,
    });

    const attackerDb = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(
      updateDoc(doc(attackerDb, 'reservedUsernames', 'captain'), {
        ownerId: 'attacker-1',
        previousOwnerId: 'attacker-1',
      }),
    );
  });

  it('allows claiming an expired reserved username', async () => {
    await seed('reservedUsernames/captain', {
      username: 'captain',
      ownerId: 'owner-1',
      previousOwnerId: 'owner-1',
      status: 'reserved',
      reservedAt: now - 20 * day,
      expiresAt: now - day,
    });

    const newOwnerDb = testEnv.authenticatedContext('new-owner-1').firestore();

    await assertSucceeds(
      updateDoc(doc(newOwnerDb, 'reservedUsernames', 'captain'), {
        ownerId: 'new-owner-1',
        status: 'active',
        claimedAt: now,
        expiresAt: null,
      }),
    );
  });

  it('denies every client analytics read and write operation', async () => {
    const anonymousDb = testEnv.unauthenticatedContext().firestore();
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    await seed('analyticsEvents/existing-event', analyticsEventData());

    await assertFails(
      setDoc(doc(anonymousDb, 'analyticsEvents', 'event-1'), analyticsEventData()),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'event-2'),
        analyticsEventData(),
      ),
    );
    await assertFails(
      setDoc(doc(actorDb, 'analyticsEvents', 'pride-event'), {
        eventName: 'pride_card_viewed',
        parameters: {
          cardType: 'mvp',
          entityType: 'guestPlayer',
          entityId: 'guest-player-1',
          campaignSource: 'post_match_mvp',
          schemaVersion: 1,
        },
        createdAt: now,
      }),
    );
    await assertFails(
      getDoc(doc(anonymousDb, 'analyticsEvents', 'existing-event')),
    );
    await assertFails(
      getDoc(doc(actorDb, 'analyticsEvents', 'existing-event')),
    );
    await assertFails(getDocs(collection(actorDb, 'analyticsEvents')));
    await assertFails(
      updateDoc(doc(actorDb, 'analyticsEvents', 'existing-event'), {
        createdAt: now + 1,
      }),
    );
    await assertFails(
      deleteDoc(doc(actorDb, 'analyticsEvents', 'existing-event')),
    );
  });

  it('denies client writes to organizerActions', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(doc(actorDb, 'organizerActions', 'action-1'), {
        actorId: 'actor-1',
        action: 'start_match',
        createdAt: now,
      }),
    );
    await assertFails(
      setDoc(doc(actorDb, 'organizerActions', 'action-2'), {
        actorId: 'other-1',
        action: 'start_match',
        createdAt: now,
      }),
    );
  });

  it('denies client auditEvents creation, update, and delete', async () => {
    await seed('auditEvents/event-1', auditEventData());
    const organizerDb = testEnv.authenticatedContext('organizer-1').firestore();
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await seed('tournaments/tournament-1', {
      name: 'Street Cup',
      organizerId: 'organizer-1',
      visibility: 'public',
      discoverable: true,
      createdAt: now,
    });

    await assertFails(
      setDoc(
        doc(actorDb, 'auditEvents', 'forged-event'),
        auditEventData({ actorId: 'actor-1' }),
      ),
    );
    await assertFails(
      updateDoc(doc(organizerDb, 'auditEvents', 'event-1'), {
        action: 'tournamentCompleted',
      }),
    );
    await assertFails(deleteDoc(doc(organizerDb, 'auditEvents', 'event-1')));
    await assertSucceeds(getDoc(doc(organizerDb, 'auditEvents', 'event-1')));
  });

  it('keeps moderation audit events private to their authenticated actor', async () => {
    await seed('auditEvents/report-event', auditEventData({
      entityType: 'moderationReport',
      entityId: 'opaque-report-id',
      action: 'profileReported',
      actorId: 'reporter-1',
      metadata: null,
    }));
    const reporterDb = testEnv.authenticatedContext('reporter-1').firestore();
    const targetDb = testEnv.authenticatedContext('target-1').firestore();
    const unrelatedDb = testEnv.authenticatedContext('other-1').firestore();

    await assertSucceeds(
      getDoc(doc(reporterDb, 'auditEvents', 'report-event')),
    );
    await assertFails(getDoc(doc(targetDb, 'auditEvents', 'report-event')));
    await assertFails(getDoc(doc(unrelatedDb, 'auditEvents', 'report-event')));
    await assertSucceeds(
      getDocs(query(
        collection(reporterDb, 'auditEvents'),
        where('actorId', '==', 'reporter-1'),
      )),
    );
    await assertFails(
      getDocs(query(
        collection(targetDb, 'auditEvents'),
        where('actorId', '==', 'reporter-1'),
      )),
    );
  });

  it('denies every direct client read and write to private user reports', async () => {
    await seed('userReports/report-1', {
      reporterId: 'actor-1',
      targetKind: 'registeredPlayer',
      targetId: 'target-1',
      contentType: 'profile',
      reason: 'spam',
      details: 'private evidence',
      status: 'open',
      createdAt: now,
      updatedAt: now,
    });
    const anonymousDb = testEnv.unauthenticatedContext().firestore();
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(getDoc(doc(anonymousDb, 'userReports', 'report-1')));
    await assertFails(getDoc(doc(actorDb, 'userReports', 'report-1')));
    await assertFails(getDocs(collection(actorDb, 'userReports')));
    await assertFails(
      setDoc(doc(actorDb, 'userReports', 'forged-report'), {
        reporterId: 'actor-1',
        targetId: 'target-1',
        status: 'open',
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'userReports', 'report-1'), {status: 'closed'}),
    );
    await assertFails(deleteDoc(doc(actorDb, 'userReports', 'report-1')));
  });

  it('keeps safety action quota counters backend-only', async () => {
    await seed('safetyActionQuotas/actor-1', {
      reportWindow: '2026-07-30',
      reportCount: 1,
      relationshipWindow: '2026-07-30T12',
      relationshipCount: 2,
    });
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      getDoc(doc(actorDb, 'safetyActionQuotas', 'actor-1')),
    );
    await assertFails(getDocs(collection(actorDb, 'safetyActionQuotas')));
    await assertFails(
      setDoc(doc(actorDb, 'safetyActionQuotas', 'forged'), {
        reportWindow: '2026-07-30',
        reportCount: 0,
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'safetyActionQuotas', 'actor-1'), {
        relationshipCount: 0,
      }),
    );
    await assertFails(
      deleteDoc(doc(actorDb, 'safetyActionQuotas', 'actor-1')),
    );
  });

  it('keeps account deletion tombstones backend-only', async () => {
    await seed('accountDeletionRequests/deleted-opaque', {
      status: 'completed',
      updatedAt: now,
    });
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      getDoc(doc(actorDb, 'accountDeletionRequests', 'deleted-opaque')),
    );
    await assertFails(
      getDocs(collection(actorDb, 'accountDeletionRequests')),
    );
    await assertFails(
      setDoc(doc(actorDb, 'accountDeletionRequests', 'forged'), {
        status: 'completed',
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'accountDeletionRequests', 'deleted-opaque'), {
        status: 'failed',
      }),
    );
    await assertFails(
      deleteDoc(doc(actorDb, 'accountDeletionRequests', 'deleted-opaque')),
    );
  });

  it('forces every block state change through backend callables', async () => {
    await seed('players/actor-1', initialPlayerData('actor-1', {
      friendIds: ['target-1'],
    }));
    await seed('players/target-1', initialPlayerData('target-1', {
      friendIds: ['actor-1'],
    }));
    await seed('players/peer-1', initialPlayerData('peer-1'));
    await seed(
      'friendships/actor-1_target-1',
      friendshipData('actor-1', 'target-1', {status: 'accepted'}),
    );
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    const targetDb = testEnv.authenticatedContext('target-1').firestore();
    const outsiderDb = testEnv.authenticatedContext('other-1').firestore();

    await assertSucceeds(
      getDoc(doc(actorDb, 'friendships', 'actor-1_target-1')),
    );
    await assertSucceeds(
      getDoc(doc(targetDb, 'friendships', 'actor-1_target-1')),
    );
    await assertFails(
      getDoc(doc(outsiderDb, 'friendships', 'actor-1_target-1')),
    );

    await assertFails(
      updateDoc(doc(actorDb, 'players', 'actor-1'), {
        blockedIds: ['target-1'],
      }),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_peer-1'),
        friendshipData('actor-1', 'peer-1', {status: 'blocked'}),
      ),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'friendships', 'actor-1_target-1'), {
        status: 'blocked',
        lastActionBy: 'actor-1',
        updatedAt: Timestamp.fromMillis(now + 1),
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_peer-1'),
        friendshipData('actor-1', 'peer-1'),
      ),
    );

    await seed('players/actor-1', initialPlayerData('actor-1', {
      blockedIds: ['target-1'],
    }));
    await seed(
      'friendships/actor-1_target-1',
      friendshipData('actor-1', 'target-1', {
        status: 'blocked',
        lastActionBy: 'actor-1',
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'players', 'actor-1'), {blockedIds: []}),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'friendships', 'actor-1_target-1'), {
        status: 'accepted',
        lastActionBy: 'actor-1',
        updatedAt: Timestamp.fromMillis(now + 2),
      }),
    );
    await assertFails(
      deleteDoc(doc(actorDb, 'friendships', 'actor-1_target-1')),
    );
  });

  it('binds friendship creates to the canonical pair and authenticated actor', async () => {
    await seed('players/actor-1', initialPlayerData('actor-1'));
    await seed('players/target-1', initialPlayerData('target-1'));
    await seed('players/peer-1', initialPlayerData('peer-1'));
    await seed('players/attacker-1', initialPlayerData('attacker-1'));
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    const attackerDb = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'arbitrary-document'),
        friendshipData('actor-1', 'target-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(attackerDb, 'friendships', 'actor-1_target-1'),
        friendshipData('attacker-1', 'target-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_target-1'),
        friendshipData('actor-1', 'target-1', {
          participants: ['target-1', 'actor-1'],
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'target-1_actor-1'),
        friendshipData('target-1', 'actor-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_target-1'),
        friendshipData('actor-1', 'target-1', {status: 'accepted'}),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_target-1'),
        friendshipData('actor-1', 'target-1', {
          lastActionBy: 'target-1',
        }),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_target-1'),
        friendshipData('actor-1', 'target-1'),
      ),
    );
  });

  it('allows only the request receiver to accept an unblocked friendship', async () => {
    await seed('players/actor-1', initialPlayerData('actor-1'));
    await seed('players/target-1', initialPlayerData('target-1'));
    await seed('players/peer-1', initialPlayerData('peer-1'));
    await seed(
      'friendships/actor-1_target-1',
      friendshipData('actor-1', 'target-1'),
    );
    await seed(
      'friendships/actor-1_peer-1',
      friendshipData('actor-1', 'peer-1'),
    );
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    const targetDb = testEnv.authenticatedContext('target-1').firestore();

    await assertFails(
      updateDoc(doc(actorDb, 'friendships', 'actor-1_peer-1'), {
        status: 'accepted',
        lastActionBy: 'actor-1',
        updatedAt: Timestamp.fromMillis(now + 1),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(targetDb, 'friendships', 'actor-1_target-1'), {
        status: 'accepted',
        lastActionBy: 'target-1',
        updatedAt: Timestamp.fromMillis(now + 1),
      }),
    );
  });

  it('rejects friendship creates and updates when either player blocks the other', async () => {
    await seed('players/actor-1', initialPlayerData('actor-1', {
      blockedIds: ['target-1'],
    }));
    await seed('players/target-1', initialPlayerData('target-1'));
    await seed('players/peer-1', initialPlayerData('peer-1', {
      blockedIds: ['actor-1'],
    }));
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    const targetDb = testEnv.authenticatedContext('target-1').firestore();
    const peerDb = testEnv.authenticatedContext('peer-1').firestore();

    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_target-1'),
        friendshipData('actor-1', 'target-1'),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'friendships', 'actor-1_peer-1'),
        friendshipData('actor-1', 'peer-1'),
      ),
    );

    await seed(
      'friendships/actor-1_target-1',
      friendshipData('actor-1', 'target-1'),
    );
    await seed(
      'friendships/actor-1_peer-1',
      friendshipData('actor-1', 'peer-1'),
    );
    await assertFails(
      updateDoc(doc(targetDb, 'friendships', 'actor-1_target-1'), {
        status: 'accepted',
        lastActionBy: 'target-1',
        updatedAt: Timestamp.fromMillis(now + 1),
      }),
    );
    await assertFails(
      updateDoc(doc(peerDb, 'friendships', 'actor-1_peer-1'), {
        status: 'accepted',
        lastActionBy: 'peer-1',
        updatedAt: Timestamp.fromMillis(now + 1),
      }),
    );
  });

  it('rejects new malformed relationship arrays without locking legacy profiles', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-1').firestore();

    await assertFails(
      setDoc(
        doc(ownerDb, 'players', 'owner-1'),
        initialPlayerData('owner-1', {friendIds: 'target-1'}),
      ),
    );
    await seed('players/owner-1', initialPlayerData('owner-1'));
    await assertFails(
      updateDoc(doc(ownerDb, 'players', 'owner-1'), {
        friendIds: 'target-1',
      }),
    );
    await assertFails(
      updateDoc(doc(ownerDb, 'players', 'owner-1'), {
        friendIds: Array.from({length: 1001}, (_, index) => `friend-${index}`),
      }),
    );
    await assertFails(
      updateDoc(doc(ownerDb, 'players', 'owner-1'), {
        followingIds: 'target-1',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(ownerDb, 'players', 'owner-1'), {
        friendIds: ['target-1'],
        followingIds: ['target-1'],
      }),
    );

    const legacyProfile = initialPlayerData('legacy-1');
    delete legacyProfile.friendIds;
    delete legacyProfile.followingIds;
    delete legacyProfile.blockedIds;
    await seed('players/legacy-1', legacyProfile);
    await seed(
      'players/legacy-peer-1',
      initialPlayerData('legacy-peer-1'),
    );
    const legacyDb = testEnv.authenticatedContext('legacy-1').firestore();
    await assertSucceeds(
      updateDoc(doc(legacyDb, 'players', 'legacy-1'), {
        name: 'ملف قديم صالح للتحديث',
      }),
    );
    await assertFails(
      updateDoc(doc(legacyDb, 'players', 'legacy-1'), {
        friendIds: {target: true},
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(legacyDb, 'friendships', 'legacy-1_legacy-peer-1'),
        friendshipData('legacy-1', 'legacy-peer-1'),
      ),
    );
  });

  it('allows only participant-scoped friendship list queries', async () => {
    await seed(
      'friendships/actor-1_target-1',
      friendshipData('actor-1', 'target-1', {status: 'accepted'}),
    );
    await seed(
      'friendships/actor-1_peer-1',
      friendshipData('actor-1', 'peer-1', {status: 'pending'}),
    );
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();
    const targetDb = testEnv.authenticatedContext('target-1').firestore();
    const outsiderDb = testEnv.authenticatedContext('other-1').firestore();

    await assertSucceeds(
      getDocs(query(
        collection(actorDb, 'friendships'),
        where('participants', 'array-contains', 'actor-1'),
        where('status', '==', 'accepted'),
      )),
    );
    await assertSucceeds(
      getDocs(query(
        collection(actorDb, 'friendships'),
        where('participants', 'array-contains', 'actor-1'),
        where('status', '==', 'pending'),
      )),
    );
    await assertSucceeds(
      getDocs(query(
        collection(targetDb, 'friendships'),
        where('participants', 'array-contains', 'target-1'),
        where('status', '==', 'accepted'),
      )),
    );
    await assertFails(getDocs(collection(actorDb, 'friendships')));
    await assertFails(
      getDocs(query(
        collection(actorDb, 'friendships'),
        where('status', '==', 'accepted'),
      )),
    );
    await assertFails(
      getDocs(query(
        collection(outsiderDb, 'friendships'),
        where('participants', 'array-contains', 'actor-1'),
        where('status', '==', 'accepted'),
      )),
    );
  });

  it('allows the current strict auth profile bootstrap for its owner', async () => {
    const ownerDb = testEnv.authenticatedContext('new-player').firestore();

    await assertSucceeds(
      setDoc(
        doc(ownerDb, 'players', 'new-player'),
        initialPlayerData('new-player'),
      ),
    );
  });

  it('denies forged initial player authority, history, time, and schema', async () => {
    const ownerDb = testEnv.authenticatedContext('new-player').firestore();
    const attempts = [
      initialPlayerData('new-player', {role: 'organizer'}),
      initialPlayerData('new-player', {rating: 9999}),
      initialPlayerData('new-player', {wins: 10}),
      initialPlayerData('new-player', {trustLevel: 'trusted'}),
      initialPlayerData('new-player', {
        createdAt: 1,
        lastActiveAt: 1,
      }),
      initialPlayerData('new-player', {admin: true}),
    ];

    for (const payload of attempts) {
      await assertFails(
        setDoc(doc(ownerDb, 'players', 'new-player'), payload),
      );
    }

    const attackerDb = testEnv.authenticatedContext('attacker').firestore();
    await assertFails(
      setDoc(
        doc(attackerDb, 'players', 'new-player'),
        initialPlayerData('new-player'),
      ),
    );
  });

  it('denies every direct client vote, session, and dispute write', async () => {
    await seed('fanVotingSessions/session-1', {
      matchId: 'match-1',
      status: 'open',
    });
    await seed('userVotes/vote-1', {
      matchId: 'match-1',
      userId: 'actor-1',
      candidateId: 'player-1',
    });
    await seed('disputes/dispute-1', {
      matchId: 'match-1',
      raisedBy: 'actor-1',
      status: 'open',
      createdAt: now,
    });
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(doc(actorDb, 'fanVotingSessions', 'session-2'), {
        matchId: 'match-1',
        status: 'open',
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'fanVotingSessions', 'session-1'), {
        status: 'closed',
      }),
    );
    await assertFails(
      deleteDoc(doc(actorDb, 'fanVotingSessions', 'session-1')),
    );

    await assertFails(
      setDoc(doc(actorDb, 'userVotes', 'vote-2'), {
        matchId: 'match-1',
        userId: 'actor-1',
        candidateId: 'player-1',
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'userVotes', 'vote-1'), {
        candidateId: 'player-2',
      }),
    );
    await assertFails(deleteDoc(doc(actorDb, 'userVotes', 'vote-1')));

    await assertFails(
      setDoc(doc(actorDb, 'disputes', 'dispute-2'), {
        matchId: 'match-1',
        raisedBy: 'actor-1',
        status: 'open',
        createdAt: now,
      }),
    );
    await assertFails(
      updateDoc(doc(actorDb, 'disputes', 'dispute-1'), {
        status: 'resolved',
      }),
    );
    await assertFails(deleteDoc(doc(actorDb, 'disputes', 'dispute-1')));
  });

  it('denies deletes for challenges and match invitations', async () => {
    await seed('challenges/challenge-1', challengeData());
    await seed('matchInvitations/invitation-1', matchInvitationData());

    const challengerDb = testEnv.authenticatedContext('challenger-1').firestore();
    const senderDb = testEnv.authenticatedContext('sender-1').firestore();

    await assertFails(deleteDoc(doc(challengerDb, 'challenges', 'challenge-1')));
    await assertFails(deleteDoc(doc(senderDb, 'matchInvitations', 'invitation-1')));
  });

  it('denies organizerAction creation with extra fields', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(doc(actorDb, 'organizerActions', 'action-extra'), {
        actorId: 'actor-1',
        action: 'start_match',
        createdAt: now,
        evilField: 'injected',
      }),
    );
  });

  it('denies reservedUsername creation when username field mismatches doc id', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-1').firestore();

    await assertFails(
      setDoc(doc(ownerDb, 'reservedUsernames', 'captain'), {
        username: 'not-captain',
        ownerId: 'owner-1',
        status: 'active',
        claimedAt: now,
        expiresAt: null,
      }),
    );
  });

  it('denies reservedUsername creation with extra fields', async () => {
    const ownerDb = testEnv.authenticatedContext('owner-1').firestore();

    await assertFails(
      setDoc(doc(ownerDb, 'reservedUsernames', 'captain'), {
        username: 'captain',
        ownerId: 'owner-1',
        status: 'active',
        claimedAt: now,
        expiresAt: null,
        evilField: 'injected',
      }),
    );
  });

  it('denies reservedUsername claim-expired update with extra fields', async () => {
    await seed('reservedUsernames/captain', {
      username: 'captain',
      ownerId: 'owner-1',
      previousOwnerId: 'owner-1',
      status: 'reserved',
      reservedAt: now - 20 * day,
      expiresAt: now - day,
    });

    const newOwnerDb = testEnv.authenticatedContext('new-owner-1').firestore();

    await assertFails(
      updateDoc(doc(newOwnerDb, 'reservedUsernames', 'captain'), {
        ownerId: 'new-owner-1',
        status: 'active',
        claimedAt: now,
        expiresAt: null,
        evilField: 'injected',
      }),
    );
  });

  it('denies challenge-backed match creation with extra fields', async () => {
    await seed('challenges/challenge-1', challengeData());

    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();

    await assertFails(
      setDoc(
        doc(challengedDb, 'matches', 'challenge-1'),
        challengeMatchData({ evilField: 'injected' }),
      ),
    );
  });

  it('denies challenge-backed match creation missing required fields', async () => {
    await seed('challenges/challenge-1', challengeData());

    const challengedDb = testEnv.authenticatedContext('challenged-1').firestore();

    await assertFails(
      setDoc(
        doc(challengedDb, 'matches', 'challenge-1'),
        { ...challengeMatchData(), teamSize: null },
      ),
    );
  });
});
