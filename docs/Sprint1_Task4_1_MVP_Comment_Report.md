# Sprint 1 / Task 4.1: MVP Comment Report

## What Comment Was Added

- Added a brief comment in `MatchSettlementService.approveScore` before registered-player rating delta calculation.
- The comment documents that:
  - V1 `mvpPlayerId` may contain `Player.id`, `GuestPlayer.id`, or `MatchSidePlayer.id`.
  - Rating bonuses remain registered-player-only.
  - Guest/MSP MVPs are preserved on the match but do not grant rating bonuses.
  - Future MatchEvent MVP dual-write will carry the full `ParticipantRef`.

## Files Changed

- `lib/core/services/match_settlement_service.dart`
- `docs/Sprint1_Task4_1_MVP_Comment_Report.md`

## Commands Run

- `dart format lib/core/services/match_settlement_service.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/core/services/match_settlement_service_test.dart`
  - Result: passed, `+9`.
- `flutter test`
  - Result: passed, `+264`.

## Final Result

- No behavior changed.
- `dart analyze lib/` passes.
- `flutter test` passes with `+264`.
