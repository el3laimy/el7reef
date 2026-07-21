const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const sampleRate = 48_000;
const durationSeconds = 1.2;
let noiseState = 0x7e1c0de;

function deterministicNoise() {
  noiseState ^= noiseState << 13;
  noiseState ^= noiseState >>> 17;
  noiseState ^= noiseState << 5;
  return ((noiseState >>> 0) / 0xffffffff) * 2 - 1;
}

function noteEnvelope(time, start, end) {
  if (time < start || time >= end) return 0;
  const attack = Math.min(1, (time - start) / 0.025);
  const release = Math.min(1, (end - time) / 0.08);
  return attack * release;
}

function motifTone(time, start, end, frequency) {
  const envelope = noteEnvelope(time, start, end);
  if (envelope === 0) return 0;
  const phase = 2 * Math.PI * frequency * (time - start);
  return envelope * (Math.sin(phase) + 0.18 * Math.sin(phase * 2));
}

function impact(time) {
  if (time >= 0.14) return 0;
  const decay = Math.exp(-time * 34);
  const fallingThump = Math.sin(2 * Math.PI * (105 - 190 * time) * time);
  return decay * (0.58 * fallingThump + 0.24 * deterministicNoise());
}

function sampleAt(time) {
  const motif =
    motifTone(time, 0.16, 0.43, 329.63) +
    motifTone(time, 0.40, 0.69, 392.0) +
    motifTone(time, 0.65, 1.04, 493.88);
  return Math.tanh(0.92 * impact(time) + 0.24 * motif) * 0.82;
}

function synthesizePcm() {
  noiseState = 0x7e1c0de;
  const sampleCount = Math.round(sampleRate * durationSeconds);
  const pcm = Buffer.alloc(sampleCount * 2);
  for (let index = 0; index < sampleCount; index += 1) {
    const amplitude = Math.round(sampleAt(index / sampleRate) * 0x7fff);
    pcm.writeInt16LE(amplitude, index * 2);
  }
  return pcm;
}

function wavHeader(pcmByteLength) {
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcmByteLength, 4);
  header.write('WAVEfmt ', 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcmByteLength, 40);
  return header;
}

function writeSting(rootDirectory = process.cwd()) {
  const pcm = synthesizePcm();
  const wav = Buffer.concat([wavHeader(pcm.length), pcm]);
  const outputPath = path.join(
    rootDirectory,
    'android/app/src/main/res/raw/pride_sting.wav',
  );
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, wav);
  const digest = crypto.createHash('sha256').update(wav).digest('hex');
  return { outputPath, digest };
}

if (require.main === module) {
  const generated = writeSting();
  process.stdout.write(
    `${generated.outputPath}\nsha256=${generated.digest}\n`,
  );
}

module.exports = { writeSting };
