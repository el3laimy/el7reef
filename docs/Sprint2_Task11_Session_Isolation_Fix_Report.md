# Sprint 2 / Task 11: P0 Session Isolation Fix

## Summary

Fixed the P0 session isolation issue where permanent GetX controllers could keep account A data visible after logout or login as account B. The fix adds explicit session reset hooks, clears user-scoped controller state immediately on logout/auth UID switch, and reloads account-scoped lists only after the new player session is active.

The addendum tournament audit also found a tournament-management isolation bug: `TournamentOperationsController` was passing `tournament.organizerId` into several admin service calls instead of using the current authenticated UID. That could make account B appear locally authorized to operate account A tournaments in controller/service tests and UI state. Those actions now require the current UID to match `tournament.organizerId` before running.

## Root Cause Analysis

Primary root cause:

- `HomeBinding` registered user-scoped controllers as `permanent: true`.
- Permanent controllers survived logout and route changes.
- Controllers such as `TeamController`, `MatchController`, `TournamentController`, `ChallengeController`, and `ActivityFeedController` stored account-specific Rx state and did not consistently clear/reload it on auth changes.
- `AuthService.signOut()` cleared `currentPlayer` only after async sign-out calls, leaving a possible frame where old state could still render.

Tournament-specific root cause from manual QA addendum:

- Public tournament discovery intentionally loads live tournaments across organizers.
- User-owned organizer lists are correctly queried by `organizerId`, but stale `myOrganizedTournaments` could persist in memory before this fix.
- Tournament operations actions did not consistently guard by current UID. Several action paths used `tournament.value?.organizerId ?? 'system'` as `actorId`, instead of the authenticated current user.

## Files Changed

- `lib/core/auth/session_reset_coordinator.dart`
- `lib/services/auth_service.dart`
- `lib/features/home/bindings/home_binding.dart`
- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/team/controllers/team_controller.dart`
- `lib/features/match/controllers/match_controller.dart`
- `lib/features/match/controllers/challenge_controller.dart`
- `lib/features/social/controllers/activity_feed_controller.dart`
- `lib/features/tournament/controllers/tournament_controller.dart`
- `lib/features/tournament/controllers/tournament_operations_controller.dart`
- `test/core/auth/session_reset_coordinator_test.dart`
- `test/data/repositories/tournament_repository_impl_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/Sprint2_Task11_Session_Isolation_Fix_Report.md`

## What Data Is Cleared On Logout

`AuthService.signOut()` now clears `currentPlayer` and calls `SessionResetCoordinator.resetForSignOut()` before Firebase/Google sign-out completes.

Controller reset coverage:

- `ProfileController`
  - clears loading state and selected edit position.
- `TeamController`
  - clears `myTeams`, errors, loading, and create-team text input.
- `MatchController`
  - clears `myMatches`, `currentMatch`, temporary participant count cache, errors, and loading.
- `TournamentController`
  - clears `myOrganizedTournaments`, errors, loading, and tournament create form state.
- `ChallengeController`
  - clears sent challenges, received challenges, cached player names, and loading.
- `ActivityFeedController`
  - clears feed items, errors, and loading.

Public discovery lists such as live tournaments and live matches may remain or reload because they are not account-owned data.

## UID Switch Behavior

`AuthService` now tracks auth UID transitions through `SessionResetCoordinator`.

- `uid A -> null`: clears current player and all registered user-scoped controller state.
- `uid A -> uid B`: clears current player and user-scoped controller state before loading B's profile.
- `uid B profile loaded`: controllers listening to `currentPlayer` reload their account-scoped data for B.

This avoids relying on app restart to clear old account data.

## Controller Lifecycle Decision

Permanent controllers were kept for minimal blast radius, but they are no longer allowed to carry stale account state.

`HomeBinding` now registers existing permanent controllers with `SessionResetCoordinator`, and each user-scoped controller exposes `resetSessionState()`.

Dependency injection constructors were added to affected controllers to make session isolation tests run without Firebase default app setup.

## Tournament Isolation Audit Answers

1. **Which tournament lists are public discovery?**
   - `TournamentRepositoryImpl.getLiveTournaments()` is public authenticated discovery. It returns registration/group/knockout tournaments across organizers and backs the main tournament list.

2. **Which tournament lists are user-owned/user-managed?**
   - `TournamentController.myOrganizedTournaments`, loaded through `getOrganizerTournaments(currentUid)`, is organizer-owned.
   - Tournament operations/admin surfaces are management-only and must require current UID to match `tournament.organizerId`.

3. **Are user-owned tournament queries filtered by current uid?**
   - Yes. `getOrganizerTournaments(String organizerId)` filters Firestore by `organizerId == currentUid`.
   - Added regression coverage proving account A tournaments do not appear in account B organizer list.

4. **Are organizer/admin actions guarded by actual current uid/role?**
   - Now yes for `TournamentOperationsController`.
   - Added `canManageTournament` and `_currentTournamentManagerActorId()` guards.
   - Admin actions now use the current authenticated UID, not `tournament.organizerId`.

5. **Can account B see account A tournaments only as public read-only items, or as manageable/owned items?**
   - Account B may see account A live tournaments in public discovery.
   - Account B must not see account A tournaments in `myOrganizedTournaments`.
   - Account B sees account A tournament operations state as read-only if routed there, with management actions disabled and controller actions denied.

6. **Can account B edit/delete/manage/join/approve teams in account A tournaments?**
   - Account B cannot manage account A tournaments through `TournamentOperationsController` after this patch.
   - Registration service already checks organizer/team ownership for registration flows.
   - Firestore rules deny direct tournament updates unless `resource.data.organizerId == request.auth.uid`.

7. **Do Firestore rules prevent account B from writing to account A tournaments?**
   - Current rules: `match /tournaments/{tournamentId}` allows read for authenticated users, create only when `organizerId == request.auth.uid`, update only for the tournament organizer, and delete is denied.
   - No Firestore rules changes were required for this patch.

## Tournament Management Actions Guarded

The following operations now require current UID to match `tournament.organizerId` before running:

- sync approved registrations
- finalize participant list
- start group stage
- publish fixtures
- regenerate group stage
- start knockout
- complete tournament
- withdraw/reactivate participant
- add/replace participant
- update participant seed
- schedule fixture

Existing `startFixture` and `approveFixtureScore` already used current actor ID and remain current-UID based.

## Tests Added/Updated

Added `test/core/auth/session_reset_coordinator_test.dart`:

- TeamController clears `myTeams` on reset.
- MatchController clears `myMatches` and `currentMatch` on reset.
- TournamentController clears `myOrganizedTournaments` on reset.
- ChallengeController clears sent/received/playerNames on reset.
- ActivityFeedController clears feed items on reset.
- ProfileController clears selected session state on reset.
- SessionResetCoordinator clears registered callbacks on sign-out reset.
- SessionResetCoordinator clears stale state on UID switch.
- TeamController reloads for the new UID when auth player changes.
- TournamentController reloads organized tournaments for the new UID only.

Updated `test/data/repositories/tournament_repository_impl_test.dart`:

- Account A tournament does not appear in account B organizer query.
- Public live tournament discovery can include tournaments from multiple organizers.

Updated `test/features/tournament/tournament_operations_dashboard_test.dart`:

- Non-organizer sees account A tournament operations as read-only controller state.
- Non-organizer controller management action is denied.

## Commands Run

- `flutter pub get`
  - Result: passed.
- `dart format lib/core/auth/session_reset_coordinator.dart lib/services/auth_service.dart lib/features/home/bindings/home_binding.dart lib/features/profile/controllers/profile_controller.dart lib/features/team/controllers/team_controller.dart lib/features/match/controllers/match_controller.dart lib/features/match/controllers/challenge_controller.dart lib/features/social/controllers/activity_feed_controller.dart lib/features/tournament/controllers/tournament_controller.dart lib/features/tournament/controllers/tournament_operations_controller.dart test/core/auth/session_reset_coordinator_test.dart test/data/repositories/tournament_repository_impl_test.dart test/features/tournament/tournament_operations_dashboard_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, `No issues found!`
- `flutter test test/core/auth/session_reset_coordinator_test.dart`
  - Result: passed, `+10`.
- `flutter test test/data/repositories/tournament_repository_impl_test.dart`
  - Result: passed, `+6`.
- `flutter test test/features/tournament/tournament_operations_dashboard_test.dart`
  - Result: passed, `+19`.
- `flutter test`
  - Result: passed, `+361`.

## Manual QA Checklist

1. Log in as account A.
2. Create or observe:
   - A-owned teams,
   - A matches,
   - A organized tournaments,
   - A challenges/activity if available.
3. Open home tabs and confirm A-owned data is visible.
4. Log out.
5. Confirm account-specific lists clear immediately before/while navigating to login.
6. Log in as account B without force-closing the app.
7. Confirm A-owned teams do not appear under B.
8. Confirm A-owned matches do not appear under B.
9. Confirm A organized tournaments do not appear in B's organized/my tournament state.
10. Confirm public live tournaments may still show A tournaments only as public discovery cards.
11. Open an A tournament as B from public discovery.
12. Confirm organizer/admin action cards are hidden or disabled for B.
13. Attempt direct operations route for A tournament as B.
14. Confirm management actions do not run and show safe denial.
15. Force refresh after B login.
16. Confirm no A-owned user-scoped data appears.
17. Force-close and reopen app as B.
18. Confirm no A-owned user-scoped data appears.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes with `+361`.
- Old user-scoped data is cleared immediately on logout.
- UID switches clear old session data before loading the next account.
- Organized/my tournaments are isolated by current UID.
- Public tournament discovery remains public read-only.
- Tournament operations now require current UID organizer ownership before running management actions.
- No Firestore schema changes.
- No Firestore rules loosening.

## Remaining Risks / Follow-ups

- Public tournament discovery intentionally shows live tournaments from other organizers. UX should keep making this clearly public/read-only for non-organizers.
- Firestore rules currently allow authenticated reads of tournament documents. That matches current public discovery behavior, but future private tournaments would need a visibility field and rules change.
- Assistant/co-organizer roles are not broadly wired into `TournamentOperationsController` permissions in this patch. V1 currently uses organizer ownership for admin operations unless a specific service supports richer roles.
- Manual QA should still verify direct route access to operations screens on a real device/build, because widget/controller tests prove logic but not every production navigation edge.
