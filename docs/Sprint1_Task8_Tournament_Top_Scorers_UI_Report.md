# Sprint 1 / Task 8: Tournament Top Scorers UI Slice

## Summary
- Added a read-only `هدافو البطولة` section to the Tournament Detail screen.
- The section loads top scorers from `TournamentTopScorersResolver`.
- Registered scorers render normally.
- Guest scorers render with a `ضيف` badge.
- Match-side-only scorers remain excluded through the resolver.

## Files Changed
- `lib/features/tournament/controllers/tournament_detail_controller.dart`
- `lib/features/tournament/views/tournament_detail_screen.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `docs/Sprint1_Task8_Tournament_Top_Scorers_UI_Report.md`

## Controller / State Added
- Added `TournamentTopScorersResolver` dependency to `TournamentDetailController`.
- Added:
  - `topScorers`
  - `isLoadingTopScorers`
  - `topScorersErrorMessage`
  - `loadTopScorers()`
- Top scorers load when tournament details load, with a limit of 5.

## UI States Implemented
- Loading: small inline progress indicator inside the section.
- Empty: Arabic empty state:
  - `لم يتم تسجيل هدافين بعد`
  - `ستظهر هنا أهداف اللاعبين بعد تسجيل نتائج المباريات.`
- Data:
  - rank number
  - scorer display name
  - goals count with `أهداف`
  - guest badge `ضيف`
- Error:
  - safe Arabic copy: `تعذر تحميل هدافي البطولة الآن.`
  - raw exceptions are not shown in the UI.

## What Was Intentionally Not Touched
- No Tournament Detail redesign.
- No navigation changes.
- No player profile navigation.
- No share cards.
- No ScoreSubmit changes.
- No MatchSettlementService changes.
- No PlayerMatchStats changes.
- No rating, fantasy, Firestore rules/indexes, or denormalized snapshot changes.

## Tests Added / Updated
- Updated tournament detail widget coverage to assert the top scorers section and empty Arabic state.
- Added widget coverage for registered and guest top scorers.
- Added assertion that guest scorers show the `ضيف` badge.
- Seeded a `matchSidePlayer` scorer and asserted it does not render.
- Added safe error-state coverage for resolver failure.

## Manual QA Checklist
- Open a tournament detail page with no goal events and confirm `هدافو البطولة` shows the empty Arabic copy.
- Submit a result with registered player goal drafts, then open tournament detail and confirm scorer name and goal count appear.
- Submit a result with guest player goal drafts, then open tournament detail and confirm the guest scorer appears with `ضيف`.
- Confirm temporary match-side scorers do not appear in tournament top scorers.
- Simulate poor network / resolver failure and confirm the section shows safe Arabic error copy without breaking the page.
- Confirm no share button or player-profile navigation was added.

## Commands Run
- `flutter pub get`
  - Passed.
  - Pub printed existing advisory decode warnings for some packages, but dependencies resolved successfully.
- `dart format lib/features/tournament/controllers/tournament_detail_controller.dart lib/features/tournament/views/tournament_detail_screen.dart test/features/tournament/tournament_operations_dashboard_test.dart`
  - Passed.
- `dart analyze lib/`
  - Passed: no issues found.
- `flutter test test/features/tournament/tournament_operations_dashboard_test.dart`
  - Passed: `+16`.
- `flutter test`
  - Passed: `+295`.

## Final Result
- `dart analyze lib/` passes.
- `flutter test` passes.
- Tournament Detail shows `هدافو البطولة`.
- Registered scorers display.
- Guest scorers display with `ضيف`.
- Empty and error states are safe Arabic UI.
- No settlement/rating/fantasy/PlayerMatchStats changes were made.

## Risks / Follow-Ups
- This is a compact V1 slice with no profile navigation or share-card CTA yet.
- Future share-card work can reuse the displayed top scorer data once pride-card flows are introduced.
