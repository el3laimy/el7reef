# Task 004: Optional Lineup Nudge Before Starting Match

## Goal
When the user starts a friendly match without saved lineups, show a nudge that encourages creating a lineup but still allows starting without one.

## Context
Lineups are optional in El7reef V1 because street football must stay fast. But lineups are important for pride, sharing, and growth, so the app should encourage them at the right moment.

## Product decision
Lineups are optional, not required. Use encouragement, not blocking.

## Scope
Do:
- Detect when a friendly match is being started without saved lineups/snapshots.
- Show a clear bottom sheet/dialog before starting.
- Provide two actions:
  1. Create lineup first.
  2. Start without lineup.
- Preserve the existing ability to start quickly.
- Keep organized/tournament behavior unchanged unless existing code already shares the same path and requires a safe guard.

Do not:
- Make lineups required globally.
- Change match status rules unnecessarily.
- Rewrite the lineup system.
- Modify tournament/fantasy flows.
- Add dependencies.

## Likely files
- lib/features/match/views/match_lobby_screen.dart
- lib/features/match/controllers/match_lobby_controller.dart
- lib/core/services/match_start_service.dart
- lib/features/lineup/controllers/team_lineup_editor_controller.dart
- lib/features/lineup/controllers/match_side_lineup_editor_controller.dart

## Required behavior
When the user taps Start Match for a friendly match and no lineup has been saved:
- Show a bottom sheet/dialog explaining that lineups are optional but make the match more professional and shareable.
- Primary action: create lineup first.
- Secondary action: start without lineup.

When at least the relevant lineup is already saved, do not show unnecessary friction.

## Suggested Arabic UX copy
Use existing tone and localization style. Suggested meaning:
- Title: "Start without a lineup?"
- Body: "The lineup is optional, but it makes the match look better and lets you share a professional card with the players."
- Primary: "Create lineup first"
- Secondary: "Start without lineup"

Translate naturally into the app's Arabic tone.

## Acceptance criteria
- [ ] Starting a friendly match without lineup shows a nudge, not a hard block.
- [ ] User can choose to create lineup first.
- [ ] User can choose to start without lineup.
- [ ] Existing start match validation still works.
- [ ] No tournament/fantasy behavior is broken.
- [ ] User-facing text is Arabic-first.

## Testing/checks
Run if available:
- dart analyze lib/
- flutter test

If unavailable, state that clearly.

## Final report
Return:
1. Summary of changes.
2. Files changed.
3. UX behavior changed.
4. Tests/checks run.
5. Risks or follow-up tasks.
