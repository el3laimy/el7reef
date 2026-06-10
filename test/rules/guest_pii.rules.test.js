const assert = require('assert');
const fs = require('fs');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {doc, getDoc, setDoc} = require('firebase/firestore');

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

async function seedGuestTeam(id, data = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'guestTeams', id), {
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
    });
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
});
