# Wave 2 / Task 7 - Official vs Provisional Leaderboards Policy Report

## Summary
Implemented the V1 official-only policy for tournament top scorers.

Tournament goal MatchEvents are still stored when score submission happens, but official tournament leaderboards now count them only when the referenced match is an official settled result. Public official tournament top scorers no longer silently include submitted, pending-review, completed-but-unapproved, draft, or scoreless match data.

## V1 Policy Decision
- Official tournament top scorers count only goal MatchEvents tied to official tournament results.
- The canonical official check is `Match.isOfficialTournamentResult`.
- In current code, that means:
  - `match.status == MatchStatus.settled`
  - `scoreTeamA != null`
  - `scoreTeamB != null`
- Event status is not trusted as proof that a result is official.
- No provisional public leaderboard was added for V1.

## Files Changed
- `lib/core/services/tournament_top_scorers_resolver.dart`
- `test/core/services/tournament_top_scorers_resolver_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/Wave2_Task7_Official_Leaderboards_Policy_Report.md`

## How Official Match Status Is Verified
`TournamentTopScorersResolver` now:
1. Loads active tournament goal events from `MatchEventService`.
2. Loads tournament matches through `MatchRepositoryImpl.getTournamentMatches`.
3. Builds an official match map using `match.isOfficialTournamentResult`.
4. Counts a goal event only when `event.matchId` exists in that official map.

This keeps the source of truth on the match record, not on user-written event fields.

## Effects On Guest Goals
Guest player goal events from settled matches with valid scores still count in official top scorers.

Guest player goal events from unapproved or pending matches are excluded from official tournament top scorers.

## Effects On Registered Goals
Registered player goal events from settled matches with valid scores still count.

Registered player goal events from submitted, pending-review, or scoreless matches are excluded.

## Effects On MVP And Share Cards
Top scorer share data uses the resolver output, so top scorer share cards inherit the official-only filtering.

No tournament-wide MVP leaderboard resolver was found in this task. Existing MVP share surfaces appear match-scoped, so they were not changed. If a future tournament MVP/pride aggregate is introduced, it should reuse the same official-match filter.

## Tests Added Or Updated
Updated `test/core/services/tournament_top_scorers_resolver_test.dart` to prove:
- settled official goals count.
- unapproved registered goals do not count.
- unapproved guest goals do not count.
- settled matches without valid scores do not count.
- mixed registered and guest official leaderboard ordering works.
- top scorer share data uses official-filtered resolver output.
- existing matchSidePlayer exclusion remains documented by test.

Updated `test/features/tournament/tournament_operations_dashboard_test.dart` fixture setup so tournament detail top scorer tests seed an official settled match and inject the fake match repository explicitly.

## Commands Run
- `flutter pub get` - passed.
- `dart format lib/core/services/tournament_top_scorers_resolver.dart test/core/services/tournament_top_scorers_resolver_test.dart test/features/tournament/tournament_operations_dashboard_test.dart` - passed.
- `dart analyze lib/` - passed.
- `flutter test test/core/services/tournament_top_scorers_resolver_test.dart test/features/shareables/top_scorers_share_card_test.dart test/features/tournament/tournament_operations_dashboard_test.dart` - passed.
- `flutter test test/features/match/score_submit_controller_test.dart` - passed.
- `flutter test` - passed, 381 tests.
- `npm run test:rules:emulator` - passed, 80 tests.

## Final Result
Official tournament top scorers now exclude unapproved and unsettled match events while preserving guest and registered scorer support for approved settled matches.

No Firestore rules, score submission UI, MatchEvent authorization, claim flow, scheduling, or fantasy behavior was changed.

## Remaining Risks
- Provisional leaderboard UI is deferred.
- `matchSidePlayer` events remain excluded from official tournament top scorers by current resolver policy. This is documented by test and should be revisited if V1 wants temporary match-side-only players on tournament leaderboards.
- The resolver uses two reads paths, goal events plus tournament matches. This avoids per-event N+1 reads and is acceptable for small V1 tournaments, but larger tournaments may need a denormalized official-stat projection later.
- Guest-to-registered stats merge remains deferred.
- Tournament-wide MVP aggregate policy remains to be implemented if that surface becomes public.
