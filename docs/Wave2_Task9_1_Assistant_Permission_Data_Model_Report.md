# Wave 2 / Task 9.1: Assistant Permission Data Model + Rules Test Plan

## Summary

Implemented the V1 assistant permission data foundation for limited matchday/results permissions.

The canonical source is now modeled as:

`tournaments/{tournamentId}/assistants/{userId}`

This task does not enable assistants to write matches or MatchEvents. It only adds the data model, repository, Firestore protection for assistant permission documents, and test coverage.

## Files Changed

- `lib/domain/entities/tournament_assistant_permission.dart`
- `lib/data/models/tournament_assistant_permission_model.dart`
- `lib/domain/repositories/tournament_assistant_permission_repository.dart`
- `lib/data/repositories/tournament_assistant_permission_repository_impl.dart`
- `firestore.rules`
- `test/rules/tournament_assistant_permissions.rules.test.js`
- `test/data/models/tournament_assistant_permission_model_test.dart`
- `test/data/repositories/tournament_assistant_permission_repository_impl_test.dart`
- `docs/Wave2_Task9_1_Assistant_Permission_Data_Model_Report.md`

## Data Model Shape

Entity: `TournamentAssistantPermission`

Path: `tournaments/{tournamentId}/assistants/{userId}`

Fields:

- `tournamentId`
- `userId`
- `addedBy`
- `status`: `active | revoked`
- `preset`: `resultsAssistant | matchdayAssistant | scoreApprover | customLimited`
- `permissions`
- `createdAt`
- `updatedAt`
- `revokedAt`

Allowed V1 permission keys only:

- `canViewMatchday`
- `canStartMatch`
- `canSubmitScore`
- `canRecordGoalsAndMvp`
- `canApproveScore`
- `canDeclareForfeit`

No structural permission fields exist in the Dart entity/model.

Immutable identity fields are represented as entity fields and are not exposed through `copyWith`:

- `tournamentId`
- `userId`
- `addedBy`
- `createdAt`

Helpers added:

- `isActive`
- `hasPermission(permission)`
- preset factories for `resultsAssistant`, `matchdayAssistant`, `scoreApprover`, and `customLimited`

## Repository Methods

Added `TournamentAssistantPermissionRepository` with:

- `getAssistantPermission(tournamentId, userId)`
- `listTournamentAssistants(tournamentId)`
- `createAssistantPermission(permission)`
- `updateAssistantPermissions(...)`
- `revokeAssistant(...)`

Implementation writes to the canonical subcollection only:

`tournaments/{tournamentId}/assistants/{userId}`

Document id is always `userId`.

## Firestore Rules Added

Added nested rules for:

`match /tournaments/{tournamentId}/assistants/{assistantUserId}`

Rules enforce:

- primary organizer can create valid assistant permission docs
- non-organizers cannot create assistant docs
- assistants cannot create their own docs
- organizer can update only `status`, `preset`, `permissions`, `updatedAt`, and `revokedAt`
- immutable fields cannot change: `tournamentId`, `userId`, `addedBy`, `createdAt`
- assistants cannot update their own permissions
- organizer can revoke by setting `status: revoked` and `revokedAt`
- hard delete is denied
- permission map must contain exactly the six V1 keys
- every permission value must be bool
- structural permission keys are denied by `hasOnly`
- `status` must be `active` or `revoked`
- `preset` must be one of the four V1 presets

No assistant permissions are used yet for match writes, MatchEvent writes, score submission, lifecycle services, fixtures, participants, or route guards.

## Read/Write Behavior

Read behavior:

- organizer can list/read all assistant docs for their own tournament
- assistant can directly read their own assistant doc
- non-organizer/non-assistant cannot read assistant docs
- unauthenticated access is denied
- revoked assistant docs remain readable to the organizer and that assistant only

Write behavior:

- organizer can create valid assistant docs under their own tournament
- organizer can update allowed mutable fields only
- organizer can revoke assistants
- hard delete is denied
- non-organizers, assistants, and anonymous users cannot write assistant docs

## Rules Tests Added

Added `test/rules/tournament_assistant_permissions.rules.test.js` covering:

- organizer can create valid assistant doc
- non-organizer cannot create assistant doc
- assistant cannot create own assistant doc
- organizer cannot create assistant doc for another organizer tournament
- organizer cannot include structural permission keys
- organizer cannot include non-bool permission values
- organizer cannot use unsupported preset
- organizer can update allowed permissions
- organizer can revoke assistant
- organizer cannot change immutable fields
- assistant cannot update own permissions
- hard delete is denied
- revoked assistant doc remains readable only to organizer and assistant
- non-authenticated access denied

The existing claim and tournament permission rules tests also passed in the compatible emulator run.

## Dart Tests Added

Added model tests:

- serialize/deserialize all V1 presets
- `hasPermission` respects active/revoked state
- structural permission keys cannot appear through model output
- revoked assistant is inactive

Added repository tests:

- create, get, list, update, and revoke assistant permissions under the canonical subcollection path
- document id remains `userId`

## Compatibility

The old embedded `Tournament.assistants` shape remains untouched.

This task does not migrate existing embedded assistants and does not remove compatibility code. New canonical reads/writes are isolated to `tournaments/{tournamentId}/assistants/{userId}`.

## Commands Run

- `flutter pub get`: passed
- `dart format lib/domain/entities/tournament_assistant_permission.dart lib/data/models/tournament_assistant_permission_model.dart lib/domain/repositories/tournament_assistant_permission_repository.dart lib/data/repositories/tournament_assistant_permission_repository_impl.dart test/data/models/tournament_assistant_permission_model_test.dart test/data/repositories/tournament_assistant_permission_repository_impl_test.dart`: passed
- `dart analyze lib/`: passed
- `flutter test test/data/models/tournament_assistant_permission_model_test.dart test/data/repositories/tournament_assistant_permission_repository_impl_test.dart`: passed
- `flutter test`: passed, `391 passing`
- `npm run test:rules:emulator`: blocked before test execution because `firebase-tools@15.13.0` requires Node `>=20.0.0 || >=22.0.0 || >=24.0.0`; current Node is `v18.19.1`
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools@13.35.1 --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`: passed, `94 passing`

## Final Result

Task 9.1 implementation is complete.

The assistant permission data foundation, repository, Firestore rules, rules tests, and Dart tests are in place. Assistants are not yet granted match or MatchEvent write permissions.

## Remaining Risks

- assistant match writes are not enabled yet
- assistant MatchEvent writes are not enabled yet
- route guards are still organizer-only
- UI assistant management is not updated
- old embedded assistants are not migrated
- service guards are not permission-policy-based yet
- local `npm run test:rules:emulator` needs Node 20+ or a Firebase CLI version compatible with Node 18
