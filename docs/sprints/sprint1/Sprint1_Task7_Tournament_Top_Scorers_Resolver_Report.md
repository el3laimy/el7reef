# Sprint 1 / Task 7: Tournament Top Scorers Resolver

## Summary
- Added a client-side tournament top scorers resolver built from active goal `MatchEvent` data.
- Added a small `TournamentTopScorerEntry` value object that preserves the scorer `ParticipantRef`, goal count, and nullable `teamDisplayName`.
- Added focused resolver tests using fake Firestore and the existing `MatchEventService` / repository path.

## Files Added
- `lib/core/services/tournament_top_scorers_resolver.dart`
- `test/core/services/tournament_top_scorers_resolver_test.dart`
- `docs/Sprint1_Task7_Tournament_Top_Scorers_Resolver_Report.md`

## Files Modified
- None beyond adding the new resolver, tests, and report.

## Resolver API
- `TournamentTopScorersResolver.getTopScorers(String tournamentId, {int limit = 10})`
- Returns `List<TournamentTopScorerEntry>`.
- Returns an empty list when `tournamentId` is blank or `limit <= 0`.
- Uses `MatchEventService.getTournamentGoalEvents(tournamentId)` so active goal filtering stays on the existing MatchEvent repository/service path.

## Aggregation Rules
- Aggregates active tournament goal events by `actor.kind + actor.id`.
- Preserves the first `ParticipantRef` actor data from the event stream, including guest `linkedPlayerId`.
- Counts one goal per goal event.
- Sorts by:
  1. goals descending
  2. `displayName` ascending, case-insensitive
  3. `id` ascending
  4. `kind` ascending as a final deterministic fallback
- Applies `limit` after sorting.
- `teamDisplayName` is left nullable; no match/team joins were added.

## Exclusion Rules
- Included:
  - `ParticipantRefKind.player`
  - `ParticipantRefKind.guestPlayer`
- Excluded:
  - `ParticipantRefKind.matchSidePlayer`
- MVP events and voided goal events are ignored by the existing MatchEvent query path and covered by tests.

## What Was Intentionally Not Touched
- No ScoreSubmit UI changes.
- No Tournament UI changes.
- No `MatchSettlementService` changes.
- No `ScoreSubmitController` changes.
- No `PlayerMatchStats` changes.
- No rating, fantasy, Firestore rules/indexes, share cards, or denormalized snapshot collection changes.

## Tests Added
- Empty result for no events and non-positive limits.
- Registered player goal aggregation.
- Guest player goal aggregation with `linkedPlayerId` preservation.
- `matchSidePlayer` exclusion from tournament leaderboard.
- MVP event and voided goal event ignore behavior.
- Goals descending sort and limit behavior.
- Deterministic tie-breaker by `displayName` then `id`.

## Commands Run
- `flutter pub get`
  - Passed.
  - Pub printed existing advisory decode warnings for some packages, but dependencies resolved successfully.
- `dart format lib/core/services/tournament_top_scorers_resolver.dart test/core/services/tournament_top_scorers_resolver_test.dart`
  - Passed.
- `dart analyze lib/`
  - Passed: no issues found.
- `flutter test test/core/services/tournament_top_scorers_resolver_test.dart`
  - Passed: `+7`.
- `flutter test`
  - Passed: `+292`.

## Final Result
- `dart analyze lib/` passes.
- `flutter test` passes.
- Tournament top scorers aggregate from active goal MatchEvents.
- Registered and guest players are included.
- Temporary match-side players are excluded.
- Voided and MVP events are ignored.

## Risks / Follow-Ups
- `teamDisplayName` is intentionally nullable because this task avoided match/team joins. A later UI or share-card task can enrich entries where needed.
- Aggregation is client-side for V1; large tournaments may eventually need a cached or server-side leaderboard projection.
