# Sprint 1 / Task 9: Top Scorers Share Card Report

## Summary of Implementation

- Added a shareable Arabic-first "هدافو البطولة" card for tournament top scorers.
- Added a compact "شارك الهدافين" CTA to the Tournament Detail top scorers section.
- Reused the existing share card capture pipeline through `ShareCardCaptureService`.
- Kept the card read-only and limited to the current top 5 scorers.
- Preserved V1 boundaries: no navigation changes, no ScoreSubmit changes, no settlement/rating/fantasy changes, and no Firestore rule/index changes.

## Files Added

- `lib/features/shareables/models/top_scorers_share_data.dart`
- `lib/features/shareables/controllers/top_scorers_share_controller.dart`
- `lib/features/shareables/widgets/top_scorers_share_card.dart`
- `test/features/shareables/top_scorers_share_card_test.dart`
- `docs/Sprint1_Task9_Top_Scorers_Share_Card_Report.md`

## Files Changed

- `lib/features/tournament/views/tournament_detail_screen.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`

## Share Data / Widget / Controller

- `TopScorersShareData` carries the card title, tournament name, brand label, and scorer entries.
- `TopScorersShareEntryData` carries rank, display name, goal count, and guest flag.
- `TopScorersShareController` maps `TournamentTopScorerEntry` values into share data, caps output at 5 scorers, and preserves guest badges.
- `TopScorersShareCard` renders the RTL share card with:
  - title: "هدافو البطولة"
  - tournament name
  - ranked scorer list
  - Arabic goal labels: `1 هدف`, `2+ أهداف`
  - guest badge: `ضيف`
  - El7reef branding: `الحريف`

## Existing Share Infrastructure Reused

- Reused `ShareCardCaptureService.captureAndShare`.
- Tournament Detail inserts an offscreen `OverlayEntry` with a `RepaintBoundary`.
- The share card is rendered in export mode and captured through the existing image share path.
- Reused the existing share export pixel ratio constant.

## UI CTA Behavior

- The Tournament Detail top scorers section now shows one CTA: `شارك الهدافين`.
- The CTA appears only when scorer data exists.
- Empty, loading, and error states do not show an active share action.
- No new route, preview screen, profile navigation, or section redesign was added.

## Error Handling

- If no scorers are available, sharing is blocked with a safe Arabic snackbar.
- If the capture overlay is unavailable, the user sees a safe Arabic snackbar.
- If capture/share fails, raw exceptions are not shown in UI.

## Intentionally Not Touched

- ScoreSubmit and goal/MVP writing behavior.
- MatchSettlementService.
- PlayerMatchStats.
- Rating and fantasy systems.
- Firestore rules and indexes.
- Denormalized snapshots.
- Tournament navigation or player profile navigation.
- Share cards for result, MVP, player, team, lineup, or champion.

## Tests Added / Updated

- Added share data tests for:
  - tournament name mapping
  - top 5 scorer cap
  - rank mapping
  - guest scorer flag
  - Arabic goal labels
- Added share card widget test for:
  - title
  - tournament name
  - scorer names
  - goal labels
  - guest badge
  - El7reef brand text
- Updated Tournament Detail tests for:
  - share CTA hidden when no scorers exist
  - share CTA visible when registered and guest scorers exist
  - guest badge remains visible
  - matchSidePlayer scorers remain excluded through resolver behavior

## Manual QA Checklist

- Open a tournament with no scored goal events and verify the top scorers section does not show `شارك الهدافين`.
- Open a tournament with goal MatchEvents and verify `شارك الهدافين` appears.
- Tap `شارك الهدافين` on a device/emulator and verify the native share sheet opens with an image.
- Verify the generated image shows "هدافو البطولة", tournament name, up to 5 scorers, goal labels, guest badge, and "الحريف" branding.
- Verify share failure shows safe Arabic feedback and does not crash.

## Commands Run

- `flutter pub get`
  - Result: passed.
- `dart format lib/features/tournament/views/tournament_detail_screen.dart lib/features/shareables/controllers/top_scorers_share_controller.dart lib/features/shareables/models/top_scorers_share_data.dart lib/features/shareables/widgets/top_scorers_share_card.dart test/features/shareables/top_scorers_share_card_test.dart test/features/tournament/tournament_operations_dashboard_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/features/shareables/top_scorers_share_card_test.dart test/features/tournament/tournament_operations_dashboard_test.dart`
  - Result: passed, `+19`.
- `flutter test`
  - Result: passed, `+298`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes.
- Tournament Detail exposes the share CTA only when top scorers exist.
- The share card includes tournament name, up to 5 scorers, Arabic goal labels, guest badges, and El7reef branding.
- Existing V1 product boundaries remain intact.

## Risks / Follow-ups

- Actual platform share sheet behavior should still be manually verified on Android/iOS because widget tests do not exercise native sharing.
- Future share-card tasks can add result/MVP/player/top-scorers variations into a more unified share card gallery if the product direction calls for it.
