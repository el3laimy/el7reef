# Wave 2 / Task 9.2: Assistant Rules for Matchday/Results Actions

## Summary

Added Firestore rules and emulator coverage so V1 assistants with `canRecordGoalsAndMvp` can create valid goal/MVP `matchEvents` for their own tournament matches.

This task is rules-only. No Flutter production code, UI, routes, service guards, `MatchEventService`, or `ScoreSubmitController` were changed.

Match updates for `canStartMatch`, `canSubmitScore`, `canApproveScore`, and `canDeclareForfeit` remain denied and are documented as deferred because the match schema needs field-specific transition rules before assistant writes can be safely opened.

## Files Changed

- `firestore.rules`
- `test/rules/tournament_assistant_permissions.rules.test.js`
- `docs/Wave2_Task9_2_Assistant_Matchday_Results_Rules_Report.md`

## Helper Functions Added

Added assistant permission helpers in `firestore.rules`:

- `isAllowedAssistantPermissionName(permissionName)`
- `hasActiveTournamentAssistantPermission(tournamentId, permissionName)`

The helper checks:

- user is authenticated
- `permissionName` is one of the six V1 permission keys
- canonical assistant doc exists at `tournaments/{tournamentId}/assistants/{request.auth.uid}`
- assistant doc status is `active`
- assistant doc `permissions` is a map
- `permissions[permissionName] == true`

MatchEvent authorization was split into:

- `canOrganizerCreateMatchEventForMatch(data)`
- `canAssistantCreateMatchEventForMatch(data)`
- `matchEventTournamentMatchesMatch(data)`

## Active Assistant Permissions In Rules

Active now:

- `canRecordGoalsAndMvp`: authorizes creating valid `goal` and `mvp` `matchEvents` for the assistant's own tournament match.

Still not active for writes:

- `canViewMatchday`
- `canStartMatch`
- `canSubmitScore`
- `canApproveScore`
- `canDeclareForfeit`

## Match Updates

Assistant match updates were deferred.

Reason:

The existing match write rule is broad and organizer-only. Safely opening assistant match updates requires exact field-level rules for start, score submission, approval/settlement, and forfeits across the real match schema. Opening broad assistant updates would risk structural mutation of tournament fixtures, teams, scores, scheduling, or bracket references.

Rules tests now explicitly prove assistant match updates remain denied even when the assistant has:

- `canStartMatch`
- `canSubmitScore`
- `canApproveScore`
- `canDeclareForfeit`

Organizer match update behavior remains preserved.

## MatchEvent Assistant Write Behavior

Assistants can create MatchEvents only when all conditions pass:

- match exists
- match has a `tournamentId`
- assistant has active `canRecordGoalsAndMvp` for that tournament
- `event.matchId` references that match
- `event.tournamentId` equals the match's tournament id
- `createdBy == request.auth.uid`
- existing MatchEvent shape validation passes
- `eventType` is `goal` or `mvp`

Denied cases covered:

- assistant without `canRecordGoalsAndMvp`
- revoked assistant
- assistant for tournament A writing to tournament B
- `createdBy` spoofing
- event/match tournament mismatch
- nonexistent match
- unsupported event type
- random user writes

Organizer goal/MVP creation remains allowed by the existing organizer path.

## Structural Denial Behavior

Assistants remain denied for structural tournament writes.

Covered in tests:

- `tournamentParticipants`
- `tournamentGroups`
- `knockoutBrackets`
- `knockoutTies`
- `matchSides`
- `matchSidePlayers`
- tournament registration approval
- tournament settings update
- assistant permission doc update

No assistant access was opened for fixture generation, fixture publishing, scheduling, participants, groups, standings snapshots, brackets, ties, registrations, tournament settings, or assistant management.

## Tests Added/Updated

Updated `test/rules/tournament_assistant_permissions.rules.test.js` with tests for:

- assistant with `canRecordGoalsAndMvp` can create goal event
- assistant with `canRecordGoalsAndMvp` can create MVP event
- assistant without `canRecordGoalsAndMvp` cannot create goal/MVP
- revoked assistant cannot create goal/MVP
- assistant for tournament A cannot create event for tournament B
- `createdBy` spoofing denied
- event tournamentId mismatch denied
- nonexistent match denied
- unsupported event type denied
- organizer still can create goal/MVP
- random user still cannot create goal/MVP
- assistant match updates remain denied for start, score submission, approval, and forfeit permissions
- organizer match update remains allowed
- assistant structural writes remain denied

Existing rules tests for claim codes, tournament ownership, tournament registrations, MatchEvent organizer behavior, operation collections, and assistant permission documents continued passing in the compatible emulator run.

## Commands Run

- `npm ci`: completed with Node engine warnings because several Firebase packages and `firebase-tools@15.13.0` require Node 20+, while current Node is `v18.19.1`; npm also reported 5 vulnerabilities.
- `npm run test:rules:emulator`: blocked before test execution because `firebase-tools@15.13.0` requires Node `>=20.0.0 || >=22.0.0 || >=24.0.0`.
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools@13.35.1 --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`: passed, `112 passing`.
- `dart analyze lib/`: passed.

## Final Result

Task 9.2 is complete.

Assistant MatchEvent writes are now narrowly enabled for `canRecordGoalsAndMvp` only. Assistant match updates and all structural tournament writes remain denied. Existing organizer behavior is preserved.

## Remaining Risks

- service guards are still organizer-only
- UI/route guards are still organizer-only
- assistant matchday UI is not implemented
- match update permissions are deferred until schema-specific transition rules are defined
- `npm run test:rules:emulator` still requires Node 20+ because the installed Firebase CLI is incompatible with Node 18
