const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_MASTER_PATH = 'docs/core/00_Master_Product_Development_Plan.md';
const DEFAULT_MANIFEST_PATH = 'docs/archive/PLANNING_RETIREMENT_MANIFEST.md';
const ALLOWED_STATUSES = new Set([
  'INBOX',
  'READY',
  'ACTIVE',
  'BLOCKED',
  'DONE',
  'PARKED',
  'REJECTED',
  'DUPLICATE',
]);
const RETIRED_PATHS = [
  'product_plan.md',
  'engineering_plan.md',
  'implementation_backlog.md',
  'implementation_backlog_v2.md',
  'master_reference_alignment_gap_plan_ar.md',
  'post_tournament_vision_priority_ar.md',
  'tournament_repair_sprint_plan_ar.md',
  'tournament_tos_execution_rules.md',
  'tournament_tos_pilot_pass_checklist_ar.md',
  'tournament_tos_remaining_plan_ar.md',
  'docs/core/05_Project_Roadmap_and_Sprint_Plan.md',
  'docs/core/06_UX_Hardening_And_Liquid_Glass_Plan.md',
  'docs/core/07_Tournament_Ego_UX_Audit_And_Repair_Plan.md',
  'docs/core/08_Unified_V1_Completion_And_Workspace_Plan.md',
  'docs/core/15_Team_Lineup_Ultimate_Squad_Redesign_Plan.md',
  'docs/core/16_Architecture_Technical_Debt_Remediation_Tasks.md',
  'docs/core/17_V1_Security_And_Release_Completion_Plan.md',
  'docs/blueprints/El7reef_V1_Complete_Documentation.md',
  'docs/blueprints/el_7_reef_complete_product_blueprint_draft_0.md',
  'docs/blueprints/el_7_reef_master_blueprint_working_version.md',
  'docs/sprints/sprint2/Sprint2_Task6_Claim_Code_Security_Hardening_Plan.md',
];
const SKIPPED_DIRECTORIES = new Set([
  '.dart_tool',
  '.git',
  '.agents',
  '.codex',
  'build',
  'node_modules',
]);

function checkDocs(options = {}) {
  const root = path.resolve(options.root ?? path.join(__dirname, '..'));
  const masterPath = options.masterPath ?? DEFAULT_MASTER_PATH;
  const manifestPath = options.manifestPath ?? DEFAULT_MANIFEST_PATH;
  const retiredPaths = options.retiredPaths ?? RETIRED_PATHS;
  const violations = [];
  const markdownDocuments = loadMarkdownDocuments(root);

  requireFile(root, masterPath, 'master plan', violations);
  requireFile(root, manifestPath, 'retirement manifest', violations);
  checkAuthorityPointers(root, masterPath, violations);
  checkSingleActivePlan(markdownDocuments, masterPath, violations);
  checkMarkdownLinks(root, markdownDocuments, violations);
  checkRetiredSources(root, markdownDocuments, manifestPath, retiredPaths, violations);
  checkMasterTicketCatalog(root, masterPath, violations);

  return {
    markdownFileCount: markdownDocuments.length,
    masterPath,
    violations,
  };
}

function requireFile(root, relativePath, label, violations) {
  if (!fs.existsSync(path.join(root, relativePath))) {
    violations.push(`missing ${label}: ${relativePath}`);
  }
}

function checkAuthorityPointers(root, masterPath, violations) {
  for (const relativePath of ['AGENTS.md', 'docs/README.md']) {
    const absolutePath = path.join(root, relativePath);
    if (!fs.existsSync(absolutePath)) {
      violations.push(`missing authority document: ${relativePath}`);
      continue;
    }
    const content = fs.readFileSync(absolutePath, 'utf8');
    if (!content.includes(masterPath)) {
      violations.push(`${relativePath} does not point to ${masterPath}`);
    }
  }
}

function checkSingleActivePlan(markdownDocuments, masterPath, violations) {
  const activePlans = [];
  const activePattern =
    /(المرجع الوحيد للأولوية والحالة والتنفيذ|المصدر التنفيذي الوحيد|\*\*(?:Status|الحالة):\*\*[^\n]*`ACTIVE`)/i;

  for (const document of markdownDocuments) {
    if (!/(plan|roadmap|backlog|blueprint)/i.test(path.basename(document.relativePath))) {
      continue;
    }
    if (activePattern.test(document.content)) {
      activePlans.push(document.relativePath);
    }
  }

  if (activePlans.length !== 1 || activePlans[0] !== masterPath) {
    violations.push(
      `expected one active plan (${masterPath}), found: ${activePlans.join(', ') || 'none'}`,
    );
  }
}

function checkMarkdownLinks(root, markdownDocuments, violations) {
  const markdownLinkPattern = /!?\[[^\]]*\]\(([^)]+)\)/g;

  for (const document of markdownDocuments) {
    for (const match of document.content.matchAll(markdownLinkPattern)) {
      const target = normalizeMarkdownTarget(match[1]);
      if (!target || isExternalTarget(target)) {
        continue;
      }
      const withoutFragment = target.split('#', 1)[0].split('?', 1)[0];
      if (!withoutFragment) {
        continue;
      }
      let decodedTarget;
      try {
        decodedTarget = decodeURIComponent(withoutFragment);
      } catch (error) {
        if (!(error instanceof URIError)) {
          throw error;
        }
        violations.push(`${document.relativePath} has an invalid encoded link: ${target}`);
        continue;
      }
      const resolved = decodedTarget.startsWith('/')
        ? path.join(root, decodedTarget.slice(1))
        : path.resolve(path.dirname(document.absolutePath), decodedTarget);
      if (!fs.existsSync(resolved)) {
        violations.push(`${document.relativePath} has a broken link: ${target}`);
      }
    }
  }
}

function normalizeMarkdownTarget(rawTarget) {
  const trimmed = rawTarget.trim();
  if (trimmed.startsWith('<')) {
    const end = trimmed.indexOf('>');
    return end === -1 ? trimmed.slice(1) : trimmed.slice(1, end);
  }
  return trimmed.replace(/\s+(?:"[^"]*"|'[^']*'|\([^)]*\))\s*$/, '');
}

function isExternalTarget(target) {
  return (
    target.startsWith('#') ||
    target.startsWith('//') ||
    /^[a-z][a-z0-9+.-]*:/i.test(target)
  );
}

function checkRetiredSources(
  root,
  markdownDocuments,
  manifestPath,
  retiredPaths,
  violations,
) {
  const manifestAbsolutePath = path.join(root, manifestPath);
  const manifest = fs.existsSync(manifestAbsolutePath)
    ? fs.readFileSync(manifestAbsolutePath, 'utf8')
    : '';

  for (const retiredPath of retiredPaths) {
    if (fs.existsSync(path.join(root, retiredPath))) {
      violations.push(`retired planning source still exists: ${retiredPath}`);
    }
    if (!manifest.includes(retiredPath)) {
      violations.push(`retirement manifest does not cover: ${retiredPath}`);
    }
    const retiredBasename = path.basename(retiredPath);
    for (const document of markdownDocuments) {
      if (document.relativePath === manifestPath) {
        continue;
      }
      if (document.content.includes(retiredBasename)) {
        violations.push(
          `${document.relativePath} still references retired source: ${retiredBasename}`,
        );
      }
    }
  }
}

function checkMasterTicketCatalog(root, masterPath, violations) {
  const absolutePath = path.join(root, masterPath);
  if (!fs.existsSync(absolutePath)) {
    return;
  }
  const content = fs.readFileSync(absolutePath, 'utf8');
  const { definitions, ranges } = parseTicketDefinitions(content, violations);

  verifyTicketStatuses(definitions, ranges, violations);
}

function parseTicketDefinitions(content, violations) {
  const definitions = new Map();
  const ranges = [];

  for (const line of content.split(/\r?\n/)) {
    if (!line.startsWith('|')) {
      continue;
    }
    const cells = line
      .split('|')
      .slice(1, -1)
      .map((cell) => cell.trim());
    if (cells.length === 0) {
      continue;
    }
    const rangeMatch = cells[0].match(/`(ELR-([A-Z]+)-(\d+)\.\.(\d+))`/);
    if (rangeMatch) {
      const status = findAllowedStatus(cells);
      ranges.push({
        domain: rangeMatch[2],
        start: Number(rangeMatch[3]),
        end: Number(rangeMatch[4]),
        status,
      });
      if (!status) {
        violations.push(`ticket range ${rangeMatch[1]} has no allowed status`);
      }
      continue;
    }
    const idMatch = cells[0].match(/`(ELR-([A-Z]+)-(\d+))`/);
    if (!idMatch) {
      continue;
    }
    const id = idMatch[1];
    if (definitions.has(id)) {
      violations.push(`duplicate ticket definition: ${id}`);
      continue;
    }
    definitions.set(id, { cells, domain: idMatch[2], number: Number(idMatch[3]) });
  }

  return { definitions, ranges };
}

function verifyTicketStatuses(definitions, ranges, violations) {
  if (definitions.size === 0) {
    violations.push('master plan defines no ELR tickets or ideas');
    return;
  }
  for (const [id, definition] of definitions) {
    const directStatus = findAllowedStatus(definition.cells);
    const inheritedStatus = ranges.find(
      (range) =>
        range.domain === definition.domain &&
        definition.number >= range.start &&
        definition.number <= range.end,
    )?.status;
    if (!directStatus && !inheritedStatus) {
      violations.push(`${id} has no allowed status in its row or live status range`);
    }
  }
}

function findAllowedStatus(cells) {
  for (const cell of cells) {
    for (const match of cell.matchAll(/`([A-Z]+)`/g)) {
      if (ALLOWED_STATUSES.has(match[1])) {
        return match[1];
      }
    }
  }
  return null;
}

function loadMarkdownDocuments(root) {
  const documents = [];
  walkMarkdownDirectory(root, '');
  return documents.sort((left, right) => left.relativePath.localeCompare(right.relativePath));

  function walkMarkdownDirectory(absoluteDirectory, relativeDirectory) {
    for (const entry of fs.readdirSync(absoluteDirectory, { withFileTypes: true })) {
      if (entry.isDirectory() && SKIPPED_DIRECTORIES.has(entry.name)) {
        continue;
      }
      const absolutePath = path.join(absoluteDirectory, entry.name);
      const relativePath = path.join(relativeDirectory, entry.name).split(path.sep).join('/');
      if (entry.isDirectory()) {
        walkMarkdownDirectory(absolutePath, relativePath);
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.md')) {
        documents.push({
          absolutePath,
          content: fs.readFileSync(absolutePath, 'utf8'),
          relativePath,
        });
      }
    }
  }
}

if (require.main === module) {
  const checkResult = checkDocs();
  if (checkResult.violations.length > 0) {
    process.stderr.write(
      `Documentation plan guard failed:\n${checkResult.violations.join('\n')}\n`,
    );
    process.exitCode = 1;
  } else {
    process.stdout.write(
      `Documentation plan guard passed (${checkResult.markdownFileCount} Markdown files, one active plan).\n`,
    );
  }
}

module.exports = {
  ALLOWED_STATUSES,
  DEFAULT_MANIFEST_PATH,
  DEFAULT_MASTER_PATH,
  RETIRED_PATHS,
  checkDocs,
};
