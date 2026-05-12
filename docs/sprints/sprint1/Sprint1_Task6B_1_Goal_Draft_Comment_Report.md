# Sprint 1 / Task 6B.1: Goal Draft Comment Report

## Comment Added

Added a brief inline comment in `ScoreSubmitController.submit()` before `detailedStats` creation explaining that:

- `goalDrafts` are in-memory `ParticipantRef`-based state for future UI and mismatch warnings.
- goal `MatchEvent` persistence is deferred to the next integration task.
- existing `PlayerMatchStats` `detailedStats` remain registered-player-only for the current settlement/rating path.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `docs/Sprint1_Task6B_1_Goal_Draft_Comment_Report.md`

## Commands Run

- `dart format lib/features/match/controllers/score_submit_controller.dart`
- `dart analyze lib/`
- `flutter test test/features/match/score_submit_controller_test.dart`
- `flutter test`

## Final Result

- `dart format`: passed.
- `dart analyze lib/`: passed with no issues.
- Targeted controller test: passed with `+17`.
- Full `flutter test`: passed with `+281`.

Flutter test commands still print the existing pub advisory decode warnings during dependency resolution, but the commands complete successfully.
