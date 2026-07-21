const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const budgets = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'hotspot_budget.json'), 'utf8'),
);
const rows = dartFiles(path.join(root, 'lib'))
  .map((absoluteFile) => ({
    file: normalize(path.relative(root, absoluteFile)),
    lines: lineCount(fs.readFileSync(absoluteFile, 'utf8')),
  }))
  .sort((left, right) => right.lines - left.lines || left.file.localeCompare(right.file));

process.stdout.write('| Lines | Budget | Production file |\n');
process.stdout.write('| ---: | ---: | --- |\n');
for (const row of rows.slice(0, 20)) {
  process.stdout.write(`| ${row.lines} | ${budgets[row.file] ?? 'observe'} | ${row.file} |\n`);
}

if (process.argv.includes('--check')) {
  const violations = Object.entries(budgets).flatMap(([file, budget]) => {
    const row = rows.find((candidate) => candidate.file === file);
    if (!row) return [`missing budgeted file: ${file}`];
    return row.lines > budget
      ? [`${file}: ${row.lines} lines exceeds budget ${budget}`]
      : [];
  });
  if (violations.length > 0) {
    process.stderr.write(`Hotspot budget failed:\n${violations.join('\n')}\n`);
    process.exitCode = 1;
  } else {
    process.stdout.write(`Hotspot budget passed (${Object.keys(budgets).length} guarded files).\n`);
  }
}

function dartFiles(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) return dartFiles(target);
    return entry.isFile() && entry.name.endsWith('.dart') ? [target] : [];
  });
}

function lineCount(source) {
  if (source.length === 0) return 0;
  return source.endsWith('\n') ? source.split('\n').length - 1 : source.split('\n').length;
}

function normalize(value) {
  return value.split(path.sep).join('/');
}
