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
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-no-project';
const now = 1770000000000;

let testEnv;

async function seedTeam(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'teams', id), {
      name: 'فريق مسجل',
      ownerId: 'owner-1',
      playerIds: [],
      viceCaptainIds: [],
      tournamentIds: [],
      createdAt: now,
      ...data,
    });
  });
}

async function seedTournament(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'tournaments', id), {
      organizerId: 'organizer-1',
      name: 'بطولة الحارة',
      format: 'groupsThenKnockout',
      teamSize: 'fiveVsFive',
      maxTeams: 8,
      createdAt: now,
      ...data,
    });
  });
}

async function seedGuestPlayer(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'guestPlayers', id), {
      displayName: 'ضيف سريع',
      normalizedName: 'ضيف سريع',
      phoneNumber: '01000000000',
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
      ...data,
    });
  });
}

function guestTeamData(data = {}) {
  return {
    name: 'فريق ضيف',
    normalizedName: 'فريق ضيف',
    creatorId: 'creator-1',
    contactName: 'كابتن ضيف',
    contactPhone: '01111111111',
    logoUrl: null,
    tournamentIds: ['tournament-1'],
    captainGuestPlayerId: null,
    claimCode: 'TEAM-CODE-1',
    createdAt: now,
    updatedAt: now,
    claimStatus: 'invited',
    linkedTeamId: null,
    ...data,
  };
}

async function seedGuestTeam(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'guestTeams', id),
      guestTeamData(data),
    );
  });
}

describe('guest PII Firestore rules', () => {
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

  it('denies guest player reads to non-managers', async () => {
    await seedTeam('team-1', {
      ownerId: 'owner-1',
      viceCaptainIds: ['vice-1'],
    });
    await seedGuestPlayer('guest-player-1');

    const db = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(getDoc(doc(db, 'guestPlayers', 'guest-player-1')));
  });

  it('allows guest player reads to team managers', async () => {
    await seedTeam('team-1', {
      ownerId: 'owner-1',
      viceCaptainIds: ['vice-1'],
    });
    await seedGuestPlayer('guest-player-1');

    const db = testEnv.authenticatedContext('vice-1').firestore();
    const snapshot = await assertSucceeds(
      getDoc(doc(db, 'guestPlayers', 'guest-player-1')),
    );

    assert.strictEqual(snapshot.exists(), true);
    assert.strictEqual(snapshot.data().phoneNumber, '01000000000');
  });

  it('allows a linked player to read and query only their guest identities', async () => {
    await seedGuestPlayer('guest-player-linked-1', {
      claimStatus: 'claimed',
      linkedPlayerId: 'player-1',
    });
    await seedGuestPlayer('guest-player-linked-2', {
      claimStatus: 'claimed',
      linkedPlayerId: 'player-2',
    });

    const ownerDb = testEnv.authenticatedContext('player-1').firestore();
    const directSnapshot = await assertSucceeds(
      getDoc(doc(ownerDb, 'guestPlayers', 'guest-player-linked-1')),
    );
    const querySnapshot = await assertSucceeds(
      getDocs(
        query(
          collection(ownerDb, 'guestPlayers'),
          where('linkedPlayerId', '==', 'player-1'),
        ),
      ),
    );

    assert.strictEqual(directSnapshot.exists(), true);
    assert.deepStrictEqual(
      querySnapshot.docs.map((entry) => entry.id),
      ['guest-player-linked-1'],
    );
  });

  it('denies linked guest records and broad queries to other players', async () => {
    await seedGuestPlayer('guest-player-linked-1', {
      claimStatus: 'claimed',
      linkedPlayerId: 'player-1',
    });

    const attackerDb = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(
      getDoc(doc(attackerDb, 'guestPlayers', 'guest-player-linked-1')),
    );
    await assertFails(getDocs(collection(attackerDb, 'guestPlayers')));
    await assertFails(
      getDocs(
        query(
          collection(attackerDb, 'guestPlayers'),
          where('linkedPlayerId', '==', 'player-1'),
        ),
      ),
    );
  });

  it('denies create and update bypasses that spoof linkedPlayerId', async () => {
    await seedTeam('team-1', {ownerId: 'owner-1'});
    await seedGuestPlayer('guest-player-unlinked', {
      createdBy: 'owner-1',
      linkedPlayerId: null,
    });
    const ownerDb = testEnv.authenticatedContext('owner-1').firestore();

    await assertFails(
      setDoc(doc(ownerDb, 'guestPlayers', 'guest-player-spoofed'), {
        displayName: 'ضيف مزيف الربط',
        normalizedName: 'ضيف مزيف الربط',
        phoneNumber: null,
        jerseyNumber: null,
        preferredPosition: null,
        teamId: 'team-1',
        tournamentId: 'tournament-1',
        createdBy: 'owner-1',
        createdAt: now,
        updatedAt: now,
        claimCode: null,
        notes: null,
        claimStatus: 'guest',
        linkedPlayerId: 'victim-1',
      }),
    );
    await assertFails(
      updateDoc(doc(ownerDb, 'guestPlayers', 'guest-player-unlinked'), {
        linkedPlayerId: 'victim-1',
        claimStatus: 'claimed',
        updatedAt: now + 1,
      }),
    );
  });

  it('denies guest team reads to unrelated users', async () => {
    await seedTournament('tournament-1', {organizerId: 'organizer-1'});
    await seedGuestTeam('guest-team-1');

    const db = testEnv.authenticatedContext('attacker-1').firestore();

    await assertFails(getDoc(doc(db, 'guestTeams', 'guest-team-1')));
  });

  it('allows guest team reads to creators and tournament organizers', async () => {
    await seedTournament('tournament-1', {organizerId: 'organizer-1'});
    await seedGuestTeam('guest-team-1', {
      creatorId: 'creator-1',
      tournamentIds: ['tournament-1'],
    });

    const creatorDb = testEnv.authenticatedContext('creator-1').firestore();
    const organizerDb = testEnv.authenticatedContext('organizer-1').firestore();

    const creatorSnapshot = await assertSucceeds(
      getDoc(doc(creatorDb, 'guestTeams', 'guest-team-1')),
    );
    const organizerSnapshot = await assertSucceeds(
      getDoc(doc(organizerDb, 'guestTeams', 'guest-team-1')),
    );

    assert.strictEqual(creatorSnapshot.exists(), true);
    assert.strictEqual(organizerSnapshot.exists(), true);
    assert.strictEqual(creatorSnapshot.data().contactPhone, '01111111111');
  });

  it('allows only trusted guest team logo sources on create and update', async () => {
    const creatorDb = testEnv.authenticatedContext('creator-1').firestore();

    await assertSucceeds(
      setDoc(
        doc(creatorDb, 'guestTeams', 'guest-team-preset'),
        guestTeamData({
          logoUrl: 'preset://v1/team_pennant/diagonal_dash',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(creatorDb, 'guestTeams', 'guest-team-unknown'),
        guestTeamData({
          logoUrl: 'preset://v1/team_pennant/not_in_catalog',
        }),
      ),
    );

    await assertSucceeds(
      updateDoc(doc(creatorDb, 'guestTeams', 'guest-team-preset'), {
        logoUrl: 'https://cdn.el7reef.app/guest-team/logo.png',
      }),
    );
    await assertFails(
      updateDoc(doc(creatorDb, 'guestTeams', 'guest-team-preset'), {
        logoUrl: 'javascript:alert(1)',
      }),
    );
  });

  it('allows tournament organizer to update only guest team roster captain', async () => {
    await seedTournament('tournament-1', {organizerId: 'organizer-1'});
    await seedGuestTeam('guest-team-1', {
      creatorId: 'guest-creator-1',
      tournamentIds: ['tournament-1'],
    });
    await seedGuestPlayer('guest-player-1', {
      teamId: null,
      guestTeamId: 'guest-team-1',
      tournamentId: 'tournament-1',
      claimStatus: 'guest',
      createdBy: 'guest-creator-1',
    });

    const organizerDb = testEnv.authenticatedContext('organizer-1').firestore();
    const attackerDb = testEnv.authenticatedContext('attacker-1').firestore();

    await assertSucceeds(
      updateDoc(doc(organizerDb, 'guestTeams', 'guest-team-1'), {
        captainGuestPlayerId: 'guest-player-1',
        updatedAt: now + 1,
      }),
    );
    await assertFails(
      updateDoc(doc(attackerDb, 'guestTeams', 'guest-team-1'), {
        captainGuestPlayerId: null,
        updatedAt: now + 2,
      }),
    );
    await assertFails(
      updateDoc(doc(organizerDb, 'guestTeams', 'guest-team-1'), {
        contactPhone: '01999999999',
        updatedAt: now + 3,
      }),
    );
  });
});
