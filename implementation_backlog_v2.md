# EL7REEF Implementation Backlog V2

Version: 2026-04-20
Source Docs:
- [product_plan.md](product_plan.md)
- [engineering_plan.md](engineering_plan.md)
- [tournament_tos_execution_rules.md](tournament_tos_execution_rules.md)
- [tournament_cross_app_flow_gap_report_ar.md](tournament_cross_app_flow_gap_report_ar.md)
- [tournament_repair_sprint_plan_ar.md](tournament_repair_sprint_plan_ar.md)
- [master_reference_alignment_gap_plan_ar.md](master_reference_alignment_gap_plan_ar.md)

Status Model:
- `Todo`
- `In Progress`
- `Blocked`
- `Done`

## Backlog Goal

Turn the V2 product and engineering direction into execution-sized tickets that are ordered, dependency-aware, and ready for implementation.

## Baseline Already Completed Before V2

These items are already in place and should be treated as foundation rather than open work:

- Firestore ownership hardening
- route contract cleanup
- match settlement stabilization
- activity feed real-data baseline
- fantasy lifecycle service
- fantasy chips and transfer policy
- fantasy round settlement and coverage

## Recommended Execution Sequence

1. `V2-001` to `V2-005`
2. `V2-006` to `V2-011`
3. `V2-012` to `V2-018`
4. `V2-019` to `V2-023`
5. `TOS-001` to `TOS-010`
6. `TOS-FIX-001` to `TOS-FIX-031`
7. `V2-024` to `V2-028`
8. `V2-029` to `V2-032`
9. `V2-033` to `V2-036`
10. `V2-037` to `V2-044`
11. `V2-045` to `V2-056`
12. `TOS-FIX-032` to `TOS-FIX-045` when full mixed guest-player fantasy becomes active scope

## Tournament Operating System Reset

The tournament module is no longer treated as "registration-complete". The
next execution slice is an operations-first reset that turns the module from
registration and review flows into a real tournament operating system.

### TOS-001 to TOS-010

Status: `In Progress`

Key outcomes:
- freeze misleading tournament surfaces and status-only controls
- establish `TournamentParticipant` as the canonical participant entity
- keep any legacy backfill/manual migration work optional and outside the critical path while current data remains disposable
- move lifecycle transitions into audited orchestration services
- expand `Match` into tournament-grade fixture storage
- add real groups, standings, knockout bracket, and operations dashboard
- cover the operating path with service and UI tests before returning to `V2-039`

Execution Snapshot: `2026-04-19`

- `TOS-001` `Done`: misleading tournament surfaces are frozen; fake standings and unbacked bracket/dashboard entry points were removed or rerouted.
- `TOS-002` `Done`: `TournamentParticipant` is now the canonical tournament participant entity with service-owned approval sync and participant lifecycle state.
- `TOS-002.5` `Done`: approved registrations can be backfilled into participants when needed, but this is now treated as optional maintenance rather than a blocker for ongoing product development.
- `TOS-003` `Done`: lifecycle transitions now run through `TournamentLifecycleService` orchestration instead of raw status flips.
- `TOS-004` `Done`: `Match` has been expanded into fixture-capable tournament storage with stage, group, slot, publish, and scheduling metadata.
- `TOS-005` `Done`: group-stage core exists end-to-end with generated groups, draft fixtures, persisted standings snapshots, and qualifier extraction.
- `TOS-006` `Done`: fixture queries, single-fixture scheduling, venue/time editing, `publishFixtures`, and guarded `regenerate groups` are now implemented.
- `TOS-007` `Done`: single-elimination knockout build and winner advancement are implemented with canonical bracket and tie persistence.
- `TOS-008` `Done`: the Tournament Operations Dashboard now supports `manual add`, `replace participant`, `withdraw`, fixture scheduling, fixture publication, and guarded group regeneration.
- `TOS-009` `Done`: real-data screens for participants, groups, fixtures, standings, and bracket now cover day-to-day organizer flows with operator-grade filtering, drill-downs, state clarity, and participant recovery/seed controls.
- `TOS-010` `In Progress`: audit events and service/UI coverage are in place; canonical `activeParticipantCount` is now synced on tournament writes, player tournament reads prefer canonical participants with legacy fallback, tournament registration capacity checks now prefer canonical participant summary before any legacy arrays, the old raw `status flip` repository/controller path has been retired, new tournament writes no longer persist empty legacy `groupRoundIds` / `knockoutRoundIds` while historical values remain preserved on read/update, organizer dashboard refresh avoids maintenance work in the default path, organizer dashboard group/knockout screens now load persisted state instead of forcing lifecycle recalculation on every open, organizer operations UI now uses cached derived labels for groups / fixtures / bracket instead of repeated list scans and raw IDs, frequent organizer actions now use targeted partial state updates instead of `refreshAll()` whenever a full reload is unnecessary, tournament registration / matchday flows now use more batched reads to reduce round trips and mobile data usage, standings / knockout refresh now skip persistence when no tournament state actually changed, participant search now uses debounce + short-lived caching, approved-registration participant sync now skips redundant participant rewrites when the canonical record is already current, participant summary refresh now skips tournament writes when `activeParticipantCount` is already correct, `replace/reactivate` participant flows now update local ops state directly instead of reloading the full participants list, `publishFixtures` now returns the post-publish fixture state without an extra repository reload, pilot smoke coverage now exercises the approval-driven tournament flow from groups through champion, and key organizer commands like `finalizeParticipants`, `scheduleFixture`, `completeTournament`, `withdrawParticipant`, and unchanged `seed` edits now avoid duplicate writes / duplicate audit when the requested state is already current. Broader cleanup and any remaining low-value legacy retirement still remain.

Current Focus:

- execute the new tournament repair workstream before returning to organizer hybrid/fantasy expansion: close `start match`, guest-team roster ownership, and guest-result flow gaps first
- production-first hardening for organizer flows: reduce non-essential reads/writes, remove maintenance work from default operating paths, and keep dashboard actions centered on real tournament ops
- treat current tournament data as resettable test data; do not create new migration-heavy work unless it directly unlocks production behavior
- begin `pilot pass readiness` with smoke coverage and a manual organizer checklist before full real-world validation
- widen `TOS-010` cleanup, regression hardening, and legacy retirement
- keep migration/compatibility work secondary and manual-only unless it directly protects a production flow
- keep full mixed guest-player fantasy explicitly outside the critical path unless it is deliberately scheduled as follow-on scope
- preserve the broader product vision in parallel planning: player identity depth, discovery, notifications, and provider-abstraction work are now scheduled as post-tournament-repair backlog, not forgotten intent

## Master Vision Alignment Snapshot

Status: `Updated`

This snapshot keeps the master project vision tied directly to execution
reality so the backlog is judged against product truth, not only module-by-module
progress.

- `Player Identity` `Partial`: baseline profile, ratings, stats, and trust exist; richer football identity, participation history, and credibility surfaces are queued in `V2-045` to `V2-048`.
- `Team Operations` `Partial`: roster, invite, claim, lineup, and role foundations exist; user-initiated join requests are queued in `V2-051`.
- `Tournament Operations` `In Repair`: the TOS core is built, but cross-app match activation, guest roster ownership, and guest-result completion remain the current blocking work in `TOS-FIX-001` to `TOS-FIX-031`.
- `Match / Result Canonical Truth` `Partial`: internal matchday and settlement truth are strong enough for current tournament operations; external match-data and provider boundaries are formalized later in `V2-056`.
- `Search / Discovery` `Weak`: search exists in isolated surfaces; unified search and Explore remain queued in `V2-049` and `V2-050`.
- `Notifications / Communication` `Weak`: operational events are still underrepresented as a product layer; canonical notifications and inbox work are queued in `V2-052` and `V2-053`.
- `Unregistered Entities And Claim Flows` `Strong`: guest players, guest teams, claim flows, and placeholder-friendly growth logic are established foundations and remain central to the roadmap.
- `Provider Flexibility / Architecture Boundaries` `Partial`: repositories and service separation are present, but auth, storage, map, and external-data abstraction seams remain queued in `V2-054` to `V2-056`.
- `Fantasy / Analytics Future Layer` `Planned`: current fantasy foundations exist, but mixed guest-player fantasy remains explicitly outside the critical path until tournament repair is complete.

Execution Rule:

- do not open `V2-045` to `V2-056` until `TOS-FIX-001` to `TOS-FIX-031` materially close the tournament repair path
- treat `V2-045` to `V2-056` as backlog that preserves the long-term vision, not as distraction from current tournament blockers

## Post-Tournament Vision Priority Order

Status: `Planned`

Once `TOS-FIX-001` to `TOS-FIX-031` are materially closed, continue in this order:

1. close the already-nearby organizer hybrid/fantasy hardening slice in `V2-039` to `V2-044`
2. open the minimum identity foundation in `V2-045` so player discovery and credibility are not built on thin profile data
3. execute the growth-loop surface in `V2-049` to `V2-053` to unlock unified search, explore, join requests, and essential notifications
4. complete the deeper player credibility layer in `V2-046` to `V2-048`
5. finish platform-boundary work in `V2-054` to `V2-056`, preferably when the touched modules are actively being expanded again

Why this order:

- `V2-039` to `V2-044` are adjacent to the tournament work already in flight and should be closed before opening broader product surfaces
- `V2-045` is the smallest high-leverage schema step that makes later search, cards, and profile credibility materially better
- `V2-049` to `V2-053` best express the product vision’s growth loops: discover players and teams, request to join, and receive action-triggered updates
- `V2-046` to `V2-048` become more meaningful after discovery and notifications are real product surfaces rather than isolated profile upgrades
- `V2-054` to `V2-056` matter structurally, but they should not delay user-facing growth surfaces unless provider pressure or new backend integration work makes them immediately valuable

Execution Rules:

- use [tournament_tos_execution_rules.md](tournament_tos_execution_rules.md) as the operating reference for ownership, sequencing, and anti-conflict guardrails during the TOS workstream

Operational Milestone Reached:

- tournament results now affect standings and knockout progression only after official score approval
- score approval refreshes tournament standings or bracket automatically
- the module has crossed from registration-centric into operating-system baseline, but not yet into fully polished day-to-day tournament ops

### Tournament Finalization Gap Snapshot

Status: `Closed`

This is the short list that still blocks calling the tournament module `100% complete`.

- `FG-01` `Done`: `TournamentDetailScreen` now shows human-readable tournament status, resolves champion display name from participant state, and includes a direct `Standings` deep link in the operating summary block.
- `FG-02` `Done`: `Tournament Operations Dashboard` now includes pending-actions summary, readiness checklist, quick fixture counters, and safer enable/disable logic for lifecycle buttons instead of exposing actions as a flat button list only.
- `FG-03` `Done`: `Participants` screen now has grouped sections for active / withdrawn / replaced participants, richer status/source chips, explicit `Reactivate` recovery for mistaken withdraw/replace cases, and inline `seed` editing before operational stages begin.
- `FG-04` `Done`: `Groups` screen now shows per-group fixture and progress summary, qualifier badges, and a direct drill-down into each group’s fixture subset.
- `FG-05` `Done`: `Fixtures` screen now includes operator-grade filters by stage / group / publication state / schedule state / scheduled day, direct `Matchday` and `Score Review` navigation from fixture rows, and clearer readiness cues per fixture.
- `FG-06` `Done`: `Standings` screen now renders a tournament-grade table with explicit `P / W / D / L / GF / GA / GD / Pts` columns, qualifier highlighting, and visible last-updated / canonical snapshot messaging.
- `FG-07` `Done`: `Bracket` screen now groups ties by round, includes knockout/final summary cards, and provides direct navigation from ties to the underlying fixture workflow.
- `FG-08` `Done`: tournament UI regression coverage now includes dedicated widget tests for `Fixtures`, `Standings`, `Bracket`, `TournamentDetailScreen`, and an organizer happy-path navigation regression across the operating surfaces.
- `FG-09` `Done`: participant picker/search dialogs now use debounced auto-search plus short-lived candidate caching to reduce repeated query churn without removing manual search control.

## Tournament Cross-App Repair Workstream

Status: `Ready`

The TOS reset solved the tournament operating core, but cross-surface execution
still has real blockers around `startMatch`, guest-team roster ownership,
score submission, and tournament-linked fantasy. This workstream turns the gap
report into execution-ready tickets.

Execution policy:

- finish `TOS-FIX-001` to `TOS-FIX-031` before resuming `V2-039` or any mixed guest-team fantasy expansion
- keep current tournament data disposable and do not create migration-heavy work unless it directly unlocks production behavior
- treat `TOS-FIX-032` to `TOS-FIX-045` as a separate optional path for full mixed guest-player fantasy, not as a blocker to closing tournament ops

### Tournament Repair Sprint 1 — Match Activation and Live Result Flow

Status: `Ready`

Goal:

- make tournament fixtures playable end-to-end through `open -> live -> submit score -> approve score`

Tasks:

- `TOS-FIX-001`: add a guarded `startMatch` command for tournament fixtures
- `TOS-FIX-002`: add `Start Match` actions in the Tournament Operations Dashboard and fixture rows
- `TOS-FIX-003`: block `startMatch` until both sides are checked in and lineups are locked
- `TOS-FIX-004`: project locked lineups into a live match roster representation
- `TOS-FIX-005`: update score submission to read the official match roster instead of relying only on `teamAPlayerIds` / `teamBPlayerIds`
- `TOS-FIX-006`: wire fan voting and settlement to the official live match roster
- `TOS-FIX-007`: add service/UI regression coverage for `open -> live -> submit -> approve`

Definition of Done:

- a tournament fixture can be started from the tournament flow
- score submission opens naturally after match start
- registered-team tournament matches work without workaround paths

### Tournament Repair Sprint 2 — Guest Team Roster Domain and Permissions

Status: `In Progress`

Goal:

- give guest teams a real roster model inside tournament operations

Tasks:

- `TOS-FIX-008`: add `guestTeamId` to `GuestPlayer` and `GuestPlayerModel`
- `TOS-FIX-009`: add guest-player repository queries scoped by `guestTeamId`
- `TOS-FIX-010`: build a `TournamentGuestRosterService` / `GuestTeamRosterService`
- `TOS-FIX-011`: add create, update, archive, and captain-management commands for guest players
- `TOS-FIX-012`: expand `TournamentPermissionService` with guest-team and guest-roster permissions
- `TOS-FIX-013`: map guest-roster permissions into assistant roles instead of relying on broad `canManageTeams` only
- `TOS-FIX-014`: emit audit events for guest roster operations
- `TOS-FIX-015`: add repository/service tests for ownership and guest-team isolation

Progress Snapshot:

- `Done`: `TOS-FIX-008`, `TOS-FIX-009`, `TOS-FIX-010`, `TOS-FIX-011`, `TOS-FIX-012`, `TOS-FIX-013`, `TOS-FIX-014`, `TOS-FIX-015` foundation
- `What shipped`:
  - `GuestPlayer` now carries `guestTeamId`
  - guest-player repository now supports `getGuestTeamPlayers(guestTeamId)`
  - `GuestTeamRosterService` now supports `create`, `update`, `archive`, and `setCaptain`
  - `TournamentPermissionService` now exposes explicit guest-roster permissions
  - guest-roster audit events now exist and are covered by tests
  - `MatchdayController` guest side now loads the selected guest-team roster instead of a tournament-wide guest list
- `Still remaining in Sprint 2`:
  - expose guest-roster management through tournament UI
  - connect guest-roster management to share/claim affordances more directly in organizer flows

Definition of Done:

- every guest player belongs explicitly to a guest team
- organizers can manage guest players without relying on generic team flows
- guest players are isolated by guest team, not by tournament-wide guest lists

### Tournament Repair Sprint 3 — Guest Team Roster UI and Matchday Integration

Status: `Ready`

Goal:

- expose guest-team roster operations in the tournament UI and bind matchday to the correct roster

Tasks:

- `TOS-FIX-016`: build a `Guest Team Roster` screen under tournament operations
- `TOS-FIX-017`: add deep links from `Participants`, `Groups`, and `Fixtures` to guest-team roster management
- `TOS-FIX-018`: update `MatchdayController` to load guest players by `guestTeamId` only
- `TOS-FIX-019`: remove the current tournament-wide guest-player fallback from guest-team matchday management
- `TOS-FIX-020`: expose guest-player claim link actions from the guest-team roster UI
- `TOS-FIX-021`: support position, jersey-number, and note editing in the guest roster UI
- `TOS-FIX-022`: add UI/integration tests for guest roster and matchday linking

Definition of Done:

- organizers can open and manage a guest-team roster from the tournament module
- guest-team matchday surfaces only show players belonging to that guest team
- guest roster editing is operationally usable before matchday

### Tournament Repair Sprint 4 — Guest Match Result Completion

Status: `Ready`

Goal:

- make guest-team matches fully playable, scorable, and approvable

Tasks:

- `TOS-FIX-023`: update score submission to support mixed lineups containing registered and guest players
- `TOS-FIX-024`: update `MatchSettlementService` to handle guest-player-backed match rosters correctly
- `TOS-FIX-025`: support MVP, player stats, and attendance truth for guest players through score approval
- `TOS-FIX-026`: preserve automatic standings / bracket refresh after official approval for guest-team matches
- `TOS-FIX-027`: add end-to-end tests for a group-stage fixture involving a guest team

Definition of Done:

- a guest team can complete a tournament match from check-in to approved result
- approved guest-team results update standings or knockout progression correctly

### Tournament Repair Sprint 5 — Pilot Pass and Production Hardening

Status: `Ready`

Goal:

- run the real organizer flow on fresh data and close operational friction before declaring the tournament path complete

Tasks:

- `TOS-FIX-028`: execute a full pilot pass on a tournament that includes registered teams and guest teams
- `TOS-FIX-029`: record operator friction points, permission issues, and runtime bottlenecks from the pilot
- `TOS-FIX-030`: fix high-priority friction found during pilot execution
- `TOS-FIX-031`: widen regression coverage around any repaired tournament flows

Definition of Done:

- the organizer can run a tournament end-to-end on fresh data without core blockers
- guest-team operations are no longer a broken edge case in tournament execution
- the tournament repair path is ready to exit the critical path

### Tournament Repair Sprint 6 — Competition Player Core

Status: `Planned`

Goal:

- introduce a unified competitive identity for registered and guest players if mixed fantasy becomes active scope

Tasks:

- `TOS-FIX-032`: define `CompetitionPlayer` / `TournamentAthlete` domain model
- `TOS-FIX-033`: add canonical fields for tournament, participant, source type, source ids, position, and fantasy eligibility
- `TOS-FIX-034`: build repository/service support for syncing competition players from real rosters
- `TOS-FIX-035`: route match stats, MVP, and roster truth through the unified competition-player identity
- `TOS-FIX-036`: add domain/service tests for the unified identity layer

Definition of Done:

- every player affecting tournament results has a unified competitive identity, whether registered or guest

### Tournament Repair Sprint 7 — Mixed Fantasy Market and Slots

Status: `Planned`

Goal:

- move tournament-linked fantasy from raw `playerId` assumptions to competition-player eligibility

Tasks:

- `TOS-FIX-037`: evolve fantasy slots toward `competitionPlayerId`
- `TOS-FIX-038`: add market values / eligibility for guest-backed competition players
- `TOS-FIX-039`: update fantasy create-team, squad, and transfer flows to use the new identity layer
- `TOS-FIX-040`: update leaderboard and transfer-market surfaces for mixed tournament fantasy
- `TOS-FIX-041`: add UI/service regression coverage for the mixed fantasy market path

Definition of Done:

- tournament-linked fantasy can represent eligible guest-backed players without breaking existing registered-player flows

### Tournament Repair Sprint 8 — Fantasy Settlement and Elimination Wiring

Status: `Planned`

Goal:

- connect approved tournament results and knockout elimination to mixed fantasy settlement

Tasks:

- `TOS-FIX-042`: update round settlement to score by competition-player identity
- `TOS-FIX-043`: wire tournament lifecycle transitions explicitly into fantasy lifecycle progression
- `TOS-FIX-044`: connect elimination/emergency-transfer logic to real tournament progression
- `TOS-FIX-045`: add smoke coverage for tournament + mixed fantasy end-to-end flow

Definition of Done:

- approved tournament results and eliminations affect mixed fantasy correctly in tournament-linked leagues

## Epic A: Hybrid Identity Foundation

### V2-001: Define `GuestPlayer` domain model and enums

Parent: `EPIC-A`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: None
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/core/enums/`
- `lib/data/models/`

Implementation:
- Add `GuestPlayer` entity and model.
- Add claim status enum and any supporting value objects.
- Keep fields compatible with later claim and merge flows.

Acceptance:
- Guest player data is expressible without using registered player hacks.
- Serialization supports nullable contact and linkage fields.

### V2-002: Define `GuestTeam` domain model and enums

Parent: `EPIC-A`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: None
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/core/enums/`
- `lib/data/models/`

Implementation:
- Add `GuestTeam` entity and model.
- Support contact details, tournament linkage, and claim status.
- Reserve fields needed by organizer and claim flows.

Acceptance:
- Guest teams are represented explicitly and queryable.
- Registered and guest team records can coexist safely.

### V2-003: Add Firestore paths, repositories, and rules for guest entities

Parent: `EPIC-A`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-001`, `V2-002`
Likely Touchpoints:
- `lib/core/constants/firebase_paths.dart`
- `lib/domain/repositories/`
- `lib/data/repositories/`
- `firestore.rules`

Implementation:
- Add collection paths for guest players, guest teams, and claim codes.
- Add repository contracts and implementations.
- Lock writes to authorized team or tournament owners only.

Acceptance:
- Guest entities have primary repository access paths.
- Rules do not allow arbitrary authenticated writes.

### V2-004: Add CRUD tests for guest entities

Parent: `EPIC-A`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `V2-003`
Likely Touchpoints:
- `test/data/repositories/`
- `test/core/services/`

Implementation:
- Add repository tests for create, read, update, and archive flows.
- Cover claim status transitions at the data layer.

Acceptance:
- Guest entity repositories are covered for happy path and invalid path behavior.

### V2-005: Add feature flags and bootstrap docs for hybrid mode

Parent: `EPIC-A`
Priority: `P1`
Estimate: `S`
Status: `Done`
Depends On: `V2-003`
Likely Touchpoints:
- `lib/core/constants/feature_flags.dart`
- `README.md`

Implementation:
- Add flags for guest identity and hybrid tournament flows.
- Document minimum seed and environment assumptions.

Acceptance:
- Engineers can enable hybrid mode intentionally.
- New collections and flags are documented.

## Epic B: Team Membership And Roster Engine

### V2-006: Introduce `TeamMembership` schema and repository layer

Parent: `EPIC-B`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-003`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`
- `lib/domain/repositories/`
- `lib/data/repositories/`

Implementation:
- Add membership entity supporting registered or guest linkage.
- Add repository reads and writes by team.
- Preserve compatibility with current team records during migration.

Acceptance:
- Team membership is no longer blocked on player arrays only.
- Membership can point to either `playerId` or `guestPlayerId`.

### V2-007: Build `TeamRosterService`

Parent: `EPIC-B`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-006`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/repositories/`

Implementation:
- Add service methods for add, remove, replace, promote, bench, and archive flows.
- Support both registered and guest players.
- Keep all critical writes audit-friendly.

Acceptance:
- Team roster actions are service-driven, not controller-driven.
- Guest replacement after claim is supported.

### V2-008: Add roster role, availability, and validation policies

Parent: `EPIC-B`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-007`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/`

Implementation:
- Define starter, bench, inactive, guest, and role validation.
- Add availability states and validation rules.
- Block invalid lineup states before matchday.

Acceptance:
- Illegal roster states are rejected centrally.
- Availability and role rules are reusable by UI and services.

### V2-009: Build roster management UI for teams

Parent: `EPIC-B`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-007`, `V2-008`
Likely Touchpoints:
- `lib/features/team/`
- `lib/features/fantasy/` where reuse is needed

Implementation:
- Add roster list, move-to-bench, change-role, and remove flows.
- Show guest vs registered participants clearly.
- Expose Arabic validation errors for failed actions.

Acceptance:
- Captains can operate the roster from UI without raw data edits.
- Guest membership is visually distinct and supported.

### V2-010: Add formation templates and roster snapshots

Parent: `EPIC-B`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-007`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/core/services/`
- `lib/features/team/`

Implementation:
- Allow saving named formation templates.
- Support generating a match-ready roster snapshot.

Acceptance:
- Teams can reuse lineup structures across matches or tournaments.

### V2-011: Add roster unit, repository, and flow tests

Parent: `EPIC-B`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-007`, `V2-008`, `V2-009`
Likely Touchpoints:
- `test/core/services/`
- `test/data/repositories/`
- `test/features/`

Implementation:
- Cover add, remove, replace, and invalid role transitions.
- Cover roster UI state and error surfaces.

Acceptance:
- Team roster operations have automated regression coverage.

## Epic C: Claim And Merge Flows

### V2-012: Define claim payload and claim code model

Parent: `EPIC-C`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `V2-001`, `V2-002`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`

Implementation:
- Add claim payload model that can target guest player or guest team.
- Support expiry, scope, and status.

Acceptance:
- Claim payloads are reusable for deep links, QR, and approval flows.

### V2-013: Build `ShareLinkService` for claim and invite payloads

Parent: `EPIC-C`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-012`
Likely Touchpoints:
- `lib/core/services/`

Implementation:
- Generate payloads for claim links and team invites.
- Support QR serialization and deep-link-safe params.

Acceptance:
- One service can generate consistent share payloads for growth flows.

### V2-014: Implement guest player claim flow in `GuestClaimService`

Parent: `EPIC-C`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-003`, `V2-012`
Likely Touchpoints:
- `lib/core/services/`
- repositories for players, teams, memberships, audit

Implementation:
- Claim a guest player into a registered player identity.
- Re-link memberships and historical references safely.
- Prevent duplicate claim.

Acceptance:
- Claim is transaction-based and idempotent.
- Re-running the same claim does not duplicate linkage.

### V2-015: Implement guest team claim flow in `GuestClaimService`

Parent: `EPIC-C`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-003`, `V2-012`
Likely Touchpoints:
- `lib/core/services/`
- repositories for guest teams, teams, tournament registrations, audit

Implementation:
- Claim guest team into registered team ownership.
- Support organizer approval or verified ownership path.
- Re-link tournament registrations and roster relationships.

Acceptance:
- Guest team claim preserves tournament participation history.
- Double claim and conflict scenarios are handled explicitly.

### V2-016: Add merge conflict policy and duplicate identity handling

Parent: `EPIC-C`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-014`, `V2-015`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/`

Implementation:
- Define conflict-safe outcomes for duplicate phone, name, or target links.
- Add explicit merge result statuses for UI and audit.

Acceptance:
- Claim flow does not silently overwrite or merge ambiguous identities.

### V2-017: Build claim screens and route contracts

Parent: `EPIC-C`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-013`, `V2-014`, `V2-015`
Likely Touchpoints:
- `lib/app/routes/`
- `lib/features/guest_claim/`

Implementation:
- Add ID-based claim routes and bindings.
- Add guest player and guest team claim UI.
- Surface approval-required and conflict states.

Acceptance:
- Claim flows can start from a link or QR-derived route safely.

### V2-018: Add claim transaction and flow tests

Parent: `EPIC-C`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-014` to `V2-017`
Likely Touchpoints:
- `test/core/services/`
- `test/features/`

Implementation:
- Cover success, rerun, expired claim, and conflict paths.
- Cover claim UI happy path and blocked path.

Acceptance:
- Claim and merge flows are regression-protected.

## Epic D: Tournament Hybrid Registration

### V2-019: Define `TournamentRegistration` schema and repository

Parent: `EPIC-D`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-002`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`
- `lib/domain/repositories/`
- `lib/data/repositories/`

Implementation:
- Add explicit registration model for team or guest team participation.
- Support status and verification fields.

Acceptance:
- Tournament participation no longer depends on direct team arrays alone.

### V2-020: Build `TournamentRegistrationService`

Parent: `EPIC-D`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-019`
Likely Touchpoints:
- `lib/core/services/`

Implementation:
- Register registered teams and guest teams.
- Support quick mode and hybrid mode.
- Add idempotent approval and status transitions.

Acceptance:
- Tournament registration is service-owned and safe to retry.

### V2-021: Add organizer registration UI flows

Parent: `EPIC-D`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-020`
Likely Touchpoints:
- `lib/features/tournament/`
- `lib/app/routes/`

Implementation:
- Add register team, create guest team, and verify registration screens.
- Keep all routes ID-based and binding-backed.

Acceptance:
- Organizer can complete hybrid registration from mobile UI.

### V2-022: Add capacity, verification, and eligibility policies

Parent: `EPIC-D`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-020`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/`

Implementation:
- Enforce max teams, duplicate registration checks, and verification rules.
- Differentiate quick, hybrid, and verified modes.

Acceptance:
- Tournament mode changes behavior through central policy, not UI branching only.

### V2-023: Add hybrid registration tests

Parent: `EPIC-D`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-020` to `V2-022`
Likely Touchpoints:
- `test/core/services/`
- `test/features/`

Implementation:
- Cover guest team registration, duplicate rejection, capacity rejection, and approval.

Acceptance:
- Hybrid registration logic is covered end-to-end.

## Epic E: Matchday Operations

### V2-024: Define check-in and attendance models

Parent: `EPIC-E`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `V2-006`, `V2-019`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`

Implementation:
- Add attendance and check-in records scoped to match and team.
- Support registered and guest participant references.

Acceptance:
- Matchday attendance is represented explicitly and queryable.

### V2-025: Build `MatchdayService` for lineup validation and lock

Parent: `EPIC-E`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-024`, `V2-007`
Likely Touchpoints:
- `lib/core/services/`

Implementation:
- Validate lineups before lock.
- Save `MatchLineupSnapshot`.
- Make lock idempotent and audit-aware.

Acceptance:
- Match lineups can be locked exactly once per final pre-match state.

### V2-026: Add substitutions log and played-truth tracking

Parent: `EPIC-E`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-025`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/entities/`

Implementation:
- Track substitutions with timestamp and actor.
- Record who actually played and for how the match should treat them.

Acceptance:
- Match stats and later fantasy logic can rely on matchday truth.

### V2-027: Add matchday UI for check-in, lineup, and substitutions

Parent: `EPIC-E`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `V2-025`, `V2-026`
Likely Touchpoints:
- `lib/features/match/`
- `lib/app/routes/`

Implementation:
- Add check-in, lineup lock, and substitution screens.
- Support organizer and captain roles with clear action states.

Acceptance:
- Matchday flows are usable from the phone without admin console dependency.

### V2-028: Add matchday integration tests

Parent: `EPIC-E`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-025` to `V2-027`
Likely Touchpoints:
- `test/core/services/`
- `test/features/`

Implementation:
- Cover check-in, lineup lock, substitution, and invalid lineup paths.

Acceptance:
- Matchday truth flows are regression-covered.

## Epic F: Audit And Disputes

### V2-029: Define `AuditEvent` schema and write service

Parent: `EPIC-F`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `V2-003`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`
- `lib/core/services/`

Implementation:
- Add audit entity and writer service.
- Standardize entity type, action, actor, and before/after payload shape.

Acceptance:
- Sensitive services can record audit events uniformly.

### V2-030: Build `DisputeService`

Parent: `EPIC-F`
Priority: `P1`
Estimate: `L`
Status: `Done`
Depends On: `V2-029`, `V2-025`
Likely Touchpoints:
- `lib/core/services/`
- `lib/domain/entities/`

Implementation:
- Add dispute open, resolve, reject, and freeze actions.
- Support evidence links and deadlines.

Acceptance:
- Result and lineup disputes can be handled in structured flows.

### V2-031: Add audit timeline and dispute viewer UI

Parent: `EPIC-F`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-029`, `V2-030`
Likely Touchpoints:
- `lib/features/tournament/`
- `lib/features/match/`

Implementation:
- Show timeline of roster, lineup, score, and dispute actions.
- Add organizer-friendly dispute viewer.

Acceptance:
- Critical changes are visible without reading raw database state.

### V2-032: Add dispute and freeze tests plus rules coverage

Parent: `EPIC-F`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-030`, `V2-031`
Likely Touchpoints:
- `test/core/services/`
- `firestore.rules`

Implementation:
- Cover deadline, freeze, and unauthorized resolution cases.

Acceptance:
- Dispute and audit controls are testable and protected.

## Epic G: Growth And Sharing

### V2-033: Build team invite and claim share flows

Parent: `EPIC-G`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-013`, `V2-017`
Likely Touchpoints:
- `lib/core/services/`
- `lib/features/team/`

Implementation:
- Add share actions for team invite and roster spot claim.
- Prepare WhatsApp-friendly message text and payload usage.

Acceptance:
- Captains and organizers can start growth loops from team and tournament UI.

### V2-034: Add lightweight public entry surfaces

Parent: `EPIC-G`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-033`
Likely Touchpoints:
- route handling and lightweight entry screens

Implementation:
- Add entry screens for unopened users that explain claim or join action clearly.

Acceptance:
- Shared links land users on purpose-built flows rather than generic app entry.

### V2-035: Add post-participation claim prompts and feed events

Parent: `EPIC-G`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-014`, `V2-025`, `V2-029`
Likely Touchpoints:
- `lib/core/services/activity_feed_service.dart`
- `lib/features/social/`

Implementation:
- Create prompts like "you were added to a team" or "your rating is waiting".
- Tie prompts to guest participation and matchday events.

Acceptance:
- Participation can trigger growth-oriented claim surfaces.

### V2-036: Add growth telemetry and funnel metrics

Parent: `EPIC-G`
Priority: `P2`
Estimate: `S`
Status: `Done`
Depends On: `V2-033` to `V2-035`
Likely Touchpoints:
- telemetry or analytics layer if present

Implementation:
- Track invites sent, claim opens, claim completions, and join completions.

Acceptance:
- Product team can measure hybrid adoption and claim conversion.

## Epic H: Fantasy And Ops Integration

### V2-037: Connect matchday truth to fantasy eligibility

Parent: `EPIC-H`
Priority: `P1`
Estimate: `L`
Status: `Done`
Depends On: `V2-025`, `V2-026`
Likely Touchpoints:
- `lib/core/services/fantasy_round_settlement_service.dart`
- `lib/core/services/fantasy_points_engine.dart`

Implementation:
- Use lineup and played-truth data to improve fantasy settlement eligibility.
- Reduce dependence on inferred participation when better truth exists.

Acceptance:
- Fantasy scoring is more trustworthy when matchday data exists.

### V2-038: Complete fantasy live team and transfer UX

Parent: `EPIC-H`
Priority: `P1`
Estimate: `M`
Status: `Done`
Depends On: `V2-037`
Likely Touchpoints:
- `lib/features/fantasy/presentation/`

Implementation:
- Finish live team visibility, transfer clarity, and round-state polish.
- Align copy and UI with lifecycle and matchday states.

Acceptance:
- Fantasy UX feels complete on top of the improved ops model.

### V2-039: Add organizer lifecycle controls for hybrid and fantasy flows

Parent: `EPIC-H`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-020`, `V2-025`, `V2-029`
Likely Touchpoints:
- organizer screens
- lifecycle services

Implementation:
- Add protected controls for registration phases, lineup lock windows, and fantasy lifecycle moves.

Acceptance:
- Admin controls operate through explicit policies and audit events.

### V2-040: Add end-to-end hybrid-to-fantasy integration tests

Parent: `EPIC-H`
Priority: `P1`
Estimate: `L`
Status: `Todo`
Depends On: `V2-037`, `V2-038`, `V2-039`
Likely Touchpoints:
- `test/features/`
- `test/core/services/`

Implementation:
- Cover organizer creates tournament, adds guest team, locks lineup, player claims, and fantasy reflects participation.

Acceptance:
- The V2 operating model is validated across system boundaries.

## Epic I: Security, Migration, And Release

### V2-041: Add Firestore rule audit for V2 entities

Parent: `EPIC-I`
Priority: `P0`
Estimate: `M`
Status: `Todo`
Depends On: `V2-003`, `V2-019`, `V2-029`
Likely Touchpoints:
- `firestore.rules`
- rules test setup if present

Implementation:
- Re-audit rules for guest, membership, registration, lineup, and dispute paths.
- Add repeatable validation for protected writes.

Acceptance:
- Hybrid entities are not writable outside intended ownership or organizer scopes.

### V2-042: Write migration strategy from arrays to memberships

Parent: `EPIC-I`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-006`
Likely Touchpoints:
- docs
- migration utilities if needed

Implementation:
- Define dual-read or dual-write strategy.
- Document backfill assumptions and rollback path.

Acceptance:
- Team data migration can happen safely without blocking product work.

### V2-043: Audit indexes and repository query contracts

Parent: `EPIC-I`
Priority: `P1`
Estimate: `S`
Status: `Todo`
Depends On: `V2-019`, `V2-024`, `V2-029`
Likely Touchpoints:
- Firestore index docs
- repository tests

Implementation:
- Document expected composite indexes for new queries.
- Validate repository access patterns before rollout.

Acceptance:
- Query requirements are known before production usage expands.

### V2-044: Prepare rollout, flags, and release checklist

Parent: `EPIC-I`
Priority: `P1`
Estimate: `S`
Status: `Todo`
Depends On: `V2-005`, `V2-041`, `V2-042`, `V2-043`
Likely Touchpoints:
- docs
- release checklist

Implementation:
- Document feature flag rollout order, smoke tests, and rollback steps.
- Separate internal preview, pilot tournament, and general rollout.

Acceptance:
- V2 can be enabled progressively and safely.

## Epic J: Player Identity And Credibility

### V2-045: Expand player identity schema beyond basic profile stats

Parent: `EPIC-J`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: None
Likely Touchpoints:
- `lib/domain/entities/player.dart`
- `lib/data/models/player_model.dart`
- `lib/features/profile/`

Implementation:
- Add missing football identity fields needed by the master vision, such as `preferredFoot`, lightweight `playingStyleTags`, and a short profile summary without over-modeling too early.
- Keep the schema backward-safe and focused on fields that materially improve player identity, discoverability, and credibility.

Acceptance:
- Player identity is no longer limited to name, photo, rating, and primary position only.

### V2-046: Build player participation history and identity rollups

Parent: `EPIC-J`
Priority: `P1`
Estimate: `L`
Status: `Todo`
Depends On: `V2-045`, `TOS-FIX-031`
Likely Touchpoints:
- `lib/features/profile/`
- profile aggregation or query layer
- team / tournament read models

Implementation:
- Surface real team history, tournament appearances, and recent official participation on the player profile from canonical product truth.
- Avoid fake counters; derive history from existing participation data where possible.

Acceptance:
- A player profile can explain where the player actually played, not just show static stats.

### V2-047: Build reliability and reputation signals from real operations

Parent: `EPIC-J`
Priority: `P1`
Estimate: `L`
Status: `Todo`
Depends On: `V2-046`, `V2-029`, `V2-032`
Likely Touchpoints:
- `lib/domain/entities/player.dart`
- rating / trust services
- audit / dispute / matchday truth services

Implementation:
- Turn trust into a more meaningful product signal by deriving reliability or reputation summaries from attendance truth, dispute history, completion patterns, and organizer-approved results.
- Keep the first version explainable and auditable.

Acceptance:
- Player credibility is grounded in actual football operations rather than a mostly opaque number.

### V2-048: Upgrade player profile and player-card UX

Parent: `EPIC-J`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-045` to `V2-047`
Likely Touchpoints:
- `lib/features/profile/`
- player cards in search / leaderboard / team surfaces

Implementation:
- Upgrade profile UI and reusable player cards to expose the richer identity, reputation, and participation history clearly.
- Keep the design Arabic-first and operationally credible rather than decorative only.

Acceptance:
- Player identity feels like a meaningful football profile, not a thin social card.

## Epic K: Discovery, Join, And Notifications

### V2-049: Build unified search service for players, teams, and tournaments

Parent: `EPIC-K`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-019`, `V2-045`
Likely Touchpoints:
- search repositories or a new search service
- `lib/features/social/`
- team / tournament list surfaces

Implementation:
- Move from isolated per-screen search toward a unified search contract that can return players, teams, and tournaments.
- Keep the first version simple and fast before recommendations or nearby logic.

Acceptance:
- Search is a product capability, not a set of isolated text fields.

### V2-050: Build Explore and discovery entry surfaces

Parent: `EPIC-K`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-049`
Likely Touchpoints:
- home / discover surfaces
- player / team / tournament cards

Implementation:
- Add an Explore surface for players, teams, and tournaments with clear entry points and action CTAs.
- Make it easier to discover opportunities and entities beyond direct search.

Acceptance:
- The app has a real `Search / Explore` product surface aligned with the master vision.

### V2-051: Add team join-request lifecycle and captain review flow

Parent: `EPIC-K`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-006`, `V2-033`
Likely Touchpoints:
- team membership lifecycle
- team roster screens
- captain review flows

Implementation:
- Add user-initiated join requests so team growth is not invite-only.
- Support captain review, accept/reject, and clear membership-state transitions.

Acceptance:
- Joining a team is a first-class flow, not only a share-link side path.

### V2-052: Build notification domain, repository, and in-app inbox

Parent: `EPIC-K`
Priority: `P1`
Estimate: `L`
Status: `Todo`
Depends On: `V2-019`, `V2-029`, `V2-033`
Likely Touchpoints:
- notification entity / repository layer
- in-app inbox UI
- action deep-link routing

Implementation:
- Introduce canonical notifications for invites, claims, registration updates, tournament actions, and match reminders.
- Separate notification storage from delivery so the product can evolve without provider lock-in.

Acceptance:
- Essential football actions can produce persistent in-app notifications instead of snackbar-only feedback.

### V2-053: Route essential operational notifications and action deep links

Parent: `EPIC-K`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `V2-051`, `V2-052`
Likely Touchpoints:
- invite / claim / tournament services
- notification routing
- inbox and entry screens

Implementation:
- Fan out essential events into the inbox with deep links, especially for team invites, join requests, guest claims, tournament approvals, and upcoming match reminders.
- Keep the first version in-app first; push delivery can be layered later.

Acceptance:
- Core actions reach users through a real notification loop with usable action routing.

## Epic L: Platform Abstractions And Data Interfaces

### V2-054: Extract auth and session provider boundary

Parent: `EPIC-L`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: None
Likely Touchpoints:
- `lib/services/auth_service.dart`
- auth session / app bootstrap

Implementation:
- Introduce a cleaner auth/session contract so UI and higher-level services are not tightly coupled to `FirebaseAuth` and `GoogleSignIn` details.
- Preserve current behavior while creating a seam for future provider flexibility.

Acceptance:
- Authentication is consumed through a clearer boundary than direct provider-specific service code alone.

### V2-055: Extract storage and media provider boundary

Parent: `EPIC-L`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: None
Likely Touchpoints:
- `lib/core/services/photo_upload_service.dart`
- any future team / tournament media upload flows

Implementation:
- Replace direct storage coupling in media-facing services with a storage abstraction suitable for profile, team, and tournament media.
- Keep current Firebase-backed behavior as the first adapter, not the permanent contract.

Acceptance:
- Media upload and retrieval no longer depend on a single storage provider at the service boundary.

### V2-056: Define map and external match-data provider contracts

Parent: `EPIC-L`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: None
Likely Touchpoints:
- future map/location services
- backend sync planning docs
- fantasy or analytics data ingestion boundaries

Implementation:
- Define `MapService` and `MatchDataProvider` contracts before map-heavy or live-data-heavy work expands.
- Make explicit that third-party match data should enrich or sync through backend-owned logic, not define core client business truth.

Acceptance:
- The codebase has a clear architecture seam for maps and future external sports data ingestion.

## Suggested Sprint Split

### Sprint 1

- `V2-001` to `V2-005`

### Sprint 2

- `V2-006` to `V2-011`

### Sprint 3

- `V2-012` to `V2-018`

### Sprint 4

- `V2-019` to `V2-023`

### Sprint 4.5

- `TOS-001` to `TOS-010`

### Tournament Repair Sprint 1

- `TOS-FIX-001` to `TOS-FIX-007`

### Tournament Repair Sprint 2

- `TOS-FIX-008` to `TOS-FIX-015`

### Tournament Repair Sprint 3

- `TOS-FIX-016` to `TOS-FIX-022`

### Tournament Repair Sprint 4

- `TOS-FIX-023` to `TOS-FIX-027`

### Tournament Repair Sprint 5

- `TOS-FIX-028` to `TOS-FIX-031`

### Sprint 5

- `V2-024` to `V2-028`

### Sprint 6

- `V2-029` to `V2-032`

### Sprint 7

- `V2-033` to `V2-036`

### Sprint 8

- `V2-037` to `V2-044`

### Sprint 9

- `V2-045` to `V2-048`

### Sprint 10

- `V2-049` to `V2-053`

### Sprint 11

- `V2-054` to `V2-056`

### Tournament Repair Sprint 6 to 8

- `TOS-FIX-032` to `TOS-FIX-045` if full mixed guest-player fantasy becomes direct product scope

## Next Ticket To Start

Start with `TOS-FIX-001`.
The tournament module now has a working operations core, but the next real
blocker is the broken cross-app match flow: tournament fixtures still need a
first-class `startMatch` transition and a live roster projection before score
submission can be considered complete. `V2-039` and any mixed guest-player
fantasy work remain blocked until `TOS-FIX-001` to `TOS-FIX-031` materially
close the tournament repair path.
