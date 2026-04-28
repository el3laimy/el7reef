# Task 003: Remove Misleading Coming Soon UI From Core Friendly Flow

## Goal
Remove or connect any misleading "coming soon" message inside the friendly match core flow when the feature already exists elsewhere.

## Context
The user must not see a button for temporary players that says the feature is coming soon while temporary players are already supported in the lobby flow.

## Product decision
No fake features and no misleading dead ends inside the V1 friendly match flow.

## Scope
Do:
- Search for user-facing "coming soon" or equivalent messages related to temporary players, lineups, match setup, results, and sharing inside the friendly match core flow.
- For each misleading message, either connect it to the existing real flow or remove/hide the action.
- Keep the UX simple and Arabic-first.

Do not:
- Remove legitimate deferred features outside the core flow unless they confuse the friendly match flow.
- Implement new large features.
- Start tournament/fantasy cleanup.
- Add dependencies.

## Likely files
- lib/features/lineup/widgets/match_formation_section.dart
- lib/features/match/views/match_lobby_screen.dart
- lib/features/match/controllers/match_lobby_controller.dart
- lib/features/match/views/match_discover_screen.dart

## Required behavior
If a user is in the friendly match setup/lineup flow, they should not hit a button that says temporary players are "coming soon" while the app already supports adding them in another part of the flow.

A valid outcome is one of:
- the action opens the existing add temporary player flow, or
- the misleading action is removed from that surface, or
- the copy is changed to guide the user to the correct existing place.

## Acceptance criteria
- [ ] No misleading "coming soon" dead end remains in the core friendly match flow for temporary players.
- [ ] Any changed action either works or clearly guides the user.
- [ ] No unrelated features are removed.
- [ ] User-facing text remains Arabic-first where touched.
- [ ] No broad redesign is introduced.

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
5. Remaining misleading/deferred surfaces, if any.
