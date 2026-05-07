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
    expiresAt: now + 604800000,
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
});
