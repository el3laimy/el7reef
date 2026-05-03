# Sprint 0 / Task 3 - V1 Test Baseline Report

## Summary of fixes
- Updated `MatchSettlementService` tests for the current score API by passing `actorId` to `submitScore()` and `approveScore()`.
- Aligned score-submission test setup with the current lifecycle rule that results can only be submitted for live matches.
- Updated matchday screen tests to register and inject `MatchSideRepositoryImpl`, matching the current `MatchdayController` constructor.
- Reworked tournament operations widget test setup to use fake Firestore-backed test bindings and fake services instead of route bindings that instantiate default Firebase services.
- Updated tournament operations assertions to match the current mixed Arabic/V1-safe labels.
- Updated app route fantasy tests to assert the V1 feature gate (`FeatureUnavailableScreen`) instead of rendering fantasy screens.

## Files changed
- `test/core/services/match_settlement_service_test.dart`
- `test/features/match/matchday_screen_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `test/widget_test.dart`
- `docs/Sprint0_Task3_Test_Baseline_Report.md`

## Tests fixed
- `test/core/services/match_settlement_service_test.dart`
- `test/features/match/matchday_screen_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `test/widget_test.dart`
- Additional full-suite regressions were checked by running `flutter test`.

## Tests skipped
- None.

## Commands run
- `flutter pub get`
  - Result: completed successfully.
  - Note: pub printed advisory decoding warnings (`advisoriesUpdated must be a String`) but exited successfully and resolved dependencies.
- `dart format test/core/services/match_settlement_service_test.dart test/features/match/matchday_screen_test.dart test/features/tournament/tournament_operations_dashboard_test.dart test/widget_test.dart`
  - Result: completed successfully.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/core/services/match_settlement_service_test.dart test/features/match/matchday_screen_test.dart test/features/tournament/tournament_operations_dashboard_test.dart test/widget_test.dart`
  - Result: passed.
- `flutter test`
  - Result: passed, `+240`.

## Final results
- `dart analyze lib/`: passed.
- `flutter test`: passed.
- V1 surface freeze remains intact.
- Fantasy UI remains hidden behind `FeatureUnavailableScreen`.
- No production schema changes.
- No new product features implemented.

## Remaining failures
- None.

## Risks or follow-up tasks
- The Flutter/Dart pub client in this environment emits hosted package advisory decoding warnings during dependency resolution. This did not fail the command, but the SDK/pub toolchain may need an update if the warnings become blocking later.
