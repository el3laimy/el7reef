# P0 Task 3: Firestore Rules Hardening for Tournament Registrations & MatchEvents

## Summary of Hardening

Closed the two P0 Firestore permission gaps found in Task 2:

- Team/guest-team owners can no longer approve or reject their own tournament registrations.
- Random authenticated users can no longer create forged goal/MVP MatchEvents in another organizer's match/tournament.

The three previously pending known-failure expectations are now normal passing emulator tests. No Flutter production code, UI, services, controllers, claim-code rules, or Cloud Functions were changed.

## Files Changed

- `firestore.rules`
- `test/rules/tournament_permissions.rules.test.js`
- `docs/P0_Task3_Firestore_Rules_Hardening_Tournament_Registrations_MatchEvents_Report.md`

## Registration Rules Before / After

### Before

`tournamentRegistrations.update` allowed an authenticated caller to update a registration when they were any of:

- tournament organizer;
- owner of the registered team;
- owner of the guest team.

The rule only required `tournamentId` to remain unchanged. This allowed team/guest-team owners to mutate organizer-owned decision fields such as `status`, `verifiedBy`, `verifiedAt`, or alternate review fields.

### After

Create rules now require:

- `createdBy == request.auth.uid`;
- organizer-created registrations may be `pending`, `approved`, or `rejected`, with approved/rejected decisions requiring `verifiedBy == request.auth.uid` and integer `verifiedAt`;
- team/guest-team owner-created registrations must be `pending` and must not contain organizer decision values.

Update rules now split responsibility:

- Organizer may approve/reject only when immutable source fields are unchanged.
- Organizer decision updates are limited to `status`, reviewer/verification fields, notes/rejection fields, and `updatedAt`.
- Team/guest-team owners may update only safe pending submitter fields: `mode`, `notes`, and `updatedAt`.
- Team/guest-team owners cannot change `status`, reviewer fields, tournament identity, source team identity, creator identity, or creation time.

Immutable fields frozen on update include:

- `tournamentId`
- `teamId`
- `guestTeamId`
- `claimedFromGuestTeamId`
- `createdBy`
- `submittedBy`
- `createdAt`
- `sourceId`
- `sourceType`

## MatchEvent Rules Before / After

### Before

`matchEvents.create` validated document shape and required `createdBy == request.auth.uid`, but it did not verify that:

- `matchId` exists;
- the caller organizes the match;
- user-provided `tournamentId` matches the match's real `tournamentId`.

That meant any authenticated user could write active `goal` or `mvp` events into another organizer's tournament as themselves.

### After

`matchEvents.create` still keeps the existing shape validation, and now also requires:

- `matchId` is a string;
- the match document exists;
- `matches/{matchId}.organizerId == request.auth.uid`;
- if the match has a `tournamentId`, the event `tournamentId` must match it exactly;
- if the match has no `tournamentId`, the event must omit `tournamentId` or set it to null;
- `createdBy == request.auth.uid`;
- only supported event types `goal` and `mvp` are allowed.

For V1, MatchEvent creation is restricted to the match/tournament organizer. Team-captain MatchEvent writes are deferred until rules can reliably verify captain authority against match sides.

## Pending Tests Converted to Passing

The following Task 2 pending expectations are now enabled and passing:

- Team owner must not self-approve by changing registration status to `approved`.
- Random authenticated user must not create a goal event in another organizer tournament.
- Random authenticated user must not create an MVP event in another organizer tournament.

The skipped `known P0 tournament permission expectations that current rules fail` block was removed.

## Tests Added / Updated

Updated `test/rules/tournament_permissions.rules.test.js` to cover:

- Team owner can submit a pending registration for own team.
- Team owner cannot create an already-approved registration.
- Tournament organizer can approve a registration using the actual schema fields `verifiedBy` and `verifiedAt`.
- Team owner can edit safe pending fields.
- Team owner cannot self-approve.
- Team owner cannot change source identity fields.
- Organizer can create valid goal MatchEvent.
- Organizer can create valid MVP MatchEvent.
- `createdBy` spoofing remains denied.
- Random authenticated user cannot create goal/MVP events in another organizer's tournament.
- MatchEvent `tournamentId` mismatch is denied.
- MatchEvent for nonexistent `matchId` is denied.
- Existing tournament/match ownership and operation collection tests still run.
- Existing claim-code rules tests still pass.

## Commands Run

- `npm ci`
  - Result: passed.
- `npm run test:rules:emulator`
  - Result: passed with `45 passing`.
- `dart analyze lib/`
  - Result: passed with no issues.

## Final Result

Acceptance criteria are met:

- Rules emulator tests pass.
- The 3 known P0 pending expectations are now passing tests.
- Team owners cannot self-approve tournament registrations.
- Random authenticated users cannot create goal/MVP events in other organizers' tournaments.
- Organizer can still approve registrations.
- Authorized organizer can still create valid goal/MVP MatchEvents.
- No Flutter production code changes were made.

## Remaining Risks

- **Operation collections still unresolved:** `tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, `knockoutTies`, `matchSides`, and `matchSidePlayers` are still denied for organizer writes unless a backend-only model is intended.
- **Service-layer guards still unresolved:** Rules are hardened, but service/controller write paths still need a dedicated guard audit so UI, service, and rules behavior stay aligned.
- **Guest-first score UI still unresolved:** This task protects MatchEvent writes; it does not complete guest-first goal/MVP score submission UX.
- **Team captain score submission deferred:** MatchEvent writes are organizer-only for V1 rules safety. Captain writes should remain denied until rules can verify the caller manages one of the match sides without trusting client-provided IDs.
