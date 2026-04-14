# EL7REEF Engineering Plan

Version: 2026-04-14
Scope: Next execution phase after the completed security, routing, activity feed, and core fantasy fixes.

Implementation backlog for this plan lives in [implementation_backlog.md](implementation_backlog.md).

## Current Baseline

- Firestore rules were tightened and aligned with real ownership fields.
- Match settlement, fan voting, username claiming, and route contracts were stabilized.
- Activity feed is connected to real data.
- Fantasy core flows are live: league list, draft, team page, leaderboard, and transfers.
- `flutter analyze` and `flutter test` are currently passing.

## Goal Of This Plan

Move the product from "core flows are working" to "fantasy and tournament operations are production-ready, controlled, and testable end-to-end".

## Priorities

- `P0`: Must be completed before broad rollout.
- `P1`: Strongly recommended for stable launch quality.
- `P2`: Improvement and scale work after launch readiness.

## Execution Order

1. `ENG-01` to `ENG-04`
2. `ENG-05` to `ENG-08`
3. `ENG-09` to `ENG-12`

## Task Breakdown

### ENG-01: Gameweek Lifecycle Service

Priority: `P0`
Area: Fantasy Backend
Task: Create a single lifecycle service that knows the current fantasy gameweek, its status, and whether actions are open or locked.
Output: Central service used by fantasy team, transfers, scoring, and chips.
Done When:
- One source of truth returns `currentGameweek`, `deadlineAt`, `isLocked`, and `phase`.
- Controllers stop hardcoding fallback gameweek values.
- Tournament phase and global league phase resolve consistently.
Depends On: None

### ENG-02: Deadline Locking For Draft And Transfers

Priority: `P0`
Area: Fantasy Rules
Task: Prevent team edits and transfers after the round deadline unless the round is in an allowed transfer phase.
Output: Locking rules enforced in services and visible in UI.
Done When:
- Draft save is blocked after deadline.
- Transfer execution is blocked after deadline unless transfer window is open.
- UI shows a clear locked state with reason.
- Tests cover allowed and blocked paths.
Depends On: `ENG-01`

### ENG-03: Chips Activation Flow

Priority: `P0`
Area: Fantasy Gameplay
Task: Implement full chip lifecycle for `Wildcard`, `Bench Boost`, and `Triple Captain`.
Output: Users can activate chips from the team page and the scoring engine consumes them correctly.
Done When:
- Chip activation is stored on the team with round context.
- `Triple Captain` and `Bench Boost` affect scoring in the correct round only.
- `Wildcard` removes transfer hit penalties only while active.
- Used chips cannot be replayed outside the allowed policy.
Depends On: `ENG-01`, `ENG-02`

### ENG-04: Transfer Policy By Tournament Phase

Priority: `P0`
Area: Fantasy Rules
Task: Align transfer permissions and free transfer refill behavior with tournament phase and round transitions.
Output: Transfer engine respects phase-based policy.
Done When:
- Free transfers are reset or carried according to policy.
- Tournament-specific leagues can have different transfer windows from global league.
- Transfer history stores enough metadata to audit why a move was accepted.
- Tests cover normal transfer, extra hit, wildcard transfer, and blocked transfer.
Depends On: `ENG-01`, `ENG-02`

### ENG-05: Idempotent Fantasy Round Settlement

Priority: `P0`
Area: Scoring
Task: Build a round settlement pipeline that applies fantasy points once per round without double counting.
Output: Round settlement service with idempotency marker.
Done When:
- Slot points, team round points, and total points are updated in one controlled flow.
- Re-running the same settlement does not duplicate points.
- Captain, vice-captain, and bench rules are applied correctly.
- Admin or background job can trigger settlement safely.
Depends On: `ENG-01`, `ENG-03`

### ENG-06: Fantasy Admin Controls

Priority: `P1`
Area: Internal Tools
Task: Add organizer/admin controls for opening rounds, locking rounds, and triggering settlement.
Output: Admin screen or protected organizer actions.
Done When:
- Authorized users can move a round between open, locked, and settled.
- Unauthorized users cannot access these actions.
- Admin actions are logged with actor and timestamp.
Depends On: `ENG-01`, `ENG-05`

### ENG-07: Team Management Polish

Priority: `P1`
Area: Flutter UI
Task: Improve the fantasy team experience around captain changes, chip activation, and transfer history.
Output: Cleaner team management flow.
Done When:
- Team page shows active chip, round status, and next deadline clearly.
- Transfer history supports basic filtering by gameweek.
- Captain and vice-captain changes have optimistic UI or clear refresh behavior.
- Empty, loading, and error states are consistent.
Depends On: `ENG-02`, `ENG-03`, `ENG-04`

### ENG-08: Notifications And Feed Integration

Priority: `P1`
Area: Social / Product
Task: Push round events into activity feed and notifications.
Output: Users see deadline reminders, chip confirmations, and major fantasy updates.
Done When:
- Feed items are generated for round open, deadline approaching, transfer completed, and settlement completed.
- Notification payloads are deduplicated.
- UI can deep-link from notification to the correct fantasy route.
Depends On: `ENG-01`, `ENG-05`, `ENG-07`

### ENG-09: Firestore Rule Tests And Index Audit

Priority: `P1`
Area: Security / Infra
Task: Add repeatable validation for rules and required indexes for fantasy and match queries.
Output: Documented rules coverage and index list.
Done When:
- Critical write paths have rules tests.
- Known composite indexes are documented.
- CI fails if protected paths become writable unexpectedly.
Depends On: None

### ENG-10: Integration And Route Tests

Priority: `P1`
Area: Quality
Task: Extend tests from unit level to flow level.
Output: Coverage for complete user journeys.
Done When:
- Tests cover `create team -> view team -> transfer -> leaderboard`.
- Tests cover `round lock -> blocked edit`.
- Tests cover `settlement -> updated leaderboard`.
- Smoke tests exist for protected and error routes.
Depends On: `ENG-02`, `ENG-04`, `ENG-05`

### ENG-11: Telemetry And Audit Logging

Priority: `P2`
Area: Observability
Task: Add product telemetry and engineering logs for critical fantasy actions.
Output: Structured events for diagnosis and product insight.
Done When:
- Transfer failures, settlement failures, and permission failures are logged.
- Product events exist for draft completion, chip use, and leaderboard entry.
- Logs avoid storing sensitive user data unnecessarily.
Depends On: `ENG-04`, `ENG-05`

### ENG-12: Rollout And Migration Checklist

Priority: `P2`
Area: Release
Task: Prepare safe rollout steps for fantasy production readiness.
Output: Release checklist with rollback plan.
Done When:
- Feature flags are documented by environment.
- Existing teams are backfilled if schema changes are needed.
- Release checklist includes smoke test steps and rollback instructions.
- Known risks and manual checks are listed.
Depends On: `ENG-01` to `ENG-10`

## Suggested Sprint Split

### Sprint 1

- `ENG-01`
- `ENG-02`
- `ENG-03`
- `ENG-04`

### Sprint 2

- `ENG-05`
- `ENG-06`
- `ENG-07`
- `ENG-08`

### Sprint 3

- `ENG-09`
- `ENG-10`
- `ENG-11`
- `ENG-12`

## Definition Of Done For Any Task

- Code is merged behind the correct feature behavior.
- Security and permission impact is reviewed.
- Unit or integration tests are added where behavior changed.
- `flutter analyze` passes.
- `flutter test` passes.
- User-facing errors have clear Arabic copy.

## Main Risks

- Round lifecycle rules may diverge between global league and tournament leagues.
- Chips can become a hidden source of double-counting unless settlement stays idempotent.
- Firestore query/index growth may surface only after more leagues and teams are added.
- Admin actions need strict authorization to avoid silent data corruption.

## Recommended Start

Start with `ENG-01` immediately.
It is the dependency that unlocks deadline locking, chips, transfer policy, and settlement in a clean way.
