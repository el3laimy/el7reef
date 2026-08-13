const assert = require('assert');
const {createHash} = require('crypto');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

const {deletedAccountId} = require('../account_deletion');

const projectId = 'demo-el7reef';
const region = 'us-central1';
const callableNames = [
  'submitMatchSettlement',
  'approveMatchScore',
  'deleteAccountData',
  'reportUserContent',
  'blockUser',
  'unblockUser',
  'issueGuestClaimCode',
  'inspectGuestClaim',
  'claimGuestPlayer',
  'claimGuestTeam',
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

async function waitForDocumentStatus(reference, expectedStatus) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    const snapshot = await reference.get();
    if (snapshot.exists && snapshot.data().status === expectedStatus) {
      return snapshot;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(
    `Timed out waiting for ${reference.path} to become ${expectedStatus}.`,
  );
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

function claimTokenHash(claimCode) {
  return createHash('sha256').update(claimCode).digest('hex');
}

function assertRawTokenAbsent(claimCode, snapshots) {
  for (const snapshot of snapshots) {
    assert.strictEqual(
      JSON.stringify(snapshot.data()).includes(claimCode),
      false,
      snapshot.ref.path,
    );
  }
}

async function verifyGuestPlayerClaim({db}) {
  const issuer = await createEmulatorUser(
    'guest-player-claim-issuer@example.test',
  );
  const claimant = await createEmulatorUser(
    'guest-player-claimant@example.test',
  );
  const teamId = 'smoke-claim-player-team';
  const guestPlayerId = 'smoke-claim-guest-player';
  const membershipId = 'smoke-claim-guest-membership';
  const issuePayload = {
    targetType: 'guestPlayer',
    targetId: guestPlayerId,
    requestId: 'smoke_claim_player_issue_0001',
  };
  await Promise.all([
    db.collection('players').doc(issuer.uid).set({
      name: 'مُصدر رابط اللاعب الضيف',
      teamIds: [],
    }),
    db.collection('players').doc(claimant.uid).set({
      name: 'صاحب هوية اللاعب',
      teamIds: [],
    }),
    db.collection('teams').doc(teamId).set({
      name: 'فريق استلام اللاعب',
      ownerId: issuer.uid,
      playerIds: [],
      tournamentIds: [],
    }),
    db.collection('guestPlayers').doc(guestPlayerId).set({
      displayName: 'لاعب ضيف للمحاكي',
      createdBy: issuer.uid,
      teamId,
      claimStatus: 'guest',
      claimCode: null,
      linkedPlayerId: null,
    }),
    db.collection('teamMemberships').doc(membershipId).set({
      teamId,
      guestPlayerId,
      playerId: null,
      status: 'starter',
    }),
  ]);

  const issued = await callAuthenticated(
    'issueGuestClaimCode',
    issuePayload,
    issuer.idToken,
  );
  assert.strictEqual(issued.targetType, 'guestPlayer');
  assert.strictEqual(issued.targetId, guestPlayerId);
  assert.strictEqual(issued.status, 'active');
  assert.strictEqual(issued.reused, false);
  assert.strictEqual(typeof issued.code, 'string');

  const repeatedIssue = await callAuthenticated(
    'issueGuestClaimCode',
    issuePayload,
    issuer.idToken,
  );
  assert.strictEqual(repeatedIssue.code, issued.code);
  assert.strictEqual(repeatedIssue.reused, true);

  const tokenHash = claimTokenHash(issued.code);
  const [hashedClaim, rawClaim, invitedGuest] = await Promise.all([
    db.collection('claimCodes').doc(tokenHash).get(),
    db.collection('claimCodes').doc(issued.code).get(),
    db.collection('guestPlayers').doc(guestPlayerId).get(),
  ]);
  assert.strictEqual(hashedClaim.exists, true);
  assert.strictEqual(rawClaim.exists, false);
  assert.strictEqual(invitedGuest.data().claimCode, null);
  assert.strictEqual(invitedGuest.data().activeClaimTokenHash, tokenHash);
  assertRawTokenAbsent(issued.code, [hashedClaim, invitedGuest]);

  const inspected = await callAuthenticated(
    'inspectGuestClaim',
    {claimCode: issued.code},
    claimant.idToken,
  );
  assert.strictEqual(inspected.targetType, 'guestPlayer');
  assert.strictEqual(inspected.targetId, guestPlayerId);
  assert.strictEqual(inspected.subjectName, 'لاعب ضيف للمحاكي');
  assert.strictEqual(inspected.status, 'active');
  assert.strictEqual(inspected.pendingApproval, false);
  assert.strictEqual(JSON.stringify(inspected).includes(issued.code), false);

  const claimPayload = {claimCode: issued.code};
  const concurrentClaims = await Promise.all([
    callAuthenticated('claimGuestPlayer', claimPayload, claimant.idToken),
    callAuthenticated('claimGuestPlayer', claimPayload, claimant.idToken),
  ]);
  assert.deepStrictEqual(
    concurrentClaims.map((claim) => claim.outcome).sort(),
    ['alreadyClaimed', 'claimed'],
  );
  assert.deepStrictEqual(
    concurrentClaims.map((claim) => claim.duplicate).sort(),
    [false, true],
  );
  const retry = await callAuthenticated(
    'claimGuestPlayer',
    claimPayload,
    claimant.idToken,
  );
  assert.strictEqual(retry.outcome, 'alreadyClaimed');
  assert.strictEqual(retry.duplicate, true);

  const [guest, player, membership, team, consumedClaim, claimAudits] =
    await Promise.all([
      db.collection('guestPlayers').doc(guestPlayerId).get(),
      db.collection('players').doc(claimant.uid).get(),
      db.collection('teamMemberships').doc(membershipId).get(),
      db.collection('teams').doc(teamId).get(),
      db.collection('claimCodes').doc(tokenHash).get(),
      db.collection('auditEvents')
        .where('actorId', '==', claimant.uid)
        .get(),
    ]);
  assert.strictEqual(guest.data().claimStatus, 'claimed');
  assert.strictEqual(guest.data().linkedPlayerId, claimant.uid);
  assert.strictEqual(guest.data().claimCode, null);
  assert.strictEqual(guest.data().activeClaimTokenHash, null);
  assert.deepStrictEqual(player.data().teamIds, [teamId]);
  assert.strictEqual(membership.data().playerId, claimant.uid);
  assert.strictEqual(membership.data().guestPlayerId, null);
  assert.strictEqual(
    membership.data().claimedFromGuestPlayerId,
    guestPlayerId,
  );
  assert.deepStrictEqual(team.data().playerIds, [claimant.uid]);
  assert.strictEqual(consumedClaim.data().status, 'claimed');
  assert.strictEqual(consumedClaim.data().claimedByPlayerId, claimant.uid);
  assert.strictEqual(claimAudits.size, 2);
  assert.deepStrictEqual(
    claimAudits.docs.map((audit) => audit.data().action).sort(),
    ['claimCodeConsumed', 'guestPlayerClaimed'],
  );
  assert(
    claimAudits.docs.every(
      (audit) => audit.data().source === 'trustedOperation',
    ),
  );
  assertRawTokenAbsent(issued.code, [
    guest,
    player,
    membership,
    team,
    consumedClaim,
    ...claimAudits.docs,
  ]);
}

async function verifyGuestClaimAssistantAuthority({db}) {
  const organizer = await createEmulatorUser(
    'guest-claim-assistant-organizer@example.test',
  );
  const assistant = await createEmulatorUser(
    'guest-claim-assistant@example.test',
  );
  const tournamentId = 'smoke-claim-assistant-tournament';
  const guestPlayerId = 'smoke-claim-assistant-guest-player';
  const assistantRef = db
    .collection('tournaments')
    .doc(tournamentId)
    .collection('assistants')
    .doc(assistant.uid);
  await Promise.all([
    db.collection('players').doc(organizer.uid).set({
      name: 'منظم صلاحيات الاستلام',
      teamIds: [],
    }),
    db.collection('players').doc(assistant.uid).set({
      name: 'مساعد صلاحيات الاستلام',
      teamIds: [],
    }),
    db.collection('tournaments').doc(tournamentId).set({
      organizerId: organizer.uid,
      assistants: [{userId: assistant.uid, role: 'full'}],
    }),
    assistantRef.set({
      tournamentId,
      userId: assistant.uid,
      status: 'active',
      permissions: {canManageGuestRoster: true},
    }),
    db.collection('guestPlayers').doc(guestPlayerId).set({
      displayName: 'لاعب ضيف بصلاحية مساعد',
      createdBy: organizer.uid,
      tournamentId,
      claimStatus: 'guest',
      claimCode: null,
      linkedPlayerId: null,
    }),
  ]);

  const firstIssue = await callAuthenticated(
    'issueGuestClaimCode',
    {
      targetType: 'guestPlayer',
      targetId: guestPlayerId,
      requestId: 'smoke_claim_assistant_issue_0001',
    },
    assistant.idToken,
  );
  assert.strictEqual(firstIssue.targetId, guestPlayerId);

  await assistantRef.update({status: 'revoked'});
  await callRejected(
    'issueGuestClaimCode',
    {
      targetType: 'guestPlayer',
      targetId: guestPlayerId,
      requestId: 'smoke_claim_assistant_issue_0002',
    },
    assistant.idToken,
    'PERMISSION_DENIED',
  );
}

async function verifyGuestTeamApprovalClaim({db}) {
  const creator = await createEmulatorUser(
    'guest-team-claim-creator@example.test',
  );
  const owner = await createEmulatorUser(
    'guest-team-claim-owner@example.test',
  );
  const teamId = 'smoke-registered-team-claim-target';
  const guestTeamId = 'smoke-guest-team-claim-target';
  const issuePayload = {
    targetType: 'guestTeam',
    targetId: guestTeamId,
    requestId: 'smoke_claim_team_issue_0001',
    requiresApproval: true,
  };
  await Promise.all([
    db.collection('players').doc(creator.uid).set({
      name: 'منشئ الفريق الضيف',
      teamIds: [],
    }),
    db.collection('players').doc(owner.uid).set({
      name: 'قائد الفريق المسجل',
      teamIds: [teamId],
    }),
    db.collection('teams').doc(teamId).set({
      name: 'الفريق المسجل',
      ownerId: owner.uid,
      tournamentIds: ['registered-tournament'],
    }),
    db.collection('guestTeams').doc(guestTeamId).set({
      name: 'الفريق الضيف',
      creatorId: creator.uid,
      tournamentIds: ['guest-tournament'],
      claimStatus: 'guest',
      claimCode: null,
      linkedTeamId: null,
    }),
  ]);

  const issued = await callAuthenticated(
    'issueGuestClaimCode',
    issuePayload,
    creator.idToken,
  );
  assert.strictEqual(issued.targetType, 'guestTeam');
  assert.strictEqual(issued.requiresApproval, true);
  assert.strictEqual(issued.reused, false);
  const tokenHash = claimTokenHash(issued.code);
  const [hashedClaim, rawClaim, invitedGuest] = await Promise.all([
    db.collection('claimCodes').doc(tokenHash).get(),
    db.collection('claimCodes').doc(issued.code).get(),
    db.collection('guestTeams').doc(guestTeamId).get(),
  ]);
  assert.strictEqual(hashedClaim.exists, true);
  assert.strictEqual(rawClaim.exists, false);
  assert.strictEqual(invitedGuest.data().claimCode, null);
  assertRawTokenAbsent(issued.code, [hashedClaim, invitedGuest]);

  const approvalRequest = await callAuthenticated(
    'claimGuestTeam',
    {claimCode: issued.code, teamId},
    owner.idToken,
  );
  assert.strictEqual(approvalRequest.outcome, 'approvalRequired');
  assert.strictEqual(approvalRequest.duplicate, false);
  const [teamAfterRequest, guestAfterRequest, claimAfterRequest, requestAudits] =
    await Promise.all([
      db.collection('teams').doc(teamId).get(),
      db.collection('guestTeams').doc(guestTeamId).get(),
      db.collection('claimCodes').doc(tokenHash).get(),
      db.collection('auditEvents')
        .where('actorId', '==', owner.uid)
        .get(),
    ]);
  assert.deepStrictEqual(
    teamAfterRequest.data().tournamentIds,
    ['registered-tournament'],
  );
  assert.strictEqual(guestAfterRequest.data().claimStatus, 'invited');
  assert.strictEqual(guestAfterRequest.data().linkedTeamId, null);
  assert.strictEqual(claimAfterRequest.data().status, 'active');
  assert.strictEqual(claimAfterRequest.data().teamId, teamId);
  assert.strictEqual(claimAfterRequest.data().claimedByPlayerId, owner.uid);
  assert.strictEqual(requestAudits.empty, true);

  await db.collection('teams').doc(teamId).update({
    ownerId: 'smoke-owner-transfer-target',
  });
  await callRejected(
    'claimGuestTeam',
    {claimCode: issued.code},
    creator.idToken,
    'FAILED_PRECONDITION',
  );
  const [
    teamAfterRejectedApproval,
    guestAfterRejectedApproval,
    claimAfterRejectedApproval,
    rejectedAudits,
  ] = await Promise.all([
    db.collection('teams').doc(teamId).get(),
    db.collection('guestTeams').doc(guestTeamId).get(),
    db.collection('claimCodes').doc(tokenHash).get(),
    db.collection('auditEvents')
      .where('actorId', '==', creator.uid)
      .get(),
  ]);
  assert.deepStrictEqual(
    teamAfterRejectedApproval.data().tournamentIds,
    ['registered-tournament'],
  );
  assert.strictEqual(guestAfterRejectedApproval.data().claimStatus, 'invited');
  assert.strictEqual(guestAfterRejectedApproval.data().linkedTeamId, null);
  assert.strictEqual(claimAfterRejectedApproval.data().status, 'active');
  assert.strictEqual(rejectedAudits.empty, true);

  await db.collection('teams').doc(teamId).update({ownerId: owner.uid});
  const pendingInspection = await callAuthenticated(
    'inspectGuestClaim',
    {claimCode: issued.code},
    creator.idToken,
  );
  assert.strictEqual(pendingInspection.pendingApproval, true);
  assert.strictEqual(pendingInspection.canApprovePendingTeamClaim, true);
  const approved = await callAuthenticated(
    'claimGuestTeam',
    {claimCode: issued.code},
    creator.idToken,
  );
  assert.strictEqual(approved.outcome, 'claimed');
  assert.strictEqual(approved.duplicate, false);

  const [team, guest, consumedClaim, claimAudits] = await Promise.all([
    db.collection('teams').doc(teamId).get(),
    db.collection('guestTeams').doc(guestTeamId).get(),
    db.collection('claimCodes').doc(tokenHash).get(),
    db.collection('auditEvents')
      .where('actorId', '==', creator.uid)
      .get(),
  ]);
  assert.deepStrictEqual(
    team.data().tournamentIds,
    ['registered-tournament', 'guest-tournament'],
  );
  assert.strictEqual(guest.data().claimStatus, 'claimed');
  assert.strictEqual(guest.data().linkedTeamId, teamId);
  assert.strictEqual(guest.data().claimCode, null);
  assert.strictEqual(guest.data().activeClaimTokenHash, null);
  assert.strictEqual(consumedClaim.data().status, 'claimed');
  assert.strictEqual(consumedClaim.data().teamId, teamId);
  assert.strictEqual(consumedClaim.data().claimedByPlayerId, owner.uid);
  assert.strictEqual(claimAudits.size, 2);
  assert.deepStrictEqual(
    claimAudits.docs.map((audit) => audit.data().action).sort(),
    ['claimCodeConsumed', 'guestTeamClaimed'],
  );
  assertRawTokenAbsent(issued.code, [
    team,
    guest,
    consumedClaim,
    ...claimAudits.docs,
  ]);

  const retry = await callAuthenticated(
    'claimGuestTeam',
    {claimCode: issued.code},
    creator.idToken,
  );
  assert.strictEqual(retry.outcome, 'alreadyClaimed');
  assert.strictEqual(retry.duplicate, true);
  const retryAudits = await db.collection('auditEvents')
    .where('actorId', '==', creator.uid)
    .get();
  assert.strictEqual(retryAudits.size, 2);
}

async function verifyGuestClaimCallables({db}) {
  await verifyGuestPlayerClaim({db});
  await verifyGuestClaimAssistantAuthority({db});
  await verifyGuestTeamApprovalClaim({db});
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
  const submittedAudits = await db.collection('auditEvents')
    .where('entityId', '==', validMatchId)
    .get();
  assert.strictEqual(submittedAudits.size, 1);
  assert.strictEqual(submittedAudits.docs[0].data().action, 'matchScoreSubmitted');
  assert.strictEqual(submittedAudits.docs[0].data().actorId, organizer.uid);
  assert.strictEqual(submittedAudits.docs[0].data().source, 'trustedOperation');

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
  const retryAudits = await db.collection('auditEvents')
    .where('entityId', '==', validMatchId)
    .get();
  assert.strictEqual(retryAudits.size, 1);

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
  const concurrentAudits = await db.collection('auditEvents')
    .where('entityId', '==', concurrentMatchId)
    .where('action', '==', 'matchScoreSubmitted')
    .get();
  assert.strictEqual(concurrentAudits.size, 1);

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
  const rejectedAudits = await db.collection('auditEvents')
    .where('entityId', '==', rejectedMatchId)
    .get();
  assert.strictEqual(rejectedAudits.empty, true);

  const approval = await callAuthenticated(
    'approveMatchScore',
    {matchId: validMatchId},
    organizer.idToken,
  );
  assert.strictEqual(approval.status, 'settled');
  assert.strictEqual(approval.alreadySettled, false);
  const approvalRetry = await callAuthenticated(
    'approveMatchScore',
    {matchId: validMatchId},
    organizer.idToken,
  );
  assert.strictEqual(approvalRetry.alreadySettled, true);
  const finalizedAudits = await db.collection('auditEvents')
    .where('entityId', '==', validMatchId)
    .get();
  assert.deepStrictEqual(
    finalizedAudits.docs.map((document) => document.data().action).sort(),
    ['matchScoreApproved', 'matchScoreSubmitted'],
  );
}

async function verifyLegacyRelationshipArrayHardening({db}) {
  const malformedFriendPairs = [
    {blocker: 'string', target: 'missing'},
    {blocker: 'missing', target: 'mixed'},
    {blocker: 'mixed', target: 'string'},
  ];
  for (let index = 0; index < malformedFriendPairs.length; index += 1) {
    const states = malformedFriendPairs[index];
    const blocker = await createEmulatorUser(
      `legacy-friend-blocker-${index}@example.test`,
    );
    const targetId = `legacy-friend-target-${index}`;
    const blockerRef = db.collection('players').doc(blocker.uid);
    const targetRef = db.collection('players').doc(targetId);
    const blockerRetainedId = `legacy-blocker-friend-${index}`;
    const targetRetainedId = `legacy-target-friend-${index}`;
    const blockerDocument = {blockedIds: []};
    const targetDocument = {blockedIds: []};
    applyMalformedListState(blockerDocument, 'friendIds', states.blocker, {
      peerId: targetId,
      retainedId: blockerRetainedId,
    });
    applyMalformedListState(targetDocument, 'friendIds', states.target, {
      peerId: blocker.uid,
      retainedId: targetRetainedId,
    });
    await Promise.all([
      blockerRef.set(blockerDocument),
      targetRef.set(targetDocument),
    ]);

    const block = await callAuthenticated(
      'blockUser',
      {blockedId: targetId},
      blocker.idToken,
    );
    assert.strictEqual(block.duplicate, false);
    let [blockerSnapshot, targetSnapshot] = await Promise.all([
      blockerRef.get(),
      targetRef.get(),
    ]);
    assert.deepStrictEqual(
      blockerSnapshot.data().friendIds,
      expectedNormalizedFriendIds(states.blocker, blockerRetainedId),
    );
    assert.deepStrictEqual(
      targetSnapshot.data().friendIds,
      expectedNormalizedFriendIds(states.target, targetRetainedId),
    );
    assert.deepStrictEqual(blockerSnapshot.data().blockedIds, [targetId]);

    const blockerBeforeUnblock = {blockedIds: [targetId]};
    const targetBeforeUnblock = {blockedIds: []};
    applyMalformedListState(
      blockerBeforeUnblock,
      'friendIds',
      states.blocker,
      {peerId: targetId, retainedId: blockerRetainedId},
    );
    applyMalformedListState(
      targetBeforeUnblock,
      'friendIds',
      states.target,
      {peerId: blocker.uid, retainedId: targetRetainedId},
    );
    await Promise.all([
      blockerRef.set(blockerBeforeUnblock),
      targetRef.set(targetBeforeUnblock),
    ]);

    const unblock = await callAuthenticated(
      'unblockUser',
      {blockedId: targetId},
      blocker.idToken,
    );
    assert.strictEqual(unblock.duplicate, false);
    [blockerSnapshot, targetSnapshot] = await Promise.all([
      blockerRef.get(),
      targetRef.get(),
    ]);
    assert.deepStrictEqual(
      blockerSnapshot.data().friendIds,
      expectedNormalizedFriendIds(states.blocker, blockerRetainedId),
    );
    assert.deepStrictEqual(
      targetSnapshot.data().friendIds,
      expectedNormalizedFriendIds(states.target, targetRetainedId),
    );
    assert.deepStrictEqual(blockerSnapshot.data().blockedIds, []);
  }

  const reversedBlocker = await createEmulatorUser(
    'legacy-reversed-friendship@example.test',
  );
  const reversedTargetId = 'legacy-reversed-friendship-target';
  const reversedPair = [reversedBlocker.uid, reversedTargetId].sort();
  const reversedFriendshipRef = db
    .collection('friendships')
    .doc(reversedPair.join('_'));
  await Promise.all([
    db.collection('players').doc(reversedBlocker.uid).set({
      friendIds: [],
      blockedIds: [reversedTargetId],
    }),
    db.collection('players').doc(reversedTargetId).set({
      friendIds: [],
      blockedIds: [],
    }),
    reversedFriendshipRef.set({
      userId1: reversedPair[1],
      userId2: reversedPair[0],
      participants: [...reversedPair].reverse(),
      status: 'blocked',
      lastActionBy: reversedBlocker.uid,
      createdAt: 'emulator-existing-time',
      updatedAt: 'emulator-existing-time',
    }),
  ]);
  const reversedBlock = await callAuthenticated(
    'blockUser',
    {blockedId: reversedTargetId},
    reversedBlocker.idToken,
  );
  assert.strictEqual(reversedBlock.duplicate, true);
  const [canonicalFriendshipSnapshot, reversedQuota, reversedAudits] =
    await Promise.all([
      reversedFriendshipRef.get(),
      db.collection('safetyActionQuotas').doc(reversedBlocker.uid).get(),
      db.collection('auditEvents')
        .where('actorId', '==', reversedBlocker.uid)
        .get(),
    ]);
  const canonicalFriendship = canonicalFriendshipSnapshot.data();
  assert.strictEqual(canonicalFriendship.userId1, reversedPair[0]);
  assert.strictEqual(canonicalFriendship.userId2, reversedPair[1]);
  assert.deepStrictEqual(canonicalFriendship.participants, reversedPair);
  assert.strictEqual(canonicalFriendship.status, 'blocked');
  assert.strictEqual(reversedQuota.exists, false);
  assert.strictEqual(reversedAudits.empty, true);

  const transitionBlocker = await createEmulatorUser(
    'legacy-blocked-transition@example.test',
  );
  const transitionTargetId = 'legacy-blocked-transition-target';
  const transitionPair = [transitionBlocker.uid, transitionTargetId].sort();
  const transitionBlockerRef = db
    .collection('players')
    .doc(transitionBlocker.uid);
  const transitionTargetRef = db
    .collection('players')
    .doc(transitionTargetId);
  const transitionFriendshipRef = db
    .collection('friendships')
    .doc(transitionPair.join('_'));
  await Promise.all([
    transitionBlockerRef.set({
      friendIds: [transitionTargetId],
      blockedIds: ['retained-block', 7, 'retained-block'],
    }),
    transitionTargetRef.set({
      friendIds: [transitionBlocker.uid],
      blockedIds: transitionBlocker.uid,
    }),
    transitionFriendshipRef.set({
      userId1: transitionPair[0],
      userId2: transitionPair[1],
      participants: transitionPair,
      status: 'accepted',
      lastActionBy: transitionTargetId,
      createdAt: 'emulator-existing-time',
      updatedAt: 'emulator-existing-time',
    }),
  ]);
  const normalizedBlock = await callAuthenticated(
    'blockUser',
    {blockedId: transitionTargetId},
    transitionBlocker.idToken,
  );
  assert.strictEqual(normalizedBlock.duplicate, false);
  let [transitionBlockerSnapshot, transitionTargetSnapshot] =
    await Promise.all([
      transitionBlockerRef.get(),
      transitionTargetRef.get(),
    ]);
  assert.deepStrictEqual(
    transitionBlockerSnapshot.data().blockedIds,
    ['retained-block', transitionTargetId],
  );
  assert.deepStrictEqual(
    transitionTargetSnapshot.data().blockedIds,
    [transitionBlocker.uid],
  );

  await Promise.all([
    transitionBlockerRef.update({
      blockedIds: [transitionTargetId, 7, 'retained-block', 'retained-block'],
    }),
    transitionTargetRef.update({blockedIds: transitionBlocker.uid}),
  ]);
  const normalizedUnblock = await callAuthenticated(
    'unblockUser',
    {blockedId: transitionTargetId},
    transitionBlocker.idToken,
  );
  assert.strictEqual(normalizedUnblock.duplicate, false);
  [transitionBlockerSnapshot, transitionTargetSnapshot] = await Promise.all([
    transitionBlockerRef.get(),
    transitionTargetRef.get(),
  ]);
  assert.deepStrictEqual(
    transitionBlockerSnapshot.data().blockedIds,
    ['retained-block'],
  );
  assert.deepStrictEqual(
    transitionTargetSnapshot.data().blockedIds,
    [transitionBlocker.uid],
  );
  const transitionFriendship = (await transitionFriendshipRef.get()).data();
  assert.strictEqual(transitionFriendship.status, 'blocked');
  assert.strictEqual(transitionFriendship.lastActionBy, transitionTargetId);
  const transitionQuota = await db
    .collection('safetyActionQuotas')
    .doc(transitionBlocker.uid)
    .get();
  assert.strictEqual(transitionQuota.data().safetyRelationship.count, 2);
  const transitionAudits = await db.collection('auditEvents')
    .where('actorId', '==', transitionBlocker.uid)
    .get();
  assert.strictEqual(transitionAudits.size, 2);

  await verifyDuplicateBlockedIdRepair({db});
}

async function verifyDuplicateBlockedIdRepair({db}) {
  const blocker = await createEmulatorUser(
    'legacy-blocked-duplicate@example.test',
  );
  const targetId = 'legacy-blocked-duplicate-target';
  const pair = [blocker.uid, targetId].sort();
  const blockerRef = db.collection('players').doc(blocker.uid);
  const targetRef = db.collection('players').doc(targetId);
  const friendshipRef = db.collection('friendships').doc(pair.join('_'));
  await Promise.all([
    blockerRef.set({friendIds: [targetId], blockedIds: targetId}),
    targetRef.set({friendIds: [blocker.uid]}),
    friendshipRef.set({
      userId1: pair[0],
      userId2: pair[1],
      participants: pair,
      status: 'accepted',
      lastActionBy: targetId,
      createdAt: 'emulator-existing-time',
      updatedAt: 'emulator-existing-time',
    }),
  ]);

  const block = await callAuthenticated(
    'blockUser',
    {blockedId: targetId},
    blocker.idToken,
  );
  assert.strictEqual(block.duplicate, true);
  const [blockerSnapshot, targetSnapshot, friendship, quota, audits] =
    await Promise.all([
      blockerRef.get(),
      targetRef.get(),
      friendshipRef.get(),
      db.collection('safetyActionQuotas').doc(blocker.uid).get(),
      db.collection('auditEvents').where('actorId', '==', blocker.uid).get(),
    ]);
  assert.deepStrictEqual(blockerSnapshot.data().blockedIds, [targetId]);
  assert.deepStrictEqual(targetSnapshot.data().blockedIds, []);
  assert.deepStrictEqual(blockerSnapshot.data().friendIds, []);
  assert.deepStrictEqual(targetSnapshot.data().friendIds, []);
  assert.strictEqual(friendship.data().status, 'blocked');
  assert.strictEqual(quota.exists, false);
  assert.strictEqual(audits.empty, true);

  await blockerRef.update({blockedIds: [7]});
  const unblock = await callAuthenticated(
    'unblockUser',
    {blockedId: targetId},
    blocker.idToken,
  );
  assert.strictEqual(unblock.duplicate, true);
  const [repairedBlocker, removedFriendship, repairedQuota, repairedAudits] =
    await Promise.all([
      blockerRef.get(),
      friendshipRef.get(),
      db.collection('safetyActionQuotas').doc(blocker.uid).get(),
      db.collection('auditEvents').where('actorId', '==', blocker.uid).get(),
    ]);
  assert.deepStrictEqual(repairedBlocker.data().blockedIds, []);
  assert.strictEqual(removedFriendship.exists, false);
  assert.strictEqual(repairedQuota.exists, false);
  assert.strictEqual(repairedAudits.empty, true);
}

function applyMalformedListState(
  document,
  fieldName,
  state,
  {peerId, retainedId},
) {
  if (state === 'missing') {
    delete document[fieldName];
    return;
  }
  if (state === 'string') {
    document[fieldName] = peerId;
    return;
  }
  document[fieldName] = retainedId == null ?
    [peerId, 7, null] :
    [peerId, 7, null, retainedId, retainedId, ''];
}

function expectedNormalizedFriendIds(state, retainedId) {
  return state === 'mixed' ? [retainedId] : [];
}

async function verifyAuthenticatedWrites() {
  const app = initializeApp(
    {projectId, storageBucket: `${projectId}.appspot.com`},
    'functions-emulator-smoke',
  );
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();
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

  await verifyGuestClaimCallables({db});

  await callRejected(
    'reportUserContent',
    {
      targetKind: 'registeredPlayer',
      targetId: reporter.uid,
      reason: 'spam',
    },
    reporter.idToken,
    'INVALID_ARGUMENT',
  );
  await callRejected(
    'blockUser',
    {blockedId: reporter.uid},
    reporter.idToken,
    'INVALID_ARGUMENT',
  );
  await callRejected(
    'unblockUser',
    {blockedId: reporter.uid},
    reporter.idToken,
    'INVALID_ARGUMENT',
  );

  const selfRelationshipId = [reporter.uid, reporter.uid].sort().join('_');
  const [
    rejectedSelfReports,
    rejectedSelfAudits,
    rejectedSelfQuota,
    rejectedSelfFriendship,
  ] = await Promise.all([
    db.collection('userReports')
      .where('reporterId', '==', reporter.uid)
      .get(),
    db.collection('auditEvents')
      .where('actorId', '==', reporter.uid)
      .get(),
    db.collection('safetyActionQuotas').doc(reporter.uid).get(),
    db.collection('friendships').doc(selfRelationshipId).get(),
  ]);
  assert.strictEqual(rejectedSelfReports.empty, true);
  assert.strictEqual(rejectedSelfAudits.empty, true);
  assert.strictEqual(rejectedSelfQuota.exists, false);
  assert.strictEqual(rejectedSelfFriendship.exists, false);

  await verifySettlementRosterGuards({
    db,
    organizer: reporter,
    rosterPlayer: target,
  });

  const reportPayload = {
    targetKind: 'registeredPlayer',
    targetId: target.uid,
    reason: 'spam',
    details: 'emulator smoke private evidence',
    reporterId: target.uid,
    actorId: target.uid,
  };
  const reports = await Promise.all([
    callAuthenticated('reportUserContent', reportPayload, reporter.idToken),
    callAuthenticated('reportUserContent', reportPayload, reporter.idToken),
  ]);
  assert.deepStrictEqual(
    reports.map((report) => report.duplicate).sort(),
    [false, true],
  );
  const report = reports[0];
  const reportAudits = await db.collection('auditEvents')
    .where('action', '==', 'profileReported')
    .get();
  assert.strictEqual(reportAudits.size, 1);
  assert.strictEqual(reportAudits.docs[0].data().actorId, reporter.uid);
  assert.strictEqual(reportAudits.docs[0].data().entityId, report.reportId);
  const reportAuditJson = JSON.stringify(reportAudits.docs[0].data());
  assert.strictEqual(reportAuditJson.includes('private evidence'), false);
  assert.strictEqual(reportAuditJson.includes(target.uid), false);
  assert.strictEqual(reportAuditJson.includes('spam'), false);

  const blocks = await Promise.all([
    callAuthenticated(
      'blockUser',
      {
        blockedId: target.uid,
        blockerId: target.uid,
        actorId: target.uid,
      },
      reporter.idToken,
    ),
    callAuthenticated('blockUser', {blockedId: target.uid}, reporter.idToken),
  ]);
  assert.deepStrictEqual(
    blocks.map((block) => block.duplicate).sort(),
    [false, true],
  );
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

  const opposite = await callAuthenticated(
    'blockUser',
    {blockedId: reporter.uid},
    target.idToken,
  );
  const repeated = await callAuthenticated(
    'blockUser',
    {blockedId: target.uid},
    reporter.idToken,
  );
  assert.strictEqual(opposite.duplicate, false);
  assert.strictEqual(repeated.duplicate, true);
  const blockAudits = await db.collection('auditEvents')
    .where('action', '==', 'playerBlocked')
    .get();
  assert.strictEqual(blockAudits.size, 2);
  const reporterBlockAudit = blockAudits.docs.find(
    (audit) => audit.data().actorId === reporter.uid,
  );
  assert(reporterBlockAudit);
  const reporterBlockAuditJson = JSON.stringify(reporterBlockAudit.data());
  assert.strictEqual(reporterBlockAuditJson.includes('blockedIds'), false);
  assert.strictEqual(reporterBlockAuditJson.includes(target.uid), false);

  const unblocks = await Promise.all([
    callAuthenticated(
      'unblockUser',
      {
        blockedId: target.uid,
        blockerId: target.uid,
        actorId: target.uid,
      },
      reporter.idToken,
    ),
    callAuthenticated('unblockUser', {blockedId: target.uid}, reporter.idToken),
  ]);
  assert.deepStrictEqual(
    unblocks.map((unblock) => unblock.duplicate).sort(),
    [false, true],
  );
  const reporterAfterUnblock = await db
    .collection('players')
    .doc(reporter.uid)
    .get();
  const targetAfterUnblock = await db.collection('players').doc(target.uid).get();
  const friendshipAfterUnblock = await db
    .collection('friendships')
    .doc(friendshipId)
    .get();
  assert.deepStrictEqual(reporterAfterUnblock.data().blockedIds, []);
  assert.deepStrictEqual(targetAfterUnblock.data().blockedIds, [reporter.uid]);
  assert.strictEqual(friendshipAfterUnblock.data().status, 'blocked');
  assert.strictEqual(friendshipAfterUnblock.data().lastActionBy, target.uid);

  await callAuthenticated(
    'unblockUser',
    {blockedId: reporter.uid},
    target.idToken,
  );
  const finalFriendship = await db
    .collection('friendships')
    .doc(friendshipId)
    .get();
  assert.strictEqual(finalFriendship.exists, false);
  const unblockAudits = await db.collection('auditEvents')
    .where('action', '==', 'playerUnblocked')
    .get();
  assert.strictEqual(unblockAudits.size, 2);
  const safetyQuota = await db
    .collection('safetyActionQuotas')
    .doc(reporter.uid)
    .get();
  assert.strictEqual(safetyQuota.exists, true);
  assert.strictEqual(safetyQuota.data().profileReport.count, 1);
  assert.strictEqual(safetyQuota.data().safetyRelationship.count, 2);

  const deletionRequestId = deletedAccountId(reporter.uid);
  const deletionRequestRef = db
    .collection('accountDeletionRequests')
    .doc(deletionRequestId);
  await deletionRequestRef.set({
    status: 'failed',
    stage: 'legacy',
    anonymizedId: deletionRequestId,
    updatedAt: Date.now(),
  });
  await callRejected(
    'reportUserContent',
    reportPayload,
    reporter.idToken,
    'PERMISSION_DENIED',
  );
  await callRejected(
    'blockUser',
    {blockedId: target.uid},
    reporter.idToken,
    'PERMISSION_DENIED',
  );
  await callRejected(
    'unblockUser',
    {blockedId: target.uid},
    reporter.idToken,
    'PERMISSION_DENIED',
  );

  const profilePath = `profiles/${reporter.uid}/photo_full.jpg`;
  await bucket.file(profilePath).save(Buffer.from('emulator profile'));
  const deletion = await callAuthenticated(
    'deleteAccountData',
    {},
    reporter.idToken,
  );
  assert.strictEqual(deletion.accepted, true);
  assert.strictEqual(deletion.deleted, false);
  assert.strictEqual(deletion.requestId, deletionRequestId);
  const deletionRequest = await waitForDocumentStatus(
    deletionRequestRef,
    'completed',
  );
  const deletedPlayer = await db.collection('players').doc(reporter.uid).get();
  assert.strictEqual(deletedPlayer.exists, false);
  const deletedSafetyQuota = await db
    .collection('safetyActionQuotas')
    .doc(reporter.uid)
    .get();
  assert.strictEqual(deletedSafetyQuota.exists, false);
  const deletedFriendship = await db
    .collection('friendships')
    .doc(friendshipId)
    .get();
  assert.strictEqual(deletedFriendship.exists, false);
  const reporterSafetyAudits = [
    reportAudits.docs[0],
    reporterBlockAudit,
    unblockAudits.docs.find((audit) => audit.data().actorId === reporter.uid),
  ];
  assert(reporterSafetyAudits.every(Boolean));
  const anonymizedAudits = await Promise.all(
    reporterSafetyAudits.map((audit) => audit.ref.get()),
  );
  for (const anonymizedAudit of anonymizedAudits) {
    assert.strictEqual(anonymizedAudit.data().actorId, deletion.requestId);
  }
  const anonymizedReport = await db
    .collection('userReports')
    .doc(report.reportId)
    .get();
  assert.strictEqual(
    anonymizedReport.data().reporterId,
    deletion.requestId,
  );
  assert.strictEqual(deletionRequest.data().status, 'completed');
  assert.strictEqual(deletionRequest.data().userId, undefined);
  const deletionAudits = await db
    .collection('auditEvents')
    .where('entityType', '==', 'accountDeletion')
    .get();
  assert(deletionAudits.size >= 3);
  assert(
    deletionAudits.docs.every(
      (audit) => audit.data().actorId === deletion.requestId,
    ),
  );
  assert.strictEqual(
    JSON.stringify(deletionAudits.docs.map((audit) => audit.data()))
      .includes(reporter.uid),
    false,
  );
  const [profileFiles] = await bucket.getFiles({prefix: profilePath});
  assert.strictEqual(profileFiles.length, 0);
  await assert.rejects(
    getAuth(app).getUser(reporter.uid),
    (error) => error.code === 'auth/user-not-found',
  );

  await verifyLegacyRelationshipArrayHardening({db});

  await app.delete();
}

async function main() {
  for (const callableName of callableNames) {
    await verifyUnauthenticatedCallable(callableName);
  }
  await verifyAuthenticatedWrites();
  console.log(
    `Functions emulator smoke: all ${callableNames.length} auth gates + ` +
      'trusted guest claims + settlement roster guards + ' +
      'legacy safety hardening + ' +
      'safety/audit/delete writes passed',
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
