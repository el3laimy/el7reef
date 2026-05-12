# Sprint 2 / Task 4: Link MVP Result CTA to Public Profile

## Summary

Added a compact MVP profile entry point to `MatchResultLineupScreen`. When the MVP identity can safely resolve to a public profile, the result screen now shows:

- `افتح بروفايل النجم`

The existing `شارك نجم المباراة` share CTA remains unchanged.

## Files Changed

- `lib/features/lineup/controllers/match_result_lineup_controller.dart`
- `lib/features/lineup/views/match_result_lineup_screen.dart`
- `test/features/lineup/match_result_lineup_controller_test.dart`
- `docs/Sprint2_Task4_Link_MVP_To_Profile_Report.md`

## Navigation Behavior

The CTA navigates with:

```dart
AppRoutes.playerProfileByKindAndId(
  kind: target.kind.name,
  id: target.id,
)
```

Supported targets:

- MVP MatchEvent actor `player` -> `/player/player/<id>`
- MVP MatchEvent actor `guestPlayer` -> `/player/guestPlayer/<id>`
- Legacy `Match.mvpPlayerId` only when an existing lineup snapshot proves it is a registered or guest participant.

## Safety Guards

- MVP MatchEvent is preferred because it carries full `ParticipantRef`.
- Empty IDs do not produce a navigation target.
- `matchSidePlayer` MVPs remain shareable but do not show the public profile CTA in this task.
- Legacy `Match.mvpPlayerId` does not navigate unless the controller can safely infer `player` or `guestPlayer` from lineup snapshots.
- Unknown or unsupported MVP identity is ignored safely.

## UI Placement

- The CTA appears directly below `شارك نجم المباراة`.
- It uses a compact `TextButton.icon` with Arabic copy.
- It only appears when `MatchResultLineupController.mvpProfileTarget` is non-null.
- No navigation was added inside exported share images.

## What Was Intentionally Not Touched

- MVP share card image/widget was not modified.
- ScoreSubmit was not modified.
- MatchSettlementService was not modified.
- MatchEvent writing was not modified.
- PlayerMatchStats, rating, fantasy, Firestore rules, and indexes were not modified.
- Full claim flow was not implemented.
- Social/feed/chat/follow features were not added.

## Tests Added / Updated

Updated `test/features/lineup/match_result_lineup_controller_test.dart`:

- `mvpProfileTarget` resolves registered MVP MatchEvent actors.
- `mvpProfileTarget` resolves guest MVP MatchEvent actors.
- `mvpProfileTarget` rejects match-side MVP MatchEvent actors while preserving shareability.
- Legacy registered MVP can be inferred from lineup snapshot.
- Legacy guest MVP can be inferred from lineup snapshot.
- Unknown legacy MVP kind does not produce a profile target.
- Widget test: registered MVP CTA navigates to `/player/player/<id>`.
- Widget test: guest MVP CTA navigates to `/player/guestPlayer/<id>`.
- Widget test: no MVP hides the profile CTA.
- Widget test: match-side MVP keeps `شارك نجم المباراة` but hides `افتح بروفايل النجم`.

## Manual QA Checklist

- Open a result lineup screen with a registered MVP MatchEvent and verify `افتح بروفايل النجم` opens the registered public profile.
- Open a result lineup screen with a guest MVP MatchEvent and verify the CTA opens the guest public profile.
- Verify `شارك نجم المباراة` remains visible and functional when MVP data exists.
- Verify a match-side MVP can still be shared but does not show the profile CTA.
- Verify a result with no MVP does not show either MVP CTA.

## Commands Run

- `flutter pub get`
  - Passed.
- `dart format lib/features/lineup/controllers/match_result_lineup_controller.dart lib/features/lineup/views/match_result_lineup_screen.dart test/features/lineup/match_result_lineup_controller_test.dart`
  - Passed.
- `dart analyze lib/`
  - Passed: `No issues found!`
- `flutter test test/features/lineup/match_result_lineup_controller_test.dart`
  - Passed: `+20`.
- `flutter test`
  - Passed: `+333`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes.
- Registered MVP can open public profile.
- Guest MVP can open public profile.
- Unsupported MVP kinds are guarded.
- MVP share CTA remains intact.
- No settlement, rating, fantasy, PlayerMatchStats, Firestore rules, or MatchEvent write behavior changed.

## Risks / Follow-ups

- Legacy `Match.mvpPlayerId` can only navigate when lineup snapshots make the participant kind clear. This is intentional until full ParticipantRef-backed MVP data is universally available.
- Claim flow remains a placeholder on public guest profiles and should be connected in a later task.
