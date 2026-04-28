# Task 006: Show Result Share CTA After Score Submission

## Goal
After submitting a match result, show a clear result/share CTA instead of simply navigating back.

## Context
The moment after submitting the score is one of the strongest sharing moments in El7reef. The user should be invited to share the result immediately.

## Product decision
Result sharing is part of the V1 core loop.

## Scope
Do:
- Locate the score submission success flow.
- After a successful score submission, show a bottom sheet/dialog/result action surface.
- Include a clear action to share the result card.
- Include a secondary action to return to matches/lobby/details.
- Reuse existing result share card/controller/services.

Do not:
- Rewrite score settlement logic.
- Change match result data model unless necessary.
- Build a new share system.
- Modify tournament result settlement unless the same controller is explicitly shared and must remain safe.
- Add dependencies.

## Likely files
- lib/features/match/controllers/score_submit_controller.dart
- lib/features/match/views/score_submit_screen.dart
- lib/features/lineup/views/match_result_lineup_screen.dart
- lib/features/shareables/widgets/match_result_share_card.dart
- lib/features/shareables/services/share_card_capture_service.dart
- lib/features/shareables/controllers/match_result_share_controller.dart

## Required behavior
After the user submits a score successfully:
- Show confirmation that the result was saved.
- Show the score clearly if data is available.
- Offer a primary action to share the result.
- Offer a secondary action to return to a relevant screen.

The user should not be dropped back without a visible next step.

## Acceptance criteria
- [ ] Successful score submission shows result/share actions.
- [ ] Result share action opens or triggers existing result share flow.
- [ ] User can still return without sharing.
- [ ] Existing validation and score save logic remains intact.
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
