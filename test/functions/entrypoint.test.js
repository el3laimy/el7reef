const assert = require('assert');

describe('Cloud Functions entrypoint', () => {
  it('loads V1 callables and the private deletion worker', () => {
    const entrypoint = require('../../functions');
    const callableNames = [
      'submitMatchSettlement',
      'approveMatchScore',
      'deleteAccountData',
      'reportUserContent',
      'blockUser',
      'unblockUser',
      'issueGuestClaimCode',
      'inspectGuestClaim',
      'claimGuestPlayer',
      'claimGuestTeam',
    ];

    for (const callableName of callableNames) {
      assert.strictEqual(typeof entrypoint[callableName], 'function');
    }
    assert.strictEqual(
      typeof entrypoint.processAccountDeletionRequest,
      'function',
    );
    assert.strictEqual(entrypoint.recordAuditEvent, undefined);
  });
});
