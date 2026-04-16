# EL7REEF Engineering Plan V2

Version: 2026-04-15
Companion Docs:
- [product_plan.md](product_plan.md)
- [implementation_backlog_v2.md](implementation_backlog_v2.md)

Legacy fantasy-focused backlog remains in [implementation_backlog.md](implementation_backlog.md) as execution history for the completed foundation work.

## Executive Summary

EL7REEF is moving from a fantasy-and-tournament app with working core flows to a real-world football operations platform that can handle hybrid participation from day one. The engineering priority is no longer only "complete missing screens", but to build the operational layer that supports:

- registered players and teams
- guest players and guest teams
- hybrid tournament registration
- lineup, check-in, and substitutions
- claim and merge flows
- audit, disputes, and trusted operations

The system should work before full adoption, then gradually convert real-world participation into verified digital identity.

## Current Baseline

The following foundation already exists and should be treated as completed input to V2:

- Firestore rules were tightened around real ownership fields.
- ID-based routing was stabilized for critical flows.
- Match settlement, fan voting, and username claim flows were hardened.
- Activity feed is connected to real data.
- Fantasy lifecycle, chips, transfer policy, and round settlement are working.
- `flutter analyze` and `flutter test` are currently passing.

## Strategic Shift

Previous planning assumed a mostly app-native experience. V2 shifts EL7REEF to a hybrid operating model:

- do not block organizers because some participants are not registered
- represent guest participation explicitly in the data model
- treat claim and merge as first-class growth flows
- make operational trust part of the product, not a later add-on

## Engineering Objectives

1. Support hybrid identity and participation without hacks.
2. Keep sensitive writes idempotent and safe to retry.
3. Align authorization with real ownership and role boundaries.
4. Build operational primitives before feature polish.
5. Keep unfinished modules behind explicit feature flags.

## Architecture Principles

### 1. ID-First Navigation

All navigation contracts must remain parameter-driven and route-safe:

- `/team/:teamId`
- `/team/:teamId/formation`
- `/tournament/:tournamentId/register`
- `/match/:matchId/lineup`
- `/guest-player/:guestPlayerId/claim`

No screen should depend on injected objects that are not reconstructible from IDs.

### 2. Controllers Orchestrate, Services Decide

Controllers should remain orchestration-only. Core business logic belongs in services, policies, and use-case style classes.

### 3. Idempotent Sensitive Flows

The following classes of writes must be safe to retry:

- match settlement
- fan voting session open
- username claim
- guest player claim
- guest team claim
- lineup lock
- tournament registration approval

### 4. Additive Schema Over Breaking Migration

V2 should add guest and membership layers beside the current data model first, then migrate traffic gradually. Avoid large destructive rewrites.

### 5. Audit-First For Operational Changes

Anything that affects trust or competitive integrity should leave an explicit audit trail.

## Target Capability Map

### Identity And Participation

- Registered Player
- Guest Player
- Registered Team
- Guest Team
- Claim status lifecycle
- Merge-safe identity linking

### Team Operations

- roster management
- starter and bench states
- availability and attendance
- captain and assistant roles
- formation templates and snapshots

### Tournament Operations

- quick setup
- hybrid registration
- verified registration mode
- organizer approval workflows

### Matchday Operations

- check-in
- lineup lock
- bench selection
- substitution log
- participation truth for stats and fantasy

### Trust And Governance

- audit events
- dispute windows
- freeze and unlock controls
- actor-scoped permissions

### Growth And Engagement

- WhatsApp-first invites
- claim links and QR payloads
- post-match claim prompts
- feed events tied to real participation

## Target Data Model

### `GuestPlayer`

Purpose: represent a player who is known to a team or tournament but has not claimed an app account yet.

Minimum fields:

- `id`
- `displayName`
- `normalizedName`
- `phoneNumber?`
- `jerseyNumber?`
- `preferredPosition?`
- `teamId?`
- `tournamentId?`
- `createdBy`
- `createdAt`
- `claimStatus`
- `claimCode?`
- `linkedPlayerId?`
- `notes?`

### `GuestTeam`

Purpose: allow a tournament or organizer to add a team before that team has a registered captain or full app presence.

Minimum fields:

- `id`
- `name`
- `normalizedName`
- `creatorId`
- `contactName?`
- `contactPhone?`
- `logoUrl?`
- `tournamentIds[]`
- `captainGuestPlayerId?`
- `claimStatus`
- `linkedTeamId?`
- `createdAt`

### `TeamMembership`

Purpose: replace fragile arrays with an explicit membership layer.

Minimum fields:

- `playerId?`
- `guestPlayerId?`
- `role`
- `status`
- `availability`
- `joinedAt`
- `invitedBy`
- `claimLinkage`

### `TournamentRegistration`

Purpose: separate tournament participation from the team entity itself.

Minimum fields:

- `tournamentId`
- `teamId?`
- `guestTeamId?`
- `registrationStatus`
- `lineupStatus`
- `paymentStatus?`
- `verifiedAt?`

### `MatchLineupSnapshot`

Purpose: capture the authoritative pre-match roster and roles at lock time.

Minimum fields:

- `matchId`
- `teamLineups`
- `starters`
- `bench`
- `guests`
- `lockedAt`
- `lockedBy`

### `AuditEvent`

Purpose: create a uniform history for sensitive operations.

Minimum fields:

- `entityType`
- `entityId`
- `action`
- `actorId`
- `actorRole`
- `before`
- `after`
- `timestamp`

## Target Services

### `GuestClaimService`

Responsibilities:

- create claim codes
- resolve guest player claim
- resolve guest team claim
- merge guest entities into registered ones
- prevent double claim
- emit audit events

### `TeamRosterService`

Responsibilities:

- add registered and guest players
- update roster status and availability
- move starter and bench assignments
- replace guest entries after claim
- save formation templates and snapshots

### `TournamentRegistrationService`

Responsibilities:

- register team or guest team
- quick mode setup
- approval and verification flow
- registration lock and capacity checks

### `MatchdayService`

Responsibilities:

- check-in
- lineup validation
- lineup lock
- substitutions
- attendance and played-truth

### `DisputeService`

Responsibilities:

- open dispute
- attach reason and evidence
- resolve or reject
- freeze protected data after ruling

### `ShareLinkService`

Responsibilities:

- create invite and claim payloads
- generate deep link and QR data
- support WhatsApp entry points

## Authorization Targets

### Players / GuestPlayers

- a player reads their own player data
- captain or organizer can create guest players inside owned team or tournament scope
- claim writes must run through controlled merge logic only

### Teams / GuestTeams

- only authorized captain, manager, or organizer roles can change roster-critical data
- guest team claim requires organizer approval or verified ownership flow

### Tournaments

- only organizers and explicitly delegated assistants can change tournament operations
- roles must be narrow, not full-admin by default

### Matches

- score submission and lineup lock must be limited to allowed actors
- stats truth should depend on trusted matchday or settlement flow

### Fantasy

- fantasy writes remain owner-scoped
- transfer and settlement logic stays lifecycle-aware
- fantasy should later consume matchday truth, not bypass it

## Delivery Roadmap

### Phase 0: Completed Foundation

- security stabilization
- route stabilization
- activity feed baseline
- fantasy lifecycle and settlement foundation

### Phase 1: Hybrid Identity Foundation

Build guest entities, paths, rules, CRUD, and feature-flagged entry points.

### Phase 2: Team Roster Engine

Introduce memberships, roster policies, formation templates, and availability states.

### Phase 3: Claim And Merge Flows

Ship guest claim, merge safety, organizer approval, and audit recording.

### Phase 4: Tournament Hybrid Registration

Support quick mode, hybrid mode, and verified mode with explicit registration records.

### Phase 5: Matchday Operations

Add check-in, lineup lock, substitution tracking, and participation truth.

### Phase 6: Audit And Dispute Layer

Add timeline visibility, dispute windows, freeze controls, and audit viewers.

### Phase 7: Growth Layer

Ship WhatsApp invites, claim CTAs, QR payloads, and lightweight share flows.

### Phase 8: Fantasy Completion On Top Of Ops Truth

Connect fantasy eligibility and engagement to real matchday and roster data.

## Testing Strategy

### Unit Tests

- claim merge rules
- roster validation rules
- lineup lock validation
- registration eligibility
- dispute resolution rules

### Repository Tests

- guest CRUD
- claim transactions
- membership queries
- hybrid registration queries
- audit event persistence

### Widget And Flow Tests

- create guest team
- create guest player
- claim guest player
- register guest team in tournament
- check-in and lineup lock
- roster save and formation save

### Integration Tests

- organizer creates hybrid tournament
- organizer registers guest team
- captain adds guest players
- match lineup gets locked
- player later claims guest slot
- claim merges without breaking history

## Major Risks

- migration from simple arrays to memberships may create temporary dual-write complexity
- duplicate identity conflicts may appear during guest claim
- too much flexibility may reduce data cleanliness without strong policies
- operational UI can become heavy if too many advanced actions are exposed at once
- new flows can drift from rules if permission review happens too late

## Safe Rollout Strategy

1. Build schema, services, and rules before heavy UI investment.
2. Ship all new modules behind feature flags first.
3. Prefer additive storage and progressive cutover.
4. Require audit output for all sensitive operations.
5. Separate "usable now" deliverables from long-term polish.

## Recommended Immediate Start

Start with the V2 foundation pack:

- `V2-001`: `GuestPlayer` model and enums
- `V2-002`: `GuestTeam` model and enums
- `V2-003`: Firestore paths, rules, and claim code storage
- `V2-004`: repository and CRUD test coverage

This is the minimum slice that unlocks hybrid registration, roster work, and claim flows without forcing disruptive rewrites later.
