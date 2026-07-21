const assert = require('assert');

const {
  normalizeAuditEventPayload,
} = require('../../functions/audit_event');

describe('audit event payload', () => {
  it('uses the authenticated actor and server timestamp', () => {
    const payload = normalizeAuditEventPayload(
      {
        id: 'client-event-id',
        entityType: 'tournament',
        entityId: 'tournament-1',
        action: 'fixtureStarted',
        actorId: 'spoofed-actor',
        createdAt: 1,
        metadata: {round: 2},
        unexpected: 'drop-me',
      },
      'authenticated-actor',
      123456,
    );

    assert.deepStrictEqual(payload, {
      entityType: 'tournament',
      entityId: 'tournament-1',
      action: 'fixtureStarted',
      actorId: 'authenticated-actor',
      beforePayload: null,
      afterPayload: null,
      metadata: {round: 2},
      createdAt: 123456,
    });
  });

  it('rejects missing required fields and non-map payloads', () => {
    assert.throws(
      () => normalizeAuditEventPayload({}, 'actor-1', 1),
      (error) => error.code === 'invalid-argument',
    );
    assert.throws(
      () =>
        normalizeAuditEventPayload(
          {
            entityType: 'match',
            entityId: 'match-1',
            action: 'matchCreated',
            metadata: ['not-a-map'],
          },
          'actor-1',
          1,
        ),
      (error) => error.code === 'invalid-argument',
    );
  });

  it('rejects oversized nested payloads', () => {
    assert.throws(
      () =>
        normalizeAuditEventPayload(
          {
            entityType: 'match',
            entityId: 'match-1',
            action: 'matchCreated',
            metadata: {value: 'x'.repeat(20_001)},
          },
          'actor-1',
          1,
        ),
      (error) => error.code === 'invalid-argument',
    );
  });
});
