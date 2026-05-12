const fs = require('fs');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
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
    parameters: { targetId: 'target-1' },
    createdAt: now,
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

  it('requires authentication for analytics events', async () => {
    const anonymousDb = testEnv.unauthenticatedContext().firestore();
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(doc(anonymousDb, 'analyticsEvents', 'event-1'), analyticsEventData()),
    );
    await assertSucceeds(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'event-2'),
        analyticsEventData({ actorId: 'actor-1' }),
      ),
    );
  });

  it('ties organizer action actorId to the authenticated user', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertSucceeds(
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
