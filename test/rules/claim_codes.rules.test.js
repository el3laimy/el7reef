const assert = require('assert');
const fs = require('fs');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

const projectId = 'demo-no-project';
const now = 1770000000000;

let testEnv;

function guestClaimCodeData(overrides = {}) {
  return {
    targetType: 'guestPlayer',
    targetId: 'guest-player-1',
    scope: 'team',
    teamId: 'team-1',
    tournamentId: 'tournament-1',
    createdBy: 'creator-1',
    requiresApproval: false,
    status: 'active',
    createdAt: now,
    updatedAt: now,
    expiresAt: null,
    claimedByPlayerId: null,
    claimedAt: null,
    ...overrides,
  };
}

function teamInviteClaimCodeData(overrides = {}) {
  return {
    targetType: 'teamInvite',
    targetId: 'team-1',
    scope: 'team',
    teamId: 'team-1',
    tournamentId: null,
    createdBy: 'creator-1',
    requiresApproval: false,
    status: 'active',
    createdAt: now,
    updatedAt: now,
    expiresAt: now + 86400000,
    claimedByPlayerId: null,
    claimedAt: null,
    ...overrides,
  };
}

async function seedGuestClaimCode(code, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'claimCodes', code),
      guestClaimCodeData(data),
    );
  });
}

async function seedTeamInviteCode(code, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'claimCodes', code),
      teamInviteClaimCodeData(data),
    );
  });
}

function guestPlayerData(overrides = {}) {
  return {
    displayName: 'ضيف سريع',
    normalizedName: 'ضيف سريع',
    phoneNumber: null,
    jerseyNumber: null,
    preferredPosition: null,
    teamId: 'team-1',
    tournamentId: 'tournament-1',
    createdBy: 'creator-1',
    createdAt: now,
    updatedAt: now,
    claimCode: 'PLAYER-CODE-1',
    notes: null,
    claimStatus: 'invited',
    linkedPlayerId: null,
    ...overrides,
  };
}

function guestTeamData(overrides = {}) {
  return {
    name: 'فريق ضيف',
    normalizedName: 'فريق ضيف',
    creatorId: 'creator-1',
    contactName: 'كابتن ضيف',
    contactPhone: null,
    logoUrl: null,
    tournamentIds: ['tournament-1'],
    captainGuestPlayerId: null,
    claimCode: 'TEAM-CODE-1',
    createdAt: now,
    updatedAt: now,
    claimStatus: 'invited',
    linkedTeamId: null,
    ...overrides,
  };
}

async function seedGuestPlayer(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'guestPlayers', id),
      guestPlayerData(data),
    );
  });
}

async function seedGuestTeam(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'guestTeams', id),
      guestTeamData(data),
    );
  });
}

async function seedTeam(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'teams', id), {
      name: 'فريق مسجل',
      ownerId: 'claimer-1',
      playerIds: [],
      viceCaptainIds: [],
      tournamentIds: [],
      createdAt: now,
      ...data,
    });
  });
}

function teamMembershipData(overrides = {}) {
  return {
    teamId: 'team-1',
    playerId: null,
    guestPlayerId: 'guest-player-1',
    claimedFromGuestPlayerId: null,
    role: 'player',
    status: 'bench',
    availability: 'available',
    joinedAt: now,
    updatedAt: now,
    invitedBy: 'creator-1',
    ...overrides,
  };
}

async function seedMembership(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'teamMemberships', id),
      teamMembershipData(data),
    );
  });
}

describe('claimCodes Firestore rules', () => {
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

  it('denies anonymous exact team invite code get', async () => {
    await seedTeamInviteCode('TEAM-INVITE-1');

    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1')));
  });

  it('allows authenticated exact team invite get as bearer proof', async () => {
    await seedTeamInviteCode('TEAM-INVITE-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();
    const snapshot = await assertSucceeds(
      getDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1')),
    );

    assert.strictEqual(snapshot.exists(), true);
    assert.strictEqual(snapshot.data().targetId, 'team-1');
  });

  it('denies broad claim code listing for authenticated users', async () => {
    await seedTeamInviteCode('TEAM-INVITE-1');

    const db = testEnv.authenticatedContext('creator-1').firestore();

    await assertFails(getDocs(collection(db, 'claimCodes')));
  });

  it('allows creator-scoped active team invite reuse query', async () => {
    await seedTeamInviteCode('OLDER-CODE', {
      createdBy: 'creator-1',
      createdAt: now - 1000,
      updatedAt: now - 1000,
    });
    await seedTeamInviteCode('NEWER-CODE', {
      createdBy: 'creator-1',
      createdAt: now,
      updatedAt: now,
    });
    await seedTeamInviteCode('OTHER-CREATOR-CODE', {
      createdBy: 'creator-2',
      createdAt: now + 1000,
      updatedAt: now + 1000,
    });

    const db = testEnv.authenticatedContext('creator-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'teamInvite'),
      where('targetId', '==', 'team-1'),
      where('status', '==', 'active'),
      where('createdBy', '==', 'creator-1'),
      orderBy('createdAt', 'desc'),
      limit(1),
    );

    const snapshot = await assertSucceeds(getDocs(reuseQuery));

    assert.strictEqual(snapshot.docs.length, 1);
    assert.strictEqual(snapshot.docs[0].id, 'NEWER-CODE');
  });

  it('allows creator-scoped team invite reuse with tournament constraint', async () => {
    await seedTeamInviteCode('TOURNAMENT-CODE', {
      createdBy: 'creator-1',
      tournamentId: 'tournament-1',
      scope: 'tournament',
    });

    const db = testEnv.authenticatedContext('creator-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'teamInvite'),
      where('targetId', '==', 'team-1'),
      where('status', '==', 'active'),
      where('createdBy', '==', 'creator-1'),
      where('tournamentId', '==', 'tournament-1'),
      orderBy('createdAt', 'desc'),
      limit(1),
    );

    const snapshot = await assertSucceeds(getDocs(reuseQuery));

    assert.strictEqual(snapshot.docs.length, 1);
    assert.strictEqual(snapshot.docs[0].id, 'TOURNAMENT-CODE');
  });

  it('denies non-creator query against another creator team invite scope', async () => {
    await seedTeamInviteCode('TEAM-INVITE-1', {createdBy: 'creator-1'});

    const db = testEnv.authenticatedContext('attacker-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'teamInvite'),
      where('targetId', '==', 'team-1'),
      where('status', '==', 'active'),
      where('createdBy', '==', 'creator-1'),
      orderBy('createdAt', 'desc'),
      limit(1),
    );

    await assertFails(getDocs(reuseQuery));
  });

  it('allows a team manager to create and expire a constrained team invite', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});

    const db = testEnv.authenticatedContext('creator-1').firestore();
    await assertSucceeds(
      setDoc(
        doc(db, 'claimCodes', 'TEAM-INVITE-1'),
        teamInviteClaimCodeData(),
      ),
    );
    await assertSucceeds(
      updateDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1'), {
        status: 'expired',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies team invite create and update schema or lifecycle bypasses', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    await seedTeamInviteCode('TEAM-INVITE-1');

    const db = testEnv.authenticatedContext('creator-1').firestore();
    await assertFails(
      setDoc(
        doc(db, 'claimCodes', 'POLLUTED-INVITE'),
        teamInviteClaimCodeData({extraData: 'malicious'}),
      ),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1'), {
        status: 'expired',
        updatedAt: now + 1,
        extraData: 'malicious',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1'), {
        targetId: 'team-2',
        status: 'expired',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest player and guest team code reads, lists, creates, and updates', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    await seedGuestClaimCode('PLAYER-CODE-1');
    await seedGuestClaimCode('TEAM-CODE-1', {
      targetType: 'guestTeam',
      targetId: 'guest-team-1',
    });

    const db = testEnv.authenticatedContext('creator-1').firestore();

    await assertFails(getDoc(doc(db, 'claimCodes', 'PLAYER-CODE-1')));
    await assertFails(getDoc(doc(db, 'claimCodes', 'TEAM-CODE-1')));
    await assertFails(
      getDocs(
        query(
          collection(db, 'claimCodes'),
          where('targetType', '==', 'guestPlayer'),
          where('createdBy', '==', 'creator-1'),
        ),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, 'claimCodes', 'CLIENT-PLAYER-CODE'),
        guestClaimCodeData(),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, 'claimCodes', 'CLIENT-TEAM-CODE'),
        guestClaimCodeData({
          targetType: 'guestTeam',
          targetId: 'guest-team-1',
        }),
      ),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'PLAYER-CODE-1'), {
        status: 'claimed',
        claimedByPlayerId: 'creator-1',
        claimedAt: now + 1,
        updatedAt: now + 1,
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'TEAM-CODE-1'), {
        status: 'expired',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies unauthorized team invite creates and updates', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    await seedTeamInviteCode('TEAM-INVITE-1', {createdBy: 'creator-1'});

    const db = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(
      setDoc(
        doc(db, 'claimCodes', 'ATTACKER-INVITE'),
        teamInviteClaimCodeData({createdBy: 'attacker-1'}),
      ),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'TEAM-INVITE-1'), {
        status: 'expired',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest player self-claim without same-batch claim code proof', async () => {
    await seedGuestClaimCode('PLAYER-CODE-1');
    await seedGuestPlayer('guest-player-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();

    await assertFails(
      updateDoc(doc(db, 'guestPlayers', 'guest-player-1'), {
        claimStatus: 'claimed',
        linkedPlayerId: 'claimer-1',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest player self-claim even with same-batch code mutation', async () => {
    await seedGuestClaimCode('PLAYER-CODE-1');
    await seedGuestPlayer('guest-player-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, 'guestPlayers', 'guest-player-1'), {
      claimStatus: 'claimed',
      linkedPlayerId: 'claimer-1',
      updatedAt: now + 1,
    });
    batch.update(doc(db, 'claimCodes', 'PLAYER-CODE-1'), {
      status: 'claimed',
      claimedByPlayerId: 'claimer-1',
      claimedAt: now + 1,
      updatedAt: now + 1,
    });

    await assertFails(batch.commit());
  });

  it('denies guest team self-claim without same-batch claim code proof', async () => {
    await seedTeam('team-claimed');
    await seedGuestClaimCode('TEAM-CODE-1', {
      targetType: 'guestTeam',
      targetId: 'guest-team-1',
      teamId: 'team-claimed',
    });
    await seedGuestTeam('guest-team-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();

    await assertFails(
      updateDoc(doc(db, 'guestTeams', 'guest-team-1'), {
        claimStatus: 'claimed',
        linkedTeamId: 'team-claimed',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest team self-claim even with same-batch code mutation', async () => {
    await seedTeam('team-claimed');
    await seedGuestClaimCode('TEAM-CODE-1', {
      targetType: 'guestTeam',
      targetId: 'guest-team-1',
      teamId: 'team-claimed',
    });
    await seedGuestTeam('guest-team-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, 'guestTeams', 'guest-team-1'), {
      claimStatus: 'claimed',
      linkedTeamId: 'team-claimed',
      updatedAt: now + 1,
    });
    batch.update(doc(db, 'claimCodes', 'TEAM-CODE-1'), {
      status: 'claimed',
      claimedByPlayerId: 'claimer-1',
      claimedAt: now + 1,
      updatedAt: now + 1,
    });

    await assertFails(batch.commit());
  });

  it('denies guest membership conversion even for the team manager', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    await seedGuestClaimCode('PLAYER-CODE-1');
    await seedGuestPlayer('guest-player-1');
    await seedMembership('membership-1');

    const db = testEnv.authenticatedContext('creator-1').firestore();

    await assertFails(
      updateDoc(doc(db, 'teamMemberships', 'membership-1'), {
        playerId: 'creator-1',
        guestPlayerId: null,
        claimedFromGuestPlayerId: 'guest-player-1',
      }),
    );

    await assertFails(
      setDoc(
        doc(db, 'teamMemberships', 'forged-claim-membership'),
        teamMembershipData({
          playerId: 'creator-1',
          guestPlayerId: null,
          claimedFromGuestPlayerId: 'guest-player-1',
        }),
      ),
    );
  });

  it('allows a team manager to create and update a valid membership', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    const db = testEnv.authenticatedContext('creator-1').firestore();
    const membershipRef = doc(db, 'teamMemberships', 'membership-valid');

    await assertSucceeds(
      setDoc(membershipRef, teamMembershipData()),
    );
    await assertSucceeds(
      updateDoc(membershipRef, {
        role: 'viceCaptain',
        status: 'starter',
        availability: 'pending',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies malformed membership creates and update bypasses', async () => {
    await seedTeam('team-1', {ownerId: 'creator-1'});
    await seedMembership('membership-valid');
    const db = testEnv.authenticatedContext('creator-1').firestore();
    const missingUpdatedAt = teamMembershipData();
    delete missingUpdatedAt.updatedAt;
    const malformedCreates = [
      missingUpdatedAt,
      teamMembershipData({teamId: 'x'.repeat(129)}),
      teamMembershipData({role: 'admin'}),
      teamMembershipData({status: 'active'}),
      teamMembershipData({availability: 'unknown'}),
      teamMembershipData({joinedAt: 'not-a-time'}),
      teamMembershipData({updatedAt: now - 1}),
      teamMembershipData({extraData: 'malicious'}),
    ];
    for (const [index, malformedMembership] of malformedCreates.entries()) {
      await assertFails(
        setDoc(
          doc(db, 'teamMemberships', `membership-malformed-${index}`),
          malformedMembership,
        ),
      );
    }

    const malformedUpdates = [
      {teamId: 'team-2', updatedAt: now + 1},
      {joinedAt: now - 1, updatedAt: now + 1},
      {invitedBy: 'attacker-1', updatedAt: now + 1},
      {role: 7, updatedAt: now + 1},
      {status: 'active', updatedAt: now + 1},
      {availability: 'unknown', updatedAt: now + 1},
      {updatedAt: now - 1},
      {extraData: 'malicious', updatedAt: now + 1},
    ];
    for (const malformedUpdate of malformedUpdates) {
      await assertFails(
        updateDoc(
          doc(db, 'teamMemberships', 'membership-valid'),
          malformedUpdate,
        ),
      );
    }
  });
});
