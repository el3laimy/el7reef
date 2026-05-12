# Sprint 1 / Task 7.1: Top Scorers Resolver Hardening

## Index Verification Result
- Verified `firestore.indexes.json` already includes both required `matchEvents` composite indexes:
  - `matchId ASC`, `eventType ASC`, `status ASC`
  - `tournamentId ASC`, `eventType ASC`, `status ASC`

## firestore.indexes.json Changed
- No.
- Both required indexes were already present, so no index patch was needed.

## Tests Added
- Added cross-tournament isolation coverage in `test/core/services/tournament_top_scorers_resolver_test.dart`.
- The test creates goal events for `tournament-1` and `tournament-2`, calls `getTopScorers('tournament-1')`, and verifies only `tournament-1` goals are counted.
- It also verifies the `tournament-2` scorer does not appear.

## Files Changed
- `test/core/services/tournament_top_scorers_resolver_test.dart`
- `docs/Sprint1_Task7_1_Top_Scorers_Hardening_Report.md`

## Commands Run
- `dart format test/core/services/tournament_top_scorers_resolver_test.dart`
  - Passed, 0 changes.
- `dart analyze lib/`
  - Passed: no issues found.
- `flutter test test/core/services/tournament_top_scorers_resolver_test.dart`
  - Passed: `+8`.
  - Pub printed existing advisory decode warnings while resolving dependencies, but dependencies resolved successfully.
- `flutter test`
  - Passed: `+293`.
  - Pub printed existing advisory decode warnings while resolving dependencies, but dependencies resolved successfully.

## Final Result
- Required Firestore indexes exist.
- Cross-tournament isolation is tested.
- `dart analyze lib/` passes.
- `flutter test` passes.
- No UI, ScoreSubmit, settlement, PlayerMatchStats, rating, fantasy, resolver behavior, or denormalized snapshot changes were made.
