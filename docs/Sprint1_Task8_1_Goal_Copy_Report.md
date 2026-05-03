# Sprint 1 / Task 8.1: Arabic Goal Count Copy Fix

## What Changed
- Updated the Tournament Detail top scorers goal-count label.
- Added a tiny private helper:
  - `1 => 1 هدف`
  - `2+ => $goals أهداف`
- Updated the existing top scorers widget test expectation for one goal.

## Files Changed
- `lib/features/tournament/views/tournament_detail_screen.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/Sprint1_Task8_1_Goal_Copy_Report.md`

## Commands Run
- `dart format lib/features/tournament/views/tournament_detail_screen.dart`
  - Passed, 0 changes.
- `dart analyze lib/`
  - Passed: no issues found.
- `flutter test test/features/tournament/tournament_operations_dashboard_test.dart`
  - Passed: `+16`.
  - Pub printed existing advisory decode warnings, but dependencies resolved successfully.
- `flutter test`
  - Passed: `+295`.
  - Pub printed existing advisory decode warnings, but dependencies resolved successfully.

## Final Result
- `1 هدف` is shown for one goal.
- `$goals أهداف` remains for two or more goals.
- No behavior, layout, navigation, share-card, resolver, ScoreSubmit, settlement, PlayerMatchStats, rating, fantasy, or Firestore rules changes were made.
