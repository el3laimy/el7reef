# P0 Task 4 - Tournament Operation Collections Rules Report

## Summary

This task resolves the remaining Firestore rules ambiguity for tournament operation collections that previously fell through to catch-all deny.

Decision: all seven audited collections are V1 organizer-client-writable, with strict ownership and schema checks. This matches the Master Blueprint direction that a single organizer should be able to run a small tournament from the app without Cloud Functions.

Non-organizers cannot create, update, or delete any of these operation documents. Organizer writes are scoped to owned tournaments or owned matches, with immutable identity references enforced on update.

No Flutter production code, UI, services, controllers, claim-code logic, or lifecycle logic was changed.

## Files Changed

- `firestore.rules`
- `test/rules/tournament_permissions.rules.test.js`
- `docs/P0_Task4_Tournament_Operation_Collections_Rules_Report.md`

## Decision Table

| Collection | Decision | Why | Service path using it | Rules behavior | Tests added |
| --- | --- | --- | --- | --- | --- |
| `tournamentParticipants` | Organizer-client-writable | Needed for approved teams, manual/guest teams, replacement, withdrawal, seed/order updates, and tournament finalization. | `TournamentParticipantService`, `TournamentLifecycleService` | Create/update/delete allowed only for organizer of `tournamentId`. Source refs and `createdAt` are immutable on update. | Organizer create/update/delete succeeds; non-organizer create/update fails; other organizer tournament create fails; immutable source update fails. |
| `tournamentGroups` | Organizer-client-writable | Group generation/regeneration is exposed through current organizer flow. | `TournamentLifecycleService`, `TournamentFixtureService`, group repositories | Create/update/delete allowed only for organizer of `tournamentId`. `tournamentId`, `groupStageId`, and `createdAt` are immutable. | Organizer create/update/delete succeeds; non-organizer create/update fails; other organizer tournament create fails; immutable group stage update fails. |
| `groupStandingSnapshots` | Organizer-client-writable | Current client services calculate and persist standings snapshots. | `TournamentLifecycleService`, `TournamentFixtureService`, standing repository | Create/update/delete allowed only for organizer of `tournamentId`. `tournamentId`, `groupStageId`, `groupId`, and `createdAt` are immutable. | Organizer create/update/delete succeeds; non-organizer create/update fails; other organizer tournament create fails; immutable group ref update fails. |
| `knockoutBrackets` | Organizer-client-writable | Knockout flow is currently present in lifecycle services and needs client persistence for V1 if exposed. | `TournamentLifecycleService`, knockout bracket repository | Create/update allowed only for organizer of `tournamentId`. `tournamentId` and `createdAt` are immutable. Delete denied. | Organizer create/update succeeds; non-organizer create/update fails; other organizer tournament create fails; immutable tournament update fails; delete denied. |
| `knockoutTies` | Organizer-client-writable | Knockout ties are generated and progressed by client lifecycle services. | `TournamentLifecycleService`, knockout tie repository | Create/update allowed only for organizer of `tournamentId`. `tournamentId`, `bracketId`, and `createdAt` are immutable. Delete denied. | Organizer create/update succeeds; non-organizer create/update fails; other organizer tournament create fails; immutable bracket update fails; delete denied. |
| `matchSides` | Organizer-client-writable | Match-side setup is required for guest/manual sides and score roster flows. | `MatchSideRepositoryImpl` | Create/update allowed only for organizer of the referenced `matches/{matchId}`. `matchId`, `sideKey`, and `createdAt` are immutable. Delete denied. | Organizer create/update succeeds; non-organizer create/update fails; other organizer match create fails; immutable match ref update fails; delete denied. |
| `matchSidePlayers` | Organizer-client-writable | Temporary and registered side-player rows are needed for guest-first scorer/MVP flows. | `MatchSidePlayerRepositoryImpl` | Create/update/delete allowed only for organizer of the referenced `matches/{matchId}`. `matchId`, `sideKey`, `sideId`, `kind`, `addedBy`, and `createdAt` are immutable. | Organizer create/update/delete succeeds; non-organizer create/update fails; other organizer match create fails; immutable match ref update fails. |

## Firestore Rules Changes

Added explicit rules blocks for:

- `tournamentParticipants`
- `tournamentGroups`
- `groupStandingSnapshots`
- `knockoutBrackets`
- `knockoutTies`
- `matchSides`
- `matchSidePlayers`

Added helper validation for:

- nullable optional primitive fields
- organizer ownership through `tournamentId`
- match ownership through referenced `matchId`
- immutable tournament and match operation references
- collection-specific schema checks

Tournament-scoped collections require:

- authenticated user
- valid `tournamentId`
- existing tournament
- `tournaments/{tournamentId}.organizerId == request.auth.uid`
- minimally valid schema
- immutable identity references on update

Match-scoped collections require:

- authenticated user
- valid `matchId`
- existing match
- `matches/{matchId}.organizerId == request.auth.uid`
- minimally valid schema
- immutable match/side identity references on update

Delete behavior:

- Allowed for `tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, and `matchSidePlayers` because current services have legitimate delete paths.
- Denied for `knockoutBrackets`, `knockoutTies`, and `matchSides` because these are structural operation records and no safe V1 delete requirement was established in this task.

## Tests Added

Updated `test/rules/tournament_permissions.rules.test.js` with shared fixture builders for all seven operation collections.

For each collection, tests now cover:

- organizer can create a valid document for own tournament/match
- non-organizer cannot create
- organizer cannot create for another organizer's tournament/match
- organizer can make a safe update
- non-organizer cannot update
- immutable tournament/match/source references cannot be changed
- delete policy is enforced

The existing suites still cover:

- claim-code rules
- tournament ownership
- match ownership
- tournament registration hardening
- MatchEvent hardening

## Final Test Result

Rules emulator:

- `80 passing`
- `0 failing`
- `0 pending`

The PERMISSION_DENIED warnings printed by the emulator are expected from negative `assertFails` cases.

## Commands Run

`npm ci`

- Result: passed.
- Output summary: `added 797 packages in 2m`.

`npm run test:rules:emulator`

- First sandbox attempt failed because the Firestore emulator could not bind local ports under sandbox restrictions.
- Re-run with elevated local emulator permissions passed.
- Result: `80 passing`.

`dart analyze lib/`

- Result: passed.
- Output: `No issues found!`

## Production Mismatches Resolved

The previous catch-all deny behavior for the seven operation collections is replaced with explicit organizer-only rules. Current client-side organizer services can now write the collections they need without opening those writes to unrelated authenticated users.

## Remaining Risks and Follow-ups

- Service-layer guards for all sensitive tournament operations are still unresolved and should be audited next.
- UI may still expose group/knockout paths that product later decides to defer; if deferred, those routes should be hidden or gated in a later UI task.
- Guest-first score UI remains unresolved.
- Scheduling conflict rules remain unresolved.
- `TournamentFixtureService.regenerateGroupStage` also deletes `matches`; existing `matches` rules still deny match deletion. That mismatch is outside this task's listed operation collections and should be handled in a scheduling/fixture lifecycle rules task.

## Recommended Next Task

Proceed with service/controller guard hardening for organizer operations, then fixture lifecycle and scheduling conflict rules. This should come before more UI work, because Firestore rules now protect the operation collections but service-level intent checks still need to be made explicit.
