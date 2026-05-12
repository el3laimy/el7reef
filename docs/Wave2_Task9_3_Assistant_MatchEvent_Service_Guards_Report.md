# Wave 2 / Task 9.3: Assistant Permission Service Guards for MatchEvents

## Summary

Updated `MatchEventService` authorization so Dart service guards now match the Task 9.2 Firestore policy for goal/MVP `MatchEvents`.

For tournament matches, goal/MVP event creation is now allowed when the actor is either:

- the match organizer
- an active canonical tournament assistant with `canRecordGoalsAndMvp`

Friendly/non-tournament matches remain organizer-only.

No Firestore rules, UI, routes, `ScoreSubmitController`, tournament lifecycle, fixture, participant, claim flow, or structural permission behavior was changed in this task.

## Files Changed

- `lib/core/services/match_event_service.dart`
- `test/core/services/match_event_service_test.dart`
- `docs/Wave2_Task9_3_Assistant_MatchEvent_Service_Guards_Report.md`

## Authorization Strategy

`MatchEventService` still loads the match document by `matchId` before creating an event.

The guard now applies this order:

1. Validate `matchId` and `createdBy` are present.
2. Load the match document from `matches/{matchId}`.
3. Deny with Arabic match-not-found error if missing.
4. Derive `matchTournamentId` from the match document.
5. If caller passed `tournamentId`, require it to match `matchTournamentId`.
6. Allow immediately if `createdBy == match.organizerId`.
7. If no `matchTournamentId`, deny assistant fallback.
8. Load canonical assistant permission doc for `matchTournamentId` and `createdBy`.
9. Allow only if the assistant is active and has `canRecordGoalsAndMvp`.
10. Otherwise deny with the existing Arabic no-permission error.

## TournamentId Derivation

The service derives tournament scope from the match document, not from caller input alone.

If caller-provided `tournamentId` exists, the service verifies it matches the match's `tournamentId`.

When creating the final `MatchEvent`, the persisted `tournamentId` is the derived match tournament id. This allows safe assistant creation even when the caller omits `tournamentId`, while still denying mismatches.

## Assistant Permission Repository Usage

`MatchEventService` now depends on `TournamentAssistantPermissionRepository`.

Default implementation:

`TournamentAssistantPermissionRepositoryImpl`

Canonical source:

`tournaments/{tournamentId}/assistants/{userId}`

The old embedded `Tournament.assistants` list is not used as a security source.

Assistant permission repository read failures are caught and converted to the same safe no-permission Arabic domain error.

## Organizer Behavior

Organizer behavior is preserved:

- organizer can record goal events
- organizer can record MVP events
- organizer can record events for friendly/non-tournament matches
- existing MatchEvent repository behavior remains unchanged

## Assistant Behavior

Allowed:

- active assistant with `canRecordGoalsAndMvp` can record goal events for tournament matches in their tournament
- active assistant with `canRecordGoalsAndMvp` can record MVP events for tournament matches in their tournament

Denied:

- assistant without `canRecordGoalsAndMvp`
- revoked assistant
- assistant from another tournament
- random authenticated user
- tournament id mismatch
- missing match

## Friendly Match Behavior

Friendly/non-tournament matches do not use assistant permissions.

If a match has no `tournamentId`, only the existing organizer path can create goal/MVP events.

## Tests Added/Updated

Updated `test/core/services/match_event_service_test.dart` with coverage for:

- organizer can record goal and MVP events
- active assistant with `canRecordGoalsAndMvp` can record a goal
- active assistant with `canRecordGoalsAndMvp` can record an MVP
- assistant-created event uses the match-derived tournament id
- assistant without `canRecordGoalsAndMvp` cannot record goal/MVP
- revoked assistant cannot record goal/MVP
- assistant from another tournament cannot record goal/MVP
- random user cannot record goal/MVP
- tournament id mismatch is denied
- friendly/non-tournament match remains organizer-only and ignores assistant permissions

Existing score submit and top scorers tests passed in the full Flutter test suite.

## Commands Run

- `flutter pub get`: passed
- `dart format lib/core/services/match_event_service.dart test/core/services/match_event_service_test.dart`: passed
- `dart analyze lib/`: passed
- `flutter test test/core/services/match_event_service_test.dart`: passed, `13 passing`
- `flutter test`: passed, `397 passing`
- `npm run test:rules:emulator`: blocked before test execution because `firebase-tools@15.13.0` requires Node `>=20.0.0 || >=22.0.0 || >=24.0.0`; current Node is `v18.19.1`
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools@13.35.1 --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`: ran but failed one unrelated untracked `backend_security.rules.test.js` test for expired reserved username claiming
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools@13.35.1 --config firebase.rules.test.json emulators:exec --only firestore "npx mocha test/rules/claim_codes.rules.test.js test/rules/tournament_assistant_permissions.rules.test.js test/rules/tournament_permissions.rules.test.js --timeout 20000"`: passed, `112 passing`

## Final Result

Task 9.3 implementation is complete.

`MatchEventService` now allows organizers and active canonical assistants with `canRecordGoalsAndMvp` to create goal/MVP events for tournament matches. Unauthorized assistants, revoked assistants, wrong-tournament assistants, random users, tournament mismatches, and friendly-match assistant attempts are denied.

## Remaining Risks

- assistant UI is not implemented
- assistant route guards are not implemented
- assistant score submit/start/approve/forfeit service guards are not implemented
- assistant match update permissions remain deferred
- npm rules emulator script still requires Node 20+ because installed Firebase CLI 15 is incompatible with Node 18
- full all-rules compatible run currently includes an unrelated untracked backend security reserved-username test failure outside Task 9.3 scope
