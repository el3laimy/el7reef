const assert = require('assert');
const admin = require('firebase-admin');

const projectId = 'demo-el7reef';
const region = 'us-central1';
const callableNames = [
  'submitMatchSettlement',
  'approveMatchScore',
  'recordAuditEvent',
  'deleteAccountData',
  'reportUserContent',
  'blockUser',
];

async function verifyUnauthenticatedCallable(callableName) {
  const response = await callCallable(callableName, {});
  const body = await response.json();

  assert.strictEqual(response.status, 401, callableName);
  assert.strictEqual(body.error.status, 'UNAUTHENTICATED', callableName);
  assert.strictEqual(
    body.error.message,
    'Authentication is required.',
    callableName,
  );
}

async function callCallable(callableName, data, idToken) {
  const headers = {'content-type': 'application/json'};
  if (idToken) headers.authorization = `Bearer ${idToken}`;
  return fetch(
    `http://127.0.0.1:5001/${projectId}/${region}/${callableName}`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({data}),
    },
  );
}

async function callAuthenticated(callableName, data, idToken) {
  const response = await callCallable(callableName, data, idToken);
  const body = await response.json();
  assert.strictEqual(response.status, 200, JSON.stringify(body));
  return body.result;
}

async function callRejected(callableName, data, idToken, expectedStatus) {
  const response = await callCallable(callableName, data, idToken);
  const body = await response.json();
  assert.notStrictEqual(response.status, 200, JSON.stringify(body));
  assert.strictEqual(body.error.status, expectedStatus, JSON.stringify(body));
  return body.error;
}

async function createEmulatorUser(email) {
  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
      '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({
        email,
        password: 'emulator-only-password',
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  assert.strictEqual(response.status, 200, JSON.stringify(body));
  return {uid: body.localId, idToken: body.idToken};
}

async function verifySettlementRosterGuards({db, organizer, rosterPlayer}) {
  const teamAId = 'smoke-team-a';
  const teamBId = 'smoke-team-b';
  const guestPlayerId = 'smoke-guest-a';
  const validMatchId = 'smoke-valid-settlement';
  const concurrentMatchId = 'smoke-concurrent-settlement';
  const rejectedMatchId = 'smoke-rejected-settlement';
  const baseMatch = {
    organizerId: organizer.uid,
    teamAId,
    teamBId,
    teamAPlayerIds: [],
    teamBPlayerIds: [],
    status: 'live',
    isFrozen: false,
    createdAt: Date.now(),
  };
  await Promise.all([
    db.collection('matches').doc(validMatchId).set(baseMatch),
    db.collection('matches').doc(concurrentMatchId).set(baseMatch),
    db.collection('matches').doc(rejectedMatchId).set(baseMatch),
    db.collection('teamMemberships').doc('smoke-registered-a').set({
      teamId: teamAId,
      playerId: rosterPlayer.uid,
      status: 'starter',
    }),
    db.collection('teamMemberships').doc('smoke-guest-membership-a').set({
      teamId: teamAId,
      guestPlayerId,
      status: 'bench',
    }),
    db.collection('guestPlayers').doc(guestPlayerId).set({
      teamId: teamAId,
      displayName: 'ضيف المحاكي',
    }),
  ]);

  const settlementPayload = (matchId) => ({
    matchId,
    scoreA: 1,
    scoreB: 0,
    mvpPlayerId: guestPlayerId,
    detailedStats: [{
      playerId: rosterPlayer.uid,
      matchId,
      teamId: teamAId,
      played: true,
      goals: 0,
    }],
    goals: [{
      sideKey: 'A',
      actor: {
        kind: 'guestPlayer',
        id: guestPlayerId,
        displayName: 'ضيف المحاكي',
      },
      goals: 1,
    }],
    mvp: {
      sideKey: 'A',
      actor: {
        kind: 'guestPlayer',
        id: guestPlayerId,
        displayName: 'ضيف المحاكي',
      },
    },
  });
  const validPayload = settlementPayload(validMatchId);
  const validResult = await callAuthenticated(
    'submitMatchSettlement',
    validPayload,
    organizer.idToken,
  );
  assert.strictEqual(validResult.status, 'completed');
  assert.strictEqual(validResult.alreadySettled, false);

  const settledMatch = await db.collection('matches').doc(validMatchId).get();
  assert.strictEqual(settledMatch.data().mvpPlayerId, guestPlayerId);
  assert.strictEqual(
    settledMatch.data().settlementSubmissionFingerprint.length,
    64,
  );
  const activeEvents = await db.collection('matchEvents')
    .where('matchId', '==', validMatchId)
    .where('status', '==', 'active')
    .get();
  assert.strictEqual(activeEvents.size, 2);
  const playerStats = await db.collection('matches')
    .doc(validMatchId)
    .collection('player_stats')
    .doc(rosterPlayer.uid)
    .get();
  assert.strictEqual(playerStats.exists, true);
  assert.strictEqual(playerStats.data().teamId, teamAId);

  await db.collection('fanVotingSessions').doc(validMatchId).update({
    totalVotes: 1,
    playerVotes: {[rosterPlayer.uid]: 1},
  });
  const retryResult = await callAuthenticated(
    'submitMatchSettlement',
    validPayload,
    organizer.idToken,
  );
  assert.strictEqual(retryResult.alreadySettled, true);
  const preservedVoting = await db
    .collection('fanVotingSessions')
    .doc(validMatchId)
    .get();
  assert.strictEqual(preservedVoting.data().totalVotes, 1);

  await callRejected(
    'submitMatchSettlement',
    {...validPayload, scoreA: 2},
    organizer.idToken,
    'FAILED_PRECONDITION',
  );
  const unchangedMatch = await db.collection('matches').doc(validMatchId).get();
  assert.strictEqual(unchangedMatch.data().scoreTeamA, 1);

  const concurrentPayload = settlementPayload(concurrentMatchId);
  const concurrentResults = await Promise.all([
    callAuthenticated(
      'submitMatchSettlement',
      concurrentPayload,
      organizer.idToken,
    ),
    callAuthenticated(
      'submitMatchSettlement',
      concurrentPayload,
      organizer.idToken,
    ),
  ]);
  assert.deepStrictEqual(
    concurrentResults.map((result) => result.alreadySettled).sort(),
    [false, true],
  );
  const concurrentEvents = await db.collection('matchEvents')
    .where('matchId', '==', concurrentMatchId)
    .where('status', '==', 'active')
    .get();
  assert.strictEqual(concurrentEvents.size, 2);

  await callRejected(
    'submitMatchSettlement',
    {
      matchId: rejectedMatchId,
      scoreA: 1,
      scoreB: 0,
      goals: [{
        sideKey: 'A',
        actor: {
          kind: 'player',
          id: 'outside-roster',
          displayName: 'Outside Roster',
        },
        goals: 1,
      }],
    },
    organizer.idToken,
    'INVALID_ARGUMENT',
  );
  const rejectedMatch = await db
    .collection('matches')
    .doc(rejectedMatchId)
    .get();
  assert.strictEqual(rejectedMatch.data().status, 'live');
  assert.strictEqual(rejectedMatch.data().scoreTeamA, undefined);
  const rejectedEvents = await db.collection('matchEvents')
    .where('matchId', '==', rejectedMatchId)
    .get();
  assert.strictEqual(rejectedEvents.empty, true);
}

async function verifyAuthenticatedWrites() {
  const app = admin.initializeApp(
    {projectId, storageBucket: `${projectId}.appspot.com`},
    'functions-emulator-smoke',
  );
  const db = app.firestore();
  const bucket = app.storage().bucket();
  const reporter = await createEmulatorUser('reporter@example.test');
  const target = await createEmulatorUser('target@example.test');
  await Promise.all([
    db.collection('players').doc(reporter.uid).set({
      friendIds: [target.uid],
      blockedIds: [],
    }),
    db.collection('players').doc(target.uid).set({
      friendIds: [reporter.uid],
      blockedIds: [],
    }),
  ]);

  await verifySettlementRosterGuards({
    db,
    organizer: reporter,
    rosterPlayer: target,
  });

  const report = await callAuthenticated(
    'reportUserContent',
    {
      targetKind: 'registeredPlayer',
      targetId: target.uid,
      reason: 'spam',
      details: 'emulator smoke',
    },
    reporter.idToken,
  );
  assert.strictEqual(report.accepted, true);
  assert.strictEqual(report.duplicate, false);

  const duplicateReport = await callAuthenticated(
    'reportUserContent',
    {
      targetKind: 'registeredPlayer',
      targetId: target.uid,
      reason: 'spam',
    },
    reporter.idToken,
  );
  assert.strictEqual(duplicateReport.duplicate, true);

  const audit = await callAuthenticated(
    'recordAuditEvent',
    {
      entityType: 'player',
      entityId: target.uid,
      action: 'memberRemoved',
      actorId: 'spoofed-actor',
      createdAt: 1,
      metadata: {source: 'emulator_smoke'},
    },
    reporter.idToken,
  );
  const auditSnapshot = await db.collection('auditEvents').doc(audit.id).get();
  assert.strictEqual(auditSnapshot.data().actorId, reporter.uid);

  const block = await callAuthenticated(
    'blockUser',
    {blockedId: target.uid},
    reporter.idToken,
  );
  assert.strictEqual(block.blocked, true);
  const blockerSnapshot = await db
    .collection('players')
    .doc(reporter.uid)
    .get();
  assert.deepStrictEqual(blockerSnapshot.data().friendIds, []);
  assert.deepStrictEqual(blockerSnapshot.data().blockedIds, [target.uid]);
  const friendshipId = [reporter.uid, target.uid].sort().join('_');
  const friendshipSnapshot = await db
    .collection('friendships')
    .doc(friendshipId)
    .get();
  assert.strictEqual(friendshipSnapshot.data().status, 'blocked');
  assert.strictEqual(friendshipSnapshot.data().lastActionBy, reporter.uid);

  const profilePath = `profiles/${reporter.uid}/photo_full.jpg`;
  await bucket.file(profilePath).save(Buffer.from('emulator profile'));
  const deletion = await callAuthenticated(
    'deleteAccountData',
    {},
    reporter.idToken,
  );
  assert.strictEqual(deletion.deleted, true);
  const deletedPlayer = await db.collection('players').doc(reporter.uid).get();
  assert.strictEqual(deletedPlayer.exists, false);
  const deletedFriendship = await db
    .collection('friendships')
    .doc(friendshipId)
    .get();
  assert.strictEqual(deletedFriendship.exists, false);
  const anonymizedAudit = await db.collection('auditEvents').doc(audit.id).get();
  assert.strictEqual(
    anonymizedAudit.data().actorId,
    deletion.requestId,
  );
  const anonymizedReport = await db
    .collection('userReports')
    .doc(report.reportId)
    .get();
  assert.strictEqual(
    anonymizedReport.data().reporterId,
    deletion.requestId,
  );
  const deletionRequest = await db
    .collection('accountDeletionRequests')
    .doc(deletion.requestId)
    .get();
  assert.strictEqual(deletionRequest.data().status, 'completed');
  const [profileFiles] = await bucket.getFiles({prefix: profilePath});
  assert.strictEqual(profileFiles.length, 0);
  await assert.rejects(
    app.auth().getUser(reporter.uid),
    (error) => error.code === 'auth/user-not-found',
  );

  await app.delete();
}

async function main() {
  for (const callableName of callableNames) {
    await verifyUnauthenticatedCallable(callableName);
  }
  await verifyAuthenticatedWrites();
  console.log(
    `Functions emulator smoke: ${callableNames.length}/6 auth gates + ` +
      'settlement roster guards + report/block/audit/delete writes passed',
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
