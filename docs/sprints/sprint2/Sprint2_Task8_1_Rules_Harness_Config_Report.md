# Sprint 2 / Task 8.1 - Rules Harness Config Path Fix

## Summary

Fixed the Firestore rules test harness config so claim-code rules tests run from the repository without a temporary manual config file.

The invalid nested config `test/rules/firebase.json` was removed because Firebase CLI treats `test/rules` as the project directory for that config and rejects `../../firestore.rules` as outside the project directory.

## Files Changed

- `firebase.rules.test.json`
- `package.json`
- `package-lock.json`
- `test/rules/claim_codes.rules.test.js`
- `docs/Sprint2_Task8_Revised_Claim_Code_Rules_Report.md`
- `docs/Sprint2_Task8_1_Rules_Harness_Config_Report.md`
- removed `test/rules/firebase.json`

## Harness Command

Preferred command:

```bash
npm run test:rules:emulator
```

Equivalent explicit command:

```bash
env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"
```

The committed root-level `firebase.rules.test.json` points to:

- `firestore.rules`
- `firestore.indexes.json`

Both paths stay inside the Firebase project directory because the config file lives at the repository root.

`firebase-tools` is now a dev dependency so `npx firebase-tools` works after `npm ci` without relying on a global install or a live package fetch during the test command.

The rules test project id was aligned to the Firebase emulator demo project id (`demo-no-project`) to avoid single-project-mode warnings.

## Behavior Changes

No app behavior changed.

No Firestore rule logic changed.

No claim repository or `ShareLinkService` logic changed.

## Commands Run

- `npm ci`
  - Result: passed
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`
  - Result: passed, `7 passing`
- `dart analyze lib/`
  - Result: passed
- `flutter test`
  - Result: passed

## Final Result

The claimCodes rules tests now run through committed repo config and pass without relying on `fake_cloud_firestore` for security-rule validation.
