const assert = require('assert');

const {
  blockUserCore,
  normalizeUserReport,
  reportUserContentCore,
  unblockUserCore,
} = require('../../functions/user_safety');
const {deletedAccountId} = require('../../functions/account_deletion');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = Date.UTC(2026, 6, 11);

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
      NOW,
    );

    assert.strictEqual(report.reporterId, 'reporter-1');
    assert.strictEqual(report.contentType, 'profile');
    assert.strictEqual(report.details, 'بيانات غير صحيحة');
    assert.strictEqual(report.status, 'open');
  });

  it('rejects invalid report identity, reason, and details', () => {
    const invalidPayloads = [
      reportPayload({targetId: 'reporter-1'}),
      reportPayload({reason: 'unsupported'}),
      reportPayload({targetId: 123}),
      reportPayload({details: 'x'.repeat(501)}),
    ];

    for (const payload of invalidPayloads) {
      assert.throws(
        () => normalizeUserReport(payload, 'reporter-1', NOW),
        (error) => error.code === 'invalid-argument',
      );
    }
  });

  it('creates one private report and one bounded trusted audit across retries', async () => {
    const db = new FakeFirestore(reportSeed({'players/player-2': player()}));
    const args = reportArgs(db, reportPayload({details: 'private context'}));

    const first = await reportUserContentCore(args);
    const second = await reportUserContentCore(args);

    assert.strictEqual(first.duplicate, false);
    assert.strictEqual(second.duplicate, true);
    assert.strictEqual(db.collectionData('userReports').length, 1);
    assert.strictEqual(
      db.docData(`userReports/${first.reportId}`).details,
      'private context',
    );
    const audits = db.collectionData('auditEvents');
    assert.strictEqual(audits.length, 1);
    assert.strictEqual(audits[0].action, 'profileReported');
    assert.strictEqual(audits[0].actorId, 'reporter-1');
    assert.strictEqual(audits[0].entityType, 'moderationReport');
    assert.strictEqual(audits[0].entityId, first.reportId);
    assert.strictEqual(JSON.stringify(audits[0]).includes('private context'), false);
    assert.strictEqual(JSON.stringify(audits[0]).includes('player-2'), false);
    assert.strictEqual(JSON.stringify(audits[0]).includes('spam'), false);
    assert.strictEqual(quotaState(db, 'reporter-1', 'profileReport').count, 1);
  });

  it('reports an existing guest profile without exposing its details in audit', async () => {
    const db = new FakeFirestore(reportSeed({
      'guestPlayers/guest-1': {name: 'ضيف'},
    }));

    await reportUserContentCore(reportArgs(db, {
      targetKind: 'guestPlayer',
      targetId: 'guest-1',
      reason: 'impersonation',
      details: 'private evidence',
    }));

    const audit = db.collectionData('auditEvents')[0];
    assert.strictEqual(audit.entityType, 'moderationReport');
    assert.strictEqual(audit.afterPayload.targetKind, 'guestPlayer');
    assert.strictEqual(JSON.stringify(audit).includes('private evidence'), false);
    assert.strictEqual(JSON.stringify(audit).includes('guest-1'), false);
    assert.strictEqual(JSON.stringify(audit).includes('impersonation'), false);
  });

  it('rejects a missing report target without writing report or audit', async () => {
    const db = new FakeFirestore(reportSeed());

    await assert.rejects(
      () => reportUserContentCore(reportArgs(db, reportPayload())),
      (error) => error.code === 'not-found',
    );

    assert.deepStrictEqual(db.collectionData('userReports'), []);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('rolls report creation back when its trusted audit fails', async () => {
    const db = new FakeFirestore(
      reportSeed({'players/player-2': player()}),
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => reportUserContentCore(reportArgs(db, reportPayload())),
      /Injected write failure/,
    );

    assert.deepStrictEqual(db.collectionData('userReports'), []);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('rejects a reporter with no profile or an account deletion tombstone', async () => {
    const missingProfileDb = new FakeFirestore({'players/player-2': player()});
    const tombstonedDb = new FakeFirestore(reportSeed({
      'players/player-2': player(),
      [`accountDeletionRequests/${deletedAccountId('reporter-1')}`]: {
        status: 'completed',
      },
    }));

    for (const db of [missingProfileDb, tombstonedDb]) {
      await assert.rejects(
        () => reportUserContentCore(reportArgs(db, reportPayload())),
        (error) => error.code === 'permission-denied',
      );
      assert.deepStrictEqual(db.collectionData('userReports'), []);
      assert.deepStrictEqual(db.collectionData('auditEvents'), []);
      assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
    }
  });

  it('blocks registered players atomically with one bounded trusted audit', async () => {
    const db = blockDatabase();

    const first = await blockUserCore(blockArgs(db));
    const second = await blockUserCore(blockArgs(db));

    assert.deepStrictEqual(first, {blocked: true, duplicate: false});
    assert.deepStrictEqual(second, {blocked: true, duplicate: true});
    assert.deepStrictEqual(db.docData('players/player-1').friendIds, []);
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, ['player-2']);
    assert.deepStrictEqual(db.docData('players/player-2').friendIds, []);
    assert.strictEqual(
      db.docData('friendships/player-1_player-2').status,
      'blocked',
    );
    const audits = db.collectionData('auditEvents');
    assert.strictEqual(audits.length, 1);
    assert.strictEqual(audits[0].action, 'playerBlocked');
    assert.strictEqual(audits[0].entityType, 'safetyRelationship');
    assert.deepStrictEqual(audits[0].beforePayload, {blocked: false});
    assert.deepStrictEqual(audits[0].afterPayload, {blocked: true});
    assert.strictEqual(JSON.stringify(audits[0]).includes('blockedIds'), false);
    assert.strictEqual(JSON.stringify(audits[0]).includes('player-2'), false);
    assert.strictEqual(
      quotaState(db, 'player-1', 'safetyRelationship').count,
      1,
    );
  });

  it('repairs legacy friendIds for either player during block and unblock', async () => {
    const sides = [
      {name: 'blocker', path: 'players/player-1', peerId: 'player-2'},
      {name: 'target', path: 'players/player-2', peerId: 'player-1'},
    ];
    const operations = [
      {
        name: 'block',
        operation: blockUserCore,
        seed: () => blockSeed(),
        expectedBlockedIds: ['player-2'],
      },
      {
        name: 'unblock',
        operation: unblockUserCore,
        seed: () => blockedRelationshipSeed(),
        expectedBlockedIds: [],
      },
    ];

    for (const operationCase of operations) {
      for (const side of sides) {
        for (const listState of malformedRelationshipLists(side.peerId)) {
          const seed = operationCase.seed();
          applyListState(seed[side.path], 'friendIds', listState);
          const db = new FakeFirestore(seed);

          const result = await operationCase.operation(blockArgs(db));
          const label = [
            operationCase.name,
            side.name,
            listState.name,
          ].join(':');

          assert.strictEqual(result.duplicate, false, label);
          assert.deepStrictEqual(
            db.docData('players/player-1').blockedIds,
            operationCase.expectedBlockedIds,
            label,
          );
          assert.deepStrictEqual(
            db.docData(side.path).friendIds,
            listState.expected,
            label,
          );
          const otherPath = side.name === 'blocker' ?
            'players/player-2' :
            'players/player-1';
          assert.deepStrictEqual(db.docData(otherPath).friendIds, [], label);
        }
      }
    }
  });

  it('canonicalizes a reversed legacy friendship for the same pair', async () => {
    const seed = blockSeed({
      'players/player-1': player({blockedIds: ['player-2']}),
      'players/player-2': player(),
      'friendships/player-1_player-2': {
        userId1: 'player-2',
        userId2: 'player-1',
        participants: ['player-2', 'player-1'],
        status: 'blocked',
        lastActionBy: 'player-1',
        createdAt: 'existing-time',
        updatedAt: 'existing-time',
      },
    });
    const db = new FakeFirestore(seed);

    const result = await blockUserCore(blockArgs(db));

    assert.deepStrictEqual(result, {blocked: true, duplicate: true});
    assert.deepStrictEqual(
      db.docData('friendships/player-1_player-2'),
      {
        userId1: 'player-1',
        userId2: 'player-2',
        participants: ['player-1', 'player-2'],
        status: 'blocked',
        lastActionBy: 'player-1',
        createdAt: 'existing-time',
        updatedAt: new Date(NOW).toISOString(),
      },
    );
    assert.deepStrictEqual(
      db.docData('players/player-1').blockedIds,
      ['player-2'],
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('normalizes legacy blockedIds and preserves every valid mutual block', async () => {
    const db = new FakeFirestore(blockSeed({
      'players/player-1': player({
        friendIds: ['player-2'],
        blockedIds: ['retained-block', 7, null, 'retained-block', ''],
      }),
      'players/player-2': player({
        friendIds: ['player-1'],
        blockedIds: 'player-1',
      }),
    }));

    const result = await blockUserCore(blockArgs(db));

    assert.deepStrictEqual(result, {blocked: true, duplicate: false});
    assert.deepStrictEqual(
      db.docData('players/player-1').blockedIds,
      ['retained-block', 'player-2'],
    );
    assert.deepStrictEqual(
      db.docData('players/player-2').blockedIds,
      ['player-1'],
    );
    assert.strictEqual(
      db.docData('friendships/player-1_player-2').status,
      'blocked',
    );
    assert.strictEqual(db.collectionData('auditEvents').length, 1);
    assert.strictEqual(
      quotaState(db, 'player-1', 'safetyRelationship').count,
      1,
    );
  });

  it('heals a duplicate legacy block without quota or audit', async () => {
    const seed = blockSeed({
      'players/player-1': player({
        friendIds: ['player-2'],
        blockedIds: 'player-2',
      }),
      'players/player-2': player({friendIds: ['player-1']}),
    });
    delete seed['players/player-2'].blockedIds;
    const db = new FakeFirestore(seed);

    const result = await blockUserCore(blockArgs(db));

    assert.deepStrictEqual(result, {blocked: true, duplicate: true});
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, ['player-2']);
    assert.deepStrictEqual(db.docData('players/player-2').blockedIds, []);
    assert.deepStrictEqual(db.docData('players/player-1').friendIds, []);
    assert.deepStrictEqual(db.docData('players/player-2').friendIds, []);
    assert.strictEqual(
      db.docData('friendships/player-1_player-2').status,
      'blocked',
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('normalizes both sides during unblock and preserves the opposite block', async () => {
    const db = new FakeFirestore(blockedRelationshipSeed({
      'players/player-1': player({
        blockedIds: ['player-2', 7, 'retained-block', 'retained-block'],
      }),
      'players/player-2': player({blockedIds: 'player-1'}),
    }));

    const result = await unblockUserCore(unblockArgs(db));

    assert.deepStrictEqual(result, {unblocked: true, duplicate: false});
    assert.deepStrictEqual(
      db.docData('players/player-1').blockedIds,
      ['retained-block'],
    );
    assert.deepStrictEqual(
      db.docData('players/player-2').blockedIds,
      ['player-1'],
    );
    assert.strictEqual(
      db.docData('friendships/player-1_player-2').lastActionBy,
      'player-2',
    );
    assert.strictEqual(db.collectionData('auditEvents').length, 1);
    assert.strictEqual(
      quotaState(db, 'player-1', 'safetyRelationship').count,
      1,
    );
  });

  it('heals duplicate unblock arrays without deleting a real friendship', async () => {
    const seed = blockSeed({
      'players/player-1': player({friendIds: ['player-2']}),
      'players/player-2': player({
        friendIds: ['player-1'],
        blockedIds: [7, 'retained-block', 'retained-block'],
      }),
    });
    delete seed['players/player-1'].blockedIds;
    const friendship = seed['friendships/player-1_player-2'];
    const db = new FakeFirestore(seed);

    const result = await unblockUserCore(unblockArgs(db));

    assert.deepStrictEqual(result, {unblocked: true, duplicate: true});
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, []);
    assert.deepStrictEqual(
      db.docData('players/player-2').blockedIds,
      ['retained-block'],
    );
    assert.deepStrictEqual(
      db.docData('players/player-1').friendIds,
      ['player-2'],
    );
    assert.deepStrictEqual(
      db.docData('players/player-2').friendIds,
      ['player-1'],
    );
    assert.deepStrictEqual(
      db.docData('friendships/player-1_player-2'),
      friendship,
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('removes a stale blocked friendship during duplicate unblock repair', async () => {
    const seed = blockedRelationshipSeed({
      'players/player-1': player({blockedIds: [7, 'retained-block']}),
      'players/player-2': player({blockedIds: []}),
    });
    const db = new FakeFirestore(seed);

    const result = await unblockUserCore(unblockArgs(db));

    assert.deepStrictEqual(result, {unblocked: true, duplicate: true});
    assert.deepStrictEqual(
      db.docData('players/player-1').blockedIds,
      ['retained-block'],
    );
    assert.deepStrictEqual(db.docData('players/player-2').blockedIds, []);
    assert.strictEqual(db.docData('friendships/player-1_player-2'), undefined);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('keeps opposite-direction blocks idempotent for both players', async () => {
    const db = blockDatabase();

    const first = await blockUserCore(blockArgs(db));
    const opposite = await blockUserCore(blockArgs(db, {
      blockerId: 'player-2',
      blockedId: 'player-1',
      now: () => NOW + 1,
    }));
    const retry = await blockUserCore(blockArgs(db, {now: () => NOW + 2}));

    assert.deepStrictEqual(first, {blocked: true, duplicate: false});
    assert.deepStrictEqual(opposite, {blocked: true, duplicate: false});
    assert.deepStrictEqual(retry, {blocked: true, duplicate: true});
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, ['player-2']);
    assert.deepStrictEqual(db.docData('players/player-2').blockedIds, ['player-1']);
    assert.strictEqual(db.collectionData('auditEvents').length, 2);
  });

  it('unblocks each direction without clearing the other player block', async () => {
    const db = blockDatabase();
    await blockUserCore(blockArgs(db));
    await blockUserCore(blockArgs(db, {
      blockerId: 'player-2',
      blockedId: 'player-1',
      now: () => NOW + 1,
    }));

    const first = await unblockUserCore(unblockArgs(db));
    const retry = await unblockUserCore(unblockArgs(db, {now: () => NOW + 3}));

    assert.deepStrictEqual(first, {unblocked: true, duplicate: false});
    assert.deepStrictEqual(retry, {unblocked: true, duplicate: true});
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, []);
    assert.deepStrictEqual(db.docData('players/player-2').blockedIds, ['player-1']);
    assert.strictEqual(
      db.docData('friendships/player-1_player-2').lastActionBy,
      'player-2',
    );

    await unblockUserCore(unblockArgs(db, {
      blockerId: 'player-2',
      blockedId: 'player-1',
      now: () => NOW + 4,
    }));

    assert.strictEqual(db.docData('friendships/player-1_player-2'), undefined);
    assert.strictEqual(
      db.collectionData('auditEvents')
        .filter((audit) => audit.action === 'playerUnblocked').length,
      2,
    );
  });

  it('uses an atomic revision for repeated transitions in one millisecond', async () => {
    const db = blockDatabase();

    await blockUserCore(blockArgs(db));
    await unblockUserCore(unblockArgs(db));
    await blockUserCore(blockArgs(db));

    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, ['player-2']);
    const audits = db.collectionData('auditEvents');
    assert.deepStrictEqual(
      audits.map((audit) => audit.action),
      ['playerBlocked', 'playerUnblocked', 'playerBlocked'],
    );
    assert.strictEqual(new Set(audits.map((audit) => audit.id)).size, 3);
    assert.deepStrictEqual(
      {
        count: quotaState(db, 'player-1', 'safetyRelationship').count,
        revision: quotaState(db, 'player-1', 'safetyRelationship').revision,
      },
      {count: 3, revision: 3},
    );
  });

  it('rejects a colliding friendship identity before block or unblock', async () => {
    const collidingFriendship = {
      userId1: 'a_b',
      userId2: 'c',
      participants: ['a_b', 'c'],
      status: 'blocked',
      lastActionBy: 'a_b',
      createdAt: 'existing-time',
      updatedAt: 'existing-time',
    };
    const operations = [
      {
        operation: blockUserCore,
        actor: player(),
      },
      {
        operation: unblockUserCore,
        actor: player({blockedIds: ['b_c']}),
      },
    ];

    for (const {operation, actor} of operations) {
      const seed = {
        'players/a': actor,
        'players/b_c': player(),
        'friendships/a_b_c': collidingFriendship,
      };
      const db = new FakeFirestore(seed);

      await assert.rejects(
        () => operation({
          db,
          blockerId: 'a',
          blockedId: 'b_c',
          now: () => NOW,
        }),
        (error) => error.code === 'failed-precondition',
      );
      assert.deepStrictEqual(db.docData('players/a'), actor);
      assert.deepStrictEqual(
        db.docData('friendships/a_b_c'),
        collidingFriendship,
      );
      assert.deepStrictEqual(db.collectionData('auditEvents'), []);
      assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
    }
  });

  it('limits new reports to twenty per actor and UTC day', async () => {
    const seed = reportSeed();
    for (let index = 0; index <= 20; index += 1) {
      seed[`players/target-${index}`] = player();
    }
    const db = new FakeFirestore(seed);

    for (let index = 0; index < 20; index += 1) {
      await reportUserContentCore(reportArgs(db, reportPayload({
        targetId: `target-${index}`,
      })));
    }
    const duplicate = await reportUserContentCore(reportArgs(db, reportPayload({
      targetId: 'target-0',
    })));

    assert.strictEqual(duplicate.duplicate, true);
    await assert.rejects(
      () => reportUserContentCore(reportArgs(db, reportPayload({
        targetId: 'target-20',
      }))),
      (error) => error.code === 'resource-exhausted',
    );
    assert.strictEqual(db.collectionData('userReports').length, 20);
    assert.strictEqual(db.collectionData('auditEvents').length, 20);
    assert.strictEqual(
      quotaState(db, 'reporter-1', 'profileReport').count,
      20,
    );
  });

  it('shares a thirty-transition hourly limit across block and unblock', async () => {
    const db = blockDatabase();

    for (let index = 0; index < 30; index += 1) {
      const operation = index % 2 === 0 ? blockUserCore : unblockUserCore;
      await operation(blockArgs(db));
    }
    const duplicate = await unblockUserCore(unblockArgs(db));

    assert.deepStrictEqual(duplicate, {unblocked: true, duplicate: true});
    await assert.rejects(
      () => blockUserCore(blockArgs(db)),
      (error) => error.code === 'resource-exhausted',
    );
    assert.deepStrictEqual(db.docData('players/player-1').blockedIds, []);
    assert.strictEqual(db.collectionData('auditEvents').length, 30);
    assert.strictEqual(
      quotaState(db, 'player-1', 'safetyRelationship').count,
      30,
    );
  });

  it('rejects a missing block target without changing the blocker', async () => {
    const db = new FakeFirestore({'players/player-1': player()});

    await assert.rejects(
      () => blockUserCore(blockArgs(db)),
      (error) => error.code === 'not-found',
    );

    assert.deepStrictEqual(db.docData('players/player-1'), player());
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('rolls every block write back when its trusted audit fails', async () => {
    const seed = blockSeed({
      'players/player-1': player({
        friendIds: ['player-2'],
        blockedIds: ['retained-block', 7, 'retained-block'],
      }),
      'players/player-2': player({
        friendIds: ['player-1'],
        blockedIds: 'player-1',
      }),
    });
    const db = new FakeFirestore(
      seed,
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => blockUserCore(blockArgs(db)),
      /Injected write failure/,
    );

    assert.deepStrictEqual(db.docData('players/player-1'), seed['players/player-1']);
    assert.deepStrictEqual(db.docData('players/player-2'), seed['players/player-2']);
    assert.deepStrictEqual(
      db.docData('friendships/player-1_player-2'),
      seed['friendships/player-1_player-2'],
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });

  it('rolls unblock state back when its trusted audit fails', async () => {
    const seed = blockSeed({
      'players/player-1': player({
        blockedIds: ['player-2', 7, 'retained-block'],
      }),
      'players/player-2': player({blockedIds: 'player-1'}),
      'friendships/player-1_player-2': {
        userId1: 'player-1',
        userId2: 'player-2',
        participants: ['player-1', 'player-2'],
        status: 'blocked',
        lastActionBy: 'player-1',
        createdAt: 'existing-time',
        updatedAt: 'existing-time',
      },
    });
    const db = new FakeFirestore(
      seed,
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => unblockUserCore(unblockArgs(db)),
      /Injected write failure/,
    );

    assert.deepStrictEqual(db.docData('players/player-1'), seed['players/player-1']);
    assert.deepStrictEqual(db.docData('players/player-2'), seed['players/player-2']);
    assert.deepStrictEqual(
      db.docData('friendships/player-1_player-2'),
      seed['friendships/player-1_player-2'],
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
    assert.deepStrictEqual(db.collectionData('safetyActionQuotas'), []);
  });
});

function reportPayload(overrides = {}) {
  return {
    targetKind: 'registeredPlayer',
    targetId: 'player-2',
    reason: 'spam',
    ...overrides,
  };
}

function reportSeed(overrides = {}) {
  return {'players/reporter-1': player(), ...overrides};
}

function reportArgs(db, reportPayload) {
  return {
    db,
    reportPayload,
    reporterId: 'reporter-1',
    now: () => NOW,
  };
}

function player(overrides = {}) {
  return {friendIds: [], blockedIds: [], ...overrides};
}

function blockSeed(overrides = {}) {
  return {
    'players/player-1': player({friendIds: ['player-2']}),
    'players/player-2': player({friendIds: ['player-1']}),
    'friendships/player-1_player-2': {
      userId1: 'player-1',
      userId2: 'player-2',
      participants: ['player-1', 'player-2'],
      status: 'accepted',
      lastActionBy: 'player-2',
      createdAt: 'existing-time',
      updatedAt: 'existing-time',
    },
    ...overrides,
  };
}

function blockedRelationshipSeed(overrides = {}) {
  return blockSeed({
    'players/player-1': player({
      friendIds: [],
      blockedIds: ['player-2'],
    }),
    'players/player-2': player(),
    'friendships/player-1_player-2': {
      userId1: 'player-1',
      userId2: 'player-2',
      participants: ['player-1', 'player-2'],
      status: 'blocked',
      lastActionBy: 'player-1',
      createdAt: 'existing-time',
      updatedAt: 'existing-time',
    },
    ...overrides,
  });
}

function malformedRelationshipLists(peerId) {
  return [
    {name: 'missing', omit: true, expected: []},
    {name: 'string', value: peerId, expected: []},
    {
      name: 'mixed',
      value: [peerId, 7, null, 'retained-friend', 'retained-friend', ''],
      expected: ['retained-friend'],
    },
  ];
}

function applyListState(document, fieldName, listState) {
  if (listState.omit) {
    delete document[fieldName];
    return;
  }
  document[fieldName] = listState.value;
}

function blockDatabase() {
  return new FakeFirestore(blockSeed());
}

function blockArgs(db, overrides = {}) {
  return {
    db,
    blockerId: 'player-1',
    blockedId: 'player-2',
    now: () => NOW,
    ...overrides,
  };
}

function unblockArgs(db, overrides = {}) {
  return blockArgs(db, overrides);
}

function quotaState(db, actorId, scope) {
  return db.docData(`safetyActionQuotas/${actorId}`)?.[scope];
}
