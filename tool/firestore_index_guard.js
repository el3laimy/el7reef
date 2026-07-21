const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const indexConfig = readJson(path.join(root, 'firestore.indexes.json'));
const baseline = readJson(path.join(__dirname, 'firestore_index_baseline.json'));
const signatures = indexConfig.indexes.map(indexSignature);
const signatureSet = new Set(signatures);
const violations = [];

if (signatureSet.size !== signatures.length) {
  violations.push('firestore.indexes.json contains duplicate composite indexes');
}
for (const requiredSignature of baseline.requiredSignatures) {
  if (!signatureSet.has(requiredSignature)) {
    violations.push(`missing production index: ${requiredSignature}`);
  }
}

if (violations.length > 0) {
  process.stderr.write(`Firestore index guard failed:\n${violations.join('\n')}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(
    `Firestore index guard passed (${baseline.requiredSignatures.length} production indexes preserved).\n`,
  );
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function indexSignature(index) {
  const fields = index.fields
    .map((field) => `${field.fieldPath}:${field.order ?? field.arrayConfig}`)
    .join(',');
  return `${index.queryScope}|${index.collectionGroup}|${fields}`;
}
