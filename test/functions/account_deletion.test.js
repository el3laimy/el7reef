const assert = require('assert');

const {
  accountDeletionEventShouldRun,
  accountDeletionPlan,
  DELETION_STAGE_ORDER,
  deletedAccountId,
  processAccountDeletionRequestCore,
  requestAccountDeletionCore,
  scrubNestedIdentity,
} = require('../../functions/account_deletion');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = 1770000000000;

describe('accountDeletionPlan', () => {
  it('removes private identity data and anonymizes historical ownership', () => {
    const plan = accountDeletionPlan('user-1');

    assert.strictEqual(plan.anonymizedId, deletedAccountId('user-1'));
    assert.notStrictEqual(plan.anonymizedId, 'user-1');
    assert.deepStrictEqual(plan.recursiveDocuments[0], ['players', 'user-1']);
    assert.ok(
      plan.recursiveDocuments.some(
        ([collection, documentId]) =>
          collection === 'safetyActionQuotas' && documentId === 'user-1',
      ),
    );
    assert.ok(
      plan.deleteQueries.some(
        ([collection, field]) =>
          collection === 'friendships' && field === 'participants',
      ),
    );
    assert.ok(
      plan.anonymizeQueries.some(
        ([collection, field, , replacement]) =>
          collection === 'tournaments' &&
          field === 'organizerId' &&
          replacement.organizerDeleted === true,
      ),
    );
    assert.ok(
      plan.anonymizeQueries.some(
        ([collection, field]) =>
          collection === 'userReports' && field === 'reporterId',
      ),
    );
    assert.ok(
      plan.arrayRemovalQueries.some(
        ([collection, field]) =>
          collection === 'teams' && field === 'playerIds',
      ),
    );
    assert.deepStrictEqual(plan.nestedIdentityCollectionGroups, [
      'player_stats',
    ]);
  });

  it('produces a stable non-reversible identifier for retries', () => {
    assert.strictEqual(deletedAccountId('user-1'), deletedAccountId('user-1'));
    assert.notStrictEqual(deletedAccountId('user-1'), deletedAccountId('user-2'));
    assert.ok(deletedAccountId('user-1').startsWith('deleted-'));
    assert.ok(!deletedAccountId('user-1').includes('user-1'));
  });

  it('de-links nested MatchEvent and lineup player identities', () => {
    const source = {
      organizerId: 'user-1',
      teamName: 'الحريف',
      actor: {
        kind: 'player',
        id: 'user-1',
        displayName: 'لاعب قديم',
      },
      starters: [
        {playerId: 'user-1', displayName: 'لاعب قديم'},
        {playerId: 'user-2', displayName: 'لاعب آخر'},
      ],
    };

    const scrubbed = scrubNestedIdentity(
      source,
      'user-1',
      'deleted-safe-id',
    );

    assert.strictEqual(scrubbed.changed, true);
    assert.strictEqual(scrubbed.value.organizerId, 'deleted-safe-id');
    assert.strictEqual(scrubbed.value.teamName, 'الحريف');
    assert.deepStrictEqual(scrubbed.value.actor, {
      kind: 'player',
      id: 'deleted-safe-id',
      displayName: 'حساب محذوف',
    });
    assert.strictEqual(scrubbed.value.starters[0].playerId, 'deleted-safe-id');
    assert.strictEqual(scrubbed.value.starters[0].displayName, 'حساب محذوف');
    assert.strictEqual(scrubbed.value.starters[1].playerId, 'user-2');
  });

  it('records a private request and pseudonymous trusted audit', async () => {
    const db = new FakeFirestore();
    const response = await requestAccountDeletionCore({
      db,
      uid: 'user-1',
      now: NOW,
    });
    const requestId = deletedAccountId('user-1');
    const request = db.docData(`accountDeletionRequests/${requestId}`);
    const audits = db.collectionData('auditEvents');

    assert.deepStrictEqual(response, {
      accepted: true,
      deleted: false,
      requestId,
      status: 'requested',
    });
    assert.strictEqual(request.userId, 'user-1');
    assert.strictEqual(request.status, 'requested');
    assert.strictEqual(audits.length, 1);
    assert.strictEqual(audits[0].action, 'accountDeletionRequested');
    assert.strictEqual(audits[0].actorId, requestId);
    assert.strictEqual(JSON.stringify(audits).includes('user-1'), false);
  });

  it('resumes after a failed stage without repeating completed stages', async () => {
    const db = new FakeFirestore();
    const requestId = deletedAccountId('user-1');
    await requestAccountDeletionCore({db, uid: 'user-1', now: NOW});
    const firstRun = stageRecorder({failOnceAt: 'references'});

    await assert.rejects(
      () => processAccountDeletionRequestCore({
        db,
        requestId,
        stages: firstRun.stages,
        now: () => NOW + firstRun.calls.length + 1,
      }),
      /injected references failure/,
    );
    const failed = db.docData(`accountDeletionRequests/${requestId}`);
    assert.strictEqual(failed.status, 'failed');
    assert.strictEqual(failed.failedStage, 'references');
    assert.deepStrictEqual(failed.completedSteps, [
      'storage',
      'privateDocuments',
    ]);

    const retry = stageRecorder();
    const response = await processAccountDeletionRequestCore({
      db,
      requestId,
      stages: retry.stages,
      now: () => NOW + 100 + retry.calls.length,
    });
    const completed = db.docData(`accountDeletionRequests/${requestId}`);
    const audits = db.collectionData('auditEvents');

    assert.deepStrictEqual(retry.calls, [
      'references',
      'nestedIdentities',
      'auth',
    ]);
    assert.strictEqual(response.deleted, true);
    assert.strictEqual(completed.status, 'completed');
    assert.strictEqual(Object.hasOwn(completed, 'userId'), false);
    assert.deepStrictEqual(completed.completedSteps, DELETION_STAGE_ORDER);
    assert.strictEqual(JSON.stringify(audits).includes('user-1'), false);
    assert.ok(audits.some((audit) => audit.action === 'accountDeletionFailed'));
    assert.ok(
      audits.some((audit) => audit.action === 'accountDeletionCompleted'),
    );
  });

  it('does not rerun destructive stages after completion', async () => {
    const db = new FakeFirestore();
    const requestId = deletedAccountId('user-1');
    await requestAccountDeletionCore({db, uid: 'user-1', now: NOW});
    const initial = stageRecorder();
    await processAccountDeletionRequestCore({
      db,
      requestId,
      stages: initial.stages,
      now: NOW + 1,
    });
    const replay = stageRecorder();

    const response = await processAccountDeletionRequestCore({
      db,
      requestId,
      stages: replay.stages,
      now: NOW + 2,
    });

    assert.strictEqual(response.deleted, true);
    assert.deepStrictEqual(replay.calls, []);
  });

  it('runs the worker only for transitions into requested', () => {
    assert.strictEqual(
      accountDeletionEventShouldRun(deletionChange(null, 'requested')),
      true,
    );
    assert.strictEqual(
      accountDeletionEventShouldRun(deletionChange('failed', 'requested')),
      true,
    );
    assert.strictEqual(
      accountDeletionEventShouldRun(deletionChange('requested', 'processing')),
      false,
    );
    assert.strictEqual(
      accountDeletionEventShouldRun(deletionChange('processing', 'failed')),
      false,
    );
  });
});

function stageRecorder({failOnceAt = null} = {}) {
  const calls = [];
  let failureInjected = false;
  const stages = Object.fromEntries(
    DELETION_STAGE_ORDER.map((stage) => [stage, async () => {
      calls.push(stage);
      if (stage === failOnceAt && !failureInjected) {
        failureInjected = true;
        throw new Error(`injected ${stage} failure`);
      }
    }]),
  );
  return {calls, stages};
}

function deletionChange(beforeStatus, afterStatus) {
  return {
    before: deletionSnapshot(beforeStatus),
    after: deletionSnapshot(afterStatus),
  };
}

function deletionSnapshot(status) {
  return {
    exists: status != null,
    data: () => ({status}),
  };
}
