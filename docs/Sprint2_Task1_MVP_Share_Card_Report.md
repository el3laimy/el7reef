# Sprint 2 / Task 1: MVP Share Card Report

## Summary of Implementation

- Added a shareable Arabic-first `نجم المباراة` MVP card.
- Added a compact `شارك نجم المباراة` CTA to the existing match result lineup/result view.
- Reused the existing `ShareCardCaptureService` image capture and native share path.
- Loaded MVP share context defensively from the result screen controller.
- Preserved existing score submission, settlement, rating, fantasy, PlayerMatchStats, Firestore rules, and indexes.

## Files Added

- `lib/features/shareables/models/mvp_share_data.dart`
- `lib/features/shareables/controllers/mvp_share_controller.dart`
- `lib/features/shareables/widgets/mvp_share_card.dart`
- `test/features/shareables/mvp_share_card_test.dart`
- `docs/Sprint2_Task1_MVP_Share_Card_Report.md`

## Files Changed

- `lib/features/lineup/controllers/match_result_lineup_controller.dart`
- `lib/features/lineup/bindings/lineup_binding.dart`
- `lib/features/lineup/views/match_result_lineup_screen.dart`

## Data Source Strategy

- Preferred source: active MVP `MatchEvent` loaded with `MatchEventService.getMvpEvent(matchId)`.
- Fallback source: `Match.mvpPlayerId` when the MVP event is missing.
- Fallback display name can be resolved from lineup snapshots or friendly match-side players when available.
- If no MVP event and no `Match.mvpPlayerId` exist, no MVP share CTA is shown.
- Tournament name is loaded from `TournamentRepositoryImpl` when available; otherwise the card safely falls back to `بطولة الحريف`.

## Share Card Content

- Title: `نجم المباراة`
- MVP display name
- Guest badge: `ضيف` for guest MVPs
- Match score when available
- MVP side/team label when available
- Tournament name or safe fallback
- El7reef branding: `الحريف`
- Arabic RTL layout with a pride-focused visual style consistent with existing share cards

## Share CTA Placement

- Added to `MatchResultLineupScreen`, directly below the existing `شارك النتيجة` result share CTA.
- The CTA text is `شارك نجم المباراة`.
- It appears only when MVP data exists via MVP MatchEvent or `Match.mvpPlayerId`.
- No new route or preview screen was added.

## Error Handling

- MVP event and tournament name loading are best-effort and do not break the result screen.
- If no MVP is available, sharing is blocked with safe Arabic feedback.
- If overlay setup or image capture/share fails, the user sees safe Arabic feedback.
- Overlay cleanup is handled in `finally`.
- Raw exceptions are not shown from the share failure path.

## Intentionally Not Touched

- Match settlement logic.
- ScoreSubmit MVP/goal write behavior.
- PlayerMatchStats.
- Rating and fantasy systems.
- Firestore rules and indexes.
- Public player profile navigation.
- Result screen navigation or route structure.
- Requirement status of MVP selection.

## Tests Added / Updated

- Added `test/features/shareables/mvp_share_card_test.dart`.
- Covered MVP MatchEvent mapping into share data.
- Covered guest MVP badge mapping.
- Covered missing tournament name fallback.
- Covered `Match.mvpPlayerId` fallback data.
- Covered share card widget rendering for title, MVP name, score, branding, side label, and guest badge.

## Manual QA Checklist

- Submit or open a result with an MVP MatchEvent and verify `شارك نجم المباراة` appears.
- Open a result without an MVP and verify the MVP share CTA is hidden.
- Tap `شارك نجم المباراة` on a device/emulator and verify the native share sheet opens with an image.
- Verify the generated card includes `نجم المباراة`, MVP name, score, side label, tournament/fallback text, guest badge when applicable, and `الحريف`.
- Verify share/capture failure shows safe Arabic feedback and does not crash.

## Commands Run

- `flutter pub get`
  - Result: passed.
- `dart format lib/features/shareables/models/mvp_share_data.dart lib/features/shareables/controllers/mvp_share_controller.dart lib/features/shareables/widgets/mvp_share_card.dart lib/features/lineup/controllers/match_result_lineup_controller.dart lib/features/lineup/bindings/lineup_binding.dart lib/features/lineup/views/match_result_lineup_screen.dart test/features/shareables/mvp_share_card_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/features/shareables/mvp_share_card_test.dart`
  - Result: passed, `+4`.
- `flutter test`
  - Result: passed, `+303`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes.
- MVP share card includes `نجم المباراة`, MVP name, branding, and score/context where available.
- Guest MVPs are marked with `ضيف`.
- Existing share infrastructure is reused.
- No settlement, rating, fantasy, PlayerMatchStats, Firestore rules, or indexes were changed.

## Risks / Follow-ups

- Native share sheet behavior still needs manual verification on Android/iOS.
- The fallback path can only show a rich MVP name when lineup or match-side data can resolve `Match.mvpPlayerId`; future result snapshots could make this fallback richer.
