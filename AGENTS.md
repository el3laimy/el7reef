# AGENTS.md

## Project
El7reef is an Arabic-first Flutter/GetX football street-match and tournament app.

The V1 product goal is:
**Tournament Ego MVP** — Let an organizer run a street tournament with registered and guest teams/players, record match results with goal scorers and MVP (including guests), generate leaderboards, and produce shareable pride cards that drive player claims and viral growth.

## Current priority
Focus on the Tournament Ego Core Loop. Friendlies and challenges are secondary retention loops between tournaments.

Core loop:
Create Tournament
→ Add Teams (registered or guest)
→ Add Players (registered or guest)
→ Generate Fixtures
→ Play Matches
→ Record Results + Goal Scorers + MVP (guests included)
→ Update Standings & Top Scorers
→ Share Pride Cards (Result / MVP / Player / Top Scorers / Champion)
→ Guest Players Claim Profiles
→ Challenges & Friendlies between tournaments

## Product principles
- Arabic RTL first.
- Street football reality first: not all players have accounts.
- Temporary players and guest teams are first-class citizens.
- Guest players MUST be able to receive goals, MVP, and appear in share cards and leaderboards.
- Tournaments are the heart of the app and the growth engine.
- Matches are the building blocks that produce data. Data produces pride. Pride produces sharing. Sharing brings new players.
- Lineups are optional, but the UX should encourage creating and sharing them.
- Share cards must appear at moments of pride, not hidden in menus.
- No fake features.
- No dead buttons.
- No "coming soon" messages inside the core tournament/match flow.
- Sharing is a growth engine, not a secondary action.
- Fantasy UI is gated off in V1 — do not expose it.

## V1 scope
In scope:
- Tournament creation and lifecycle (groups, knockout, hybrid).
- Team management (registered + guest teams).
- Player management (registered + guest players).
- Hybrid tournament registration (official + guest teams in same tournament).
- Match creation within tournament/challenge/friendly context.
- Team size selection from 5v5 to 11v11.
- MatchEvent-based goal/MVP recording for ALL player types.
- Tournament standings and top scorers leaderboards.
- Optional lineup creation and sharing.
- Start match, submit result, approve/settle result.
- Share cards: Result, MVP, Player, Top Scorers, Team, Lineup, Champion.
- Guest player/team claim via links and QR.
- Audit events and basic dispute flow.
- Challenges between teams as retention loop.
- Simple friendlies (not the main message, but supported).
- Play Store readiness: release signing, target SDK, privacy policy, data safety.

Out of scope for V1:
- Fantasy.
- Advanced social feed.
- In-app chat.
- Complex player ratings.
- Pitch bookings.
- Advanced maps experience.
- Live streaming.
- Monetization.
- Player transfer market.

## Key technical decisions for V1
- MatchEvent is the source of truth for goals, MVP, and match statistics — not scattered player_stats fields.
- PlayerIdentityRef (registered | guest | matchSidePlayer) is used everywhere stats or share cards reference a player.
- Guest players receive full statistical treatment identical to registered players.
- Services handle all sensitive operations — not controllers writing directly to Firestore.
- Feature gates are explicit: fantasy is off, social feed is secondary.

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
- Respect the existing design system (8px grid, Cairo font, AppDesign tokens).

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
- Firestore rules exist but may need updates for new collections like matchEvents.
- Lineups are optional, not required.
- If a user starts a match without a lineup, show encouragement/nudge, not a hard block.
- The immediate roadmap follows the Sprint Plan in docs/05_Project_Roadmap_and_Sprint_Plan.md.
- Score submission must support guest players as goal scorers and MVP — the old message "temporary players don't get stats" must be removed.

## Do not do this
- Do not implement the whole roadmap in one task.
- Do not start with fantasy.
- Do not build fake UI surfaces.
- Do not hide important sharing actions behind tiny icons only.
- Do not count only registered players when temporary players are present.
- Do not record stats for registered players only — guest players are first-class.
- Do not expose fantasy toggles or UI in V1.
- Do not treat friendlies as the core product message — tournaments are the heart.

## Reference documentation
See `docs/` for the full V1 documentation pack:
- `docs/01_PRD_Product_Requirements_Document.md`
- `docs/02_SRS_Software_Requirements_Specification.md`
- `docs/03_SAD_System_Architecture_Document.md`
- `docs/04_UI_UX_Designs.md`
- `docs/05_Project_Roadmap_and_Sprint_Plan.md`