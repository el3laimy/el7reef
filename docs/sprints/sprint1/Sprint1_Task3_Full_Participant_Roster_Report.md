# Sprint 1 / Task 3: Full Participant Roster Loader Report

## Summary of Implementation

- Added a full match participant roster loader alongside the existing registered-only roster path.
- Added a side-based `MatchParticipantRoster` value object with side A, side B, flattened participants, and side membership helpers.
- Implemented `ParticipantRef` mapping for registered players, guest players, and temporary match-side players.
- Preserved the existing `loadRegisteredRoster` behavior for settlement, rating, and fan-voting callers.

## Files Added

- `lib/domain/entities/match_participant_roster.dart`
- `test/core/services/official_match_roster_service_test.dart`
- `docs/Sprint1_Task3_Full_Participant_Roster_Report.md`

## Files Modified

- `lib/core/services/official_match_roster_service.dart`

## Method / Service API Added

- `OfficialMatchRosterService.loadParticipantRoster({required String matchId, Match? match})`
  - Returns `MatchParticipantRoster`.
  - Loads side A participants and side B participants separately.
  - Provides `allParticipants`, `participantsForSide`, `isParticipantOnSide`, and `sideKeyFor` helpers through the roster value object.

## Mapping Rules Implemented

- Registered player:
  - `kind = ParticipantRefKind.player`
  - `id = Player.id`
  - `displayName = Player.name`
  - `linkedPlayerId = null`
- Guest player:
  - `kind = ParticipantRefKind.guestPlayer`
  - `id = GuestPlayer.id`
  - `displayName = GuestPlayer.displayName`
  - `linkedPlayerId = GuestPlayer.linkedPlayerId`
- Temporary match-side player:
  - `kind = ParticipantRefKind.matchSidePlayer`
  - `id = MatchSidePlayer.id`
  - `displayName = MatchSidePlayer.displayName`
  - `linkedPlayerId = null`
- Registered match-side player:
  - If `MatchSidePlayer.playerId` is present, maps as `ParticipantRefKind.player`.
- De-duplication:
  - De-dupes within each side by `kind + id`.
  - Preserves insertion order from snapshots, fallback match arrays, official roster records, and match-side players.

## What Was Intentionally Not Touched

- ScoreSubmit UI and controller behavior.
- MatchSettlementService.
- GuestClaimService.
- MatchEventService behavior.
- Firestore rules and indexes.
- Rating, fantasy, and PlayerMatchStats.
- Leaderboards and user-facing UI.
- Existing registered-player-only `loadRegisteredRoster` semantics.

## Tests Added

- Registered players appear as `ParticipantRefKind.player`.
- Guest players appear as `ParticipantRefKind.guestPlayer` with `linkedPlayerId` preserved.
- Temporary match-side players appear as `ParticipantRefKind.matchSidePlayer`.
- Registered match-side players are mapped to `ParticipantRefKind.player` when `playerId` exists.
- Participants are de-duplicated by `kind + id` within a side.
- Empty rosters return empty side lists.
- Side membership helper verifies side A and side B membership.

## Commands Run

- `flutter pub get`
  - Result: passed.
  - Note: pub emitted existing advisory decode warnings for hosted advisories, then completed successfully.
- `dart format lib/domain/entities/match_participant_roster.dart lib/core/services/official_match_roster_service.dart test/core/services/official_match_roster_service_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test test/core/services/official_match_roster_service_test.dart`
  - Result: passed, `+7`.
- `flutter test`
  - Result: passed, `+257`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes with `+257`.
- Existing registered-only roster behavior remains intact.
- No UI, ScoreSubmit, MatchSettlementService, rating, fantasy, PlayerMatchStats, Firestore rules, or leaderboard changes were made.

## Risks / Follow-Ups

- The loader is intentionally read-only and does not enforce MatchEvent validation yet; ScoreSubmit and MatchEvent integration can use the side helper in a later task.
- Guest team rosters are supported through tournament participant source data when present; legacy matches without participant source metadata rely on existing match arrays, memberships, and match-side data.
