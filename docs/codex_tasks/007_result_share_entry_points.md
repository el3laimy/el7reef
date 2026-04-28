# Task 007: Add Clear Result Share Entry Points After Result Exists

## Goal
Make result sharing easy to find after a match result already exists.

## Context
A user may submit a result and decide to share later. Result sharing should not only be available immediately after submission.

## Product decision
Sharing is a growth engine and should be discoverable from relevant result surfaces.

## Scope
Do:
- Identify match cards/details/screens where a completed result is shown.
- Add or improve a clear result share action when a result exists.
- Reuse existing result share card/capture infrastructure.
- Keep changes minimal and focused.

Do not:
- Redesign the entire match list.
- Add new share card types.
- Change score data model.
- Modify fantasy/tournament features unless they share the same result card component safely.

## Likely files
- lib/features/match/views/match_discover_screen.dart
- lib/features/match/views/match_lobby_screen.dart
- lib/features/match/widgets/*
- lib/features/shareables/widgets/match_result_share_card.dart
- lib/features/shareables/controllers/match_result_share_controller.dart
- lib/features/shareables/services/share_card_capture_service.dart

## Required behavior
When a match result exists:
- The user can find a clear share action from a relevant match/result surface.
- The action should use existing result share functionality.
- It should not be hidden only behind a tiny or ambiguous icon if the screen has room for a labeled CTA.

## Acceptance criteria
- [ ] At least one clear post-result share entry point exists outside the immediate score-submit success flow.
- [ ] The entry point appears only when a result exists.
- [ ] The share action uses existing infrastructure.
- [ ] No unrelated redesign is introduced.
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
