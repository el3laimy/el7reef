# EL7REEF Product Plan V2

Version: 2026-04-15
Companion Docs:
- [engineering_plan.md](engineering_plan.md)
- [implementation_backlog_v2.md](implementation_backlog_v2.md)

## Executive Summary

EL7REEF is evolving from a football community app into a real-world operating system for local football, tournaments, and team activity. The product should not assume that every player, captain, or team is already inside the app. Instead, it should support the real flow of the game first, then convert participation into trusted digital identity over time.

Core product direction:

- play first, claim later
- organizer-first adoption
- hybrid participation by design
- trust, audit, and operational clarity as core value

## Product Vision

EL7REEF should let a tournament organizer or captain run football activity from the phone even when:

- some players do not have the app
- a full team is still unregistered
- registrations happen through calls, WhatsApp, or field-side entry
- the digital system catches up after the matchday workflow starts

The product promise becomes:

"Play now, then take your place inside the system later."

## Product Principles

### 1. Real-World First

The product must work in messy, incomplete, real environments.

### 2. Claim Later, Don’t Block Now

Guest participation should be allowed now and claimable later without losing history.

### 3. Organizer-First Adoption

Organizers and captains are the primary growth engine and should get the fastest workflows.

### 4. Trust Is The Product

Results, lineup truth, permissions, disputes, and audit history are core product value.

### 5. Progressive Digitization

The app should support a gradual move from manual entry to verified participation.

## Primary Personas

### Organizer

Needs:

- quick tournament creation
- manual team and player entry
- hybrid registration
- dispute handling
- result and lineup trust

### Captain

Needs:

- team creation and roster management
- starter and bench control
- invite and join handling
- guest player support
- lineup confirmation

### Player

Needs:

- quick join and claim
- access to match history and ratings
- clear identity inside team and tournament context

### Guest Player

Needs:

- to exist in the system without friction
- to claim identity later with minimal steps

### Team Manager / Academy Admin

Needs:

- multi-player oversight
- attendance and availability visibility
- tournament participation control

## Product Scope

### A. Identity And Participation

- registered player
- guest player
- registered team
- guest team
- claim and merge flows
- QR, deep links, and WhatsApp entry

### B. Team Operations

- roster management
- formation board
- invite and join flows
- attendance and availability
- guest-to-registered replacement

### C. Tournament Operations

- quick setup
- hybrid registration
- verified mode
- bracket and lineup management
- dispute timeline

### D. Matchday Operations

- check-in
- lineup lock
- substitutions log
- attendance truth
- score settlement support

### E. Social And Growth

- real activity feed
- claim prompts after participation
- team and tournament shares
- WhatsApp-first loops

### F. Fantasy And Engagement

- fantasy team and leagues
- leaderboards
- achievements
- player cards and reputation

## Key Product Gaps To Close

### Team Management As A Living Unit

The team should no longer be just a page. It needs:

- full roster states
- roles
- formation presets
- availability
- invites and join requests
- replacements and guest handling

### Guest Players And Guest Teams

The system must let tournaments start with incomplete adoption.

### Claim And Merge

Claim should be a core growth loop, not a cleanup tool.

### Tournament Hybrid Mode

Support:

- quick mode
- hybrid mode
- verified mode

### Matchday Ops

The app needs pre-match and in-match truth:

- who checked in
- who started
- who sat on the bench
- who actually played

### Disputes And Audit

The system needs a clear history of who changed what and when.

### Viral Adoption Layer

Growth loops should include:

- team invite loop
- organizer claim funnel
- post-match identity unlock

## Product Roadmap

### Phase A: Real-World Operations Foundation

Deliver:

- guest players
- guest teams
- claim status
- hybrid participation model
- attendance and lineup lock foundation

### Phase B: Organizer Console

Deliver:

- fast tournament setup
- manual and hybrid registration
- approval workflows
- audit and dispute timeline

### Phase C: Team Ops Pro

Deliver:

- formation board
- invitations and join requests
- assistant manager roles
- substitution and bench management

### Phase D: Social And Growth Expansion

Deliver:

- deeper activity feed
- public share surfaces
- claim CTAs
- WhatsApp-first actions

### Phase E: Fantasy End-To-End

Deliver:

- complete fantasy management
- transfers
- real matchday-to-fantasy mapping
- league-specific engagement

## Product KPIs

### Adoption

- percentage of tournaments that launch in hybrid mode
- guest player claim rate within 7 days
- guest team claim rate

### Activation

- invites sent per team
- QR and WhatsApp join rate
- roster spot claim completion rate

### Operations

- tournament setup time
- time to add team or player
- percentage of matches approved without dispute
- dispute resolution completion rate in-app

### Engagement

- weekly activity feed usage
- fantasy adoption rate
- retention after first tournament

## Not Now

- do not force full registration before first use
- do not over-expand fantasy before core operations are trustworthy
- do not build deep analytics before data truth is stable
- do not overbuild the social layer before operations gaps are closed

## Product Decision

The next strategic step for EL7REEF is to build the real-world operating layer:

1. support guest players and guest teams
2. enable hybrid tournament management
3. ship roster, formation, and invite operations
4. use claim flows as the growth engine
5. tie everything to trust, audit, and secure permissions

That is the path from a promising app to an adoptable and durable football platform.
