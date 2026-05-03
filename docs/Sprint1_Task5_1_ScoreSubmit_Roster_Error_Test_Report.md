# Sprint 1 / Task 5.1: ScoreSubmit Full Roster Error Path Test Report

## Tests Added

Added focused coverage in `test/features/match/score_submit_controller_test.dart` for the full participant roster failure path.

The new test uses a test-only subclass of `OfficialMatchRosterService` that preserves the real `loadRegisteredRoster` behavior and fails only `loadParticipantRoster`.

It asserts that:

- `loadMatchAndPlayers()` completes without throwing.
- `fullParticipantRoster.value` remains `null`.
- `fullRosterErrorMessage` is populated.
- `teamAParticipants`, `teamBParticipants`, and `allParticipants` are empty.
- Registered `teamAPlayers` and `teamBPlayers` still load.
- Registered `playerStats` remain usable after the full roster failure.

## Files Changed

- `test/features/match/score_submit_controller_test.dart`
- `docs/Sprint1_Task5_1_ScoreSubmit_Roster_Error_Test_Report.md`

## Production Behavior Changed

No production behavior changed. This was a test-only patch.

## Commands Run

- `dart format test/features/match/score_submit_controller_test.dart`
- `dart analyze lib/`
- `flutter test test/features/match/score_submit_controller_test.dart`
- `flutter test`

## Final Result

- `dart format`: passed.
- `dart analyze lib/`: passed with no issues.
- Targeted controller test: passed with `+5`.
- Full `flutter test`: passed with `+269`.

The Flutter test commands still print the existing pub advisory decode warnings during dependency resolution, but the commands complete successfully.
