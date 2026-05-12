# El7reef Current Code Gap Audit — Initial Pass

## 0. Scope

This is an initial audit of the uploaded codebase against the design documents:

1. Complete Product Blueprint.
2. V1 Scope & Anti-goals.
3. Role & Permission Matrix.
4. Tournament Lifecycle & Scheduling Blueprint.

This is not a full code review and not an implementation task. It identifies mismatches, risks, and areas requiring deeper audit before more development.

---

## 1. Executive Summary

The current codebase is more advanced than the visible product plan in some areas: it already contains tournament lifecycle services, group/knockout builders, participant finalization, fixture publishing, scheduling, audit emitters, top scorers, claim flow, and rules tests for claim codes.

However, the project still has critical architectural gaps before it can be treated as V1-ready:

1. Public tournament listing and organizer-owned tournament listing are not clearly separated in the main tournament UI.
2. Tournament operations guard exists in controller code, but Firestore rules and emulator tests for tournament ownership are missing.
3. Match/tournament state machines exist but do not match the Draft 0 lifecycle language cleanly.
4. Scheduling exists technically (`scheduledAt`, `publishedAt`, `fixtureStatus`, `venueId`) but V1 product policy is not settled.
5. There are only Firestore rules emulator tests for `claimCodes`, not for tournaments, teams, registrations, matches, or score approval.
6. Session reset infrastructure now exists, but the tournament issue reported in manual QA still requires a two-account ownership/query audit.

Conclusion: the codebase has valuable building blocks, but it is not yet safe to resume feature work. The next work should be a permission and ownership gap audit, not new product implementation.

---

## 2. High-Level Inventory Findings

## 2.1 Existing major feature areas

Current feature folders include:

- `auth`
- `home`
- `team`
- `tournament`
- `match`
- `lineup`
- `guest_claim`
- `profile`
- `shareables`
- `social`
- `organizer`
- `splash`

This confirms the app already contains more than a pure Tournament Ego MVP. Some social/challenge/fantasy structures still exist and must remain gated or excluded from V1 unless deliberately reintroduced.

---

## 3. Session Isolation State

## 3.1 What exists now

The current uploaded code includes a `SessionResetCoordinator`:

- `lib/core/auth/session_reset_coordinator.dart`

`HomeBinding` registers reset callbacks for permanent controllers:

- `ProfileController`
- `TeamController`
- `MatchController`
- `TournamentController`
- `ActivityFeedController`
- `ChallengeController`

`AuthService.signOut()` now calls:

```dart
currentPlayer.value = null;
await _sessionResetCoordinator.resetForSignOut();
await _googleSignIn.signOut();
await _auth.signOut();
currentPlayer.value = null;
```

`AuthService._onAuthStateChanged` also calls `handleAuthUidChanged(uid)` before loading the new profile.

This means some version of the P0 session cleanup work has already been added to the uploaded codebase.

## 3.2 Remaining concern

The user reported that after force-close/restart:

- teams and matches disappeared,
- tournaments remained visible under the new account.

That pattern suggests the remaining issue may not be only stale GetX state. It is likely related to tournament query semantics or UI classification.

---

## 4. Tournament List / Ownership Audit

## 4.1 TournamentController state

`TournamentController` currently has:

```dart
final RxList<Tournament> liveTournaments = <Tournament>[].obs;
final RxList<Tournament> myOrganizedTournaments = <Tournament>[].obs;
```

It loads:

```dart
loadLiveTournaments();
loadMyTournaments();
```

`loadMyTournaments()` correctly uses current uid:

```dart
myOrganizedTournaments.value = await _repo.getOrganizerTournaments(uid);
```

The repository uses:

```dart
.where('organizerId', isEqualTo: organizerId)
```

So `myOrganizedTournaments` appears correctly user-scoped at repository level.

## 4.2 Main TournamentListScreen displays liveTournaments, not myOrganizedTournaments

`TournamentListScreen` displays:

```dart
controller.liveTournaments
```

under the heading:

```text
الدورات الجارية
```

It also shows a global create button:

```text
أنشئ دورة جديدة
```

This screen appears to be a public/live tournament discovery screen, not a `my organized tournaments` screen.

## 4.3 Risk

If the user expects the tournament tab to represent “my tournaments” or “my managed tournaments,” then this UI is misleading because it shows live tournaments from all organizers.

If the screen is intended as public discovery, then visibility is acceptable only if:

1. It is clearly labeled as public/discovery.
2. Non-organizers see read-only detail.
3. Non-organizers cannot enter operations/admin surfaces.
4. Firestore rules prevent unauthorized writes.

Current label `الدورات الجارية` suggests discovery, but the nearby create action and absence of a separate “بطولاتي/إدارتي” section may confuse ownership.

### Gap

Need explicit separation:

- Public/discover tournaments.
- My organized tournaments.
- My participating tournaments.
- Tournament operations.

---

## 5. Tournament Operations Permissions

## 5.1 Controller guard exists

`TournamentOperationsController.canManageTournament` checks:

```dart
currentTournament.organizerId == actorId
```

Most core admin actions use `_currentTournamentManagerActorId()`, which calls `_ensureCanManageTournament()`:

```dart
if (currentTournament == null || currentTournament.organizerId != actorId) {
  errorMessage.value = 'لا تملك صلاحية إدارة هذه البطولة.';
  return false;
}
```

This is good controller-level protection for organizer-only operations.

## 5.2 Inconsistency: assistant roles exist but operations controller uses organizer-only

`TournamentPermissionService` supports assistants:

- full
- resultsOnly
- observer
- emergency

But `TournamentOperationsController.canManageTournament` only checks `organizerId == actorId`.

This means either:

1. assistant roles are not actually part of V1 operations, or
2. operations controller is too strict and inconsistent with `TournamentPermissionService`, or
3. assistant roles are legacy/unfinished and should be hidden/gated.

### Decision needed

For V1, choose one:

- **Strict V1:** exactly one organizer, assistant roles hidden/deferred.
- **Assistant V1:** use `TournamentPermissionService` consistently across operations and rules.

Given our V1 Scope document, the safer decision is: one organizer only, no custom assistant permissions in V1.

---

## 6. Firestore Rules Findings

## 6.1 Tournament rules

Current tournament rules:

```rules
match /tournaments/{tournamentId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated() &&
    request.resource.data.organizerId == request.auth.uid;
  allow update: if isTournamentOrganizer();
  allow delete: if false;
}
```

This is a reasonable minimal organizer-only write model.

## 6.2 But there are no tournament rules emulator tests

Only rules test file found:

```text
test/rules/claim_codes.rules.test.js
```

No emulator tests currently verify:

- account B cannot update account A tournament.
- non-organizer cannot schedule/update tournament matches.
- captain cannot approve registrations.
- non-owner cannot edit team roster.
- non-organizer cannot approve score.

### Gap

Any release claim about ownership safety is unsupported until rules emulator tests exist for tournaments, teams, registrations, and matches.

---

## 7. Match Rules vs Tournament Operations

## 7.1 Match Firestore rules

Current match rules:

```rules
match /matches/{matchId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated() &&
    request.resource.data.organizerId == request.auth.uid;
  allow update: if isMatchOrganizer();
  allow delete: if false;
}
```

`isMatchOrganizer()` checks:

```rules
resource.data.organizerId == request.auth.uid
```

## 7.2 Risk

This allows the match organizer to update a match. If tournament-generated matches correctly set `organizerId` to tournament organizer, this is consistent.

But if any match creation path allows arbitrary organizerId or wrong propagation, update authority can become inconsistent.

### Required audit

- Verify all tournament fixture builders set `Match.organizerId = tournament.organizerId`.
- Verify no captain-created score path changes match organizer incorrectly.
- Verify score approval path is compatible with tournament organizer authority.

---

## 8. Tournament Lifecycle / Scheduling Code

## 8.1 Existing scheduling fields

`Match` already has:

- `stageType`
- `groupId`
- `groupStageId`
- `knockoutTieId`
- `roundIndex`
- `slotNumber`
- `scheduledAt`
- `publishedAt`
- `venueId`
- `fixtureStatus`
- `lineupRequirement`

This is stronger than expected and provides a foundation for scheduling.

## 8.2 Existing lifecycle services

The code contains:

- `TournamentLifecycleService`
- `TournamentFixtureService`
- `GroupStageBuilder`
- `KnockoutBuilder`
- `TournamentCompletionPolicy`
- `TournamentAuditEmitter`

Key operations include:

- finalize participants.
- start group stage.
- publish fixtures.
- start knockout.
- schedule fixture.
- start match.

## 8.3 Product mismatch

Our V1 scheduling blueprint proposed a simpler flow:

```text
single elimination first
or generated pairings + manual schedule
```

The current code has group stage and knockout machinery already. This is not automatically bad, but it increases complexity and permission surface.

### Decision needed

Do we keep the current advanced tournament lifecycle in V1, or do we deliberately hide/gate parts and expose only a simple path?

---

## 9. Scheduling Gaps

## 9.1 `scheduledAt` exists, but publish rules may not require it

`TournamentLifecycleService.publishFixtures()` publishes all unpublished fixtures by changing `fixtureStatus` to published.

Initial read did not confirm a hard check that every fixture has `scheduledAt` before publish.

If fixtures can be published without times, that conflicts with the Draft 0 recommendation:

> `scheduledAt` required before publish.

### Gap

Verify whether publish requires `scheduledAt`; if not, decide whether V1 permits unscheduled published fixtures.

## 9.2 Conflict prevention requires verification

`TournamentFixtureService.scheduleFixture()` updates `scheduledAt` and `venueId`. Initial read did not show conflict checks for:

- same team at same time.
- match before registration close.
- match before tournament start.
- completed match reschedule.

It does block official-result rescheduling:

```dart
if (match.isOfficialTournamentResult) throw ...
```

But V1 needs stronger scheduling constraints or explicit acceptance of manual responsibility.

---

## 10. Result Approval / Official Stats Gap

`Match.isOfficialTournamentResult` requires:

```dart
status == MatchStatus.settled && scoreTeamA != null && scoreTeamB != null
```

This is good.

But `MatchEvent` top scorers resolver aggregates active goal events by tournamentId. It must be verified whether it filters by match official/settled status. Earlier implementation likely aggregates events directly, which may count goals before organizer approval.

### Gap

Need decide:

- Are leaderboards provisional/live?
- Or must they count only approved/settled matches?

For V1, official standings and leaderboards should ideally use approved/settled matches only, or clearly mark as provisional.

---

## 11. Tournament Registration Existing System

The code contains:

- `TournamentRegistrationService`
- `TournamentRegistrationController`
- `TournamentRegistrationReviewController`
- `TournamentRegistration` model/entity/repository

This suggests team registration/approval is more developed than originally assumed.

Initial observations from service grep:

- registration create/update checks include organizer/team/guest team ownership.
- approve/reject paths check `tournament.organizerId == actorId`.

### Gap

Need a focused audit of:

- captain submit team.
- organizer approve/reject.
- Firestore rules compatibility.
- whether a player can submit a team they do not manage.
- rules tests.

---

## 12. Social/Friends Existing Surface

The code includes:

- `FriendController`
- `SearchPlayersController`
- `friends_screen`
- `search_players_screen`
- `friend_repository_impl`
- `friendship` rules.

This means search/friends are not entirely absent. But they were outside the current V1 scope and may be incomplete or ungated.

### Risk

If UI exposes social/search features without a complete permissions/privacy model, it can confuse product scope and privacy.

### Decision

For V1, either:

- keep social surfaces hidden/gated, or
- deliberately include only player search for team invites with privacy constraints.

---

## 13. Claim Code Security Status

The uploaded code includes revised claim code rules:

```rules
allow get: if isAuthenticated();
allow list: if isAuthenticated() && resource.data.createdBy == request.auth.uid;
```

Rules emulator tests exist for `claimCodes` and cover:

- anonymous get denied.
- exact get allowed for authenticated users.
- broad listing denied.
- creator-scoped reuse allowed.
- non-creator query denied.
- unauthorized writes denied.

This part is currently the best-tested security area.

Remaining known debt:

- raw `guestPlayers.claimCode` and `guestTeams.claimCode` can still exist.
- server-mediated claim completion deferred.

---

## 14. Immediate P0/P1 Findings

### P0-1: Tournament ownership behavior needs two-account verification

The code has some correct filters and guards, but the user observed tournament carryover after restart. The most likely explanation may be public `liveTournaments` display, but the danger is whether management actions are also available.

Required manual/code verification:

- Account B sees account A tournament only in public list, not in managed list.
- Account B cannot open tournament operations.
- Account B cannot execute operations controller actions.
- Firestore rules reject B updates.

### P0-2: No tournament/team/match rules emulator tests

Claim rules are tested. Tournament ownership is not.

### P1-1: Scheduling policy not finalized

The code has fields and services, but product policy is unsettled:

- is scheduledAt required before publish?
- are conflicts blocked?
- is V1 group+knockout or simpler?

### P1-2: Leaderboard official/provisional status unclear

Top scorers from MatchEvents may not be tied to approved matches.

### P1-3: Assistant roles exist but V1 scope says one organizer

Need decide whether to hide/defer assistants or fully support them across rules/controllers.

---

## 15. Recommended Next Audit Tasks, Not Implementation

### Audit A — Tournament Ownership and UI Surface Classification

Inventory all tournament screens and classify:

- public discovery.
- my organized.
- my participating.
- admin/operations.

Verify each uses the correct list and guard.

### Audit B — Firestore Rules Emulator Tests for Tournaments

Add rules tests proving:

- organizer can update own tournament.
- non-organizer cannot update tournament.
- non-organizer cannot update generated matches.
- captain cannot approve registrations unless organizer.
- public read does not imply write.

### Audit C — Scheduling Policy vs Code

Verify:

- fixture generation formats.
- publish requirements.
- scheduledAt rules.
- conflict checks.
- reschedule restrictions.

### Audit D — Official Stats Policy

Verify:

- standings source.
- top scorers source.
- whether unapproved events count.
- how MatchEvents are voided/rewritten on score changes.

---

## 16. Provisional Conclusion

The current codebase is not blind or empty; it has serious infrastructure already. The main problem is not lack of code. The main problem is lack of enforced product boundaries and full permission proof.

Before any new implementation, we need a stricter audit pass that maps every tournament/team/match write path to:

```text
role decision
controller guard
Firestore rule
rules emulator test
manual two-account QA
```

Until that exists, no release decision should be made.

