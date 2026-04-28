# Task 008: Friendly Match Manual QA Checklist

## Goal
Create or update a manual QA checklist for the Friendly Match Core Loop.

## Context
After several UX changes, we need a repeatable manual QA path to confirm the user can complete the V1 loop without confusion.

## Product decision
The MVP is successful only when the full friendly match flow works end-to-end for registered and temporary players.

## Scope
Do:
- Create or update a QA checklist document under docs/.
- Cover the complete core flow:
  Create Match -> Add Players / Temporary Players -> Optional Lineup -> Start Match -> Submit Result -> Share Lineup / Result.
- Include expected behavior and failure signs.
- Include Arabic RTL and mobile usability checks.

Do not:
- Modify app code unless necessary for a tiny doc link or comment.
- Add dependencies.
- Work on tournaments/fantasy/social feed.

## Suggested file
- docs/qa/friendly_match_core_loop_qa.md

## Required checklist areas
Include checks for:
- Create a 7v7 friendly match.
- Add registered players.
- Add temporary players.
- Verify counts include temporary players.
- Open lineup editor.
- Save complete lineup.
- Save incomplete lineup if allowed and verify warning.
- Share lineup.
- Start match with lineup.
- Start match without lineup and verify nudge.
- Submit score.
- Share result immediately after score submission.
- Share result later from a result surface.
- Verify no misleading "coming soon" appears in the core flow.
- Verify Arabic text and RTL layout.

## Acceptance criteria
- [ ] QA checklist file exists under docs/qa/.
- [ ] Checklist covers the full V1 friendly match loop.
- [ ] Checklist includes expected results and red flags.
- [ ] Checklist includes temporary players and share flows.
- [ ] No app behavior is changed unless explicitly justified.

## Testing/checks
No code tests required if only docs changed.
If code changed, run if available:
- dart analyze lib/
- flutter test

## Final report
Return:
1. Summary of documentation changes.
2. Files changed.
3. Any code changes, if any.
4. Follow-up QA recommendations.
