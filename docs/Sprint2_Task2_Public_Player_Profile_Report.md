# Sprint 2 / Task 2: Public Player Profile Basic Route

## Summary

Implemented a small public player profile route for V1 pride stats. The route supports registered players and guest players, resolves display data safely, and aggregates active MatchEvent goals and MVPs by participant identity.

The profile is Arabic-first and player-centric: it shows the player name, type badge, goal count, MVP count, and a safe guest claim placeholder for unclaimed guest players.

## Route Added

- `/player/:kind/:id`
- Route helper: `AppRoutes.playerProfileByKindAndId(kind: ..., id: ...)`
- Supported kinds:
  - `player`
  - `guestPlayer`

Invalid kinds or empty IDs resolve to a safe Arabic empty/error state instead of crashing.

## Files Added

- `lib/features/profile/models/public_player_profile_data.dart`
- `lib/features/profile/services/public_player_profile_resolver.dart`
- `lib/features/profile/controllers/public_player_profile_controller.dart`
- `lib/features/profile/bindings/public_player_profile_binding.dart`
- `lib/features/profile/views/public_player_profile_screen.dart`
- `test/features/profile/public_player_profile_test.dart`
- `docs/Sprint2_Task2_Public_Player_Profile_Report.md`

## Files Changed

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- `lib/domain/repositories/match_event_repository.dart`
- `lib/data/repositories/match_event_repository_impl.dart`
- `lib/core/services/match_event_service.dart`
- `firestore.indexes.json`

## Data Source Strategy

- Registered display names are resolved from `PlayerRepositoryImpl` where possible.
- Guest display names, linked player metadata, and claim status are resolved from `GuestPlayerRepositoryImpl` where possible.
- Pride stats are aggregated from active MatchEvents using exact `actor.kind + actor.id`.
- If the player or guest document is missing but MatchEvents exist, the resolver falls back to the actor display name stored on the event.
- `matchSidePlayer` is intentionally not exposed as a public profile kind in this task.

## Stats Aggregation Behavior

- Total goals count active `goal` MatchEvents.
- Total MVPs count active `mvp` MatchEvents.
- Voided events are excluded.
- Aggregation is client-side after querying MatchEvents for the requested actor.
- A Firestore composite index was added for:
  - `matchEvents.actor.kind ASC`
  - `matchEvents.actor.id ASC`
  - `matchEvents.status ASC`

No Firestore rules were changed.

## UI States

- Loading: lightweight progress indicator.
- Not found / invalid input: safe Arabic empty state.
- Error: safe Arabic error copy without raw exceptions.
- Data: compact profile card with badge and stats row.

## Claim Placeholder Behavior

Unclaimed guest profiles show:

- `ده أنت؟ اطلب ربط البروفايل`
- Supporting copy explaining that the full claim flow should happen through the guest invite link or QR path.

No full claim flow, edit profile flow, or profile navigation was added in this task.

## What Was Intentionally Not Touched

- No ScoreSubmit changes.
- No MatchSettlementService changes.
- No PlayerMatchStats changes.
- No rating or fantasy changes.
- No social feed, follow, friend, chat, comments, or likes.
- No edit profile flow.
- No Firestore rules changes.
- No share card added in this task.

## Tests Added

- Resolver aggregates goals and MVPs for registered players.
- Resolver aggregates goals and MVPs for guest players.
- Voided MatchEvents are ignored.
- Invalid kind and empty ID return safe null state.
- Public profile screen renders Arabic labels and the guest claim placeholder.

## Manual QA Checklist

- Open `/player/player/<playerId>` for a registered player with active MatchEvents and verify name, `لاعب` badge, goals, and MVP count.
- Open `/player/guestPlayer/<guestPlayerId>` for a guest player with active MatchEvents and verify name, `ضيف` badge, goals, MVP count, and claim placeholder when unclaimed.
- Open an invalid kind or empty/missing ID and verify a safe Arabic state appears.
- Verify a linked guest shows linked-profile copy instead of the unclaimed placeholder.

## Commands Run

- `flutter pub get`
  - Passed.
- `dart format` on changed Dart files
  - Passed.
- `dart analyze lib/`
  - Passed: `No issues found!`
- `flutter test test/features/profile/public_player_profile_test.dart`
  - Passed: `+5`.
- `flutter test`
  - Passed: `+318`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes.
- Public player profile route works for registered and guest players.
- Goals and MVP counts come from active MatchEvents.
- Guest/unclaimed profile shows a safe claim placeholder.
- V1 surface direction remains intact.

## Risks / Follow-ups

- The new actor-based MatchEvent query requires the added Firestore composite index to be deployed before production traffic uses the route heavily.
- Claim CTA is intentionally a placeholder; the full Claim Profile loop should wire into the existing guest invite/QR claim flow in a later task.
- Public profile links from share cards or leaderboard rows were not added here; this task only establishes the safe route and basic profile surface.
