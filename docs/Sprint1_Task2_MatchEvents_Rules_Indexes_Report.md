# Sprint 1 / Task 2: MatchEvents Firestore Rules & Indexes Report

## Summary of Changes

- Added V1 Firestore security rules for the top-level `matchEvents` collection.
- Added validation helpers for `MatchEvent` creation payloads and embedded `actor` participant references.
- Restricted updates to creator-only voiding by changing `status` from `active` to `voided`.
- Disallowed deletes for `matchEvents`; voiding is the supported lifecycle path.
- Added the required composite indexes for match-level and tournament-level MatchEvent queries.

## Files Changed

- `firestore.rules`
- `firestore.indexes.json`
- `docs/Sprint1_Task2_MatchEvents_Rules_Indexes_Report.md`

## Rules Added

- Authenticated users can read `matchEvents`.
- Anonymous users cannot read, create, update, or delete `matchEvents`.
- Authenticated users can create `matchEvents` only when:
  - `createdBy == request.auth.uid`
  - `matchId` is a string
  - `eventType` is `goal` or `mvp`
  - `sideKey` is `A` or `B`
  - `actor` is a map
  - `actor.kind` is `player`, `guestPlayer`, or `matchSidePlayer`
  - `actor.id` is a non-empty string
  - `actor.displayName` is a non-empty string
  - `status == active`
- Updates are limited to:
  - authenticated users
  - the original `createdBy`
  - `status` changing from `active` to `voided`
  - no other field changes
- Deletes are disallowed.

## Indexes Added

Added `firestore.indexes.json` with composite indexes for:

- `matchEvents`: `matchId` ascending, `eventType` ascending, `status` ascending
- `matchEvents`: `tournamentId` ascending, `eventType` ascending, `status` ascending

## Assumptions

- `matchEvents` is a top-level collection, matching the existing MatchEvent repository foundation.
- V1 void permission is intentionally limited to the original creator because no safe organizer permission helper was required for this task.
- `firebase.json` was not modified because the project did not already contain a Firestore config section; the standard root `firestore.indexes.json` file was added instead.
- No Firestore rules test infrastructure was found in the project.

## Commands Run

- `firebase emulators:exec`: not run; no rules test infrastructure was present.
- `dart analyze lib/`
  - Result: passed, no issues found.
- `flutter test`
  - Result: passed, `+250`.

## Final Result

- `dart analyze lib/` passes.
- `flutter test` passes with `+250`.
- MatchEvent Firestore rules and indexes are in place.
- No Flutter production code, UI, ScoreSubmit, MatchSettlementService, GuestClaimService, rating, fantasy, or leaderboard code was changed.

## Remaining Risks

- MatchEvent rules were not exercised through Firebase emulator tests because the repository does not currently include a rules test harness.
- `createdAt` is validated as an integer timestamp to match the current lightweight data layer; future server timestamp behavior should be reviewed if the write path changes.
