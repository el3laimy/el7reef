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

function prideAnalyticsEventData(overrides = {}) {
  return {
    eventName: 'pride_card_viewed',
    parameters: {
      cardType: 'mvp',
      entityType: 'guestPlayer',
      entityId: 'guest-player-1',
      tournamentId: 'tournament-1',
      matchId: 'match-1',
      campaignSource: 'post_match_mvp',
      schemaVersion: 1,
    },
    createdAt: now,
    ...overrides,
  };
}

function prideExportAnalyticsEventData(overrides = {}) {
  return {
    eventName: 'pride_export_finished',
    parameters: {
      cardType: 'matchResult',
      format: 'story9x16',
      mediaType: 'video',
      exportDurationMs: 11800,
      fallbackUsed: false,
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
        analyticsEventData(),
      ),
    );
  });

  it('allows only the current invite, claim, and join analytics schemas', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertSucceeds(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'invite-valid'),
        analyticsEventData(),
      ),
    );
    await assertSucceeds(
      setDoc(doc(actorDb, 'analyticsEvents', 'claim-open-valid'), {
        eventName: 'claim_open',
        parameters: { type: 'guestPlayer', targetId: 'guest-player-1' },
        createdAt: now,
      }),
    );
    await assertSucceeds(
      setDoc(doc(actorDb, 'analyticsEvents', 'claim-complete-valid'), {
        eventName: 'claim_completion',
        actorId: 'actor-1',
        parameters: {
          type: 'guest_player',
          targetId: 'guest-player-1',
          actorId: 'actor-1',
        },
        createdAt: now,
      }),
    );
    await assertSucceeds(
      setDoc(doc(actorDb, 'analyticsEvents', 'join-valid'), {
        eventName: 'join_completion',
        actorId: 'actor-1',
        parameters: {
          type: 'team_invite',
          targetId: 'team-1',
          actorId: 'actor-1',
        },
        createdAt: now,
      }),
    );
  });

  it('allows privacy-safe pride funnel and export analytics events', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertSucceeds(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-valid'),
        prideAnalyticsEventData(),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-valid'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            fallbackUsed: true,
            failureCode: 'encoder_unavailable',
          },
        }),
      ),
    );
  });

  it('rejects PII and extra fields in analytics parameters', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-player-name'),
        prideAnalyticsEventData({
          parameters: {
            ...prideAnalyticsEventData().parameters,
            playerName: 'Secret Player',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-top-level-extra'),
        prideAnalyticsEventData({ email: 'player@example.com' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-extra'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            targetUrl: 'https://example.com/private',
          },
        }),
      ),
    );
  });

  it('rejects invalid pride analytics enums, types, and ranges', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-bad-card'),
        prideAnalyticsEventData({
          parameters: {
            ...prideAnalyticsEventData().parameters,
            cardType: 'fakeAward',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-bad-schema'),
        prideAnalyticsEventData({
          parameters: {
            ...prideAnalyticsEventData().parameters,
            schemaVersion: 2,
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'pride-bad-entity'),
        prideAnalyticsEventData({
          parameters: {
            ...prideAnalyticsEventData().parameters,
            entityType: 'profile',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-format'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            format: 'portrait',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-media'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            mediaType: 'gif',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-duration-type'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            exportDurationMs: '11800',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-fallback-type'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            fallbackUsed: 'false',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-failure-code'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            failureCode: 'encoder failed: player@example.com',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'legacy-bad-type'),
        analyticsEventData({
          parameters: {
            ...analyticsEventData().parameters,
            type: 'guestPlayer',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'export-bad-duration-range'),
        prideExportAnalyticsEventData({
          parameters: {
            ...prideExportAnalyticsEventData().parameters,
            exportDurationMs: 600001,
          },
        }),
      ),
    );
  });

  it('rejects analytics actor spoofing and unsupported events', async () => {
    const actorDb = testEnv.authenticatedContext('actor-1').firestore();

    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'spoofed-top-level-actor'),
        analyticsEventData({ actorId: 'attacker-1' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(actorDb, 'analyticsEvents', 'spoofed-parameter-actor'),
        analyticsEventData({
          parameters: {
            ...analyticsEventData().parameters,
            actorId: 'attacker-1',
          },
        }),
      ),
    );
    await assertFails(
      setDoc(doc(actorDb, 'analyticsEvents', 'unsupported-event'), {
        eventName: 'player_profile_viewed',
        parameters: {},
        createdAt: now,
      }),
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
