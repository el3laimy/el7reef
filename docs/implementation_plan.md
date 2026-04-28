# El7reef Implementation Plan

## Vision
El7reef V1 is an Arabic-first street football app that helps organizers create friendly matches, add players even if they are not registered, optionally create lineups, submit results, and share beautiful football cards.

## V1 Goal
Own the best simple Arabic experience for organizing and sharing a street football match.

## Core User Journey
Create Match
→ Add Players / Guests
→ Optional Lineup
→ Start Match
→ Submit Result
→ Share Result / Lineup
→ Invite More People

## MVP Acceptance Criteria
The MVP is successful when a user can:

1. Create a 7v7 friendly match.
2. Add registered players.
3. Add temporary players.
4. See correct player counts including temporary players.
5. Create an optional lineup.
6. Save a complete or incomplete lineup with clear warnings.
7. Share the lineup from a clear CTA.
8. Start the match without being forced to create a lineup.
9. See a nudge before starting without a lineup.
10. Submit the final score.
11. Share the result immediately after submitting.
12. Complete the flow without dead buttons or misleading "coming soon" messages.

## Roadmap

### Sprint 0: Product Baseline
Goal:
Define MVP scope, hide distractions, and document the current implementation.

Deliverables:
- Confirm MVP screens.
- Confirm disabled/deferred features.
- Confirm feature flags.
- Confirm core flow.
- Create QA checklist.

### Sprint 1: Friendly Match Flow
Goal:
Make friendly match creation and lobby flow clear and usable.

Deliverables:
- Clear create match flow.
- Correct player counts.
- Temporary players visible as real match participants.
- Remove misleading "coming soon" messages from core flow.
- Clear CTAs in match lobby.

### Sprint 2: Optional Lineup Encouragement
Goal:
Lineups remain optional but are strongly encouraged.

Deliverables:
- Nudge before starting without lineup.
- Clear "Create Lineup" CTA.
- Clear "Share Lineup" CTA after saving.
- Incomplete lineup warning.

### Sprint 3: Result & Share Loop
Goal:
Turn match completion into a share moment.

Deliverables:
- Result submission flow shows share actions.
- Result card can be opened/shared clearly.
- Share fallback/error handling.
- Result share CTA accessible from match details/card.

### Sprint 4: Guest Identity
Goal:
Make temporary players first-class citizens.

Deliverables:
- Better temporary player add/edit flow.
- Temporary players appear consistently in counts, lineups, and share cards.
- Prepare basic invite/claim path.

### Sprint 5: Teams V1
Goal:
Allow captains to manage simple teams.

Deliverables:
- Create team.
- Add registered and temporary players.
- Team profile.
- Simple captain/manager controls.
- Team lineup reuse.

### Sprint 6: Backend Readiness
Goal:
Prepare for real deployment.

Deliverables:
- Firestore rules aligned with used collections.
- Storage rules reviewed.
- Required indexes documented.
- Permission model reviewed.
- Emulator/staging testing plan.

### Sprint 7: Tournaments Lite
Goal:
Manage small real tournaments without fake surfaces.

Deliverables:
- Create tournament.
- Add/approve teams.
- Generate groups/fixtures.
- Submit results.
- Show real standings.
- Complete champion flow.

## Deferred
- Fantasy.
- Advanced social feed.
- Advanced stats.
- Advanced rankings.
- Heavy maps/location experience.
- Monetization.