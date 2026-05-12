# Sprint 1 / Task 6C: ScoreSubmit Goal MatchEvent Write

## Summary
- Wired `ScoreSubmitController.submit()` to persist goal `MatchEvent` documents from in-memory `goalDrafts` after `submitScore` succeeds.
- Kept goal attribution optional: empty drafts write no goal events, and draft/score mismatches do not block result submission.
- Preserved MVP dual-write behavior and registered-only `PlayerMatchStats` detailed stats behavior.
- Added controller tests for registered, guest, and temporary match-side player goal events.

## Files Changed
- `lib/features/match/controllers/score_submit_controller.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/Sprint1_Task6C_Goal_MatchEvent_Write_Report.md`

## Goal Event Write Behavior
- `submitScore` runs first.
- Goal `MatchEvent` writes happen only after successful score submission.
- Each `ScoreSubmitGoalDraft` writes one goal event per drafted goal.
- Goal events use:
  - `eventType = goal`
  - `actor = draft.actor`
  - `sideKey = draft.sideKey`
  - `matchId = submitted match id`
  - `tournamentId = submitted match tournamentId`
  - `createdBy = current user id`
  - `status = active`
  - `minute = null` for V1
- If `goalDrafts` is empty, no goal events are written.
- Goal draft total mismatch remains non-blocking and still writes the explicit draft events after a successful score submit.

## Duplicate Prevention Strategy
- Before writing the current goal drafts, the controller loads active match events for the match and voids active goal events only.
- It then writes deterministic goal event ids in this shape:
  - `goal-<matchId>-<sideKey>-<participantKind>-<participantId>-<index>`
- Match and participant id segments are encoded with `Uri.encodeComponent` before being used in document ids.
- Repeated submit therefore replaces the active goal event set for the match instead of accumulating duplicates.

## Best-Effort Failure Behavior
- Goal event persistence is best-effort after score submission succeeds.
- If goal event reads, voids, or creates fail, the controller catches the error and keeps the submitted match result intact.
- This mirrors the existing MVP MatchEvent best-effort behavior.

## What Was Intentionally Not Touched
- No `ScoreSubmitScreen` UI changes.
- No `MatchSettlementService` changes.
- No `PlayerMatchStats` changes or sync from `goalDrafts`.
- No rating, fantasy, Firestore rules/indexes, or leaderboard changes.
- No goal attribution requirement was added.

## Tests Added/Updated
- Registered player goal drafts write `ParticipantRefKind.player` goal events.
- Guest player goal drafts write `ParticipantRefKind.guestPlayer` goal events and preserve `linkedPlayerId`.
- Temporary match-side player goal drafts write `ParticipantRefKind.matchSidePlayer` goal events.
- Multiple goals for one participant create multiple goal events.
- Empty goal drafts write no goal events.
- Goal draft mismatch does not block submission and still writes draft goal events.
- `submitScore` failure writes no goal events.
- Repeated submit does not create duplicate active goal events.
- Existing MVP event behavior remains covered when MVP is selected.
- No MVP event is written when MVP is not selected.

## Commands Run
- `flutter pub get`
  - Passed.
  - Pub printed existing advisory decode warnings for some packages, but dependencies resolved successfully.
- `dart format lib/features/match/controllers/score_submit_controller.dart test/features/match/score_submit_controller_test.dart`
  - Passed, 2 files checked, 0 changed.
- `dart analyze lib/`
  - Passed: no issues found.
- `flutter test test/features/match/score_submit_controller_test.dart`
  - Passed: all controller tests passed.
- `flutter test`
  - Passed: `+285`.

## Final Result
- `dart analyze lib/` passes.
- `flutter test` passes.
- Goal events are written for registered, guest, and temporary match-side participants.
- Empty drafts write no goal events.
- Mismatches do not block.
- Submit failure writes no goal events.
- Repeated submit does not duplicate active goal events.

## Risks / Follow-Ups
- Goal event persistence is intentionally best-effort; a future retry or reconciliation path may be useful if Firestore write failures need recovery.
- `PlayerMatchStats` remains registered-player-only until the MatchEvent leaderboards/stat surfaces fully replace the older detailed stats path.
