const assert = require('assert');

describe('Cloud Functions entrypoint', () => {
  it('loads every V1 callable with the installed Functions SDK', () => {
    const entrypoint = require('../../functions');
    const callableNames = [
      'submitMatchSettlement',
      'approveMatchScore',
      'recordAuditEvent',
      'deleteAccountData',
      'reportUserContent',
      'blockUser',
    ];

    for (const callableName of callableNames) {
      assert.strictEqual(typeof entrypoint[callableName], 'function');
    }
  });
});
