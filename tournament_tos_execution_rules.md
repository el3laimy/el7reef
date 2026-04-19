# EL7REEF Tournament OS Execution Rules

Version: 2026-04-19
Applies To:
- `TOS-001` to `TOS-010`
- tournament operating-system work only

## Purpose

This document turns the Tournament Operating System plan into execution rules
that reduce development conflicts, rework, and feature overlap.

The main principle is simple:

- build the tournament core first
- route all operational behavior through canonical services
- do not let UI or legacy data paths invent tournament state on their own

## Canonical Sources Of Truth

These rules are non-negotiable during the TOS workstream:

- `TournamentParticipant` is the canonical participant record inside a tournament.
- `TournamentLifecycleService` is the only orchestration entry point for phase transitions.
- tournament fixtures live in `Match` with tournament stage metadata.
- group standings are derived from official tournament fixtures only.
- knockout progression is derived from official knockout fixtures only.
- `registeredTeamIds` and `team.tournamentIds` are compatibility fields, not operating truth.
- any route or screen that cannot show persisted operational data must stay hidden or clearly read-only.

## Hard Execution Rules

1. No controller may perform tournament lifecycle writes directly.
Controllers may call services, but they must not flip tournament status or mutate groups, ties, or standings by themselves.

2. No UI-first tournament feature is allowed.
Before any new tournament screen or action ships, its domain model, repository path, and service contract must already exist.

3. No direct writes to operational collections outside the owning service.
`tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, and `knockoutTies` must be written only by the service that owns that domain.

4. No placeholder data on operational screens.
If real data is not available yet, the screen must show an honest empty state or remain hidden.

5. No tournament result affects progression before official approval.
`completed` is not enough. Only officially approved results may affect standings, qualifiers, knockout winners, or tournament completion.

6. No ticket may quietly repurpose legacy fields as canonical state.
If a field is compatibility-only, new logic must not depend on it for operating decisions.

7. No parallel ticket should own the same core file without explicit coordination.
If two tickets need the same service or screen, split by sequence, not by hope.

## Safe Build Order

The enforced order for the current workstream is:

1. participant core and migration
2. lifecycle orchestration
3. fixture-capable `Match`
4. group stage generation and standings
5. fixture queries, scheduling, publishing, and regeneration guardrails
6. knockout build and advancement
7. Tournament Operations Dashboard actions
8. UI completion and polish
9. audit, cleanup, and legacy retirement

This means:

- `TOS-006` must stabilize before deeper dashboard actions expand
- `TOS-008` must use existing services rather than creating side logic
- `V2-039` stays blocked until `TOS-006`, `TOS-008`, and `TOS-010` are sufficiently stable

## File Ownership Guidance

Use this to avoid collision when multiple developers work in parallel.

### Core lifecycle ownership

Primary files:
- `lib/core/services/tournament_lifecycle_service.dart`
- `lib/core/services/group_stage_builder.dart`
- `lib/core/services/knockout_builder.dart`
- `lib/core/services/tournament_participant_service.dart`
- `lib/domain/entities/tournament.dart`
- `lib/domain/entities/match.dart`

Rules:
- one developer at a time should own lifecycle orchestration changes
- do not mix dashboard/UI work into these files unless the ticket is specifically lifecycle-owned

### Fixture operations ownership

Primary files:
- `lib/domain/entities/match.dart`
- `lib/data/models/match_model.dart`
- `lib/data/repositories/match_repository_impl.dart`
- tournament fixture UI and controllers

Rules:
- scheduling, publish, and regenerate work should be grouped together
- any change that affects official result handling must be reviewed against lifecycle rules

### Organizer operations ownership

Primary files:
- `lib/features/tournament/controllers/tournament_operations_controller.dart`
- `lib/features/tournament/views/tournament_operations_screens.dart`
- related routes and bindings

Rules:
- dashboard work must consume service APIs only
- do not add organizer actions that bypass service guardrails

### Migration and cleanup ownership

Primary files:
- `lib/core/services/tournament_ops_migration_service.dart`
- compatibility reads in repositories and services
- tests covering backfill and legacy safety

Rules:
- migration work must be explicit and reversible
- cleanup must happen only after compatibility reads are verified

## Parallel Work Matrix

These slices are safe to run in parallel when needed:

- Track A: fixture scheduling and fixture publication UX
- Track B: participant operations UI such as `manual add`, `withdraw`, `replace`
- Track C: audit expansion, regression tests, and legacy cleanup preparation

These slices should not run in parallel without coordination:

- two tickets editing `tournament_lifecycle_service.dart`
- two tickets changing `Match` tournament fields
- dashboard work that depends on a service contract still being redesigned
- migration cleanup while compatibility reads are still being added

## Definition Of Ready

A tournament ticket is ready only if:

- the canonical owner service is identified
- the write path is known
- the compatibility impact is known
- the audit requirement is known
- the idempotency behavior is known
- the UI dependency, if any, is downstream rather than foundational

## Definition Of Done

A tournament ticket is done only if:

- it writes to the canonical model, not just a legacy field
- repeated execution is safe or explicitly blocked
- the resulting state is visible from real data
- audit behavior exists where the action is operationally important
- tests cover the behavior that could silently regress
- no misleading placeholder or unreachable route remains behind

## Pull Request Checklist

Before merging tournament operating-system work, confirm:

- this ticket does not introduce a new status-only shortcut
- this ticket does not bypass `TournamentLifecycleService` for transitions
- this ticket does not count non-official results as official progression input
- this ticket does not expand UI ahead of persisted data
- this ticket updates tests if progression logic changed
- this ticket documents any new compatibility field or migration impact

## Current Enforcement Focus

As of `2026-04-19`, the next priority is:

1. finish `TOS-006`
2. then finish the missing organizer actions in `TOS-008`
3. then widen `TOS-010` cleanup and regression hardening

Until that is complete:

- do not restart work on `V2-039`
- do not add cosmetic tournament screens
- do not add fantasy or assistant expansion on top of unstable tournament operations
