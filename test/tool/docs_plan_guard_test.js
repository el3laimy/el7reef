const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { checkDocs } = require('../../tool/docs_plan_guard');

function createFixture(context) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'el7reef-docs-guard-'));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  write(root, 'AGENTS.md', 'Authority: docs/core/00_Master_Product_Development_Plan.md\n');
  write(root, 'docs/README.md', 'Authority: docs/core/00_Master_Product_Development_Plan.md\n');
  write(
    root,
    'docs/core/00_Master_Product_Development_Plan.md',
    [
      '# Master Plan',
      '**الحالة:** `ACTIVE` — المرجع الوحيد للأولوية والحالة والتنفيذ',
      '',
      '| المعرف | الأفق | الحالة |',
      '| :--- | :--- | :--- |',
      '| `ELR-SEC-001` | `V1` | `READY` |',
      '',
      '[دليل](../../evidence.md)',
    ].join('\n'),
  );
  write(root, 'docs/archive/PLANNING_RETIREMENT_MANIFEST.md', '# Recovery map\n');
  write(root, 'evidence.md', '# Evidence\n');
  return root;
}

test('accepts one master plan with valid links and unique ticket definitions', (context) => {
  const root = createFixture(context);
  const checkResult = checkDocs({ root, retiredPaths: [] });
  assert.deepEqual(checkResult.violations, []);
});

test('reports a broken internal Markdown link', (context) => {
  const root = createFixture(context);
  write(
    root,
    'docs/core/00_Master_Product_Development_Plan.md',
    `${fs.readFileSync(path.join(root, 'docs/core/00_Master_Product_Development_Plan.md'))}\n[مفقود](missing.md)\n`,
  );
  const checkResult = checkDocs({ root, retiredPaths: [] });
  assert.ok(checkResult.violations.some((violation) => violation.includes('broken link')));
});

test('reports a second active planning authority', (context) => {
  const root = createFixture(context);
  write(root, 'docs/roadmap_plan.md', '**Status:** `ACTIVE`\n');
  const checkResult = checkDocs({ root, retiredPaths: [] });
  assert.ok(
    checkResult.violations.some((violation) => violation.includes('expected one active plan')),
  );
});

test('reports duplicate ticket definitions', (context) => {
  const root = createFixture(context);
  const masterPath = path.join(root, 'docs/core/00_Master_Product_Development_Plan.md');
  fs.appendFileSync(masterPath, '\n| `ELR-SEC-001` | `V1` | `READY` |\n');
  const checkResult = checkDocs({ root, retiredPaths: [] });
  assert.ok(checkResult.violations.includes('duplicate ticket definition: ELR-SEC-001'));
});

test('reports retired files and references outside the recovery manifest', (context) => {
  const root = createFixture(context);
  write(root, 'old_plan.md', '# Old plan\n');
  write(root, 'notes.md', 'See old_plan.md\n');
  write(root, 'docs/archive/PLANNING_RETIREMENT_MANIFEST.md', 'old_plan.md\n');
  const checkResult = checkDocs({ root, retiredPaths: ['old_plan.md'] });
  assert.ok(checkResult.violations.some((violation) => violation.includes('still exists')));
  assert.ok(checkResult.violations.some((violation) => violation.includes('still references')));
});

function write(root, relativePath, content) {
  const absolutePath = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  fs.writeFileSync(absolutePath, content);
}
