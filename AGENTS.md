# AGENTS.md

## Project
El7reef is an Arabic-first Flutter/GetX football street-match app.

The V1 product goal is:
Let an organizer create a friendly match, add registered or temporary players, optionally create a lineup, start the match, submit the result, and share lineup/result cards.

## Current priority
Focus on the Friendly Match Core Loop before tournaments, fantasy, or advanced social features.

Core loop:
Create Match
→ Add Players / Guests
→ Optional Lineup
→ Start Match
→ Submit Result
→ Share Result / Lineup
→ Invite More People

## Product principles
- Arabic RTL first.
- Street football reality first: not all players have accounts.
- Temporary players are first-class citizens.
- Lineups are optional, but the UX should strongly encourage creating and sharing them.
- No fake features.
- No dead buttons.
- No "coming soon" messages inside the core friendly match flow if the feature already exists elsewhere.
- Sharing is a growth engine, not a secondary action.
- Keep the match creation flow fast.

## MVP scope
In scope:
- Friendly match creation.
- Team size selection from 5v5 to 11v11.
- Registered players.
- Temporary players.
- Optional lineup creation.
- Lineup sharing.
- Start match.
- Submit result.
- Result sharing.
- Basic teams/guest support only when needed by the core loop.

Out of scope for now:
- Fantasy.
- Advanced tournaments.
- Advanced social feed.
- Deep statistics.
- Complex rankings.
- Maps-heavy location experience.
- Monetization.

## Codebase expectations
- Follow the existing architecture and naming conventions.
- Prefer small targeted changes over broad rewrites.
- Do not introduce new dependencies unless clearly necessary.
- Do not change Firebase collection names unless the task explicitly asks for it.
- Do not break existing routes, models, or tests without explaining why.
- Prefer using existing services/controllers before creating new ones.
- Use AppRoutes helpers when available instead of raw route strings.
- Keep UI text Arabic-first where user-facing.
- Preserve RTL behavior.
- Do not remove existing features unless the task explicitly says to hide, gate, or simplify them.

## Flutter commands
After code changes, run when available:
- flutter pub get
- dart analyze lib/
- flutter test

If Flutter/Dart is unavailable in the environment, state that clearly in the final report and list the commands that should be run locally.

## Output expected after each task
At the end of every task, report:
1. Summary of what changed.
2. Files changed.
3. Any UX behavior changed.
4. Tests/checks run.
5. Any commands that could not be run.
6. Risks or follow-up tasks.

## Important current product decisions
- Firestore rules are not currently deployed, so they are not the first implementation blocker.
- Lineups are optional, not required.
- If a user starts a match without a lineup, show encouragement/nudge, not a hard block.
- The immediate roadmap should start with Product Baseline, Friendly Match Flow, Optional Lineup Encouragement, and Result Sharing.

## Do not do this
- Do not implement the whole roadmap in one task.
- Do not start with fantasy.
- Do not start with advanced tournament work.
- Do not build fake UI surfaces.
- Do not hide important sharing actions behind tiny icons only.
- Do not count only registered players when temporary players are present.