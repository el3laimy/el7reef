# P0 Task 5 - Service-Layer Guard Hardening Report

## Summary

Added explicit service-layer authorization guards for sensitive tournament operation writes. The services now fail early with safe Arabic errors when the caller is not the organizer, before attempting Firestore writes.

Firestore rules remain the final authority, but tournament operations no longer rely only on controller/UI checks or Firestore denial.

No Firestore rules, UI, routes, lifecycle redesign, claim flow, fantasy, rating, or settlement logic was changed in this task.

## Files Changed

- `lib/core/services/tournament_lifecycle_service.dart`
- `lib/core/services/tournament_participant_service.dart`
- `lib/core/services/tournament_fixture_service.dart`
- `lib/core/services/match_event_service.dart`
- `test/core/services/tournament_lifecycle_service_test.dart`
- `test/core/services/tournament_participant_service_test.dart`
- `test/core/services/tournament_fixture_service_test.dart`
- `test/core/services/match_event_service_test.dart`
- `test/core/services/tournament_top_scorers_resolver_test.dart`
- `test/features/match/score_submit_controller_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `test/features/profile/public_player_profile_test.dart`
- `test/features/lineup/match_result_lineup_controller_test.dart`
- `docs/P0_Task5_Service_Layer_Guard_Hardening_Report.md`

## Guard Strategy

Tournament-scoped writes now:

- load the tournament from Firestore
- trim and validate `actorId`
- require `tournament.organizerId == actorId`
- throw `لا تملك صلاحية إدارة هذه البطولة.` when unauthorized
- stop before write/no-op admin state is presented as successful

Match-scoped writes now:

- load the match from Firestore
- trim and validate `actorId`
- require `match.organizerId == actorId`
- for MatchEvents, require caller-provided `tournamentId` to match the stored match `tournamentId`
- throw safe Arabic errors before write attempts

## Methods Guarded

`TournamentLifecycleService`:

- `finalizeParticipants`
- `startGroupStage`
- `publishFixtures`
- `startKnockout`
- `completeTournament`
- `refreshGroupStandings` when called with `actorId`
- `refreshKnockoutProgress` when called with `actorId`

`TournamentParticipantService`:

- `addManualParticipant`
- `removeParticipant`
- `withdrawParticipant`
- `reactivateParticipant`
- `replaceParticipant`
- `updateParticipantSeed`

`TournamentFixtureService`:

- `scheduleFixture`
- `startMatch`
- `regenerateGroupStage`

`MatchEventService`:

- `recordGoal`
- `recordGoals`
- `recordMvp`

## Unauthorized Behavior

Non-organizer calls now fail early in the service layer. Tests assert that operation state is not written after denied calls for lifecycle, participant, fixture, and MatchEvent paths.

Representative safe errors:

- `لا تملك صلاحية إدارة هذه البطولة.`
- `لا تملك صلاحية إدارة هذه المباراة.`
- `لا تملك صلاحية تسجيل أحداث هذه المباراة.`
- `بيانات البطولة لا تطابق المباراة.`

## Authorized Behavior Preserved

Existing organizer flows continue to pass:

- finalize participants
- start group stage
- publish fixtures
- start knockout
- complete tournament
- add/withdraw/reactivate/replace/seed participants
- schedule/start fixtures
- create valid goal/MVP MatchEvents
- compute top scorers from approved MatchEvents

## Tests Added or Updated

Added service-level coverage proving:

- non-organizer cannot finalize participants
- non-organizer cannot start group stage
- non-organizer cannot publish fixtures
- non-organizer cannot start knockout
- non-organizer cannot complete tournament
- non-organizer cannot add, remove, withdraw, reactivate, replace, or seed participants
- non-organizer cannot schedule fixtures
- non-organizer cannot start fixtures
- non-organizer cannot create goal/MVP MatchEvents
- organizer MatchEvent creation still works
- missing match and tournament mismatch MatchEvents are denied

Updated MatchEvent-related test fixtures to seed real match documents because the service now verifies match ownership before writing events.

## Commands Run

`flutter pub get`

- Result: passed.

`dart format` on changed Dart files

- Result: passed.

Targeted service tests:

`flutter test test/core/services/tournament_lifecycle_service_test.dart test/core/services/tournament_participant_service_test.dart test/core/services/tournament_fixture_service_test.dart test/core/services/match_event_service_test.dart test/core/services/tournament_top_scorers_resolver_test.dart`

- Result: passed.
- Output summary: `46 passed`.

`dart analyze lib/`

- Result: passed.
- Output: `No issues found!`

`flutter test`

- Result: passed.
- Output summary: `372 passed`.

`npm run test:rules:emulator`

- Result: passed.
- Output summary: `80 passing`.
- Emulator PERMISSION_DENIED warnings are expected from negative `assertFails` cases.

## Final Result

Task acceptance criteria are met:

- `dart analyze lib/` passes.
- `flutter test` passes.
- Rules emulator tests still pass.
- Non-organizer service calls fail early for guarded tournament operation mutations.
- Organizer service calls still work.
- No Firestore rules changes were made in this task.
- No UI or route changes were made in this task.

## Remaining Risks

- P1: `refreshGroupStandings` and `refreshKnockoutProgress` still support existing no-actor internal call sites. Guarded organizer flows now pass `actorId`, but settlement-triggered refreshes still rely on `MatchSettlementService` authorization plus Firestore rules.
- P1: `MatchEventService.voidEvent` still has no `actorId` parameter, so service-level authorization cannot be applied there without a signature migration. Firestore rules still guard voiding by `createdBy`.
- P1: guest-first score UI is still unresolved.
- P1: scheduling conflict rules are still unresolved.
- P1: advanced group/knockout exposure remains a product decision if V1 later defers those flows.
- P1: `TournamentFixtureService.regenerateGroupStage` still deletes `matches`; Firestore `matches` rules still deny match deletion. This match delete/regenerate mismatch remains outside Task 5.
- P1: assistant/co-organizer score operation semantics remain deferred. MatchEvent creation is now organizer-only at service and rules level for V1.
