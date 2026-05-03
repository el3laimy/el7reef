# Sprint 1 / Task 4: MVP Validation Report

## Summary of Change

- Updated `MatchSettlementService.submitScore` MVP validation to use `OfficialMatchRosterService.loadParticipantRoster`.
- Preserved `loadRegisteredRoster` for registered-only detailed stats, fan-voting eligibility, and approval/rating behavior.
- Accepted MVP IDs for registered players, guest players, and temporary match-side players when they belong to the full match participant roster.
- Continued rejecting MVP IDs outside the full participant roster.

## Files Changed

- `lib/core/services/match_settlement_service.dart`
- `test/core/services/match_settlement_service_test.dart`
- `docs/Sprint1_Task4_MVP_Validation_Report.md`

## Validation Behavior

- `mvpPlayerId == null` remains unchanged.
- Non-empty `mvpPlayerId` is normalized and validated against full participant roster IDs.
- Registered player MVPs continue to be accepted.
- Guest player MVPs are accepted when present in the full participant roster.
- Temporary match-side player MVPs are accepted when present in the full participant roster.
- Invalid MVP IDs throw `StateError` and do not submit the score.
- `approveScore` remains registered-player-only for rating and aggregate stat updates.

## What Was Intentionally Not Touched

- ScoreSubmit UI and controller behavior.
- MatchEvent writing or dual-write behavior.
- PlayerMatchStats model or schema.
- GuestClaimService.
- Firestore rules and indexes.
- Fantasy, leaderboards, and user-facing UI.
- Registered-only rating behavior in `approveScore`.

## Tests Added / Updated

- Added `submitScore accepts registered MVP as before`.
- Added `submitScore accepts guest player MVP from full roster`.
- Added `submitScore accepts temporary match-side player MVP`.
- Added `submitScore rejects MVP id outside the full participant roster`.
- Added `approveScore with guest MVP keeps registered-only rating behavior`.

## Collision Limitation

- `Match.mvpPlayerId` is currently a string only, so validation checks whether any full participant has `participant.id == mvpPlayerId`.
- This cannot distinguish collisions where a registered player, guest player, and match-side player share the same raw ID.
- The future MatchEvent dual-write should carry the full `ParticipantRef` (`kind + id + displayName + linkedPlayerId`) to remove this ambiguity.

## Commands Run

- `flutter pub get`
  - Result: passed.
  - Note: pub emitted existing advisory decode warnings for hosted advisories, then completed successfully.
- `dart format lib/core/services/match_settlement_service.dart test/core/services/match_settlement_service_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/core/services/match_settlement_service_test.dart`
  - Result: passed, `+9`.
- `flutter test`
  - Result: passed, `+264`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes with `+264`.
- Registered MVP still works.
- Guest MVP is accepted.
- Temporary match-side MVP is accepted.
- Invalid MVP is rejected.
- No UI changes and no MatchEvent writing were introduced.

## Risks / Follow-Ups

- Replace string-only MVP storage with full `ParticipantRef` through MatchEvent dual-write in a later task.
- ScoreSubmit can later use the full participant roster loader for MVP selection UI without changing this validation contract.
