const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { writeSting } = require('../../tool/generate_pride_sting');

const expectedDigest =
  'e21819e04ebbc18f7c426f9e1b7de98fffebbc9e4891f44b23fc851a6f4d755b';

test('generator emits the reviewed 1.2 second PCM Pride sting', (context) => {
  const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'el7reef-sting-'));
  context.after(() => fs.rmSync(temporaryRoot, { recursive: true, force: true }));
  const { outputPath } = writeSting(temporaryRoot);
  const wav = fs.readFileSync(outputPath);
  const digest = crypto.createHash('sha256').update(wav).digest('hex');

  assert.equal(digest, expectedDigest);
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.toString('ascii', 8, 12), 'WAVE');
  assert.equal(wav.readUInt16LE(20), 1);
  assert.equal(wav.readUInt16LE(22), 1);
  assert.equal(wav.readUInt32LE(24), 48_000);
  assert.equal(wav.readUInt16LE(34), 16);
  assert.equal(wav.readUInt32LE(40), 115_200);
});
