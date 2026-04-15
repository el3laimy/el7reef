# EL7REEF Implementation Backlog

Version: 2026-04-14
Source Plan: [engineering_plan.md](engineering_plan.md)
Status Model:
- `Todo`: not started
- `In Progress`: actively being implemented
- `Blocked`: waiting on dependency or decision
- `Done`: implemented and verified

## Backlog Goal

Turn the engineering plan into execution-sized tickets that can be picked up one by one without ambiguity.

## Recommended Execution Sequence

1. `IMP-001` to `IMP-006`
2. `IMP-007` to `IMP-014`
3. `IMP-015` to `IMP-021`
4. `IMP-022` to `IMP-029`
5. `IMP-030` to `IMP-035`

## Milestone A: Lifecycle And Locking

### IMP-001: Define round lifecycle domain model

Parent: `ENG-01`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: None
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/core/enums/`

Implementation:
- Add a domain model for fantasy round state.
- Define fields like `leagueId`, `gameweek`, `phase`, `deadlineAt`, `isLocked`, and `settledAt`.
- Define enum values for lifecycle phases instead of relying on scattered string checks.

Acceptance:
- One reusable model exists for both global and tournament leagues.
- No controller needs to infer lifecycle from raw tournament state directly.

### IMP-002: Add lifecycle repository contract

Parent: `ENG-01`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-001`
Likely Touchpoints:
- `lib/domain/repositories/`
- `lib/data/repositories/`

Implementation:
- Add repository methods for reading and writing round lifecycle state.
- Support both global league and tournament league lookups.

Acceptance:
- App code can request lifecycle state by `leagueId`.
- Contract is testable without Firebase bootstrapping.

### IMP-003: Implement `FantasyLifecycleService`

Parent: `ENG-01`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-001`, `IMP-002`
Likely Touchpoints:
- `lib/core/services/`

Implementation:
- Create a single service that resolves current gameweek, deadline, lock status, and active phase.
- Add consistent fallback behavior for `global` league.

Acceptance:
- All fantasy flows can call one service for lifecycle checks.
- No hardcoded current gameweek fallback remains in controllers.

### IMP-004: Wire lifecycle service into fantasy controllers

Parent: `ENG-01`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-003`
Likely Touchpoints:
- `lib/features/fantasy/presentation/controllers/`
- `lib/features/fantasy/presentation/bindings/`

Implementation:
- Inject lifecycle service into create team, team page, leaderboard, and transfer controllers.
- Remove direct tournament-status mapping from presentation layer where possible.

Acceptance:
- Controllers use lifecycle service instead of local round assumptions.
- Bindings register the service cleanly through GetX.

### IMP-005: Add lifecycle unit tests

Parent: `ENG-01`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-003`
Likely Touchpoints:
- `test/core/services/`

Implementation:
- Add tests for global league lifecycle resolution.
- Add tests for tournament league lifecycle resolution.
- Add tests for lock and deadline evaluation.

Acceptance:
- Lifecycle service is covered for open, locked, and settled states.

### IMP-006: Add lifecycle bootstrap data strategy

Parent: `ENG-01`
Priority: `P0`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-003`
Likely Touchpoints:
- `README.md`
- `firestore.rules`
- seed/config docs if present

Implementation:
- Define how round state is initialized for new leagues.
- Document required lifecycle documents or fields.

Acceptance:
- Engineers can create a new fantasy-enabled league without guessing required lifecycle state.

## Milestone B: Draft And Transfer Locking

### IMP-007: Block draft save after deadline

Parent: `ENG-02`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-004`
Likely Touchpoints:
- `lib/features/fantasy/presentation/controllers/fantasy_create_team_controller.dart`
- supporting service layer

Implementation:
- Check lifecycle before saving or updating a team draft.
- Return a user-facing reason when the round is locked.

Acceptance:
- Team creation/edit is blocked when lifecycle says locked.
- Error copy is visible in Arabic and not just logs.

### IMP-008: Block transfers outside allowed window

Parent: `ENG-02`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-004`
Likely Touchpoints:
- `lib/core/services/transfer_engine.dart`
- `lib/features/fantasy/presentation/controllers/transfer_market_controller.dart`

Implementation:
- Enforce lifecycle validation before any transfer is processed.
- Allow only explicit transfer phases or unlocked rounds.

Acceptance:
- Transfer execution fails safely when locked.
- Transfer UI cannot silently proceed into a failed action.

### IMP-009: Show lock state across fantasy UI

Parent: `ENG-02`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-007`, `IMP-008`
Likely Touchpoints:
- `lib/features/fantasy/presentation/screens/`

Implementation:
- Add visible deadline and status banners.
- Disable or relabel action buttons when locked.

Acceptance:
- Team page, draft page, and transfers page all show the same lock reason.
- Users can tell whether the round is locked or just unavailable due to missing data.

### IMP-010: Add lock rule tests

Parent: `ENG-02`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-007`, `IMP-008`
Likely Touchpoints:
- `test/core/services/`
- `test/widget_test.dart`

Implementation:
- Add tests for blocked draft save.
- Add tests for blocked transfer.
- Add route-level UI coverage for disabled or locked states.

Acceptance:
- Regression coverage exists for allowed and blocked paths.

## Milestone C: Chips

### IMP-011: Normalize chip data model

Parent: `ENG-03`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-003`
Likely Touchpoints:
- `lib/domain/entities/fantasy_team.dart`
- related models and serialization

Implementation:
- Replace loose chip strings with a structured chip usage model.
- Track `chipType`, `gameweek`, `activatedAt`, and `consumedAt` where needed.

Acceptance:
- Chip state can be validated per round without fragile string matching.

### IMP-012: Implement chip activation service

Parent: `ENG-03`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-011`
Likely Touchpoints:
- `lib/core/services/`
- `lib/data/repositories/`

Implementation:
- Create service for activating and validating chips.
- Enforce one-time use and lifecycle checks.

Acceptance:
- Service rejects invalid reuse and invalid activation timing.
- Service is independent from UI.

### IMP-013: Add chip actions to team page

Parent: `ENG-03`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-012`
Likely Touchpoints:
- `lib/features/fantasy/presentation/screens/fantasy_team_screen.dart`
- `lib/features/fantasy/presentation/controllers/fantasy_team_controller.dart`

Implementation:
- Add activate-chip UI for `Wildcard`, `Bench Boost`, and `Triple Captain`.
- Show active chip and usage history.

Acceptance:
- Team page reflects chip state immediately after activation.
- Locked or consumed chips are visibly unavailable.

### IMP-014: Extend scoring and transfer rules for chips

Parent: `ENG-03`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-012`
Likely Touchpoints:
- `lib/core/services/fantasy_points_engine.dart`
- `lib/core/services/transfer_engine.dart`

Implementation:
- Make `Triple Captain` affect scoring only in the right round.
- Make `Bench Boost` include bench points only for the active round.
- Make `Wildcard` remove hit penalties only while active.

Acceptance:
- Chip effects are round-scoped and not sticky across future rounds.

### IMP-015: Add chip tests

Parent: `ENG-03`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-014`
Likely Touchpoints:
- `test/core/services/`

Implementation:
- Add unit tests for chip activation validity.
- Add scoring tests for `Triple Captain` and `Bench Boost`.
- Add transfer tests for `Wildcard`.

Acceptance:
- All three chip types are covered by automated tests.

## Milestone D: Transfer Policy

### IMP-016: Implement free transfer refill policy

Parent: `ENG-04`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-003`
Likely Touchpoints:
- `lib/core/services/transfer_engine.dart`
- settlement or lifecycle services

Implementation:
- Define how free transfers refresh between rounds.
- Support carry-over policy if that is part of the product rule.

Acceptance:
- Transfer counts update consistently on round change.

### IMP-017: Make transfer policy phase-aware

Parent: `ENG-04`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-008`, `IMP-016`
Likely Touchpoints:
- `lib/core/services/transfer_engine.dart`
- `lib/core/services/fantasy_lifecycle_service.dart`

Implementation:
- Differentiate round lock, transfer window, and special tournament phases.
- Keep global and tournament leagues independently configurable.

Acceptance:
- Transfer rules are not hardcoded to tournament status alone.

### IMP-018: Expand transfer audit metadata

Parent: `ENG-04`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-017`
Likely Touchpoints:
- `lib/domain/entities/transfer_record.dart`
- repository serialization

Implementation:
- Store policy metadata like `usedFreeTransfer`, `hitApplied`, `policyPhase`, and `blockedReason` where relevant.

Acceptance:
- Engineers can reconstruct why a transfer was accepted or rejected.

### IMP-019: Add transfer policy tests

Parent: `ENG-04`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-016`, `IMP-017`, `IMP-018`
Likely Touchpoints:
- `test/core/services/transfer_engine_test.dart`

Implementation:
- Cover free transfer refill.
- Cover extra hit.
- Cover wildcard exception.
- Cover locked transfer denial.

Acceptance:
- Transfer engine behavior is fully covered for normal round transitions.

## Milestone E: Round Settlement

### IMP-020: Define settlement marker model

Parent: `ENG-05`
Priority: `P0`
Estimate: `S`
Status: `Done`
Depends On: `IMP-003`
Likely Touchpoints:
- `lib/domain/entities/`
- `lib/data/models/`

Implementation:
- Add an idempotency record for `(leagueId, gameweek, settlementType)`.

Acceptance:
- The system can detect that a round has already been settled.

### IMP-021: Build `FantasyRoundSettlementService`

Parent: `ENG-05`
Priority: `P0`
Estimate: `L`
Status: `Done`
Depends On: `IMP-020`, `IMP-014`
Likely Touchpoints:
- `lib/core/services/`
- `lib/data/repositories/`

Implementation:
- Aggregate stats for the round.
- Calculate slot and team points.
- Persist results atomically with settlement marker.

Acceptance:
- Re-running settlement does not duplicate points.
- Failure in the middle does not partially corrupt standings.

### IMP-022: Apply captain, vice-captain, and bench rules in settlement

Parent: `ENG-05`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-021`
Likely Touchpoints:
- `lib/core/services/fantasy_points_engine.dart`
- settlement service

Implementation:
- Resolve captain multipliers.
- Resolve vice-captain fallback.
- Apply bench rules and any active chips.

Acceptance:
- Round points match business rules for all supported cases.

### IMP-023: Add settlement tests

Parent: `ENG-05`
Priority: `P0`
Estimate: `M`
Status: `Done`
Depends On: `IMP-021`, `IMP-022`
Likely Touchpoints:
- `test/core/services/`

Implementation:
- Add tests for first settlement.
- Add tests for idempotent rerun.
- Add tests for captain and bench outcomes.

Acceptance:
- Settlement behavior is covered for happy path and rerun path.

## Milestone F: Admin And Internal Tools

### IMP-024: Add admin lifecycle controls

Parent: `ENG-06`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-003`, `IMP-021`
Likely Touchpoints:
- organizer screens and bindings
- admin service layer

Implementation:
- Add actions to open round, lock round, and trigger settlement.

Acceptance:
- Admin can manage round state without editing Firestore manually.

### IMP-025: Protect admin actions with explicit authorization

Parent: `ENG-06`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-024`
Likely Touchpoints:
- `firestore.rules`
- organizer/admin controllers

Implementation:
- Restrict lifecycle writes and settlement triggers to authorized users only.

Acceptance:
- Unauthorized access is blocked in both app logic and rules.

### IMP-026: Add admin audit logging

Parent: `ENG-06`
Priority: `P1`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-024`, `IMP-025`
Likely Touchpoints:
- admin action service
- audit collection if introduced

Implementation:
- Log actor, action, target league, and timestamp for manual admin changes.

Acceptance:
- Round state changes are auditable after the fact.

## Milestone G: UX And Feed

### IMP-027: Polish team management states

Parent: `ENG-07`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-009`, `IMP-013`
Likely Touchpoints:
- `lib/features/fantasy/presentation/screens/fantasy_team_screen.dart`

Implementation:
- Show next deadline, active chip, round state, and league context more clearly.
- Improve feedback after captain or vice-captain changes.

Acceptance:
- Team page gives enough context to act without guessing round status.

### IMP-028: Add transfer history filtering

Parent: `ENG-07`
Priority: `P1`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-018`
Likely Touchpoints:
- team screen
- team controller

Implementation:
- Filter transfer history by gameweek or recent period.

Acceptance:
- Users can inspect recent transfer behavior without scanning a flat list.

### IMP-029: Push fantasy events into feed and deep links

Parent: `ENG-08`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-021`, `IMP-027`
Likely Touchpoints:
- `lib/core/services/activity_feed_service.dart`
- route helpers

Implementation:
- Add events for deadline reminder, transfer completed, chip activated, and round settled.
- Ensure feed events can open the relevant fantasy screen.

Acceptance:
- Feed entries deep-link to the right league/team route.

## Milestone H: Quality, Infra, Release

### IMP-030: Add Firestore rules tests for fantasy writes

Parent: `ENG-09`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-025`
Likely Touchpoints:
- firestore rules test setup

Implementation:
- Cover team update, transfer write, lifecycle write, and admin-only flows.

Acceptance:
- Rules regressions are caught before merge.

### IMP-031: Document required composite indexes

Parent: `ENG-09`
Priority: `P1`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-017`, `IMP-021`
Likely Touchpoints:
- Firebase index docs
- repo documentation

Implementation:
- List required indexes for leaderboard, transfers, lifecycle, and settlement queries.

Acceptance:
- A fresh environment can enable indexes without trial and error.

### IMP-032: Add integration flow tests

Parent: `ENG-10`
Priority: `P1`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-010`, `IMP-019`, `IMP-023`
Likely Touchpoints:
- `test/`

Implementation:
- Add end-to-end style tests for:
  - create team -> team page -> transfer -> leaderboard
  - round lock -> blocked edit
  - settlement -> updated leaderboard

Acceptance:
- Key user journeys are protected beyond isolated unit tests.

### IMP-033: Add telemetry for critical fantasy actions

Parent: `ENG-11`
Priority: `P2`
Estimate: `M`
Status: `Todo`
Depends On: `IMP-021`, `IMP-029`
Likely Touchpoints:
- analytics or logging service

Implementation:
- Track draft completion, chip activation, transfer success/failure, and settlement failures.

Acceptance:
- Product and engineering teams can inspect the health of fantasy flows.

### IMP-034: Create rollout checklist and migration notes

Parent: `ENG-12`
Priority: `P2`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-030`, `IMP-031`, `IMP-032`
Likely Touchpoints:
- release docs

Implementation:
- Document feature flags, smoke tests, rollback steps, and any backfill/migration needs.

Acceptance:
- Release can be executed without relying on tribal knowledge.

### IMP-035: Final launch readiness review

Parent: `ENG-12`
Priority: `P2`
Estimate: `S`
Status: `Todo`
Depends On: `IMP-034`
Likely Touchpoints:
- `README.md`
- planning docs

Implementation:
- Review open risks, unresolved backlog items, and production rollout blockers.

Acceptance:
- There is a final go/no-go checklist for fantasy production readiness.

## Suggested Sprint Mapping

### Sprint 1

- `IMP-001` to `IMP-010`

### Sprint 2

- `IMP-011` to `IMP-023`

### Sprint 3

- `IMP-024` to `IMP-035`

## Next Ticket To Start

Start with `IMP-024`.
Round settlement is now idempotent and covered for captain, vice-captain, and
bench behavior, so the next highest-value step is adding admin lifecycle
controls to operate league phases safely.
