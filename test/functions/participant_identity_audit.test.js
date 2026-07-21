const assert = require('assert');

const {
  auditParticipantIdentityKinds,
  classifyActor,
} = require('../../functions/scripts/audit_participant_identity_kinds');

describe('participant identity audit', () => {
  it('classifies valid and invalid actor shapes without rewriting them', () => {
    assert.deepStrictEqual(
      classifyActor({kind: 'guestPlayer', id: 'guest-1', displayName: 'ضيف'}),
      {classification: 'valid', kind: 'guestPlayer'},
    );
    assert.deepStrictEqual(
      classifyActor({kind: 'legacyPlayer', id: 'player-1', displayName: 'قديم'}),
      {classification: 'invalidKind', kind: 'legacyPlayer'},
    );
    assert.deepStrictEqual(
      classifyActor(null),
      {classification: 'missingActor', kind: null},
    );
  });

  it('returns counts and bounded invalid document samples', async () => {
    const documents = [
      {id: 'valid', data: () => ({actor: {kind: 'player', id: 'p1', displayName: 'P1'}})},
      {id: 'bad-kind', data: () => ({actor: {kind: 'legacy', id: 'p2', displayName: 'P2'}})},
      {id: 'bad-id', data: () => ({actor: {kind: 'guestPlayer', id: '', displayName: 'Guest'}})},
    ];
    const db = {
      collection: () => ({
        select: () => ({
          get: async () => ({size: documents.length, docs: documents}),
        }),
      }),
    };

    const report = await auditParticipantIdentityKinds({db, sampleLimit: 1});

    assert.strictEqual(report.counts.total, 3);
    assert.strictEqual(report.counts.valid, 1);
    assert.strictEqual(report.counts.invalidKind, 1);
    assert.strictEqual(report.counts.missingId, 1);
    assert.deepStrictEqual(report.counts.byKind, {
      player: 1,
      guestPlayer: 0,
      matchSidePlayer: 0,
    });
    assert.strictEqual(report.invalidSamples.length, 1);
    assert.strictEqual(report.invalidSamples[0].documentId, 'bad-kind');
  });
});
