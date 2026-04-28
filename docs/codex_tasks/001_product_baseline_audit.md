# Task 001: Product Baseline Audit - Friendly Match Core Loop

## Goal
Audit the current Friendly Match Core Loop without changing code.

## Context
El7reef V1 must focus on the simplest valuable loop:
Create Match -> Add Players / Temporary Players -> Optional Lineup -> Start Match -> Submit Result -> Share Lineup / Result.

Before implementation, we need a grounded audit of the current screens, controllers, services, and UX gaps.

## Product decisions
- Friendly matches are the V1 priority.
- Lineups are optional, but the UX should encourage creating and sharing them.
- Temporary players are first-class participants.
- Do not start with fantasy, advanced tournaments, or broad social features.

## Scope
Do:
- Inspect the current codebase for the friendly match core flow only.
- Identify existing screens, controllers, services, repositories, and widgets involved.
- Identify what already works.
- Identify misleading UI, dead buttons, hidden features, and hard-to-reach actions.
- Identify places where temporary players are not counted or shown correctly.
- Propose the next 5 small implementation tasks.

Do not:
- Modify code.
- Reformat files.
- Implement fixes.
- Work on fantasy.
- Work on advanced tournaments.
- Work on social feed unless it directly affects sharing from the friendly match flow.

## Likely files to inspect
- lib/features/match/views/match_discover_screen.dart
- lib/features/match/views/match_lobby_screen.dart
- lib/features/match/controllers/match_controller.dart
- lib/features/match/controllers/match_lobby_controller.dart
- lib/core/services/match_start_service.dart
- lib/features/lineup/views/team_lineup_editor_screen.dart
- lib/features/lineup/views/match_side_lineup_editor_screen.dart
- lib/features/lineup/controllers/team_lineup_editor_controller.dart
- lib/features/lineup/controllers/match_side_lineup_editor_controller.dart
- lib/features/shareables/widgets/lineup_share_card.dart
- lib/features/shareables/widgets/match_result_share_card.dart
- lib/features/shareables/services/share_card_capture_service.dart
- lib/features/match/controllers/score_submit_controller.dart

## Required output
Return a concise audit with these sections:
1. Current core flow map.
2. Screens/controllers/services involved.
3. What already works.
4. What is missing or misleading.
5. Dead buttons or misleading "coming soon" messages in the core flow.
6. Places where temporary players are not counted or displayed correctly.
7. Share actions that are hidden, weak, or hard to discover.
8. Recommended next 5 small implementation tasks.

## Acceptance criteria
- [ ] No code changes were made.
- [ ] The audit focuses on friendly match core loop only.
- [ ] The audit identifies specific files and UX issues.
- [ ] The audit identifies the next 5 implementation tasks.
- [ ] Fantasy and advanced tournaments are not treated as current priorities.

## Testing/checks
No code changes are expected, so do not run full tests unless useful for inspection.

## Final report
Return:
1. Audit summary.
2. Files inspected.
3. Recommended next 5 tasks.
4. Any uncertainty or assumptions.
