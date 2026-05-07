# Sprint 2 / Task 8 — Architecture Security Review

**Reviewed:** 2026-05-06  
**Scope:** Firestore Claim Code Read Rules Hardening  
**Verdict:** 🛑 **NEEDS REVISION / NO-GO — Critical Production Regression Found**

---

## Executive Summary

Task 8 attempted to harden `claimCodes` access by splitting the broad `allow read` into `allow get` and `allow list: if false;`. 

While this correctly secures the collection against batch extraction by attackers, **it breaks existing production share link generation.** The `ShareLinkService` relies on a collection query to find existing active claim codes before generating new ones. The proposed rule change would block organizers and captains from generating invite links.

---

## Review Axis 1: Verify the claimCodes rule change

### Changes verified in `firestore.rules`

```rules
match /claimCodes/{claimCodeId} {
  allow get: if isAuthenticated();
  allow list: if false;
  allow create: if canCreateClaimCode(request.resource.data);
  allow update: ...
}
```

- **Ordinary authenticated users cannot list/query:** ✅ Verified. `allow list: if false` blocks all queries.
- **Exact get still works:** ✅ Verified. `allow get: if isAuthenticated()` permits document fetches by ID.
- **Anonymous users cannot get/list:** ✅ Verified. `isAuthenticated()` handles this.
- **Write rules were not loosened:** ✅ Verified. No changes to `create`, `update`, or `delete`.

---

## Review Axis 2 & 3: Deferral of removing `guestPlayers.claimCode`

### Is the deferral technically justified?

**Yes.** The report correctly identifies that `canSelfClaimGuestPlayer` (rules line 195) explicitly relies on `resource.data.claimCode`:

```rules
function canSelfClaimGuestPlayer(guestPlayerId) {
  return isAuthenticated() &&
    resource.data.claimCode is string &&
    isActiveGuestPlayerClaimCode(resource.data.claimCode, guestPlayerId) &&
    ...
    request.resource.data.claimCode == resource.data.claimCode &&
    ...
}
```

If `ShareLinkService` stops writing `claimCode` to new `guestPlayers` documents, the `canSelfClaimGuestPlayer` rule will fail because `resource.data.claimCode` will be null/missing.

### Assessment

The report's reasoning is 100% correct. Removing `claimCode` from guest documents requires a coordinated change to the claim completion architecture (either rewriting the Firestore rules to validate against the `claimCodes` collection, or moving claim completion to a server/Cloud Function). It cannot be done in isolation without breaking claims.

---

## Review Axis 4: Is exact `get` acceptable for V1?

**Yes.** In V1, the token-delivery model relies on trusted out-of-band sharing (QR codes, WhatsApp links). 

The claim code acts as a bearer token. Knowing the exact 12-character document ID is the proof of possession. Allowing `get` for authenticated users who possess the code is the correct, standard implementation for this architecture type, provided they cannot guess or list other people's codes.

---

## Review Axis 5: Hidden Regression Risk (The Blocker)

### 🛑 CRITICAL REGRESSION: `ShareLinkService` broken by `allow list: if false`

The audit discovered that the app **does** use queries on `claimCodes` during invite link generation.

**Path:**
1. User taps "Invite Guest" → `TeamRosterController` or `TournamentRegistrationReviewController`
2. Calls `ShareLinkService.createGuestPlayerClaimLink`
3. Calls `ShareLinkService._reuseOrCreateClaimCode`
4. Calls `ClaimCodeRepository.getActiveClaimCodeForTarget`

**The Query (`claim_code_repository_impl.dart` lines 45-54):**
```dart
Query<Map<String, dynamic>> query = _claimCodesRef
    .where('targetType', isEqualTo: targetType.name)
    .where('targetId', isEqualTo: targetId)
    .where('status', isEqualTo: 'active');
// ...
final snapshot = await query.orderBy('createdAt', descending: true).limit(1).get();
```

**Why this breaks:**
A Firestore `.where().get()` is evaluated as a `list` operation, not a `get` operation. Because Task 8 changed the rule to `allow list: if false;`, this query will throw a `permission-denied` exception for all users. No one will be able to generate or reuse invite links.

---

## Review Axis 6: Why did tests pass? (Test Gaps)

The report states:
> `flutter test test/core/services/share_link_service_test.dart` -> Passed, +4.

**The Test Gap:**
The test suite uses `FakeFirebaseFirestore` (from the `fake_cloud_firestore` package). This package simulates the Firestore API but **does not evaluate Firebase Security Rules**. 

The tests successfully executed the query against the fake local database, masking the fact that production rules would reject the read.

---

## Conclusion & Decision

### Verdict: NO-GO

Task 8 cannot be accepted. The implementation fixes the security exposure (listing claim codes) but inadvertently breaks a core product feature (generating claim links).

### Security State Summary

- **A. Exposure fixed by Task 8:** None (rejected).
- **B. Exposure still remaining:** `claimCodes` can be queried by any authenticated user; `guestPlayers` and `guestTeams` still store raw codes.
- **C. Minimum safe next step:** Revise the `claimCodes` list rule to allow authorized users to query codes they created or manage, while blocking broad listing.

---

## Recommended Next Task

**Sprint 2 / Task 8 (Revised): Granular Claim Code Read Rules & Test Harness**

Before merging rules changes, we must safely permit `ShareLinkService` queries while blocking attackers.

**Scope for the revised task:**
1. **Rule Fix:** Instead of `allow list: if false;`, implement a targeted list rule that allows organizers/captains to query codes for specific targets they manage (e.g., restricting `list` by matching `request.auth.uid` against a required `createdBy` query filter).
2. **Rules Emulator Tests:** Set up `@firebase/rules-unit-testing` or the Firebase Emulator Suite to write automated tests that actually validate the `firestore.rules` file against `get` and `list` scenarios. Relying on `fake_cloud_firestore` for rules validation is unsafe.
3. **Deferral:** Continue deferring the removal of `guestPlayers.claimCode` until claim completion is redesigned in V1.1.
