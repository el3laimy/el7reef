# Sprint 2 / Task 3: Link Top Scorers Rows to Public Profile

## Summary

Made Tournament Detail top scorer rows tappable so registered and guest scorers can open the public player profile route. The row keeps the existing compact Arabic layout, adds a subtle ripple, and shows a small trailing chevron only when the scorer can safely open a profile.

## Files Changed

- `lib/features/tournament/views/tournament_detail_screen.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/Sprint2_Task3_Link_Top_Scorers_To_Profile_Report.md`

## Navigation Behavior

Supported top scorer rows navigate with:

```dart
AppRoutes.playerProfileByKindAndId(
  kind: actor.kind.name,
  id: actor.id,
)
```

Supported profile kinds:

- `ParticipantRefKind.player` -> `/player/player/<id>`
- `ParticipantRefKind.guestPlayer` -> `/player/guestPlayer/<id>`

The existing `شارك الهدافين` CTA remains unchanged.

## Safety Guards

- Rows only enable tap behavior for `player` and `guestPlayer`.
- Empty actor IDs disable navigation.
- `matchSidePlayer` remains unsupported defensively, even though the top scorers resolver already excludes it from tournament leaderboards.
- Unsupported or invalid rows do not crash.

## What Was Intentionally Not Touched

- Public Player Profile implementation was not modified.
- ScoreSubmit was not modified.
- MatchSettlementService was not modified.
- MatchEvent writing was not modified.
- PlayerMatchStats, rating, fantasy, Firestore rules, and indexes were not modified.
- Full claim flow was not implemented.
- Social/feed features were not added.
- Share card rows were not linked in this task.

## Tests Added / Updated

Updated `test/features/tournament/tournament_operations_dashboard_test.dart`:

- Registered top scorer row tap navigates to `/player/player/<id>`.
- Guest top scorer row tap navigates to `/player/guestPlayer/<id>`.
- Existing top scorers UI test still verifies registered and guest scorers display, share CTA remains visible when scorers exist, and match-side players are not shown.
- Existing empty state test still verifies no share CTA when no scorers exist.

## Manual QA Checklist

- Open Tournament Detail for a tournament with top scorer events.
- Tap a registered scorer row and verify the public player profile opens.
- Tap a guest scorer row and verify the public guest profile opens.
- Verify the top scorers share CTA still appears when scorers exist.
- Verify an empty top scorers section has no active scorer row.
- Verify match-side-only scorers do not appear in the tournament top scorers list.

## Commands Run

- `flutter pub get`
  - Passed.
- `dart format lib/features/tournament/views/tournament_detail_screen.dart test/features/tournament/tournament_operations_dashboard_test.dart`
  - Passed.
- `dart analyze lib/`
  - Passed: `No issues found!`
- `flutter test test/features/tournament/tournament_operations_dashboard_test.dart`
  - Passed: `+18`.
- `flutter test`
  - Passed: `+323`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes.
- Registered top scorer rows open the public registered-player profile route.
- Guest top scorer rows open the public guest-player profile route.
- `matchSidePlayer` remains unsupported and guarded.
- No settlement, rating, fantasy, PlayerMatchStats, Firestore rules, or MatchEvent write behavior changed.

## Risks / Follow-ups

- Share card scorer rows are still intentionally static; linking them should be handled separately if needed.
- Public profile claim flow remains a placeholder and should be connected to the safe guest claim path in a later task.
