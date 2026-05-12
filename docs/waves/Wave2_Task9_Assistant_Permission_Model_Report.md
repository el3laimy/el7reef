# Wave 2 / Task 9: Assistant Permission Model for V1

## 1. Executive Summary

V1 should include assistant permissions, but only as a tightly scoped matchday/results capability model.

The recommended V1 model is GO for limited custom assistants, with permissions restricted to:

- `canViewMatchday`
- `canStartMatch`
- `canSubmitScore`
- `canRecordGoalsAndMvp`
- `canApproveScore`
- `canDeclareForfeit`

Structural tournament management must remain primary-organizer-only in V1:

- tournament settings
- team approval/rejection
- fixture generation/publishing
- scheduling/rescheduling
- participant management
- assistant management
- tournament format or structure changes

The current codebase already has assistant concepts, but the implementation is inconsistent. Some services use assistant-style checks, while recent safety hardening made routes, Firestore rules, and several service guards organizer-only. Before implementation, the permission model must become canonical across data, rules, services, and UI.

## 2. Existing Code Inventory

### Assistant Entities and Models

Current assistant data is embedded inside `Tournament.assistants`.

Relevant files:

- `lib/domain/entities/tournament.dart`
- `lib/domain/entities/tournament_assistant.dart`
- `lib/data/models/tournament_model.dart`

Current `TournamentAssistant` fields:

- `userId`
- `role`
- `assignedAt`
- `expiresAt`

Current limitation:

- No assistant id.
- No tournament id on the assistant object.
- No `addedBy`.
- No status such as `active` or `revoked`.
- No granular permission map.
- Stored as an embedded array on the tournament document, which is weak for Firestore rules and revocation auditing.

### Existing Roles / Enums

Current enum: `TournamentAssistantRole` in `lib/core/enums/tournament_enums.dart`.

Current values:

- `full`
- `resultsOnly`
- `observer`
- `emergency`

Current limitation:

- `full` and `emergency` are too broad for V1.
- `observer` is not clearly wired to safe read-only routes.
- Roles are coarse presets, not explicit capabilities.
- `emergency` currently implies temporary broad leadership, which is outside the safe V1 assistant model unless heavily constrained.

### Assistant Routes / Screens / Controllers

Current route:

- `AppRoutes.tournamentAssistants = '/tournament/:id/assistants'`

Current files:

- `lib/features/tournament/controllers/tournament_assistants_controller.dart`
- `lib/features/tournament/views/tournament_assistants_screen.dart`
- `lib/features/tournament/bindings/tournament_assistants_binding.dart`

Current behavior:

- Organizer can add an assistant by raw `User ID`.
- Organizer can choose `resultsOnly`, `full`, `emergency`, or `observer`.
- Controller writes the embedded `Tournament.assistants` array by updating the tournament document.

Current limitation:

- The screen is closer to a mock/admin utility than a production-safe flow.
- It exposes dangerous broad roles (`full`, `emergency`).
- It does not choose a registered user through a safe search/selector.
- It does not expose granular allowed V1 toggles.
- It does not communicate that assistants cannot edit tournament structure.

### Services With Assistant-Like Permission Checks

`TournamentPermissionService` already exists in `lib/core/services/tournament_permission_service.dart`.

Current methods:

- `canEditResults`
- `canManageTeams`
- `canManageGuestTeams`
- `canManageGuestRoster`
- `canIssueGuestClaims`
- `canEditSettings`
- `canAssignAssistants`

Current behavior:

- `canEditResults` allows `full`, `resultsOnly`, and `emergency`.
- Many other methods allow `full` and `emergency`.
- `canAssignAssistants` allows organizer and `emergency`.

Current limitation:

- This is role-based, not permission-based.
- It grants structural powers through `full` and `emergency`.
- It is not aligned with the new V1 decision that structural operations stay organizer-only.

Other current service references:

- `MatchSettlementService` uses `TournamentPermissionService.canEditResults` for tournament score management.
- `MatchdayService` and `MatchdayController` use organizer/team manager checks plus `canManageTeams` in some paths.
- `GuestTeamRosterService` allows full assistants but blocks results-only assistants in tests.
- `ShareLinkService` references `TournamentPermissionService` for guest claim/link flows.

### Current Organizer-Only Guards and Recent Hardening

Recent hardening made multiple paths organizer-only:

- `TournamentOrganizerGuard` checks `tournament.organizerId == actorId`.
- `TournamentOperationsController.canManageTournament` checks organizer only.
- `TournamentOperationsController.refreshAll` fails closed for non-organizer.
- `TournamentFixtureService.scheduleFixture` is organizer-only.
- `TournamentFixtureService.startMatch` is organizer-only.
- `TournamentLifecycleService` structural methods are organizer-only.
- `TournamentParticipantService` participant mutations are organizer-only.
- `MatchEventService` verifies `match.organizerId == createdBy`.

The organizer-only hardening is safe as a baseline, but it will block legitimate V1 assistants until policy-aware guards are introduced.

### Firestore Rules That Currently Block Assistants

Current rules are mostly organizer-only for tournament and match operations.

Relevant rule patterns:

- `organizesTournamentById(tournamentId)` checks tournament `organizerId == request.auth.uid`.
- `isTournamentOrganizer()` checks resource `organizerId == request.auth.uid`.
- `isMatchOrganizerById(matchId)` checks match `organizerId == request.auth.uid`.
- `canCreateMatchEventForMatch(data)` requires match `organizerId == request.auth.uid`.
- `/matches/{matchId}` updates require `isMatchOrganizer()`.
- `/matches/{matchId}/player_stats/{playerId}` creates/updates require `isMatchOrganizerById(matchId)`.
- `/tournamentParticipants`, `/tournamentGroups`, `/groupStandingSnapshots`, `/knockoutBrackets`, `/knockoutTies` use organizer ownership through tournament id.
- `/matchSides` and `/matchSidePlayers` use `canManageMatchOperationById`, which checks match organizer only.
- `canManageMatchdaySide(data)` allows team managers, guest team owners, or match organizer, but not tournament assistants.

There is no canonical assistant permission document in rules today.

### Assistant-Related Tests

Existing tests show assistant concepts but not the proposed V1 permission model.

Observed tests:

- `test/core/services/guest_team_roster_service_test.dart` seeds `TournamentAssistant` values and confirms full assistant can manage guest roster while results-only cannot.
- `test/features/match/matchday_screen_test.dart` registers `TournamentPermissionService` but primarily exercises matchday access through team/organizer paths.
- Firestore rules tests currently verify organizer-only operation rules; they do not validate assistant permissions.

## 3. Proposed V1 Permission Model

### Primary Organizer

The primary organizer is the tournament owner: `tournaments/{tournamentId}.organizerId`.

Primary organizer can:

- edit tournament settings
- approve/reject registrations
- generate fixtures
- publish fixtures
- schedule/reschedule fixtures
- manage participants
- add/remove assistants
- start matches
- submit scores
- record goals/MVP
- approve scores
- declare forfeit/no-show
- manage tournament structure

### AssistantPermissionSet

Recommended V1 permissions:

- `canViewMatchday`
- `canStartMatch`
- `canSubmitScore`
- `canRecordGoalsAndMvp`
- `canApproveScore`
- `canDeclareForfeit`

No structural permissions should exist in the V1 assistant permission map.

Forbidden/deferred permissions must not be represented as toggles in V1:

- `canEditTournamentSettings`
- `canApproveTeams`
- `canGenerateFixtures`
- `canPublishFixtures`
- `canScheduleOrRescheduleMatches`
- `canManageParticipants`
- `canAddRemoveAssistants`
- `canChangeTournamentFormat`
- `canDeleteFixtures`
- `canManageTournamentStructure`

### Presets

#### Results Assistant

Purpose: trusted person records score and pride events after a match.

Permissions:

- `canViewMatchday = true`
- `canSubmitScore = true`
- `canRecordGoalsAndMvp = true`

No approval by default.

#### Matchday Assistant

Purpose: trusted person handles matchday flow around starting a match and recording the result.

Permissions:

- `canViewMatchday = true`
- `canStartMatch = true`
- `canSubmitScore = true`
- `canRecordGoalsAndMvp = true`

`canDeclareForfeit` should be optional and off by default unless the organizer explicitly enables it.

#### Score Approver

Purpose: highly trusted reviewer can settle/approve submitted scores.

Permissions:

- `canViewMatchday = true`
- `canApproveScore = true`

Optional:

- `canDeclareForfeit = true` only if explicitly enabled.

#### Observer

Recommendation: defer as a formal assistant preset for V1 unless there is a clear privacy-safe read-only assistant screen.

If included later, it should only have:

- `canViewMatchday = true`

It must not get any write permission.

#### Custom Limited Assistant

Purpose: organizer can choose any subset of the six allowed V1 permissions.

Validation:

- Only allowed V1 keys can be present.
- All permission values must be booleans.
- Preset should be stored for UX/audit, but rules should evaluate the permission map.

## 4. Permission Matrix

| Action | Primary Organizer | Results Assistant | Matchday Assistant | Score Approver | Observer | Custom Limited Assistant |
|---|---:|---:|---:|---:|---:|---:|
| View organizer dashboard | Yes | Limited matchday/results only | Limited matchday/results only | Limited matchday/results only | Deferred/read-only only | Only if `canViewMatchday` |
| View matchday screen | Yes | Yes | Yes | Yes | Deferred/read-only only | `canViewMatchday` |
| Start match | Yes | No | Yes | No | No | `canStartMatch` |
| Submit score | Yes | Yes | Yes | No | No | `canSubmitScore` |
| Record goals/MVP | Yes | Yes | Yes | No | No | `canRecordGoalsAndMvp` |
| Approve/settle score | Yes | No | No by default | Yes | No | `canApproveScore` |
| Declare no-show/forfeit | Yes | No | Optional | Optional | No | `canDeclareForfeit` |
| Edit tournament settings | Yes | No | No | No | No | No |
| Approve/reject teams | Yes | No | No | No | No | No |
| Generate/publish fixtures | Yes | No | No | No | No | No |
| Schedule/reschedule matches | Yes | No | No | No | No | No |
| Manage participants | Yes | No | No | No | No | No |
| Add/remove assistants | Yes | No | No | No | No | No |

Important interpretation:

The existing `TournamentOperationsDashboardScreen` is structural-heavy. Assistants should not receive the current full dashboard. They need a restricted matchday/results entry point or a route guard that hides all structural actions.

## 5. Data Model Recommendation

### Canonical Firestore Shape

Recommended canonical path:

`tournaments/{tournamentId}/assistants/{userId}`

Why this is safest:

- Firestore rules can read a deterministic path with `get()`.
- No query is needed in rules.
- Revocation is per user and per tournament.
- The assistant document id can equal the assistant user id, preventing duplicate assistant records.
- The assistant document is scoped under the tournament it authorizes.

Avoid using embedded `tournaments.assistants` for authorization. It may remain temporarily as a display cache during migration, but not as the security source of truth.

### Recommended Document Fields

Path: `tournaments/{tournamentId}/assistants/{userId}`

Fields:

- `id`: same as `userId`, optional if doc id is used.
- `tournamentId`: must equal path tournament id.
- `userId`: must equal path assistant user id.
- `addedBy`: primary organizer uid.
- `status`: `active` or `revoked`.
- `preset`: `resultsAssistant`, `matchdayAssistant`, `scoreApprover`, `customLimited`.
- `permissions.canViewMatchday`: bool.
- `permissions.canStartMatch`: bool.
- `permissions.canSubmitScore`: bool.
- `permissions.canRecordGoalsAndMvp`: bool.
- `permissions.canApproveScore`: bool.
- `permissions.canDeclareForfeit`: bool.
- `createdAt`: int millis or server timestamp equivalent used consistently.
- `updatedAt`: int millis or server timestamp equivalent used consistently.
- `revokedAt`: nullable int.

### Immutable Fields

These fields should be immutable after create:

- `tournamentId`
- `userId`
- `addedBy`
- `createdAt`

### Validation Rules

Create:

- only primary organizer can create.
- document id must match `userId`.
- path tournament id must match `tournamentId`.
- `addedBy` must equal request auth uid and that uid must be the tournament organizer.
- `status` must start as `active`.
- `permissions` must contain only allowed V1 keys.
- all permission values must be bool.
- no structural permission key is allowed.

Update:

- only primary organizer can update.
- immutable fields must not change.
- allowed changes: `status`, `preset`, `permissions`, `updatedAt`, `revokedAt`.
- revocation should set `status = revoked` and `revokedAt`.

Delete:

- disallow hard delete in V1.
- use revocation for auditability.

## 6. UI Recommendation

### Organizer Assistant Management UX

The organizer should manage assistants from a production assistant management screen.

Recommended flow:

- Add assistant.
- Search/select a registered user, not raw User ID.
- Choose preset: Results Assistant, Matchday Assistant, Score Approver, Custom Limited.
- Show optional limited toggles for the six allowed V1 permissions.
- Disable or hide structural permissions entirely.
- Show a clear warning: `المساعدون لا يمكنهم تعديل هيكل البطولة أو الفرق أو جدول المباريات.`
- Show active/revoked status.
- Show who added the assistant and when.
- Allow organizer to revoke, not delete.

### Assistant-Facing UX

Assistants should not see the full organizer dashboard in V1.

Assistant UX should:

- show only matchday/results actions granted by permissions.
- hide participants/groups/fixtures/bracket/settings actions.
- hide assistant management.
- show empty/denied state when permission is revoked.
- explain limited role in Arabic.

Recommended entry points:

- Matchday screen if `canViewMatchday`.
- Start match action if `canStartMatch`.
- Score submit screen if `canSubmitScore`.
- Goals/MVP controls if `canRecordGoalsAndMvp`.
- Score approval action if `canApproveScore`.
- Forfeit/no-show action if `canDeclareForfeit`.

## 7. Firestore Rules Strategy

### Canonical Rules Shape

Use deterministic assistant documents:

`tournaments/{tournamentId}/assistants/{uid}`

Recommended helper:

```js
function hasTournamentAssistantPermission(tournamentId, permission) {
  return isAuthenticated() &&
    tournamentId is string &&
    exists(/databases/$(database)/documents/tournaments/$(tournamentId)/assistants/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/tournaments/$(tournamentId)/assistants/$(request.auth.uid)).data.status == 'active' &&
    get(/databases/$(database)/documents/tournaments/$(tournamentId)/assistants/$(request.auth.uid)).data.permissions[permission] == true;
}
```

Recommended owner-or-assistant helper:

```js
function canOperateTournamentMatch(tournamentId, permission) {
  return organizesTournamentById(tournamentId) ||
    hasTournamentAssistantPermission(tournamentId, permission);
}
```

Rules must not trust client-provided permission flags on match/matchEvent writes. They must read the canonical assistant document.

### Match-Based Permission Lookup

For match event and match update rules, derive `tournamentId` from the match document where possible:

- for `matchEvents`, read `matches/{matchId}.tournamentId`.
- for match score/status updates, read `resource.data.tournamentId`.
- for friendly matches with no tournament id, keep organizer-only.

### Rules Must Remain Granular

Do not replace organizer-only update rules with broad assistant write access.

Recommended future granular checks:

- `canStartMatch` only for allowed start-match fields such as `status`, `startedAt`, projected team player ids if needed.
- `canSubmitScore` only for submitted score fields and status transitions to completed/pending review.
- `canRecordGoalsAndMvp` only for `matchEvents` create/void related to goals and MVP.
- `canApproveScore` only for score approval/settlement transitions.
- `canDeclareForfeit` only for explicit forfeit/no-show fields and audit-safe state transitions.

Structural collections should remain organizer-only:

- `tournamentParticipants`
- `tournamentGroups`
- `groupStandingSnapshots` when manually generated from structural lifecycle operations
- `knockoutBrackets`
- `knockoutTies`
- fixture generation/publishing/scheduling operations

Note: standings refresh after score approval may still happen server-side through trusted service code, but client rules should not grant assistants broad direct writes to structural collections unless the exact write path is made safe and narrow.

## 8. Service Guard Strategy

The code needs a single permission policy used consistently by controllers and services.

### TournamentPermissionService

Refactor from role methods to permission methods:

- `canViewMatchday(tournament, userId)`
- `canStartMatch(tournament, userId)`
- `canSubmitScore(tournament, userId)`
- `canRecordGoalsAndMvp(tournament, userId)`
- `canApproveScore(tournament, userId)`
- `canDeclareForfeit(tournament, userId)`
- `isPrimaryOrganizer(tournament, userId)`

Structural methods should become organizer-only:

- `canEditSettings` should return true only for primary organizer.
- `canManageTeams` should not be used for V1 assistants unless renamed and scoped.
- `canAssignAssistants` should return true only for primary organizer.

### Guards That Must Change Later

`TournamentOrganizerGuard`:

- Keep for structural tournament routes.
- Add a separate permission-aware guard such as `TournamentPermissionGuard(requiredPermission: canViewMatchday)` for assistant matchday/results routes.

`TournamentOperationsController`:

- Keep structural dashboard organizer-only.
- Do not simply let assistants into the existing full dashboard.
- If reused, it must become action-level permission-aware and hide structural actions.

`TournamentFixtureService`:

- `startMatch` should allow `canStartMatch`.
- `scheduleFixture` should remain organizer-only.
- `regenerateGroupStage` and fixture generation/publishing should remain organizer-only.

`ScoreSubmitController` and score submit paths:

- Should require `canSubmitScore` for score submit.
- Should require `canRecordGoalsAndMvp` for goal/MVP event writes.
- If a user can submit score but not record goals/MVP, UI should be score-only and clearly say top scorers will not update.

`MatchEventService`:

- Should change from organizer-only to `canRecordGoalsAndMvp` for tournament matches.
- Friendly matches should remain match-organizer-only.

`MatchSettlementService`:

- `submitScore` should use `canSubmitScore`.
- `approveScore` should use `canApproveScore`.
- Forfeit/no-show method should use `canDeclareForfeit` when implemented.

`TournamentLifecycleService`:

- No assistant access for structural methods in V1.
- `finalizeParticipants`, `startGroupStage`, `publishFixtures`, `startKnockout`, `completeTournament` remain organizer-only.

`TournamentParticipantService`:

- No assistant access in V1.
- Manual add, replace, withdraw, reactivate, seed edits remain organizer-only.

## 9. Routes Strategy

Assistants should access matchday/results routes only.

Allowed route categories for assistants:

- matchday detail route when `canViewMatchday`.
- score submit/approval route when the user has the relevant permission.
- future assistant-specific match list filtered to assigned tournament/matches, if needed.

Routes that should remain organizer-only:

- tournament participants
- tournament groups
- tournament fixtures management
- tournament standings management
- tournament bracket management
- organizer dashboard as currently built
- tournament assistants management
- tournament registration review
- tournament guest team create if it impacts registration/team approval

Route guard recommendation:

- Keep `TournamentOrganizerGuard` for structural screens.
- Introduce `TournamentMatchPermissionGuard` or `MatchPermissionGuard` for matchday/results screens.
- Avoid naming assistant routes under `/organizer/...` long-term if they are not organizer-only.

## 10. Tests Required

### Firestore Rules Emulator Tests

Required positive tests:

- organizer can create/revoke assistant doc.
- assistant with `canViewMatchday` can perform only allowed matchday reads/writes if any write is required.
- assistant with `canStartMatch` can perform exact start-match update and no other match update.
- assistant with `canSubmitScore` can perform exact score submit update.
- assistant with `canRecordGoalsAndMvp` can create goal/MVP `matchEvents`.
- assistant with `canApproveScore` can perform exact score approval update.
- assistant with `canDeclareForfeit` can perform exact forfeit update.

Required negative tests:

- assistant without permission cannot perform that action.
- revoked assistant cannot perform any assistant action.
- assistant cannot edit tournament settings.
- assistant cannot approve/reject teams.
- assistant cannot generate/publish fixtures.
- assistant cannot schedule/reschedule matches.
- assistant cannot manage participants.
- assistant cannot add/remove assistants.
- assistant cannot add forbidden permission keys to their own document.
- non-organizer cannot grant themselves assistant permissions.
- assistant cannot write a matchEvent for another tournament.

### Service Tests

Required service tests:

- `TournamentPermissionService` maps presets to exact permissions.
- `TournamentFixtureService.startMatch` allows `canStartMatch` and rejects no permission.
- `TournamentFixtureService.scheduleFixture` rejects assistants.
- `MatchSettlementService.submitScore` allows `canSubmitScore` and rejects no permission.
- `MatchSettlementService.approveScore` allows `canApproveScore` and rejects `canSubmitScore` only.
- `MatchEventService.recordGoal/recordMvp` allows `canRecordGoalsAndMvp` and rejects `canSubmitScore` only.
- `TournamentLifecycleService` rejects assistants for structural operations.
- `TournamentParticipantService` rejects assistants for participant operations.

### UI / Route Guard Tests

Required UI tests:

- assistant with matchday permission can enter matchday route.
- assistant without matchday permission is denied.
- assistant sees only allowed result actions.
- assistant does not see structural dashboard actions.
- organizer sees assistant management screen.
- assistant does not see assistant management screen.

### Account-Switch Tests

Required session tests:

- switch from organizer to assistant refreshes permissions.
- switch from assistant to unrelated user clears access.
- revoked assistant loses access after reload/session refresh.

### Negative Escalation Tests

Required escalation tests:

- client cannot add structural permission keys.
- client cannot change immutable fields.
- assistant cannot modify their own permissions.
- assistant cannot use `canRecordGoalsAndMvp` to update score.
- assistant cannot use `canSubmitScore` to create match events if `canRecordGoalsAndMvp` is false.
- assistant cannot use `canApproveScore` to schedule a match.

## 11. Implementation Sequence

### Task 9.1: Data Model and Repository

Create canonical assistant permission entity/model/repository for:

`tournaments/{tournamentId}/assistants/{userId}`

Deliverables:

- `TournamentAssistantPermission` entity.
- `AssistantPermissionSet` value object.
- repository methods: get, list, create, update permissions, revoke.
- adapter from old embedded assistants for migration/read compatibility if needed.

### Task 9.2: Rules Tests First

Add emulator tests for assistant permission documents and all allowed/forbidden V1 actions before changing rules.

### Task 9.3: Firestore Rules

Implement deterministic assistant permission helpers in rules.

Keep structural operations organizer-only.

Add granular match/result/event permission checks.

### Task 9.4: Service Guard Policy

Refactor `TournamentPermissionService` into explicit permission checks.

Update only matchday/results services:

- `TournamentFixtureService.startMatch`
- `MatchSettlementService.submitScore`
- `MatchSettlementService.approveScore`
- `MatchEventService.recordGoal/recordMvp`
- future forfeit/no-show service

Do not open structural services.

### Task 9.5: Route Guards

Keep `TournamentOrganizerGuard` for structural routes.

Add permission guard for matchday/results routes.

Ensure assistants do not enter participants/groups/fixtures/bracket/settings.

### Task 9.6: Organizer Assistant Management UI

Replace raw User ID flow with registered user picker.

Add presets and limited toggles.

Add revocation UX.

Add warning that assistants cannot edit tournament structure.

### Task 9.7: Assistant Matchday/Results UX

Show only allowed actions in matchday/result screens.

Support score-only, goal/MVP, approval, and forfeit permissions independently.

### Task 9.8: QA and Audit

Run full Flutter tests.

Run rules emulator tests.

Perform account-switch QA.

Perform revoked-assistant QA.

Perform privilege escalation QA.

## 12. Risks

### Privilege Escalation

Risk: broad rules or broad service guards accidentally give assistants structural permissions.

Mitigation: permission-specific rules and negative escalation tests.

### Stale Permissions After Revocation

Risk: UI or service cache continues to allow a revoked assistant.

Mitigation: load permissions from canonical document before sensitive actions and refresh on auth/session changes.

### Assistant Account Switch

Risk: GetX controllers retain previous user permission state.

Mitigation: session reset coordinator and account-switch tests must clear assistant permission caches.

### Rule / Service Mismatch

Risk: service allows an action that rules deny, causing production-only failures.

Mitigation: rules tests and service tests must use the same permission matrix.

### Over-Complex Custom Permissions

Risk: organizers may misunderstand toggles.

Mitigation: ship safe presets first, keep custom toggles advanced and limited to six V1 permissions.

### Organizer Confusion

Risk: organizer thinks assistants can run the whole tournament.

Mitigation: Arabic copy must clearly state assistants cannot change tournament structure, teams, or schedule.

### Embedded Assistant Migration

Risk: existing `Tournament.assistants` array diverges from new canonical subcollection.

Mitigation: choose one canonical auth source and optionally use embedded data only as read/display cache during migration.

## 13. Final Recommendation

GO for implementing limited custom assistant permissions next.

Recommended exact next implementation task:

`Wave 2 / Task 9.1: Assistant Permission Data Model + Rules Test Plan`

Scope for the next task should be:

- create canonical assistant permission entity/model/repository targeting `tournaments/{tournamentId}/assistants/{userId}`.
- add rules emulator tests for create/revoke and forbidden structural permissions.
- do not yet open match writes until rules tests describe every allowed write shape.

This keeps V1 assistants useful for matchday/results while preserving the current safety hardening around tournament structure.

## Commands Run

No tests or build commands were required for this design/audit task.

Analysis was performed by reading and searching the relevant project files only.
