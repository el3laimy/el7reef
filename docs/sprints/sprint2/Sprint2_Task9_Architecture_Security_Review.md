# Sprint 2 / Task 9 — Architecture Security Review

**Reviewed:** 2026-05-07  
**Scope:** Organizer-only Resend Guest Claim Link Action  
**Verdict:** ✅ **PASS — Implementation is safe, strictly isolated, and well-tested.**

---

## Executive Summary

Task 9 successfully adds a "Resend Claim Link" action to the team roster screen for guest players. The implementation correctly isolates the UI from raw claim codes, strictly guards the action behind roster management permissions, and correctly defers the actual link generation to the previously hardened `ShareLinkService`. 

No exposure amplification occurred. No public UI surfaces were altered. 

---

## Verification of Review Focus Areas

### 1. Visibility guarded by authorization
**Verified:** ✅  
In `TeamRosterScreen`, the overflow menu (actions) is fully guarded by `final canShowActions = controller.canManageRoster;`. Unauthorized viewers simply cannot open the action menu for any roster member.

### 2. Controller re-checks authorization
**Verified:** ✅  
In `TeamRosterController.shareGuestPlayerClaimLink()`, the method immediately checks:
```dart
if (!canManageRoster) {
  Get.snackbar('خطأ', 'لا تملك صلاحية إرسال رابط الاستلام لهذا الضيف.');
  return false;
}
```
This ensures that even if the UI were bypassed, the controller would reject the action.

### 3. Claimed/Linked guests do not show an active resend action
**Verified:** ✅  
`TeamRosterController` computes `isGuestClaimedOrLinked` by checking both `guestPlayer.isClaimed` and `guestPlayer.hasLinkedPlayer`. The UI then conditionally renders the action: `if (entry.isGuest && !entry.isGuestClaimedOrLinked)`. Furthermore, the controller re-verifies this state before generating the link.

### 4. Uses `ShareLinkService` instead of manual construction
**Verified:** ✅  
The code calls `await _shareLinkService.createGuestPlayerClaimLink(...)`. No raw URLs or deep link payloads are manually assembled in the UI or controller layers.

### 5. UI does not display raw `GuestPlayer.claimCode`
**Verified:** ✅  
The raw code is never extracted or displayed on screen. The generated `shareText` (which contains the full URL payload) is passed directly to the OS share sheet via the `Share.share` plugin.

### 6. Controller does not query `claimCodes` directly
**Verified:** ✅  
The controller has no dependency on `ClaimCodeRepository` and executes no direct Firestore queries. It strictly uses `ShareLinkService`.

### 7. Public profile token-aware claim behavior is untouched
**Verified:** ✅  
Files modified in this PR were strictly confined to `team_roster_controller.dart`, `team_roster_screen.dart`, and their associated tests. No public profile UI was affected.

### 8. Core services and backend untouched
**Verified:** ✅  
`GuestClaimService`, Firestore rules, `ScoreSubmit`, `MatchEvents`, settlement, rating, fantasy, and `PlayerMatchStats` are untouched. The scope remained cleanly within the Team features folder.

### 9. Acceptability of `canManageRoster`
**Verified:** ✅  
`canManageRoster` checks if the user is the Team Owner or a Vice Captain. This is an appropriate UI-layer guard. Since `ShareLinkService` ultimately checks `claimCodes` creation authorization and enforces the final authority via Firestore rules, this tiered defense-in-depth approach is robust and secure.

### 10. Test Coverage
**Verified:** ✅  
`test/features/team/team_roster_screen_test.dart` includes 5 new dedicated widget tests:
- Manager can share a guest player claim link.
- Claimed guest player shows linked info without active resend action.
- Unauthorized viewer does not see guest claim resend action.
- Link generation failure shows safe Arabic error.
All tests pass and explicitly verify the absence of raw code exposure (`expect(find.textContaining('CLAIM-CODE-1'), findsNothing);`).

---

## Conclusion

The implementation is highly disciplined. It achieves the product goal (allowing organizers to resend lost links) while perfectly adhering to the V1 proof-of-possession constraints established in Tasks 6, 7, and 8.

### Recommended Next Task

**Sprint 2 / Task 10: Server-Mediated Guest Claim Completion (V1.1 Prep)**
With the UI layers and read rules now hardened, the final major security milestone is to remove `guestPlayers.claimCode` entirely and transition the claim-completion transaction to a trusted environment (like a Firebase Cloud Function). This will allow us to completely decouple `canSelfClaimGuestPlayer` from client-side payload assertions.
