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

function claimCodeData(overrides = {}) {
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

async function seedClaimCode(code, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'claimCodes', code),
      claimCodeData(data),
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

  it('denies anonymous exact claim code get', async () => {
    await seedClaimCode('PLAYER-CODE-1');

    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(db, 'claimCodes', 'PLAYER-CODE-1')));
  });

  it('allows authenticated exact claim code get as proof of possession', async () => {
    await seedClaimCode('PLAYER-CODE-1');

    const db = testEnv.authenticatedContext('claimer-1').firestore();
    const snapshot = await assertSucceeds(
      getDoc(doc(db, 'claimCodes', 'PLAYER-CODE-1')),
    );

    assert.strictEqual(snapshot.exists(), true);
    assert.strictEqual(snapshot.data().targetId, 'guest-player-1');
  });

  it('denies broad claim code listing for authenticated users', async () => {
    await seedClaimCode('PLAYER-CODE-1');

    const db = testEnv.authenticatedContext('creator-1').firestore();

    await assertFails(getDocs(collection(db, 'claimCodes')));
  });

  it('allows creator-scoped active claim code reuse query', async () => {
    await seedClaimCode('OLDER-CODE', {
      createdBy: 'creator-1',
      createdAt: now - 1000,
      updatedAt: now - 1000,
    });
    await seedClaimCode('NEWER-CODE', {
      createdBy: 'creator-1',
      createdAt: now,
      updatedAt: now,
    });
    await seedClaimCode('OTHER-CREATOR-CODE', {
      createdBy: 'creator-2',
      createdAt: now + 1000,
      updatedAt: now + 1000,
    });

    const db = testEnv.authenticatedContext('creator-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'guestPlayer'),
      where('targetId', '==', 'guest-player-1'),
      where('status', '==', 'active'),
      where('createdBy', '==', 'creator-1'),
      orderBy('createdAt', 'desc'),
      limit(1),
    );

    const snapshot = await assertSucceeds(getDocs(reuseQuery));

    assert.strictEqual(snapshot.docs.length, 1);
    assert.strictEqual(snapshot.docs[0].id, 'NEWER-CODE');
  });

  it('allows creator-scoped reuse query with tournament constraint', async () => {
    await seedClaimCode('TOURNAMENT-CODE', {
      createdBy: 'creator-1',
      tournamentId: 'tournament-1',
    });

    const db = testEnv.authenticatedContext('creator-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'guestPlayer'),
      where('targetId', '==', 'guest-player-1'),
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

  it('denies non-creator query against another creator claim code scope', async () => {
    await seedClaimCode('PLAYER-CODE-1', {createdBy: 'creator-1'});

    const db = testEnv.authenticatedContext('attacker-1').firestore();
    const reuseQuery = query(
      collection(db, 'claimCodes'),
      where('targetType', '==', 'guestPlayer'),
      where('targetId', '==', 'guest-player-1'),
      where('status', '==', 'active'),
      where('createdBy', '==', 'creator-1'),
      orderBy('createdAt', 'desc'),
      limit(1),
    );

    await assertFails(getDocs(reuseQuery));
  });

  it('denies unauthorized claim code creates and updates', async () => {
    await seedClaimCode('PLAYER-CODE-1', {createdBy: 'creator-1'});

    const db = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(
      setDoc(
        doc(db, 'claimCodes', 'ATTACKER-CODE'),
        claimCodeData({createdBy: 'creator-1'}),
      ),
    );
    await assertFails(
      updateDoc(doc(db, 'claimCodes', 'PLAYER-CODE-1'), {
        status: 'expired',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest player self-claim without same-batch claim code proof', async () => {
    await seedClaimCode('PLAYER-CODE-1');
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

  it('allows guest player self-claim with same-batch claim code proof', async () => {
    await seedClaimCode('PLAYER-CODE-1');
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

    await assertSucceeds(batch.commit());
  });

  it('denies guest team self-claim without same-batch claim code proof', async () => {
    await seedTeam('team-claimed');
    await seedClaimCode('TEAM-CODE-1', {
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

  it('allows guest team self-claim with same-batch claim code proof', async () => {
    await seedTeam('team-claimed');
    await seedClaimCode('TEAM-CODE-1', {
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

    await assertSucceeds(batch.commit());
  });
});
