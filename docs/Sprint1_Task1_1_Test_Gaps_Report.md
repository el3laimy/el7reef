# Sprint 1 / Task 1.1 - MatchEvent Test Gaps Report

## Tests added
- Added a `ParticipantRefKind.player` round-trip serialization test in `participant_ref_model_test.dart`.
  - Asserts `kind`, `id`, `displayName`, and `linkedPlayerId`.
- Added a guest-player MVP service test in `match_event_service_test.dart`.
  - Records MVP using a `guestPlayer` `ParticipantRef`.
  - Asserts `eventType == mvp`.
  - Asserts `actor.kind == guestPlayer`.
  - Asserts `actor.id` is the guest player id.
  - Asserts `getMvpEvent(matchId)` returns the guest MVP event.

## Files changed
- `test/data/models/participant_ref_model_test.dart`
- `test/core/services/match_event_service_test.dart`
- `docs/Sprint1_Task1_1_Test_Gaps_Report.md`

## Commands run
- `dart format test/data/models/participant_ref_model_test.dart test/core/services/match_event_service_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/data/models/participant_ref_model_test.dart test/core/services/match_event_service_test.dart`
  - Result: passed.
  - Note: Flutter printed non-blocking pub advisory decoding warnings (`advisoriesUpdated must be a String`).
- `flutter test`
  - Result: passed, `+250`.
  - Note: Flutter printed the same non-blocking pub advisory decoding warnings.

## Final result
- `dart analyze lib/` passes.
- `flutter test` passes.
- No production behavior changed.
- No UI, ScoreSubmit, MatchSettlementService, Firestore rules, rating, fantasy, or PlayerMatchStats files were modified.
