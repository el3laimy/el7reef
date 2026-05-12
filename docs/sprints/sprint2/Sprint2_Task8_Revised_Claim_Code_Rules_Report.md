# Sprint 2 / Task 8 Revised - Granular Claim Code Read Rules & Rules Test Harness

## Summary of Gemini-Discovered Regression

The first Task 8 rule direction changed `claimCodes` from broad authenticated reads to:

- `allow get: if isAuthenticated();`
- `allow list: if false;`

That blocks production claim-link generation because `ShareLinkService._reuseOrCreateClaimCode` calls `ClaimCodeRepository.getActiveClaimCodeForTarget`, which runs a Firestore query:

- `targetType == ...`
- `targetId == ...`
- `status == active`
- optional `tournamentId == ...`
- `orderBy createdAt desc`
- `limit 1`

Firestore evaluates that as a `list` operation, so `allow list: if false` would deny authorized reuse queries in production even though `fake_cloud_firestore` tests pass.

## Files Changed

- `firestore.rules`
- `firestore.indexes.json`
- `lib/domain/repositories/claim_code_repository.dart`
- `lib/data/repositories/claim_code_repository_impl.dart`
- `lib/core/services/share_link_service.dart`
- `test/data/repositories/claim_code_repository_impl_test.dart`
- `test/core/services/share_link_service_test.dart`
- `test/rules/claim_codes.rules.test.js`
- `firebase.rules.test.json`
- `package.json`
- `package-lock.json`

## ClaimCodes Get/List/Query Paths Found

Exact document get paths:

- `ClaimCodeRepositoryImpl.getClaimCode(code)` reads `claimCodes/{code}`.
- `ShareLinkService._generateUniqueCode` uses exact get to avoid a code collision while minting a new link.
- `TeamInviteService._requireActiveInviteCode` uses exact get for team invite resolution.
- `GuestTeamClaimController._loadClaimDetails` uses exact get for guest-team claim preview.
- `GuestClaimService.claimGuestPlayer` and `GuestClaimService.claimGuestTeam` use exact document refs from the route code.

List/query paths:

- `ClaimCodeRepositoryImpl.getActiveClaimCodeForTarget` is the active-code reuse query.
- It is used by `ShareLinkService._reuseOrCreateClaimCode` for guest player claim links, guest team claim links, and team invite links.
- The acting user is the link creator/manager after the existing ShareLinkService permission checks.

Create/update/finalize paths:

- `ShareLinkService._reuseOrCreateClaimCode` creates new `claimCodes/{code}` documents.
- `ShareLinkService._reuseOrCreateClaimCode` can expire an existing creator-owned active code.
- `TeamInviteService._requireActiveInviteCode` can expire an exact invite code after route-token use.
- `GuestClaimService` finalizes guest player/team claim codes through exact route-code refs.

Authorization fields available on `claimCodes`:

- `createdBy`
- `targetType`
- `targetId`
- `teamId`
- `tournamentId`
- `status`
- `scope`
- `expiresAt`
- `requiresApproval`

## Final Rules Design

`claimCodes` now uses:

- `allow get: if isAuthenticated();`
- `allow list: if isAuthenticated() && resource.data.createdBy == request.auth.uid;`

Exact get remains allowed for authenticated users because V1 claim routes treat knowing the code document id as proof-of-possession. Broad list/query is blocked unless Firestore can prove every returned document was created by the requesting user.

Writes were not loosened. Existing create/update/finalize helper rules remain in place.

## Why Authorized Reuse Still Works

`ClaimCodeRepository.getActiveClaimCodeForTarget` now accepts optional `createdBy`.

`ShareLinkService._reuseOrCreateClaimCode` passes the current `actorId`, so the production reuse query is creator-scoped and rule-provable:

- `createdBy == actorId`
- `targetType == ...`
- `targetId == ...`
- `status == active`
- optional `tournamentId == ...`
- `orderBy createdAt desc`
- `limit 1`

V1 tradeoff: if another authorized manager previously created an active link for the same target, the current actor will not reuse that other manager's code and may mint a new active code. This avoids broad list access and is acceptable for the minimal V1 hardening path.

## Index Changes

Added composite indexes for the creator-scoped reuse query:

- `claimCodes`: `createdBy ASC`, `targetType ASC`, `targetId ASC`, `status ASC`, `createdAt DESC`
- `claimCodes`: `createdBy ASC`, `targetType ASC`, `targetId ASC`, `status ASC`, `tournamentId ASC`, `createdAt DESC`

## Rules Tests Added

Added `test/rules/claim_codes.rules.test.js` with Firebase rules-unit-testing coverage for:

- anonymous users cannot get exact `claimCodes/{code}`
- authenticated users can exact-get a known claim code
- authenticated users cannot broad-list `claimCodes`
- the creator can run the allowed active-code reuse query
- creator-scoped reuse works with a tournament constraint
- a non-creator cannot query another creator's claim-code scope
- unauthorized creates and updates are denied

Added `firebase.rules.test.json` as a dedicated root-level emulator config so the Flutter-generated root `firebase.json` is not repurposed for rules tests. The earlier nested `test/rules/firebase.json` config was removed because Firebase CLI rejects `../../firestore.rules` as outside the configured Firebase project directory.

Rules tests can now be run from the repository with:

- `npm run test:rules:emulator`
- or `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`

`firebase-tools` is included as a dev dependency so `npx firebase-tools` resolves from `npm ci` instead of depending on a global install or live package fetch.

## Flutter Tests Added/Updated

- `test/data/repositories/claim_code_repository_impl_test.dart`
  - added creator filtering coverage for active target links
- `test/core/services/share_link_service_test.dart`
  - added coverage that active claim-link reuse is scoped to the requesting actor

## Commands Run

- `npm install`
  - Result: completed, generated `package-lock.json`
- `npm ci`
  - Result: passed
- `flutter pub get`
  - Result: passed
- `dart format lib/domain/repositories/claim_code_repository.dart lib/data/repositories/claim_code_repository_impl.dart lib/core/services/share_link_service.dart test/data/repositories/claim_code_repository_impl_test.dart test/core/services/share_link_service_test.dart`
  - Result: passed
- `env FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npx firebase-tools --config firebase.rules.test.json emulators:exec --only firestore "npm run test:rules"`
  - Result: passed, `7 passing`
- `dart analyze lib/`
  - Result: passed, no issues found
- `flutter test test/data/repositories/claim_code_repository_impl_test.dart`
  - Result: passed, `+3`
- `flutter test test/core/services/share_link_service_test.dart`
  - Result: passed, `+5`
- `flutter test test/core/services/guest_claim_service_test.dart`
  - Result: passed, `+14`
- `flutter test test/features/guest_claim/guest_claim_screen_test.dart`
  - Result: passed, `+6`
- `flutter test test/features/profile/public_player_profile_test.dart`
  - Result: passed, `+17`
- `flutter test`
  - Result: passed, `+344`

## Manual Emulator QA

For local/manual verification:

1. Run `npm ci`.
2. Run `npm run test:rules:emulator`.
3. Confirm all `claimCodes Firestore rules` tests pass.
4. Generate a guest player claim link as the creator and verify the active-code reuse query succeeds.
5. Attempt a broad `claimCodes` collection query as a normal authenticated user and verify it fails.
6. Attempt a creator-scoped query with `createdBy` set to another user and verify it fails.

## Deferred Items

- Removing raw `guestPlayers.claimCode` remains deferred.
- Removing raw `guestTeams.claimCode` remains deferred.
- Hashing claim codes or adding a private verifier remains deferred.
- Cloud Function/private verifier design remains deferred.
- Richer organizer/team-manager reuse across multiple authorized managers remains deferred.

## Remaining Risks

- Exact `claimCodes/{code}` get remains allowed for authenticated users by design. This is still a proof-of-possession V1 model, not a private verifier model.
- Old public-readable guest player/team documents may still contain raw `claimCode`.
- The harness now depends on the committed `firebase.rules.test.json`; avoid reintroducing nested Firebase configs that reference paths outside their project directory.

## Final Recommendation

Proceed with the creator-scoped query/rules patch. The root-level rules harness proves broad claim-code listing is blocked while authorized creator-scoped reuse remains compatible with production Firestore rules.
