const assert = require('assert');

const {
  accountDeletionPlan,
  deletedAccountId,
  scrubNestedIdentity,
} = require('../../functions/account_deletion');

describe('accountDeletionPlan', () => {
  it('removes private identity data and anonymizes historical ownership', () => {
    const plan = accountDeletionPlan('user-1');

    assert.strictEqual(plan.anonymizedId, deletedAccountId('user-1'));
    assert.notStrictEqual(plan.anonymizedId, 'user-1');
    assert.deepStrictEqual(plan.recursiveDocuments[0], ['players', 'user-1']);
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
});
