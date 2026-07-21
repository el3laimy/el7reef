const firebaseAuth = require('firebase-tools/lib/auth');
const firebaseRules = require('firebase-tools/lib/gcp/rules');

const FIRESTORE_RELEASE = 'cloud.firestore';

async function main() {
  const rollbackRequest = parseRollbackRequest(process.argv.slice(2));
  authorizeFirebaseCli();
  const rollbackSummary = await restoreRuleset(rollbackRequest);
  process.stdout.write(`${JSON.stringify(rollbackSummary)}\n`);
}

async function restoreRuleset({projectId, rulesetName, mode}) {
  const activeRuleset = await firebaseRules.getLatestRulesetName(
    projectId,
    FIRESTORE_RELEASE,
  );
  const targetFiles = await firebaseRules.getRulesetContent(rulesetName);
  if (targetFiles.length === 0) {
    throw new Error(`Ruleset has no files: ${rulesetName}`);
  }
  if (mode === '--apply' && activeRuleset !== rulesetName) {
    await firebaseRules.updateRelease(
      projectId,
      rulesetName,
      FIRESTORE_RELEASE,
    );
  }
  return {projectId, activeRuleset, targetRuleset: rulesetName, mode};
}

function parseRollbackRequest(argumentsList) {
  const [projectId, rulesetName, mode = '--dry-run'] = argumentsList;
  if (!projectId || !rulesetName) {
    throw new Error(
      'Usage: node tool/firestore_ruleset_rollback.js <project-id> <ruleset-name> [--dry-run|--apply]',
    );
  }
  const requiredPrefix = `projects/${projectId}/rulesets/`;
  if (!rulesetName.startsWith(requiredPrefix)) {
    throw new Error(`Ruleset must start with ${requiredPrefix}`);
  }
  if (!['--dry-run', '--apply'].includes(mode)) {
    throw new Error(`Unsupported mode: ${mode}`);
  }
  return {projectId, rulesetName, mode};
}

function authorizeFirebaseCli() {
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI login is required.');
  }
  firebaseAuth.setRefreshToken(account.tokens.refresh_token);
}

main().catch((error) => {
  process.stderr.write(`Firestore rules rollback failed: ${error.message}\n`);
  process.exitCode = 1;
});
