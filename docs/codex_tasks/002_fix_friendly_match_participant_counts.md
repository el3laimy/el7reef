# Task 002: Fix Friendly Match Participant Counts Outside Lobby

## Goal
Make friendly match cards outside the lobby show correct participant counts including both registered and temporary players.

## Context
Temporary players are first-class participants in El7reef. The audit found that the lobby already shows temporary players correctly, but discover/list cards count only `teamAPlayerIds.length` and `teamBPlayerIds.length`.

This creates a bad user experience: a match with temporary players may look empty or under-filled outside the lobby.

## Product decision
Temporary players must be treated as real match participants anywhere the user sees match participant counts.

## Scope

Do:
- Inspect UI code for friendly match cards/lists that display participant counts.
- Search for count usage based only on:
  - `teamAPlayerIds.length`
  - `teamBPlayerIds.length`
  - `teamAPlayers.length`
  - `teamBPlayers.length`
- Fix the discover/list match card counts to include temporary players where side data is available.
- Keep the existing lobby behavior if it already counts temporary players correctly.
- Prefer using existing models/services/repositories already used in the match flow.
- Add small helper methods only if they reduce duplication and stay local to the relevant widget/controller.
- Preserve Arabic RTL UI.

Do not:
- Redesign the match card.
- Rewrite the lobby.
- Change match creation.
- Change match start rules.
- Change lineup logic.
- Change matchday behavior.
- Work on tournaments, fantasy, or social feed.
- Add new dependencies.
- Change Firebase collection names.
- Implement temporary-player edit/remove controls in this task.
- Implement formation preview temporary-player support in this task.

## Likely files
- lib/features/match/views/match_discover_screen.dart
- lib/features/match/controllers/match_controller.dart
- lib/features/match/controllers/match_lobby_controller.dart
- lib/core/models/match.dart
- lib/core/models/match_model.dart
- any reusable match card widget if one exists

## Required behavior
If a friendly match has:
- Team A: 2 registered players and 3 temporary players
- Team B: 1 registered player and 4 temporary players

Then any discover/list card participant count should show:
- Team A: 5
- Team B: 5

If temporary side data is not loaded for a card, do not show a misleading precise count that ignores temporary players. Use the best safe existing data path, or show a conservative label only if needed.

## Acceptance criteria
- [ ] Discover/list match cards no longer show counts based only on registered player IDs when temporary player counts are available.
- [ ] Lobby counting behavior is not broken or unnecessarily rewritten.
- [ ] The UI remains Arabic and RTL-friendly.
- [ ] No unrelated tournament/fantasy/social code is changed.
- [ ] No dead buttons or new “coming soon” messages are introduced.
- [ ] The final report explains exactly how temporary counts are loaded and what fallback is used if they are unavailable.

## Testing/checks
Run if available:
- dart analyze lib/
- flutter test

If unavailable, state clearly.

## Final report
Return:
1. Summary of changes.
2. Files changed.
3. How temporary player counts are now included.
4. Tests/checks run.
5. Any commands unavailable.
6. Risks or follow-up tasks.