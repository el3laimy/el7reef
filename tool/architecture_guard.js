const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const libRoot = path.join(root, 'lib');
const allowlist = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'architecture_allowlist.json'), 'utf8'),
);

const rules = [
  {
    name: 'viewDataImports',
    applies: (file) => file.includes('/views/'),
    pattern: /^import\s+['"][^'"]*\/data\//m,
    message: 'views must depend on controllers/services, not data implementations',
  },
  {
    name: 'controllerFirestoreAccess',
    applies: (file) => file.includes('/controllers/'),
    pattern: /cloud_firestore|FirebaseFirestore|\.collection\(FirebasePaths\./,
    message: 'controllers must delegate Firestore access to a service/repository',
  },
  {
    name: 'controllerSensitiveWrites',
    applies: (file) => file.includes('/controllers/'),
    pattern:
      /_matchEventService\.(recordGoal|recordGoals|recordMvp|voidEvent)\(|updatePrideEventsPending\(/,
    message: 'score, MatchEvent, and settlement-state writes must use the server settlement boundary',
  },
  {
    name: 'clientAnalyticsAccess',
    applies: () => true,
    pattern:
      /FirebasePaths\.analyticsEvents|\.collection\(\s*['"]analyticsEvents['"]\s*\)/,
    message: 'ELR-SEC-105 forbids Flutter reads and writes to analyticsEvents',
  },
  {
    name: 'clientBlockAuthorityWrites',
    applies: () => true,
    pattern:
      /FriendshipStatus\.blocked|['"]blockedIds['"]\s*:\s*FieldValue\.(arrayUnion|arrayRemove)/,
    message: 'ELR-SEC-106 requires block state changes through trusted callables',
  },
];

const files = dartFiles(libRoot);
const violations = [];
const usedAllowlist = new Set();

for (const absoluteFile of files) {
  const relativeFile = normalize(path.relative(root, absoluteFile));
  const normalizedForRule = `/${relativeFile}`;
  const source = fs.readFileSync(absoluteFile, 'utf8');
  for (const rule of rules) {
    if (!rule.applies(normalizedForRule) || !rule.pattern.test(source)) continue;
    const allowed = new Set(allowlist[rule.name] || []);
    if (allowed.has(relativeFile)) {
      usedAllowlist.add(`${rule.name}:${relativeFile}`);
      continue;
    }
    violations.push(`${rule.name}: ${relativeFile} — ${rule.message}`);
  }
}

for (const rule of rules) {
  for (const allowedFile of allowlist[rule.name] || []) {
    const key = `${rule.name}:${allowedFile}`;
    if (!usedAllowlist.has(key)) {
      violations.push(`${rule.name}: stale allowlist entry — ${allowedFile}`);
    }
  }
}

if (violations.length > 0) {
  process.stderr.write(`Architecture guard failed:\n${violations.join('\n')}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(`Architecture guard passed (${files.length} Dart files).\n`);
}

function dartFiles(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) return dartFiles(target);
    return entry.isFile() && entry.name.endsWith('.dart') ? [target] : [];
  });
}

function normalize(value) {
  return value.split(path.sep).join('/');
}
