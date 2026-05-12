# P0 Task 1: Public Tournament View vs Organizer Dashboard Separation

## Summary of Implementation

This task separated the tournament public detail experience from organizer-only operations surfaces.

Public tournament detail now remains read-only for non-organizers and no longer exposes the operations snapshot or operations/admin links. The real organizer sees a single clear Arabic CTA, `إدارة البطولة`, which routes to the existing tournament operations dashboard.

Operations/admin routes are now wrapped in an organizer ownership guard. Direct route entry by another account fails closed, shows safe Arabic feedback, and redirects back to the public tournament detail route when a tournament id is available.

## Files Changed

- `lib/features/tournament/views/tournament_detail_screen.dart`
- `lib/features/tournament/views/tournament_organizer_guard.dart`
- `lib/features/tournament/controllers/tournament_operations_controller.dart`
- `lib/app/routes/app_pages.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/P0_Task1_Public_Tournament_View_Organizer_Dashboard_Separation_Report.md`

No Firestore rules, tournament lifecycle services, score submit logic, MatchEvent logic, or claim flow files were changed.

## Public View Behavior

- Non-organizers can still open public tournament detail.
- Public/read-only content still renders, including tournament overview, registration summary, and public top scorers content.
- Non-organizers no longer see:
  - `حالة التشغيل`
  - operations snapshot rows
  - participants/groups/fixtures/standings/bracket operations links
  - organizer dashboard/admin links
  - `إدارة البطولة`
- The old operations wording was removed from public detail, keeping the screen focused on tournament viewing.

## Organizer Dashboard Access Behavior

- The tournament organizer sees exactly one management CTA on public detail: `إدارة البطولة`.
- The CTA routes to the existing operations dashboard via `AppRoutes.organizerDashboardForTournament(tournament.id)`.
- The public detail page no longer lists every operations screen directly, so organizer management is guided through the dashboard rather than mixed into public read-only content.

## Route Guard Behavior

The following operations/admin routes are wrapped with `TournamentOrganizerGuard`:

- `AppRoutes.organizerDashboard`
- `AppRoutes.tournamentParticipants`
- `AppRoutes.tournamentGroups`
- `AppRoutes.tournamentFixtures`
- `AppRoutes.tournamentStandings`
- `AppRoutes.tournamentBracket`
- `AppRoutes.tournamentAssistants`

Guard behavior:

- Reads `tournamentId` or `id` from GetX route parameters.
- Resolves the tournament through `TournamentRepositoryImpl`.
- Compares the current authenticated uid with `tournament.organizerId`.
- Allows the wrapped operations screen only when the current user owns the tournament.
- Fails closed when uid, tournament id, or tournament lookup is missing.
- Shows `لا تملك صلاحية إدارة هذه البطولة.` for denied access.
- Redirects safely to public tournament detail when possible.

This is a widget-level route guard because the ownership check is asynchronous.

## Account-Switch Behavior

- `TournamentOrganizerGuard` listens to `AuthService.currentPlayer`.
- When the account changes while an operations route is open, the guard recomputes ownership against the current uid.
- If the new uid is not the tournament organizer, the operations surface is closed and redirected to public detail.
- `TournamentOperationsController.refreshAll()` now also recomputes ownership from the current uid and tournament organizer id. Non-owners receive the same Arabic access-denied message and admin-shaped state is cleared.

## Tests Added/Updated

Updated `test/features/tournament/tournament_operations_dashboard_test.dart` to cover:

- Organizer sees `إدارة البطولة` on tournament detail.
- Non-organizer does not see `إدارة البطولة`.
- Non-organizer does not see operations links/snapshot on tournament detail.
- Organizer CTA navigates to the operations dashboard.
- Direct operations route as non-organizer is blocked/redirected.
- Direct operations route as organizer is allowed by existing dashboard coverage.
- Existing public tournament detail content still renders.
- Account switch from organizer to another account removes access to admin operations.
- Operations controller fails closed for a non-organizer and clears operational state.

## Commands Run

- `flutter pub get`
- `dart format lib/app/routes/app_pages.dart lib/features/tournament/views/tournament_detail_screen.dart lib/features/tournament/views/tournament_organizer_guard.dart lib/features/tournament/controllers/tournament_operations_controller.dart test/features/tournament/tournament_operations_dashboard_test.dart`
- `dart analyze lib/`
- `flutter test test/features/tournament/tournament_operations_dashboard_test.dart`
- `flutter test`

Results:

- `dart analyze lib/`: passed with no issues.
- Targeted tournament tests: passed.
- Full `flutter test`: passed.

Note: green widget/unit tests are not treated as proof of Firestore permission correctness. Firestore rules were intentionally not changed in this task.

## Final Result

Acceptance criteria are met for this task:

- Public tournament detail no longer shows operations/admin links to non-organizers.
- Organizer sees one clear Arabic `إدارة البطولة` CTA.
- Non-organizers cannot enter the guarded tournament operations/admin routes for another organizer's tournament.
- Existing operations screens remain reachable for the real organizer.
- Controller-level access now fails closed for non-organizers.
- Account-switch risk is reduced by both route guard rechecks and controller ownership recomputation.
- No forbidden Firestore rules, score, claim, MatchEvent, lifecycle, fantasy, rating, or settlement changes were made.

## Remaining Risks and Follow-Ups

- **P0 risk:** Firestore rules were out of scope here. Server-side permission correctness still depends on existing rules and should be verified in the rules emulator in a dedicated permissions task.
- **P0 risk:** Match-scoped admin routes such as score approval were not changed because this task explicitly excluded score submit/settlement logic. If score approval is classified as an organizer/admin route in the Master Blueprint, it needs its own guard path using match-to-tournament ownership resolution.
- **P1 risk:** The guard uses a route wrapper instead of GetX middleware because tournament ownership requires asynchronous repository lookup. This is acceptable for V1, but a shared async ownership-guard pattern should be standardized if more admin surfaces are added.
- **P1 risk:** Assistant/co-organizer permissions remain outside this task. The new guard enforces organizer-only access, which matches this task, but future assistant roles need explicit product and rules decisions before being re-enabled as active managers.
- **P2 improvement:** Public tournament detail can later expose richer read-only fixtures, standings, and bracket previews without linking to admin operations screens.
