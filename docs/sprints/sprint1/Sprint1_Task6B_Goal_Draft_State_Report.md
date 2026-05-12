# Sprint 1 / Task 6B: ScoreSubmit Goal Draft State Report

## Summary of Change

Added controller-only goal attribution draft state to `ScoreSubmitController`. The draft state is based on `ParticipantRef` and supports registered players, guest players, and temporary match-side players.

This task does not write goal `MatchEvent` documents and does not modify the score submission UI.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/Sprint1_Task6B_Goal_Draft_State_Report.md`

## Goal Draft API / State Added

Added `ScoreSubmitGoalDraft` with:

- `actor: ParticipantRef`
- `sideKey: A | B`
- `goals: int`
- `minute: int?`

Added controller state and helpers:

- `goalDrafts`
- `allGoalDrafts`
- `setParticipantGoals(ParticipantRef participant, int goals)`
- `clearParticipantGoals(ParticipantRef participant)`
- `clearGoalDrafts()`
- `goalDraftsForSide(String sideKey)`
- `totalDraftGoalsForSide(String sideKey)`
- `goalDraftMismatchForSide(String sideKey)`

Draft identity uses the existing roster key of `ParticipantRefKind + id`.

## Mismatch Helper Behavior

`goalDraftMismatchForSide` compares the draft total for side `A` or `B` against the current submitted score source for that side. It is read-only warning state for later UI work.

It does not block submit and does not trigger validation errors.

## Temporary Separation From PlayerMatchStats

Goal draft state is intentionally separate from the existing registered-only `playerStats` and `PlayerMatchStats` flow.

Registered detailed stats continue to behave exactly as before. Draft goal attribution is not synced into `playerStats`, and `submit()` does not consume draft goals yet.

## What Was Intentionally Not Touched

- `ScoreSubmitScreen` UI
- goal `MatchEvent` writing
- `MatchSettlementService`
- `MatchEventService`
- `PlayerMatchStats`
- rating and fantasy code
- Firestore rules or indexes
- leaderboards

## Tests Added / Updated

Updated `test/features/match/score_submit_controller_test.dart` to verify:

- registered participants can receive goal drafts
- guest participants can receive goal drafts
- temporary match-side participants can receive goal drafts
- invalid participants are ignored safely
- missing full roster prevents adding drafts safely
- `clearParticipantGoals` and `clearGoalDrafts` work
- draft totals are computed by side
- mismatch helper detects mismatch without blocking submit
- submit with goal drafts writes no goal `MatchEvent` documents
- existing MVP dual-write tests still pass

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
- Targeted controller test: passed with `+17`.
- Full `flutter test`: passed with `+281`.

## Risks / Follow-Ups

- Goal drafts are not persisted yet.
- Goal drafts are not displayed in `ScoreSubmitScreen` yet.
- Goal `MatchEvent` writing is intentionally deferred to a later task.
- The mismatch helper is currently advisory only and should be surfaced by UI later without blocking submission.
