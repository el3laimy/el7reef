# Sprint 1 / Task 5: ScoreSubmit Full Participant Roster Wiring Report

## Summary of Change

Wired `ScoreSubmitController` to load the full `MatchParticipantRoster` alongside the existing registered-only roster. The controller now exposes read-only participant accessors and side lookup helpers so a later UI task can select MVPs from registered players, guest players, or temporary match-side players.

This was controller wiring only. No UI, MatchEvent writing, settlement, rating, fantasy, Firestore rules, or leaderboard behavior was changed.

## Files Changed

- `lib/features/match/controllers/score_submit_controller.dart`
- `test/features/match/score_submit_controller_test.dart`
- `docs/Sprint1_Task5_ScoreSubmit_Roster_Wiring_Report.md`

## Controller API / State Added

- `fullParticipantRoster`
- `fullRosterErrorMessage`
- `teamAParticipants`
- `teamBParticipants`
- `allParticipants`
- `isParticipantOnSide(...)`
- `sideKeyForParticipant(...)`
- `selectMvp(...)`
- Public `loadMatchAndPlayers()` for focused controller tests

The controller constructor also supports dependency injection for repositories, services, and current-user lookup. Default production construction still uses the existing Firebase/GetX dependencies.

## Behavior Preserved

- `loadRegisteredRoster` remains the source for `teamAPlayers` and `teamBPlayers`.
- `PlayerMatchStats` draft state is still created only for registered players.
- Detailed stats submission remains registered-player-only.
- Submit still delegates to `MatchSettlementService.submitScore`.
- Existing registered MVP flow remains compatible.

## Intentionally Not Touched

- `ScoreSubmitScreen` UI
- `MatchSettlementService`
- `MatchEventService` and MatchEvent writes
- `PlayerMatchStats`
- Rating engine / fantasy code
- Firestore rules and indexes
- Leaderboards

## Tests Added / Updated

Added `test/features/match/score_submit_controller_test.dart` with coverage for:

- Loading registered players into the full participant roster as `ParticipantRefKind.player`.
- Loading guest participants from lineup snapshots with `linkedPlayerId` preserved.
- Loading temporary match-side participants as `ParticipantRefKind.matchSidePlayer`.
- Submitting registered detailed stats while allowing a guest MVP id without controller-side rejection, confirming no guest `player_stats` document is written.

## Commands Run

- `dart format lib/features/match/controllers/score_submit_controller.dart test/features/match/score_submit_controller_test.dart`
- `dart format test/features/match/score_submit_controller_test.dart`
- `flutter test test/features/match/score_submit_controller_test.dart`
- `flutter pub get`
- `dart analyze lib/`
- `flutter test`

## Final Result

- `flutter pub get`: passed. Pub printed existing advisory decode warnings, but dependency resolution completed.
- `dart analyze lib/`: passed with no issues.
- Targeted controller test: passed.
- Full `flutter test`: passed with `+268`.

## Risks / Follow-Ups

- The visible `ScoreSubmitScreen` still uses the current registered-player UI until a later UI integration task.
- `Match.mvpPlayerId` is still a string, so future UI/MatchEvent integration should carry the full `ParticipantRef` for collision-safe MVP attribution.
- Full roster load failures are isolated into `fullRosterErrorMessage`; the registered stats flow continues to load through the existing path.
