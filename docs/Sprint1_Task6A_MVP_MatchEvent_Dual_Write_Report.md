# Sprint 1 / Task 6A: ScoreSubmit MVP MatchEvent Dual-Write Report

## Summary of Change

`ScoreSubmitController.submit()` now preserves the existing `MatchSettlementService.submitScore` flow and, after a successful score submission, writes one MVP `MatchEvent` with the full `ParticipantRef`.

This task is MVP-only. No goal attribution or goal `MatchEvent` writing was added.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/Sprint1_Task6A_MVP_MatchEvent_Dual_Write_Report.md`

## MVP ParticipantRef Resolution

The controller resolves the selected MVP from `fullParticipantRoster` after `submitScore` succeeds:

- side A participants are matched with side key `A`
- side B participants are matched with side key `B`
- the selected id must resolve to exactly one participant
- if the full roster is missing, the id is not found, or the id is ambiguous, no `MatchEvent` is written and the score submission result is preserved

The written MVP event includes:

- `eventType = mvp`
- `matchId`
- `tournamentId` from the submitted match when available
- `sideKey`
- full `ParticipantRef`
- `createdBy` from the existing controller current-user provider
- `status = active`

## Duplicate Prevention Strategy

The controller writes MVP events with a deterministic id:

- `mvp-<matchId>`

Before writing that deterministic event, the controller loads active match events and voids any other active MVP events for the same match. Repeated submits for the same match overwrite the deterministic MVP event instead of creating another active MVP event.

## What Was Intentionally Not Touched

- `ScoreSubmitScreen` UI
- goal attribution
- goal `MatchEvent` writing
- `MatchSettlementService`
- `PlayerMatchStats`
- rating and fantasy code
- Firestore rules or indexes
- leaderboards

## Tests Added / Updated

Updated `test/features/match/score_submit_controller_test.dart` to verify:

- registered MVP writes one active MVP `MatchEvent` with `ParticipantRefKind.player`
- guest MVP writes one active MVP `MatchEvent` with `ParticipantRefKind.guestPlayer`
- temporary match-side MVP writes one active MVP `MatchEvent` with `ParticipantRefKind.matchSidePlayer`
- no selected MVP writes no MVP `MatchEvent`
- `submitScore` failure writes no MVP `MatchEvent`
- repeated submit does not create duplicate active MVP events
- MVP dual-write does not create goal events

## Commands Run

- `dart format lib/features/match/controllers/score_submit_controller.dart test/features/match/score_submit_controller_test.dart`
- `dart analyze lib/`
- `flutter test test/features/match/score_submit_controller_test.dart`
- `flutter pub get`
- `dart analyze lib/`
- `flutter test`

## Final Result

- `flutter pub get`: passed. Pub printed existing advisory decode warnings, but dependency resolution completed.
- `dart analyze lib/`: passed with no issues.
- Targeted controller test: passed with `+10`.
- Full `flutter test`: passed with `+274`.

## Risks / Follow-Ups

- `Match.mvpPlayerId` is still string-only. The controller resolves it against the full roster, but id collisions across participant kinds are treated as ambiguous and do not dual-write an MVP event.
- Goal events remain intentionally deferred to the next goal-attribution task.
- UI still needs a later task to expose full-roster MVP selection visually.
