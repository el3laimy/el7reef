# P0 Task 2: Tournament Permissions Rules Emulator Tests

## Summary

Added Firestore rules emulator coverage for tournament ownership, match/fixture ownership, tournament registrations, MatchEvent writes, and tournament operation collections.

This task did not change Firestore rules or Flutter production code. The tests intentionally document current permission behavior, including unsafe behavior that must be fixed in the next rules-hardening task.

## Files Changed

- `test/rules/tournament_permissions.rules.test.js`
- `docs/P0_Task2_Tournament_Permissions_Rules_Emulator_Tests_Report.md`

No changes were made to:

- `firestore.rules`
- Flutter production code
- services/controllers
- UI
- score submit logic
- MatchEvent logic
- claim-code rules

## Rules Tests Added

### Tournament Ownership

- Organizer can create a tournament with `organizerId == request.auth.uid`.
- Authenticated user cannot create a tournament with another user's `organizerId`.
- Organizer can update own tournament.
- Non-organizer cannot update another user's tournament.
- Tournament delete is denied.

### Match / Fixture Ownership

- Organizer can create a match/fixture with `organizerId == request.auth.uid`.
- Authenticated user cannot create a match with another user's `organizerId`.
- Organizer can update own match fixture.
- Non-organizer cannot update another organizer's match.
- Match delete is denied.

### Tournament Registrations

- Team owner can submit a registration for their own team.
- Non-team-owner cannot submit registration for another team.
- Tournament organizer can approve a registration.
- Current unsafe behavior is documented: team owner can self-approve a registration by changing `status` to `approved`.

### MatchEvents

- Organizer can create a valid goal event fixture.
- `createdBy` spoofing is denied.
- Current unsafe behavior is documented:
  - random authenticated user can create a goal event in another organizer's tournament;
  - random authenticated user can create an MVP event in another organizer's tournament.

### Tournament Operation Collections

Write behavior was tested for:

- `tournamentParticipants`
- `tournamentGroups`
- `groupStandingSnapshots`
- `knockoutBrackets`
- `knockoutTies`
- `matchSides`
- `matchSidePlayers`

Current behavior:

- Non-organizer writes are denied for all listed collections.
- Organizer writes are also denied for all listed collections because there are no explicit collection rules and the catch-all deny applies.

## Which Tests Pass

`npm run test:rules:emulator` passed with:

- `39 passing`
- `3 pending`

Claim-code rules tests still pass.

The passing tests include both intended-secure expectations and explicit current-behavior documentation for known gaps.

## Expectations That Fail Against Current Rules

The following Master Blueprint expectations would fail if enabled as normal tests:

- Team owner must not self-approve a tournament registration.
- Random authenticated user must not create a goal event in another organizer's tournament.
- Random authenticated user must not create an MVP event in another organizer's tournament.

These are encoded in a clearly named skipped block:

- `known P0 tournament permission expectations that current rules fail`

They are skipped to keep the emulator suite runnable in CI while preserving the exact denied expectations for the rules-hardening task.

## P0 Gaps Discovered

### P0: Tournament Registration Self-Approval

Current `tournamentRegistrations.update` allows team/guest-team owners to update an existing registration if they own the source team and the `tournamentId` does not change.

Observed result:

- A team owner can change `status` from `pending` to `approved`.
- A team owner can write organizer-shaped fields like `reviewedBy` and `reviewedAt`.

Risk:

- A non-organizer can approve themselves into another organizer's tournament.
- This violates the Master Blueprint requirement that organizer-owned approval/rejection is organizer-only.

### P0: MatchEvents Forgery

Current `matchEvents.create` validates document shape and requires `createdBy == request.auth.uid`, but does not verify that the caller is the match/tournament organizer or otherwise authorized for that match.

Observed result:

- A random authenticated user can create `goal` events in another organizer's tournament.
- A random authenticated user can create `mvp` events in another organizer's tournament.
- `createdBy` spoofing is denied, but that is not enough because the attacker can use their own uid.

Risk:

- Forged goals/MVPs can contaminate standings, top scorers, share cards, and pride surfaces if downstream code trusts active MatchEvents.

## Production Mismatches Discovered

### Operation Collections Are Denied For Organizers

The following collections have no explicit rules and fall through to the catch-all deny:

- `tournamentParticipants`
- `tournamentGroups`
- `groupStandingSnapshots`
- `knockoutBrackets`
- `knockoutTies`
- `matchSides`
- `matchSidePlayers`

Observed result:

- Non-organizer writes are denied, which is correct.
- Organizer writes are also denied.

Risk classification:

- **P1 mismatch** if production client services are expected to write these documents directly.
- **Expected current deny** if these collections are intended to become backend-only/server-written.

This needs a product/architecture decision in the rules-hardening task: either add organizer-scoped client rules with strict schemas or move writes to trusted backend/service paths.

## Skipped Tests

Skipped tests:

- `team owner must not self-approve by changing status to approved`
- `random authenticated user must not create goal event in another organizer tournament`
- `random authenticated user must not create MVP event in another organizer tournament`

Why skipped:

- The current rules allow these actions.
- Leaving them enabled would fail the rules test command and make the test suite unusable as a baseline.
- Matching current-behavior tests are enabled and passing, so the gaps are still visible and verified.

## Commands Run

- `npm ci`
  - Result: passed.
- `npm run test:rules:emulator`
  - First sandboxed run failed because the emulator could not bind local ports.
  - Reran with local emulator permissions.
  - Result: passed with `39 passing`, `3 pending`.
- `dart analyze lib/`
  - Result: passed with no issues.

`flutter test` was not run because this task did not change Flutter production code or Flutter tests.

## Final Result

Acceptance criteria are met:

- Tournament rules emulator test file added.
- Claim-code rules tests still pass.
- Tournament permission expectations are encoded.
- Known current-rule failures are explicitly skipped and documented.
- P0 Firestore rules gaps are identified.
- No production code or Firestore rules were changed.

## Recommended Next Task

Next task should be **Firestore rules hardening**, not UI work.

Recommended hardening order:

1. **P0:** Lock `tournamentRegistrations.update` so team/guest-team owners can only edit submitter-owned fields while pending; approval/rejection fields and status transitions must be organizer-only.
2. **P0:** Lock `matchEvents.create` to organizer/service-authorized match contexts, verify match/tournament ownership, and deny forged tournament/match references.
3. **P1:** Decide whether tournament operation collections are organizer-client-writable or backend-only, then add explicit rules/tests for the chosen model.
4. **P1:** Add immutable-field checks for organizer-owned tournament/match documents, including `organizerId`, `tournamentId`, and ownership-sensitive references.
