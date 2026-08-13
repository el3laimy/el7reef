const assert = require('assert');

const {
  appendAuditEvent,
  trustedAuditEventId,
  TrustedAuditError,
} = require('../../functions/trusted_audit');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = 1770000000000;

describe('trusted audit writer', () => {
  it('creates one bounded provenance-stamped event with a deterministic ID', async () => {
    const db = new FakeFirestore();
    const input = auditInput(db);
    const expectedId = trustedAuditEventId(input);

    await db.runTransaction((transaction) => appendAuditEvent({
      ...input,
      transaction,
    }));

    assert.deepStrictEqual(db.docData(`auditEvents/${expectedId}`), {
      entityType: 'match',
      entityId: 'match-1',
      action: 'matchScoreSubmitted',
      actorId: 'organizer-1',
      beforePayload: {status: 'live'},
      afterPayload: {status: 'completed'},
      metadata: {tournamentId: 'tournament-1'},
      source: 'trustedOperation',
      verificationVersion: 1,
      requestId: 'settlement-fingerprint-1',
      createdAt: NOW,
    });
  });

  it('uses create semantics so an operation request cannot replace its event', async () => {
    const db = new FakeFirestore();
    const write = () => db.runTransaction((transaction) => appendAuditEvent({
      ...auditInput(db),
      transaction,
    }));

    await write();
    await assert.rejects(write, (error) => error.code === 'already-exists');
    assert.strictEqual(db.collectionData('auditEvents').length, 1);
  });

  it('accepts only the trusted guest-claim action/entity pairs', async () => {
    const db = new FakeFirestore();
    const pairs = [
      ['guestPlayerClaimed', 'guestPlayer'],
      ['guestTeamClaimed', 'guestTeam'],
      ['claimCodeConsumed', 'claimCode'],
    ];

    for (const [action, entityType] of pairs) {
      await db.runTransaction((transaction) => appendAuditEvent({
        ...auditInput(db),
        transaction,
        action,
        entityType,
        entityId: `${entityType}-1`,
        requestId: `${action}-request-1`,
      }));
    }

    assert.strictEqual(db.collectionData('auditEvents').length, pairs.length);
    await assert.rejects(
      () => db.runTransaction((transaction) => appendAuditEvent({
        ...auditInput(db),
        transaction,
        action: 'claimCodeConsumed',
        entityType: 'guestPlayer',
      })),
      (error) => error instanceof TrustedAuditError,
    );
  });

  it('accepts only bounded account-deletion lifecycle actions', async () => {
    const db = new FakeFirestore();
    const actions = [
      'accountDeletionRequested',
      'accountDeletionProcessing',
      'accountDeletionCompleted',
      'accountDeletionFailed',
    ];

    for (const action of actions) {
      await db.runTransaction((transaction) => appendAuditEvent({
        ...auditInput(db),
        transaction,
        action,
        entityType: 'accountDeletion',
        entityId: 'deleted-opaque-id',
        actorId: 'deleted-opaque-id',
        beforePayload: null,
        afterPayload: null,
        metadata: {status: action},
        requestId: `${action}-request-1`,
      }));
    }

    assert.strictEqual(db.collectionData('auditEvents').length, actions.length);
    await assert.rejects(
      () => db.runTransaction((transaction) => appendAuditEvent({
        ...auditInput(db),
        transaction,
        action: 'accountDeletionCompleted',
        entityType: 'player',
      })),
      (error) => error instanceof TrustedAuditError,
    );
  });

  it('rejects unknown actions, unknown entities, and oversized payloads', async () => {
    const db = new FakeFirestore();
    const attempt = (overrides) => db.runTransaction((transaction) => (
      appendAuditEvent({...auditInput(db), ...overrides, transaction})
    ));

    await assert.rejects(
      () => attempt({action: 'clientChosenAction'}),
      (error) => error instanceof TrustedAuditError,
    );
    await assert.rejects(
      () => attempt({entityType: 'clientChosenEntity'}),
      (error) => error instanceof TrustedAuditError,
    );
    await assert.rejects(
      () => attempt({entityType: 'player'}),
      (error) => error instanceof TrustedAuditError,
    );
    await assert.rejects(
      () => attempt({entityType: 'moderationReport'}),
      (error) => error instanceof TrustedAuditError,
    );
    await assert.rejects(
      () => attempt({
        entityType: 'safetyRelationship',
        action: 'profileReported',
      }),
      (error) => error instanceof TrustedAuditError,
    );
    await assert.rejects(
      () => attempt({metadata: {note: 'x'.repeat(513)}}),
      (error) => error instanceof TrustedAuditError,
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });
});

function auditInput(db) {
  return {
    db,
    entityType: 'match',
    entityId: 'match-1',
    action: 'matchScoreSubmitted',
    actorId: 'organizer-1',
    beforePayload: {status: 'live'},
    afterPayload: {status: 'completed'},
    metadata: {tournamentId: 'tournament-1'},
    requestId: 'settlement-fingerprint-1',
    createdAt: NOW,
  };
}
