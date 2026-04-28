# Task 005: Clear Share CTA After Saving Lineup

## Goal
After a lineup is saved successfully, show a clear user-facing CTA to share the lineup, not only a small AppBar icon.

## Context
Lineup sharing is a growth engine for El7reef. If sharing is hidden, users may never discover one of the most important V1 behaviors.

## Product decision
Sharing must be visible and encouraged in the core flow.

## Scope
Do:
- Identify the successful lineup save path for team lineups and match-side lineups.
- After save success, show a bottom sheet/snackbar/dialog with a clear share action.
- Keep the existing AppBar share icon if present, but do not rely on it as the only action.
- Reuse the existing share/capture service and share card widgets.
- Handle incomplete lineups gracefully if current flow allows saving them.

Do not:
- Redesign the entire lineup editor.
- Build a new share card system.
- Add dependencies.
- Change lineup formation rules.
- Modify tournament/fantasy features.

## Likely files
- lib/features/lineup/controllers/team_lineup_editor_controller.dart
- lib/features/lineup/controllers/match_side_lineup_editor_controller.dart
- lib/features/lineup/views/team_lineup_editor_screen.dart
- lib/features/lineup/views/match_side_lineup_editor_screen.dart
- lib/features/shareables/widgets/lineup_share_card.dart
- lib/features/shareables/services/share_card_capture_service.dart

## Required behavior
After a lineup is saved successfully:
- Show a clear success message.
- Offer a visible action to share the lineup immediately.
- Offer a secondary action to return to the match/lobby or continue editing.

If the lineup is incomplete and saving is allowed:
- Make it clear that the saved lineup is incomplete before sharing.

## Acceptance criteria
- [ ] User sees a clear share CTA after saving a lineup.
- [ ] Existing AppBar share behavior remains working if present.
- [ ] Share action reuses existing share card/capture infrastructure.
- [ ] Incomplete lineup behavior remains clear.
- [ ] User-facing text is Arabic-first.
- [ ] No unrelated features are changed.

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
