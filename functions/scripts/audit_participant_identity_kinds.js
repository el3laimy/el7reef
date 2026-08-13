#!/usr/bin/env node
'use strict';

const {getApps, initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');

const VALID_KINDS = new Set(['player', 'guestPlayer', 'matchSidePlayer']);

function classifyActor(actor) {
  if (!actor || typeof actor !== 'object' || Array.isArray(actor)) {
    return {classification: 'missingActor', kind: null};
  }
  const kind = typeof actor.kind === 'string' ? actor.kind.trim() : '';
  const id = typeof actor.id === 'string' ? actor.id.trim() : '';
  const displayName = typeof actor.displayName === 'string'
    ? actor.displayName.trim()
    : '';
  if (!VALID_KINDS.has(kind)) {
    return {classification: 'invalidKind', kind: kind || null};
  }
  if (!id) return {classification: 'missingId', kind};
  if (!displayName) return {classification: 'missingDisplayName', kind};
  return {classification: 'valid', kind};
}

async function auditParticipantIdentityKinds({db, sampleLimit = 20}) {
  const snapshot = await db.collection('matchEvents').select('actor').get();
  const counts = {
    total: snapshot.size,
    valid: 0,
    missingActor: 0,
    invalidKind: 0,
    missingId: 0,
    missingDisplayName: 0,
    byKind: {player: 0, guestPlayer: 0, matchSidePlayer: 0},
  };
  const invalidSamples = [];
  for (const document of snapshot.docs) {
    const result = classifyActor(document.data().actor);
    counts[result.classification] += 1;
    if (result.classification === 'valid') {
      counts.byKind[result.kind] += 1;
    } else if (invalidSamples.length < sampleLimit) {
      invalidSamples.push({documentId: document.id, ...result});
    }
  }
  return {collection: 'matchEvents', counts, invalidSamples};
}

async function main() {
  const projectId = process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.argv[2];
  if (getApps().length === 0) {
    initializeApp(projectId ? {projectId} : undefined);
  }
  const report = await auditParticipantIdentityKinds({
    db: getFirestore(),
  });
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  const invalidCount = report.counts.total - report.counts.valid;
  if (invalidCount > 0) process.exitCode = 2;
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`Participant identity audit failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {auditParticipantIdentityKinds, classifyActor};
