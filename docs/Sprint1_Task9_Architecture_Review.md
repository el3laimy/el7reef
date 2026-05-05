# Sprint 1 / Task 9 — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** Top Scorers Share Card  
**Verdict:** ✅ PASS — serves pride/ego clearly, reuses existing infra, well-tested

---

## Files Reviewed

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `lib/features/shareables/models/top_scorers_share_data.dart` | 34 | Immutable data model for the share card |
| `lib/features/shareables/controllers/top_scorers_share_controller.dart` | 38 | Maps resolver output → share card data |
| `lib/features/shareables/widgets/top_scorers_share_card.dart` | 367 | The share card widget (preview + export) |
| `test/features/shareables/top_scorers_share_card_test.dart` | 102 | 3 tests: controller mapping, Arabic labels, widget rendering |

### Modified files

| File | Change | Summary |
|---|---|---|
| `lib/features/tournament/views/tournament_detail_screen.dart` | +85 lines | `_shareTopScorers` method, `onShare` callback on section, share button CTA |

### Verified untouched (0 diff from HEAD)

| File | Status |
|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/features/shareables/services/share_card_capture_service.dart` | ✅ Clean (reused, not modified) |
| `firestore.rules` | ✅ Clean |

---

## Review Axis 1: Does the share card serve the pride/ego goal clearly?

### Visual design audit

The card uses the same premium dark background (`#07140D`) and dual-glow aesthetic as the existing match result share card:

```
┌──────────────────────────────────┐
│  الحريف                 TOP 5   │  ← brand + meta chip
│                                  │
│         هدافو البطولة            │  ← title (center, white, w900)
│          Street Cup              │  ← tournament name (center, faded)
│                                  │
│  ┌────────────────────────────┐  │
│  │  1  •  أحمد         3 أهداف│  │  ← glassmorphic scorer row
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  2  •  ضيف [ضيف]   2 أهداف│  │  ← guest badge visible
│  └────────────────────────────┘  │
│         ...                      │
│                                  │
│   سجّل أهدافك وخلي اسمك يظهر    │  ← CTA tagline (faded, center)
└──────────────────────────────────┘
```

### Pride signals

1. **"هدافو البطولة"** — title declares achievement
2. **Rank badges** — numbered circles in primary green, immediate bragging value
3. **"TOP 5"** chip — exclusive club messaging
4. **"سجّل أهدافك وخلي اسمك يظهر"** — CTA tagline inviting viral competition
5. **"الحريف"** brand mark — associates achievement with the platform

### Background: pitch stripe painter + dual glow

`_PitchStripePainter` draws subtle diagonal lines + center circle, creating a football pitch mood. `_Glow` widgets add primary and secondary radial gradients in corners. This matches the aesthetic established by the match result card.

**Verdict:** ✅ The card is designed to make the top scorer feel celebrated. The ranking, branding, and CTA tagline all serve the "player pride → sharing → growth" loop.

---

## Review Axis 2: Does it include all required elements?

### Checklist

| Element | Present? | Implementation |
|---|---|---|
| Tournament name | ✅ | `data.tournamentName` in center subtitle |
| "هدافو البطولة" | ✅ | `data.title` in center headline |
| Ranks | ✅ | `_RankBadge` (1-indexed circle badges) |
| Player names | ✅ | `scorer.displayName` in white bold |
| Goal counts | ✅ | `scorer.goalLabel` in primary green |
| Guest label | ✅ | `_GuestBadge` ("ضيف" pill) when `isGuest` |
| El7reef branding | ✅ | `_BrandMark` ("الحريف") top-left |

### Arabic singular/plural fix

```dart
String get goalLabel => goals == 1 ? '1 هدف' : '$goals أهداف';
```

This addresses F1 from the Task 8 review. "1 هدف" is correct Arabic singular; "2+ أهداف" is correct Arabic plural. The dual form "هدفان" (for exactly 2) is not used, which is acceptable for a casual/street context.

### Default tournament name

```dart
tournamentName: normalizedName.isEmpty ? 'بطولة الحريف' : normalizedName,
```

Falls back to "بطولة الحريف" if name is empty — prevents blank header on the card.

**Verdict:** ✅ All required elements present with correct Arabic text.

---

## Review Axis 3: Is the UI CTA clear and only visible/enabled when scorers exist?

### CTA button placement (from diff)

```dart
else ...[
  ...scorers.indexed.map((item) {
    final rank = item.$1 + 1;
    final scorer = item.$2;
    return _TopScorerRow(rank: rank, scorer: scorer);
  }),
  const SizedBox(height: AppDimensions.sm),
  Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton.icon(
      onPressed: onShare,
      icon: const Icon(Icons.ios_share_rounded),
      label: const Text('شارك الهدافين'),
    ),
  ),
],
```

The share button ("شارك الهدافين") is in the `else` branch — it only renders when `scorers.isNotEmpty`. It never appears during loading, error, or empty states.

### Double guard in `_shareTopScorers`

```dart
final scorers = controller.topScorers.toList(growable: false);
if (scorers.isEmpty) {
  Get.snackbar('تعذر المشاركة', 'لا يوجد هدافون لمشاركتهم بعد.');
  return;
}
```

Even if somehow invoked with empty scorers, the method exits early with an Arabic snackbar. Defense in depth.

### Button styling

`OutlinedButton.icon` with `Icons.ios_share_rounded` — matches the existing share button pattern in the codebase (used in lineup/result share flows). Not oversized, not hidden.

**Verdict:** ✅ CTA is clear, correctly gated, and follows existing button patterns.

---

## Review Axis 4: Does it reuse the existing share card capture/share infrastructure?

### `ShareCardCaptureService` — reused, not modified

The existing service (`0 diff` confirmed) handles the full pipeline:
1. `RepaintBoundary` → `toImage()` → PNG bytes
2. Save to temp file
3. `Share.shareXFiles()` via `share_plus`

### Overlay pattern — identical to match result and lineup share flows

```dart
final boundaryKey = GlobalKey();
final entry = OverlayEntry(
  builder: (_) => Positioned(
    left: 0, top: 0,
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.01,
        child: RepaintBoundary(
          key: boundaryKey,
          child: TopScorersShareCard(data: shareData, exportMode: true),
        ),
      ),
    ),
  ),
);
overlay.insert(entry);
await WidgetsBinding.instance.endOfFrame;
await _captureService.captureAndShare(
  boundaryKey: boundaryKey,
  fileName: 'el7reef_top_scorers_${tournament.id}',
  text: 'هدافو ${tournament.name} على الحريف',
  pixelRatio: matchResultShareExportPixelRatio,
);
```

This is the exact same `OverlayEntry → capture → share → cleanup` pattern used by:
- `LineupEditorScreen` for lineup share
- `MatchResultHub` for result share

### `exportMode` flag — follows existing convention

The card supports `exportMode` (fixed dimensions, no shadows, explicit pixel fonts) for PNG capture, and normal mode for in-app preview. This is the same dual-mode approach as `MatchResultShareCard` (same `exportLogicalWidth: 360`, `exportLogicalHeight: 450`).

**Verdict:** ✅ Full reuse of existing capture infrastructure. No new services, no modified services.

---

## Review Axis 5: Does it avoid navigation/player profile/share preview overreach?

### No navigation in scorer rows

`_ShareScorerRow` is a `Container > Row`. No `GestureDetector`, `InkWell`, or `onTap`.

### No share preview dialog

The share flow goes directly from overlay capture → `Share.shareXFiles()`. No in-app preview dialog, no confirmation screen, no new route push.

### No player profile linking

Zero references to player profiles, `AppRoutes.player*`, or any navigation from the share card or the CTA button. Tapping "شارك الهدافين" immediately starts the capture+share pipeline.

**Verdict:** ✅ No overreach. The share action is direct and minimal.

---

## Review Axis 6: Does it handle share/capture errors safely in Arabic?

### Error paths in `_shareTopScorers`

| Failure | Handling |
|---|---|
| `scorers.isEmpty` | Snackbar: "لا يوجد هدافون لمشاركتهم بعد." → return |
| `Overlay.maybeOf()` returns null | Snackbar: "تعذر تجهيز نافذة المشاركة." → return |
| `captureAndShare` throws | Caught by `catch (error)` → `_readableShareError(error)` |
| Overlay cleanup | `finally { if (inserted) entry.remove(); }` → always cleans up |

### `_readableShareError` helper

```dart
String _readableShareError(Object error) {
  final raw = error.toString();
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }
  return 'تعذر تجهيز بطاقة المشاركة.';
}
```

The `ShareCardCaptureService` throws exceptions with Arabic messages (e.g., "تعذر تجهيز بطاقة المشاركة." and "تعذر التقاط بطاقة المشاركة."). The helper strips the `Exception:` prefix and passes through the Arabic message. For unexpected errors, it falls back to a generic Arabic message.

### Overlay leak prevention

```dart
var inserted = false;
try {
  overlay.insert(entry);
  inserted = true;
  // ...
} catch (error) { ... }
finally {
  if (inserted) entry.remove();
}
```

The `inserted` flag ensures `entry.remove()` is only called if the entry was actually inserted. This prevents `StateError` from calling `remove()` on an entry that was never inserted.

**Verdict:** ✅ All error paths produce Arabic snackbars. Overlay is always cleaned up. No crash paths.

---

## Review Axis 7: Did it avoid protected files?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_controller.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `share_card_capture_service.dart` | Reused, not modified | ✅ 0 diff |
| `firestore.rules` | Untouched | ✅ 0 diff |
| Firestore indexes | Untouched | ✅ |
| Any leaderboard/tournament resolver | Untouched | ✅ 0 diff |

**Verdict:** ✅ Perfect isolation. 4 new files + 1 modified screen only.

---

## Review Axis 8: Are tests sufficient?

### Test inventory: 3 tests

**Unit test 1:** "maps tournament name and top five scorers"
- Seeds 6 scorers (index 2 is guest)
- Asserts: title is "هدافو البطولة", tournament name preserved, only 5 returned
- Asserts: rank sequence [1,2,3,4,5], scorer 2 `isGuest: true`, scorer 6 excluded

**Unit test 2:** "uses Arabic goal labels"
- Asserts: `1 هدف` (singular), `2 أهداف` (plural)

**Widget test 3:** "renders tournament, scorers, guest badge, and brand"
- Seeds 2 scorers: Ali (player, 1 goal) + ضيف هداف (guest, 3 goals)
- Pumps `TopScorersShareCard(data: data)`
- Finds: title, tournament name, player names, goal labels, "ضيف" badge, "الحريف" brand

### Coverage matrix

| Scenario | Covered? | How |
|---|---|---|
| Controller maps resolver → share data | ✅ | Test 1 |
| Limit enforced (5 max) | ✅ | Test 1 (6 input → 5 output) |
| Guest `isGuest` flag set correctly | ✅ | Test 1 (index 2) |
| Singular/plural goal labels | ✅ | Test 2 |
| Widget renders all elements | ✅ | Test 3 (find.text) |
| Guest badge rendered | ✅ | Test 3 (`find.text('ضيف')`) |
| Brand mark rendered | ✅ | Test 3 (`find.text('الحريف')`) |
| Empty name fallback ("لاعب") | ❌ | Not tested — see F1 |
| Empty tournament name fallback | ❌ | Not tested — see F1 |
| `_shareTopScorers` overlay flow | ❌ | Requires device — manual QA |
| Actual device share (share_plus) | ❌ | Requires device — manual QA |

### Missing test: empty name/tournament fallbacks

The controller handles empty display names (`→ 'لاعب'`) and empty tournament names (`→ 'بطولة الحريف'`), but neither is tested.

**Verdict:** ✅ Strong for a share card feature. Widget rendering and data mapping are tested. Overlay capture requires device testing.

---

## Review Axis 9: Is manual QA for actual device sharing documented?

### Existing documentation

A report file exists at `docs/Sprint1_Task9_Top_Scorers_Share_Card_Report.md` (untracked). I have not read its contents, but its presence suggests the implementer created a task report.

### Recommended manual QA checklist

| # | Scenario | How to test |
|---|---|---|
| 1 | Share button visible only with scorers | Open tournament with 0 matches |
| 2 | Share produces PNG with all elements | Tap "شارك الهدافين", check share sheet image |
| 3 | Guest badge visible in exported PNG | Share with a guest scorer in top 5 |
| 4 | Share text is Arabic with tournament name | Check share sheet text: "هدافو {name} على الحريف" |
| 5 | Overlay cleanup after share cancel | Cancel share sheet, verify no overlay artifacts |
| 6 | Overlay cleanup after share error | Airplane mode + share, verify snackbar + cleanup |
| 7 | RTL layout correct in PNG | Inspect the PNG — rank on right, goals on left |
| 8 | Card renders correctly with 1 scorer | Submit goals for 1 player only |
| 9 | Card renders correctly with 5 scorers | Submit goals for 5+ players |
| 10 | Long player names truncate correctly | Use a very long display name |

**Verdict:** ⚠️ No explicit manual QA checklist in the reviewed code. Task report may contain one. The checklist above should be used before production.

---

## Findings

### F1: Empty name fallbacks not tested — LOW

**Severity:** Low

`_displayName('')` → `'لاعب'` and empty tournament name → `'بطولة الحريف'` are implemented but not covered by tests. These are defensive edge cases unlikely to occur in practice (the resolver always returns `ParticipantRef` with populated `displayName`).

**Action:** Add 2 assertions to the controller test if convenient. Not blocking.

### F2: `exportLogicalHeight: 450` may be tight with 5 rows — LOW

**Severity:** Low

Each `_ShareScorerRow` occupies roughly 50px (10 margin + 10+10 padding + 20 text). Five rows ≈ 250px. With header (~100px) and footer (~30px), that's ~380px in a 450px frame. This should fit, but if a row overflows (long name + badge), the `maxLines: 1` + `overflow: TextOverflow.ellipsis` on names prevents visual overflow.

**Action:** Verify on device that 5 rows render without clipping. If tight, consider `exportLogicalHeight: 500`.

### F3: `matchResultShareExportPixelRatio` name implies match-only — INFO

**Severity:** Info

The constant `matchResultShareExportPixelRatio = 3.0` is used for the top scorers card too. The name suggests it's match-result-specific, but it's actually a generic export quality setting. A rename to `shareCardExportPixelRatio` would be cleaner but is cosmetic.

**Action:** None for V1. Track for a future naming cleanup.

### F4: Overlay `opacity: 0.01` not fully invisible — INFO

**Severity:** Info

`Opacity(opacity: 0.01)` renders the export card at 1% opacity. This is near-invisible but technically not `0.0`. Using `0.0` could cause Flutter to skip rendering entirely (optimization), which would break `toImage()`. The `0.01` value is an intentional workaround used across all share card flows in the codebase.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Serves pride/ego | ✅ Pass | Rank badges, TOP 5 chip, CTA tagline, premium dark aesthetic |
| 2. All required elements | ✅ Pass | Tournament name, title, ranks, names, goals, guest badge, brand |
| 3. CTA clear and gated | ✅ Pass | Button only with scorers, double guard with snackbar fallback |
| 4. Reuses capture infra | ✅ Pass | `ShareCardCaptureService` reused exactly, 0 diff |
| 5. No overreach | ✅ Pass | No navigation, no profile links, no preview dialog |
| 6. Error handling in Arabic | ✅ Pass | All snackbars Arabic, overlay always cleaned up |
| 7. Protected files untouched | ✅ Pass | 0 diff on all guarded components |
| 8. Tests sufficient | ✅ Pass | 3 tests covering data mapping + widget rendering |
| 9. Manual QA documented | ⚠️ Partial | 10-scenario checklist recommended above |

### Before production

1. Run the 10-scenario manual QA checklist on a real device.
2. Verify 5-row card fits in 450px export height (F2).
