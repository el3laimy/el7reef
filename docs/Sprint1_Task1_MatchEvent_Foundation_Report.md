# Sprint 1 / Task 1 - MatchEvent Foundation Report

## Summary of implementation
- Added a lightweight Pride Data Layer foundation for V1 match events.
- Added `ParticipantRef` for registered players, guest players, and temporary match-side players.
- Added `MatchEvent` for goal and MVP events with active/voided status.
- Added Firestore serialization models for `ParticipantRef` and `MatchEvent`.
- Added a `MatchEventRepository` contract and Firestore implementation backed by the new `matchEvents` collection path.
- Added `MatchEventService` with basic validation and methods to record goals, record multiple goals, record MVP, void events, and read match/tournament event data.
- Added focused unit tests for model round-trips and service/repository behavior with fake Firestore.

## Files added
- `lib/domain/entities/participant_ref.dart`
- `lib/data/models/participant_ref_model.dart`
- `lib/domain/entities/match_event.dart`
- `lib/data/models/match_event_model.dart`
- `lib/domain/repositories/match_event_repository.dart`
- `lib/data/repositories/match_event_repository_impl.dart`
- `lib/core/services/match_event_service.dart`
- `test/data/models/participant_ref_model_test.dart`
- `test/data/models/match_event_model_test.dart`
- `test/core/services/match_event_service_test.dart`
- `docs/Sprint1_Task1_MatchEvent_Foundation_Report.md`

## Files modified
- `lib/core/constants/firebase_paths.dart`

## What was intentionally not touched
- No UI changes.
- No `ScoreSubmit` changes.
- No `MatchSettlementService` changes.
- No `rating_engine` changes.
- No fantasy settlement changes.
- No `PlayerMatchStats` replacement or refactor.
- No assists behavior.
- No own-goal behavior.
- No Firestore security rules changes.
- No Firestore schema migration beyond adding `FirebasePaths.matchEvents`.

## Tests added
- `ParticipantRefModel` round-trip and fallback parsing tests.
- `MatchEventModel` round-trip and status/type parsing tests.
- `MatchEventService` tests for:
  - Recording goal and MVP events for registered/guest participants.
  - Recording multiple goals.
  - Reading match events and tournament goal events.
  - Reading the match MVP event.
  - Voiding events and excluding voided events from active queries.
  - Basic field validation.

## Commands run
- `flutter pub get`
  - Result: passed.
  - Note: pub printed non-blocking advisory decoding warnings (`advisoriesUpdated must be a String`).
- `dart format lib/domain/entities/participant_ref.dart lib/data/models/participant_ref_model.dart lib/domain/entities/match_event.dart lib/data/models/match_event_model.dart lib/domain/repositories/match_event_repository.dart lib/data/repositories/match_event_repository_impl.dart lib/core/services/match_event_service.dart test/data/models/participant_ref_model_test.dart test/data/models/match_event_model_test.dart test/core/services/match_event_service_test.dart`
  - Result: passed.
- `flutter test test/data/models/participant_ref_model_test.dart test/data/models/match_event_model_test.dart test/core/services/match_event_service_test.dart`
  - Result: passed.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test`
  - Result: passed, `+248`.

## Final result
- `dart analyze lib/` passes.
- `flutter test` passes.
- Existing tests remain green.
- MatchEvent Tier 1 foundation is implemented without UI, rating, fantasy, ScoreSubmit, or settlement changes.

## Risks or follow-up needed
- Firestore indexes and security rules for `matchEvents` are still needed in the dedicated rules/index task.
- Later integration work must connect ScoreSubmit and tournament leaderboards to `MatchEventService`.
- Later claim flow work should relink guest-player match events by updating `actor.linkedPlayerId` after profile claim.
