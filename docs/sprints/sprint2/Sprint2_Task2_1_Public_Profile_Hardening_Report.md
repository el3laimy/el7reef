# Sprint 2 / Task 2.1: Public Player Profile Hardening

## Index Verification Result

Verified `firestore.indexes.json` includes the required `matchEvents` composite index:

- `actor.kind ASC`
- `actor.id ASC`
- `status ASC`

The index was already present, so no index patch was needed for this task.

## Whether `firestore.indexes.json` Changed

No Task 2.1 change was made to `firestore.indexes.json`.

## Tests Added

Added focused coverage in `test/features/profile/public_player_profile_test.dart`:

- Guest profile with `linkedPlayerId` shows:
  - `هذا الضيف مربوط ببروفايل لاعب مسجل.`
- Resolver falls back to `MatchEvent.actor.displayName` when the registered player document is missing but events exist.
- Resolver falls back to `MatchEvent.actor.displayName` when the guest player document is missing but events exist.
- Guest fallback preserves `actor.linkedPlayerId` from the event.
- Resolver returns `null` safely when no source document and no MatchEvents exist.

## Whether Production Code Changed

No production code changed.

## Files Changed

- `test/features/profile/public_player_profile_test.dart`
- `docs/Sprint2_Task2_1_Public_Profile_Hardening_Report.md`

## Commands Run

- `flutter pub get`
  - Passed.
- `dart format test/features/profile/public_player_profile_test.dart`
  - Passed.
- `dart analyze lib/`
  - Passed: `No issues found!`
- `flutter test test/features/profile/public_player_profile_test.dart`
  - Passed: `+8`.
- `flutter test`
  - Passed: `+321`.

## Final Result

- Required actor-based MatchEvent index exists.
- Linked guest info panel is widget-tested.
- Event actor display-name fallback is resolver-tested.
- Missing document plus no events returns a safe null state.
- `dart analyze lib/` passes.
- `flutter test` passes.

## Remaining Risks / Follow-ups

- The verified Firestore composite index still needs to be deployed with Firebase config before production traffic relies on actor-based profile lookups.
- Public profile links from share cards and leaderboard rows remain intentionally deferred to a later task.
