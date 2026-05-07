# Sprint 2 / Task 8: Claim Code Rules Hardening

## Summary of Security Hardening

Hardened Firestore `claimCodes` reads by splitting broad authenticated reads into exact document reads and blocked collection list/query access.

Implemented:

- `claimCodes/{claimCodeId}` exact `get` remains available to authenticated users.
- `claimCodes` `list`/query is now denied.
- Existing create/update/finalize/delete rules were not loosened.
- Added rules comments documenting the V1 proof-of-possession model: knowing the exact claim code document id is treated as possession of the invite token.

Deferred:

- Stopping `ShareLinkService.createGuestPlayerClaimLink` from writing `guestPlayers.claimCode` for new links.

Reason for deferral: the current guest player claim path is client-side Firestore writes. `canSelfClaimGuestPlayer` validates the `guestPlayers/{id}` update using `resource.data.claimCode`; Firestore rules cannot read route query parameters, and they cannot query for an arbitrary matching claim code by `targetId`. Removing the field now would make new guest player claim links fail under production Firestore rules unless the claim is moved to a trusted server function/private verifier or a new non-public claim verifier document is introduced.

## Files Changed

- `firestore.rules`
- `docs/Sprint2_Task8_Claim_Code_Rules_Hardening_Report.md`

No Flutter/Dart production code was changed.

## Exact Firestore Rules Changes

Before:

```rules
match /claimCodes/{claimCodeId} {
  allow read: if isAuthenticated();
  ...
}
```

After:

```rules
match /claimCodes/{claimCodeId} {
  // V1 claim links treat the exact claim code document id as
  // proof-of-possession for client claim entry. Listing/querying all claim
  // codes would expose active invite tokens, so only exact document reads
  // remain available to authenticated users.
  allow get: if isAuthenticated();
  allow list: if false;
  ...
}
```

## ClaimCodes List / Query

Blocked.

Ordinary authenticated users can no longer list/query `claimCodes`.

## Exact ClaimCodes Get

Exact `get` remains allowed for authenticated users.

Why: existing client claim entry and guest team claim screens load `claimCodes/{code}` directly from the route token. In V1, knowing the exact unguessable code is the proof-of-possession signal. Removing exact `get` would require Cloud Functions, hashed verifiers, or a private document split, which are explicitly out of scope for this task.

## GuestPlayers.claimCode

Still written for new guest player claim links in this task.

Verified blocker:

- `ShareLinkService.createGuestPlayerClaimLink` currently writes `claimCode` onto the guest player.
- `GuestClaimService.claimGuestPlayer` completes a client-side transaction that updates both `guestPlayers/{id}` and `claimCodes/{code}`.
- `firestore.rules` `canSelfClaimGuestPlayer` validates the guest player update from `resource.data.claimCode`.
- If new guest players no longer store `claimCode`, production Firestore rules cannot verify the guest player update from the route token without a server/private verifier design.

This is intentionally documented rather than shipping a change that would pass fake Firestore tests but break deployed rules.

## GuestTeams.claimCode

Deferred.

Guest team claim rules also depend on `resource.data.claimCode` through `canSelfClaimGuestTeam`, and guest team claim includes an approval-oriented flow. Removing guest team claim codes safely should be handled with the same private verifier/server-mediated design as guest players.

## Compatibility Notes

- Existing claim links and QR payloads continue to contain the route `code`.
- Existing `claimCodes/{code}` documents continue to be created and updated.
- Existing guest player and guest team claim flows continue to work.
- Existing guest documents with `claimCode` remain compatible.
- No migration was added.

## Tests Added / Updated

No automated rules tests were added because no Firestore rules test harness is currently present in the repository.

Existing targeted tests were run to verify app-level claim/link compatibility:

- `test/core/services/share_link_service_test.dart`
- `test/core/services/guest_claim_service_test.dart`
- `test/features/guest_claim/guest_claim_screen_test.dart`
- `test/features/profile/public_player_profile_test.dart`

## Commands Run

| Command | Result |
|---|---|
| `flutter pub get` | Passed. Dependencies resolved; newer incompatible package versions were reported by Flutter. |
| `dart format on changed files` | Not applicable; only `firestore.rules` and docs changed. |
| `dart analyze lib/` | Passed. No issues found. |
| `flutter test test/core/services/share_link_service_test.dart` | Passed, `+4`. |
| `flutter test test/core/services/guest_claim_service_test.dart` | Passed, `+14`. |
| `flutter test test/features/guest_claim/guest_claim_screen_test.dart test/features/profile/public_player_profile_test.dart` | Passed, `+23`. |
| `flutter test` | Passed, `+342`. |

## Manual Firebase Emulator / Rules QA Checklist

Rules tests or emulator QA should verify:

- Authenticated exact `get` of `claimCodes/{knownCode}` succeeds.
- Authenticated collection `list`/query on `claimCodes` fails.
- Anonymous exact `get` of `claimCodes/{knownCode}` fails.
- Existing guest player claim path still succeeds for a guest player document with legacy `claimCode`.
- Existing guest team claim path still succeeds for a guest team document with legacy `claimCode`.
- Claim code create/update/finalize rules still reject unauthorized writes.

## Final Result

`claimCodes` list/query exposure is closed without breaking existing client claim flows.

## Remaining Risks / Follow-Ups

- `guestPlayers.claimCode` and `guestTeams.claimCode` still expose raw codes on public-readable guest documents when those fields are present.
- A safe follow-up should introduce one of:
  - Cloud Function/server-mediated guest claim completion,
  - private claim verifier documents,
  - or a public/private guest identity split.
- After a trusted verifier exists, stop writing raw claim codes to `guestPlayers` and `guestTeams`, then migrate/clear old public claim code fields.
- Add automated Firestore rules tests for claim code confidentiality and claim completion.
