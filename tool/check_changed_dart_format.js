const {execFileSync, spawnSync} = require('child_process');

const baseSha = process.env.BASE_SHA?.trim();
const diffArgs = ['diff', '--name-only', '--diff-filter=ACMR'];
if (baseSha && !/^0+$/.test(baseSha)) {
  diffArgs.push(baseSha, 'HEAD');
}
diffArgs.push('--', '*.dart');

const files = execFileSync('git', diffArgs, {encoding: 'utf8'})
  .split('\n')
  .map((file) => file.trim())
  .filter(Boolean);

if (files.length === 0) {
  process.stdout.write('No changed Dart files to format-check.\n');
  process.exit(0);
}

const result = spawnSync(
  'dart',
  ['format', '--output=none', '--set-exit-if-changed', ...files],
  {stdio: 'inherit'},
);
if (result.error) throw result.error;
process.exit(result.status ?? 1);
