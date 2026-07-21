const assert = require('assert');

const {
  blockUserCore,
  normalizeUserReport,
  reportUserContentCore,
} = require('../../functions/user_safety');

describe('user safety reports', () => {
  it('normalizes an authenticated profile report for review', () => {
    const report = normalizeUserReport(
      {
        targetKind: 'guestPlayer',
        targetId: 'guest-1',
        reason: 'impersonation',
        details: '  بيانات غير صحيحة  ',
      },
      'reporter-1',
      Date.UTC(2026, 6, 11),
    );

    assert.strictEqual(report.reporterId, 'reporter-1');
    assert.strictEqual(report.contentType, 'profile');
    assert.strictEqual(report.details, 'بيانات غير صحيحة');
    assert.strictEqual(report.status, 'open');
  });

  it('rejects self-reporting and unsupported reasons', () => {
    assert.throws(
      () =>
        normalizeUserReport(
          {
            targetKind: 'registeredPlayer',
            targetId: 'player-1',
            reason: 'spam',
          },
          'player-1',
        ),
      (error) => error.code === 'invalid-argument',
    );
    assert.throws(
      () =>
        normalizeUserReport(
          {
            targetKind: 'guestPlayer',
            targetId: 'guest-1',
            reason: 'unsupported',
          },
          'player-1',
        ),
      (error) => error.code === 'invalid-argument',
    );
  });

  it('deduplicates repeated reports for the same profile and day', async () => {
    const writes = [];
    const db = {
      collection: () => ({
        doc: (id) => ({
          get: async () => ({exists: writes.length > 0}),
          create: async (data) => writes.push({id, data}),
        }),
      }),
    };
    const args = {
      db,
      reportPayload: {
        targetKind: 'registeredPlayer',
        targetId: 'player-2',
        reason: 'spam',
      },
      reporterId: 'player-1',
      now: () => Date.UTC(2026, 6, 11),
    };

    const first = await reportUserContentCore(args);
    const second = await reportUserContentCore(args);

    assert.strictEqual(first.duplicate, false);
    assert.strictEqual(second.duplicate, true);
    assert.strictEqual(writes.length, 1);
  });

  it('blocks registered users through one server-side batch', async () => {
    const operations = [];
    const db = {
      collection: (collection) => ({
        doc: (id) => ({
          id,
          path: `${collection}/${id}`,
          get: async () => ({exists: true}),
        }),
      }),
      batch: () => ({
        set: (ref, data) => operations.push(['set', ref.path, data]),
        update: (ref, data) => operations.push(['update', ref.path, data]),
        commit: async () => operations.push(['commit']),
      }),
    };
    const fieldValue = {
      arrayRemove: (value) => `remove:${value}`,
      arrayUnion: (value) => `union:${value}`,
    };

    const result = await blockUserCore({
      db,
      blockerId: 'player-1',
      blockedId: 'player-2',
      fieldValue,
      now: 123,
    });

    assert.deepStrictEqual(result, {blocked: true});
    assert.ok(
      operations.some(
        ([kind, path, data]) =>
          kind === 'set' &&
          path === 'friendships/player-1_player-2' &&
          data.status === 'blocked',
      ),
    );
    assert.ok(
      operations.some(
        ([kind, path, data]) =>
          kind === 'update' &&
          path === 'players/player-1' &&
          data.blockedIds === 'union:player-2',
      ),
    );
  });
});
