# Sprint 2 / Task 7 + 7.1 — Architecture Security Review

**Reviewed:** 2026-05-06  
**Scope:** Token-Aware Guest Profile Claim Entry + Analyzer Baseline Restore  
**Verdict:** ✅ PASS — all 9 security constraints verified, no exposure amplification

---

## Files Changed

### Task 7: Token-Aware Guest Profile Claim Entry

| File | Delta | Summary |
|---|---|---|
| `lib/features/profile/controllers/public_player_profile_controller.dart` | +92 lines | `_claimPayloadKeys`, `hasValidGuestClaimPayload`, `guestClaimWarningMessage`, `guestClaimQueryParameters`, `guestClaimRoute`, `openGuestClaim`, `_canEvaluateGuestClaim` |
| `lib/features/profile/views/public_player_profile_screen.dart` | +65 lines | `_ClaimAction`, `_ClaimPlaceholder`, `_InfoPanel`; conditional CTA rendering |
| `test/features/profile/public_player_profile_test.dart` | +215 lines | 10 new widget tests for token-aware CTA behavior |

### Task 7.1: Analyzer Baseline Restore

| File | Delta | Summary |
|---|---|---|
| `lib/features/shareables/services/share_card_capture_service.dart` | ~20 lines | Removed unused `loadingDialog` variable; moved overlay/navigator lookup before async gap; `navigator.mounted` check |

### Verified untouched (0 diff from HEAD)

| File | Status |
|---|---|
| `lib/core/services/guest_claim_service.dart` | ✅ Clean |
| `lib/core/services/share_link_service.dart` | ✅ Clean |
| `lib/data/repositories/claim_code_repository_impl.dart` | ✅ Clean |
| `firestore.rules` | ✅ Clean |
| `firestore.indexes.json` | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/features/match/controllers/score_submit_controller.dart` | ✅ Clean |
| `lib/core/services/match_event_service.dart` | ✅ Clean |

---

## Security Review Axis 1: No CTA on plain `/player/guestPlayer/:id`

### Controller guard: `_canEvaluateGuestClaim` (line 143)

```dart
bool _canEvaluateGuestClaim(PublicPlayerProfileData? data) {
  if (data == null) return false;
  if (!data.isGuest) return false;
  if (data.id.trim().isEmpty) return false;
  if (data.isClaimed || _hasText(data.linkedPlayerId)) return false;
  return true;
}
```

### Controller guard: `_hasAnyClaimPayload` (line 140)

```dart
bool get _hasAnyClaimPayload =>
    _claimPayloadKeys.any((key) => _hasText(Get.parameters[key]));
```

### Flow for plain profile URL

```
/player/guestPlayer/guest-1 (no query params)
  │
  ├── _canEvaluateGuestClaim: ✅ (guest, unclaimed)
  ├── _hasAnyClaimPayload: ❌ (no query params)
  │
  ├── hasValidGuestClaimPayload: false
  ├── guestClaimWarningMessage: null
  │
  └── Screen renders: _ClaimPlaceholder
      → "ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق."
```

### Test evidence

"screen shows Arabic labels and guest claim placeholder" (test line 180–203):
```dart
expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsOneWidget);
expect(find.text('استلم البروفايل'), findsNothing);  // ← CTA absent
```

**Verdict:** ✅ Plain profiles show placeholder only. No CTA.

---

## Security Review Axis 2: CTA only with valid code + type=guestPlayer + matching targetId

### `hasValidGuestClaimPayload` (line 61)

```dart
bool get hasValidGuestClaimPayload {
  final data = profile.value;
  if (!_canEvaluateGuestClaim(data)) return false;
  if (!_hasAnyClaimPayload) return false;
  return guestClaimWarningMessage == null;
}
```

### `guestClaimWarningMessage` validation chain (lines 68–107)

```
1. _canEvaluateGuestClaim? → only if guest, unclaimed, non-empty id
2. _hasAnyClaimPayload?    → only if any claim key exists in route
3. code non-empty?         → "رابط الدعوة غير مكتمل"
4. targetId non-empty?     → "رابط الدعوة غير مكتمل"
5. type == 'guestPlayer'?  → "رابط الدعوة لا يخص بروفايل لاعب ضيف"
6. targetId == profile.id? → "رابط الدعوة لا يطابق هذا البروفايل"
7. status == 'active'?     → "رابط الدعوة لم يعد نشطًا"
8. expiresAt valid & not expired? → "انتهت صلاحية رابط الدعوة"
```

All checks must pass (return `null` from `guestClaimWarningMessage`) for CTA to show.

### Screen rendering logic (view lines 126–134)

```dart
if (profile.showClaimPlaceholder) ...[
  const SizedBox(height: AppDimensions.md),
  if (controller.hasValidGuestClaimPayload)
    _ClaimAction(onPressed: controller.openGuestClaim)
  else if (controller.guestClaimWarningMessage != null)
    _InfoPanel(message: controller.guestClaimWarningMessage!)
  else
    _ClaimPlaceholder(),
],
```

Three mutually exclusive states:
1. Valid payload → `_ClaimAction` (CTA button)
2. Has payload but invalid → `_InfoPanel` (warning message)
3. No payload at all → `_ClaimPlaceholder` (ask organizer)

### Test evidence

"guest profile with valid matching token shows claim CTA" (test line 205–223):
```dart
queryParameters: _validClaimQuery(),
// ...
expect(find.text('استلم البروفايل'), findsOneWidget);
expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsNothing);
```

**Verdict:** ✅ CTA only appears when all 8 validation checks pass.

---

## Security Review Axis 3: Code is NOT read from GuestPlayer.claimCode

### Controller imports

```dart
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../models/public_player_profile_data.dart';
import '../services/public_player_profile_resolver.dart';
```

**No imports of:**
- ❌ `guest_player.dart`
- ❌ `guest_player_model.dart`
- ❌ `guest_player_repository_impl.dart`
- ❌ `guest_claim_service.dart`
- ❌ `share_link_service.dart`
- ❌ `claim_code_repository_impl.dart`
- ❌ `claim_code.dart`

### Where does the code come from?

```dart
String? _queryValue(String key) {
  final value = Get.parameters[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}
```

The `code` value comes exclusively from `Get.parameters['code']` — the route query parameter. This is the value that was already in the deep link/QR URL when the user tapped it.

### `PublicPlayerProfileData` model

```dart
class PublicPlayerProfileData {
  final ParticipantRefKind kind;
  final String id;
  final String displayName;
  final int totalGoals;
  final int totalMvps;
  final String? linkedPlayerId;
  final bool isClaimed;
  // ...
}
```

**No `claimCode` field.** The resolver fetches the full `GuestPlayer` entity (which does contain `claimCode`) but strips it when building `PublicPlayerProfileData`. The controller never touches the resolver's intermediate data.

**Verdict:** ✅ The code comes only from the route. Zero access to `GuestPlayer.claimCode`.

---

## Security Review Axis 4: ClaimCodeRepository / claimCodes collection not accessed

### grep verification

Zero matches for `ClaimCode`, `GuestClaimService`, `ShareLinkService`, `claim_code_repository`, `guest_claim_service`, `share_link_service` in both:
- `lib/features/profile/controllers/public_player_profile_controller.dart`
- `lib/features/profile/views/public_player_profile_screen.dart`

### No Firestore queries

The controller does not inject or reference any repository. Its only dependency is `PublicPlayerProfileResolver` (for loading the profile data). The token validation is purely string comparison of `Get.parameters` values.

**Verdict:** ✅ No access to `claimCodes` collection or repository.

---

## Security Review Axis 5: Raw code never displayed in UI

### Screen text audit

All user-visible strings in `public_player_profile_screen.dart`:

| Widget | Text | Contains code? |
|---|---|---|
| AppBar | 'بروفايل اللاعب' | ❌ |
| Stat labels | 'أهداف', 'نجومية المباراة' | ❌ |
| Badge | profile.badgeLabel | ❌ |
| Claim CTA | 'استلم البروفايل' | ❌ |
| CTA description | 'رابط الدعوة جاهز لهذا البروفايل.' | ❌ |
| Placeholder | 'ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق.' | ❌ |
| Linked info | 'هذا الضيف مربوط ببروفايل لاعب مسجل.' | ❌ |
| Warnings | 5 Arabic warning strings | ❌ |

No string interpolation includes `code`, `Get.parameters['code']`, or any claim secret.

### Test evidence

Test line 222 explicitly validates this:
```dart
expect(find.textContaining('CLAIM-CODE-1'), findsNothing);
```

This test pumps a profile with a valid token containing `CLAIM-CODE-1` and asserts that the raw code string never appears in any rendered text widget.

**Verdict:** ✅ Raw code is never displayed. Explicitly tested.

---

## Security Review Axis 6: All invalid states are guarded

### Guard matrix

| Scenario | Controller behavior | UI behavior | Test? |
|---|---|---|---|
| No query params at all | `_hasAnyClaimPayload = false` | `_ClaimPlaceholder` | ✅ test line 180 |
| Valid matching token | `hasValidGuestClaimPayload = true` | `_ClaimAction` | ✅ test line 205 |
| Wrong targetId | Warning: 'لا يطابق هذا البروفايل' | `_InfoPanel` | ✅ test line 247 |
| Missing code | Warning: 'غير مكتمل' | `_InfoPanel` | ✅ test line 266 |
| Wrong type (guestTeam) | Warning: 'لا يخص بروفايل لاعب ضيف' | `_InfoPanel` | ✅ test line 283 |
| Inactive status (claimed) | Warning: 'لم يعد نشطًا' | `_InfoPanel` | ✅ test line 319 |
| Expired expiresAt | Warning: 'انتهت صلاحية' | `_InfoPanel` | ✅ test line 300 |
| Claimed/linked guest | `_canEvaluateGuestClaim = false` | Linked info panel, no CTA | ✅ test line 336 |
| Registered player profile | `_canEvaluateGuestClaim = false` | No CTA, no placeholder | ✅ test line 359 |

### Edge case: unparseable expiresAt

```dart
final expiresAtMillis = int.tryParse(expiresAt!);
if (expiresAtMillis == null) {
  return 'رابط الدعوة غير صالح. اطلب رابطًا جديدًا من منظم البطولة أو قائد الفريق.';
}
```

Non-integer `expiresAt` returns a warning. **Not separately tested** but the logic path is clear and consistent with the same pattern as other guards.

**Verdict:** ✅ All 9 invalid states are guarded. 9 of 10 scenarios have explicit tests.

---

## Security Review Axis 7: Navigation uses AppRoutes.guestPlayerClaimById

### `guestClaimRoute` (controller line 118)

```dart
String? get guestClaimRoute {
  final data = profile.value;
  if (data == null || !hasValidGuestClaimPayload) return null;
  return AppRoutes.guestPlayerClaimById(
    data.id,
    queryParameters: guestClaimQueryParameters,
  );
}
```

### `guestClaimQueryParameters` (controller line 109)

```dart
Map<String, String?> get guestClaimQueryParameters {
  if (!hasValidGuestClaimPayload) return const {};
  return {
    for (final key in _claimPayloadKeys)
      if (_hasText(Get.parameters[key])) key: Get.parameters[key]!.trim(),
  };
}
```

Only the 9 allowlisted keys from `_claimPayloadKeys` are forwarded. Any unexpected query parameters are dropped.

### `openGuestClaim` (controller line 127)

```dart
void openGuestClaim() {
  final route = guestClaimRoute;
  if (route == null) return;
  Get.toNamed(route);
}
```

Null guard prevents navigation when route is invalid.

### Test evidence

"claim CTA routes to guest claim screen and preserves code" (test line 225–245):
```dart
await tester.tap(find.text('استلم البروفايل'));
await tester.pumpAndSettle();
expect(find.text('claim-route:guest-1:CLAIM-CODE-1'), findsOneWidget);
```

The stub claim route captures both `guestPlayerId` and `code` from parameters, confirming the route was constructed correctly with the code forwarded.

**Verdict:** ✅ Uses `AppRoutes.guestPlayerClaimById` with filtered query payload. Tested with parameter capture.

---

## Security Review Axis 8: Protected services and systems untouched

### Verified 0 diff

| Protected component | Status |
|---|---|
| `GuestClaimService` | ✅ 0 diff |
| `ShareLinkService` | ✅ 0 diff |
| `ClaimCodeRepository` | ✅ 0 diff |
| `firestore.rules` | ✅ 0 diff |
| `firestore.indexes.json` | ✅ 0 diff |
| `ScoreSubmitController` | ✅ 0 diff |
| `MatchEventService` | ✅ 0 diff |
| `MatchSettlementService` | ✅ 0 diff |
| `RatingEngine` | ✅ 0 diff |
| `FantasyRoundSettlementService` | ✅ 0 diff |
| `PlayerMatchStats` | ✅ 0 diff |

### Controller imports are minimal

Only 3 imports in the controller:
1. `get/get.dart` — framework
2. `app_routes.dart` — route helpers
3. `public_player_profile_data.dart` — DTO
4. `public_player_profile_resolver.dart` — read-only data loader

No service, repository, or entity imports for claim, match, settlement, or rating.

**Verdict:** ✅ Perfect isolation. The task is purely a UI guard layer.

---

## Security Review Axis 9: Analyzer baseline restoration did not alter share behavior

### `share_card_capture_service.dart` diff analysis

**Change 1: Removed unused `loadingDialog` variable**

```diff
-    final loadingDialog = showDialog(
+    unawaited(
+      showDialog<void>(
```

`showDialog` return value was never awaited or used. Wrapping in `unawaited()` silences the analyzer warning without changing behavior. The dialog still shows.

**Change 2: Moved overlay/navigator lookup before async gap**

```diff
+    final overlay = Overlay.maybeOf(context, rootOverlay: true);
+    if (overlay == null) throw Exception('تعذر تجهيز نافذة المشاركة.');
+    final navigator = Navigator.of(context, rootNavigator: true);
+
     // إظهار مؤشر تحميل
     unawaited(
```

Previously, `Overlay.maybeOf(context)` was called after `showDialog` (an async gap). This is the `use_build_context_synchronously` fix — capturing the overlay and navigator before any `await` statement.

**Change 3: Navigator mounted check**

```diff
-      if (Navigator.canPop(context)) {
-        Navigator.of(context, rootNavigator: true).pop();
+      if (navigator.mounted && navigator.canPop()) {
+        navigator.pop();
```

Replaces a post-await `context` usage with the pre-captured `navigator`. Adds `mounted` check for safety.

### Behavioral equivalence

| Step | Before | After |
|---|---|---|
| Show loading dialog | `showDialog(context: ...)` | `unawaited(showDialog(context: ...))` — same |
| Capture overlay | `Overlay.maybeOf(context)` after await | `Overlay.maybeOf(context)` before await — same, safer |
| Insert overlay entry | `overlay.insert(entry)` | Same |
| Capture & share | Same | Same |
| Dismiss dialog | `Navigator.canPop(context)` | `navigator.mounted && navigator.canPop()` — same, safer |

### Test evidence

Task 7.1 report states: `flutter test test/features/shareables/ → Passed, +8` and `flutter test → Passed, +342`.

**Verdict:** ✅ Analyzer fix is purely defensive. No share behavior change. All shareables tests pass.

---

## Test Coverage Assessment

### Test count: 17 total (6 resolver + 11 widget)

#### Existing resolver tests (6, unchanged)

| # | Test | What it covers |
|---|---|---|
| 1 | Aggregates goals/MVPs for registered player | Resolver correctness |
| 2 | Aggregates goals/MVPs for guest player | Resolver correctness |
| 3 | Ignores voided events | Event filtering |
| 4 | Invalid kind/id returns null | Safe null handling |
| 5 | Falls back to event actor displayName | Missing document handling |
| 6 | Returns null when no doc and no events | Complete absence handling |

#### New widget tests (10, added in Task 7)

| # | Test | Security property verified |
|---|---|---|
| 7 | Plain profile shows placeholder, no CTA | ✅ No CTA without token |
| 8 | Valid matching token shows CTA | ✅ CTA appears correctly |
| 9 | CTA routes to claim screen, preserves code | ✅ Navigation correctness |
| 10 | Wrong targetId → warning, no CTA | ✅ Target mismatch guarded |
| 11 | Missing code → no CTA | ✅ Missing token guarded |
| 12 | Type mismatch → no CTA | ✅ Wrong type guarded |
| 13 | Expired token → no CTA | ✅ Expiry guarded |
| 14 | Inactive status → no CTA | ✅ Status guarded |
| 15 | Claimed/linked guest → no CTA even with token | ✅ Already-claimed guarded |
| 16 | Registered player → no CTA even with token | ✅ Kind guarded |
| 17 | Linked guest shows info panel | ✅ Linked state UX |

### Previously existing test (modified)

One existing test had its expected placeholder text updated from `'ده أنت؟ اطلب ربط البروفايل'` to `'ده أنت؟ اطلب رابط الدعوة'` — reflecting the copy change.

### Test gap: unparseable expiresAt

The controller handles `int.tryParse(expiresAt!)` returning `null` (line 95–97), but no test exercises this path. This is a low-risk gap because:
- The `expiresAt` comes from a controlled claim link generator
- The fallback is a safe Arabic warning message
- The CTA stays hidden

**Verdict:** ✅ Strong test coverage. 10 explicit security-scenario tests. One minor gap (unparseable expiresAt).

---

## Findings

### F1: No security regressions — VERIFIED

The implementation strictly follows the Task 6 constraints:
1. ❌ No CTA on plain profiles → verified
2. ❌ No `GuestPlayer.claimCode` read → verified (zero imports)
3. ❌ No `claimCodes` query → verified (zero imports)
4. ❌ No raw code displayed → verified (tested with `findsNothing`)
5. ✅ Only route-present token used → verified (`Get.parameters['code']`)
6. ✅ All invalid states guarded → verified (9 of 10 tested)
7. ✅ `AppRoutes.guestPlayerClaimById` used → verified
8. ✅ All protected systems untouched → verified (0 diff)

### F2: Placeholder copy improved — INFO

**Before:** `'ده أنت؟ اطلب ربط البروفايل\nميزة الربط الكاملة ستفتح من رابط الدعوة أو QR المخصص للضيف.'`

**After:** `'ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق.'`

Shorter, more actionable, directs the user to the correct person (organizer/captain). Good improvement.

### F3: `guestClaimQueryParameters` allowlist is defense in depth — INFO

```dart
static const Set<String> _claimPayloadKeys = {
  'code', 'type', 'targetId', 'scope', 'teamId',
  'tournamentId', 'requiresApproval', 'expiresAt', 'status',
};
```

Only these 9 keys are forwarded to the claim route. Any extra query parameters from the URL are stripped. This prevents parameter pollution attacks.

### F4: Expiry check uses `DateTime.now()` — LOW

```dart
if (expiresAtDate.isBefore(DateTime.now())) {
```

This is not injectable for testing. However, since the claim screen itself (and `GuestClaimService`) re-validates expiry, this is a soft pre-filter, not a security boundary. Acceptable for V1.

### F5: Analyzer fix is safe — VERIFIED

The `share_card_capture_service.dart` change:
- Removes an unused variable
- Moves context-dependent lookups before async gaps
- Adds a `mounted` check
- All shareables tests pass (+8)
- No behavioral change

---

## GO / NO-GO

### Task 7: Token-Aware Guest Profile Claim Entry

**✅ GO — ACCEPTED**

All 9 security constraints from the Task 6 hardening plan are verified:

| Constraint | Verified |
|---|---|
| No CTA on plain `/player/guestPlayer/:id` | ✅ |
| No lookup of `GuestPlayer.claimCode` | ✅ |
| No query of `claimCodes` | ✅ |
| No raw code displayed | ✅ |
| CTA only when code + type + targetId present and valid | ✅ |
| Routes through `AppRoutes.guestPlayerClaimById` | ✅ |
| All protected systems untouched | ✅ |
| All invalid states guarded | ✅ |
| Existing claim service remains final authority | ✅ |

### Task 7.1: Analyzer Baseline Restore

**✅ GO — ACCEPTED**

Minimal, safe fix. No behavioral change. Shareables tests pass.

---

## Recommended Next Task

**Sprint 2 / Task 8: Firestore Claim Code Read Rules Hardening**

Now that the token-aware CTA is safely implemented without amplifying exposure, the highest-priority remaining work is reducing the underlying data exposure:

1. Restrict `claimCodes` collection: split `allow read` into `allow get` (exact document by ID) + block `allow list` for ordinary users
2. Remove `claimCode` field from `guestPlayers` documents (stop writing it in `ShareLinkService.createGuestPlayerClaimLink`)
3. Update `canSelfClaimGuestPlayer` Firestore rule to not depend on `resource.data.claimCode`
4. Add rules tests for claim code confidentiality

This is the V1.1 hardening path recommended in Task 6, and is now the most impactful security improvement remaining.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. No CTA on plain profiles | ✅ Pass | Placeholder only when no query params |
| 2. CTA only with valid matching token | ✅ Pass | 8-check validation chain, tested |
| 3. No `GuestPlayer.claimCode` read | ✅ Pass | Zero imports of guest player entities |
| 4. No `claimCodes` access | ✅ Pass | Zero repository/service imports |
| 5. Raw code never displayed | ✅ Pass | Explicit `findsNothing` test |
| 6. All invalid states guarded | ✅ Pass | 9 scenarios tested |
| 7. Safe navigation route | ✅ Pass | `AppRoutes.guestPlayerClaimById` with filtered payload |
| 8. Protected systems untouched | ✅ Pass | 11 files verified 0 diff |
| 9. Analyzer fix safe | ✅ Pass | No behavioral change, shareables tests pass |
