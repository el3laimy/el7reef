# Sprint 0 / Task 2 - V1 Visible Surface Freeze

## 1. Summary of Changes

The V1 visible surface is now tournament-first by default. The main bottom navigation opens on `البطولات`, keeps matches as a secondary tab, keeps teams/profile available, and does not expose an unfinished leaderboard tab.

Fantasy UI is hidden from normal V1 flows: tournament creation no longer shows the fantasy switch, tournament cards/details no longer show fantasy badges or CTAs while the flag is disabled, and created tournaments cannot opt into fantasy unless the global fantasy flag is enabled.

Activity feed, top-level challenges, golden rating prompts, social/profile placeholder actions, profile settings, profile sharing, and advanced organizer assistant entry points are hidden behind disabled feature flags. Existing routes and feature code remain in place for deep links and later reactivation.

## 2. Files Changed

- `lib/core/constants/feature_flags.dart`
- `lib/features/home/views/home_screen.dart`
- `lib/features/tournament/controllers/tournament_controller.dart`
- `lib/features/tournament/views/tournament_list_screen.dart`
- `lib/features/tournament/views/tournament_detail_screen.dart`
- `lib/features/match/views/match_discover_screen.dart`
- `lib/features/profile/views/profile_screen.dart`
- `docs/Sprint0_Task2_Surface_Freeze_Report.md`

## 3. Feature Flags Added or Changed

- `fantasyUiEnabled`: remains `false`; now also prevents tournament creation from setting `isFantasyEnabled`.
- `activityFeedEnabled`: changed from `true` to `false`.
- `challengesUiEnabled`: added as `false`.
- `friendlyMatchTopLevelEnabled`: added as `false`.
- `socialUiEnabled`: added as `false`.
- `organizerAdvancedOpsEnabled`: added as `false`.
- `goldenRatingUiEnabled`: added as `false`.
- `profileSettingsUiEnabled`: added as `false`.
- `profileSharingUiEnabled`: added as `false`.

Existing V1-supporting flags were left enabled:

- `guestIdentityEnabled`
- `hybridTournamentRegistrationEnabled`
- `matchdayUiEnabled`

## 4. Visible Surfaces Hidden

- Fantasy switch in tournament creation.
- Fantasy badge in tournament list cards.
- Fantasy leaderboard CTA in tournament detail.
- Fantasy opt-in during tournament creation when `fantasyUiEnabled == false`.
- Activity feed on the hidden legacy Home tab unless `activityFeedEnabled == true`.
- Legacy Home tab as the first/default bottom tab unless `friendlyMatchTopLevelEnabled == true`.
- Challenge tab in match discovery unless `challengesUiEnabled == true`.
- Golden rating prompt/action on match cards unless `goldenRatingUiEnabled == true`.
- Friends/social profile quick action unless `socialUiEnabled == true`.
- Profile share quick action unless `profileSharingUiEnabled == true`.
- Profile settings icon unless `profileSettingsUiEnabled == true`.
- Organizer assistant management CTA unless `organizerAdvancedOpsEnabled == true`.

## 5. Remaining Known Visible Risks

- `TournamentOperationsDashboard` still exists and may expose advanced organizer operations if reached from an organizer tournament detail. It is real functionality rather than a dead feature, but parts of that surface are still more admin/tooling-like than V1 consumer polish.
- Fantasy routes remain registered and intentionally route to `FeatureUnavailableScreen` when opened directly. Normal V1 UI should not expose buttons into those routes.
- Friendly matches remain visible as the second bottom tab. This keeps the retention loop accessible, but it is no longer the default first surface.
- Existing tests still expect fantasy route screens to render while `fantasyUiEnabled == false`; those tests need a V1-freeze update.
- Some tournament operations tests expect English labels and/or unmocked Firebase dependencies. Those failures predate this surface freeze pattern and need separate test cleanup.

## 6. Manual QA Checklist

- Launch app and confirm the first visible tab is `البطولات`.
- Confirm bottom navigation order is `البطولات`, `المباريات`, `الفرق`, `أنا`.
- Open tournament creation and confirm there is no fantasy switch.
- Create a tournament and confirm it does not get a visible fantasy badge.
- Open tournament detail and confirm there is no fantasy leaderboard CTA.
- Confirm the legacy activity feed is not visible in the default V1 flow.
- Open `المباريات` and confirm tabs are only `مبارياتي` and `اكتشاف`.
- Confirm no `التحديات` top-level tab appears with default flags.
- Confirm match cards do not show golden rating prompts with default flags.
- Open profile and confirm only safe quick actions remain visible.
- Confirm no visible V1 CTA opens a fantasy or unavailable-feature screen.
- Confirm deep links/routes remain registered for existing non-visible features.

## 7. Commands Run and Results

- `flutter pub get`
  - Result: passed.
  - Notes: dependencies resolved successfully; Flutter reported that 55 packages have newer versions incompatible with current constraints.

- `dart analyze lib/`
  - Result: passed after the visible-surface changes.
  - Notes: an initial unused `_HomeTab` warning was resolved by keeping the legacy Home tab behind `friendlyMatchTopLevelEnabled`.

- `flutter test`
  - Result: failed.
  - Final count: `+214 -20`.
  - Known failures:
    - `test/core/services/match_settlement_service_test.dart` does not compile because `submitScore()` and `approveScore()` calls are missing the required `actorId` named parameter.
    - `test/features/match/matchday_screen_test.dart` does not compile because `MatchdayController` now requires `matchSideRepository`.
    - `test/features/tournament/tournament_operations_dashboard_test.dart` has widget setup/expectation failures around Firebase/repository wiring and old operation labels.
    - `test/widget_test.dart` still expects fantasy route screens to render, but V1 freeze intentionally gates fantasy routes behind `FeatureUnavailableScreen`.
    - `test/widget_test.dart` also has a locked draft route setup failure because `FantasyLifecycleRepositoryImpl` is not registered in that test path.
