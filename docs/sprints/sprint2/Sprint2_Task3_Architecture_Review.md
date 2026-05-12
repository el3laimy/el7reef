# Sprint 2 / Task 3 — Architecture Review

**Reviewed:** 2026-05-05  
**Scope:** Link Top Scorers Rows to Public Player Profile  
**Verdict:** ✅ PASS — minimal, well-guarded, tested with real navigation

---

## Files Changed

| File | Delta | Summary |
|---|---|---|
| `lib/features/tournament/views/tournament_detail_screen.dart` | +58 net lines (within the overall +170 from previous tasks) | `_TopScorerRow` wrapped in `InkWell`, `_canOpenPublicProfile`, `_openPublicProfile`, chevron indicator |
| `test/features/tournament/tournament_operations_dashboard_test.dart` | +48 lines | 2 new widget tests + stub route for player profile + assertions for share CTA visibility |

### Verified untouched (0 diff from HEAD)

| File | Status |
|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/features/shareables/services/share_card_capture_service.dart` | ✅ Clean |
| `firestore.rules` | ✅ Clean |

---

## Review Axis 1: Are only player and guestPlayer top scorer rows tappable?

### Guard logic (lines 392–396)

```dart
bool _canOpenPublicProfile(ParticipantRef actor) {
  if (actor.id.trim().isEmpty) return false;
  return actor.kind == ParticipantRefKind.player ||
      actor.kind == ParticipantRefKind.guestPlayer;
}
```

### What this rejects

| Actor kind | `_canOpenPublicProfile` | InkWell tappable? |
|---|---|---|
| `player` | ✅ `true` | Yes — navigates |
| `guestPlayer` | ✅ `true` | Yes — navigates |
| `matchSidePlayer` | ❌ `false` | No — `onTap: null` |
| Any kind, empty ID | ❌ `false` | No — `onTap: null` |

### InkWell binding (line 312)

```dart
InkWell(
  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
  onTap: canOpenProfile ? () => _openPublicProfile(actor) : null,
  ...
)
```

When `onTap` is `null`, the `InkWell` is inert — no ripple, no click handler. The row is visually identical but non-interactive.

### Consistency with resolver

The public profile resolver (Task 2) also returns `null` for `matchSidePlayer` via its `_parseKind` method and `switch` dispatch. So even if a `matchSidePlayer` somehow navigated to the route, the profile screen would show "تعذر العثور على هذا اللاعب." — safe at both ends.

### Top scorers resolver filter

The `TournamentTopScorersResolver` (Task 7) already excludes `matchSidePlayer` from tournament leaderboards. So in practice, no `matchSidePlayer` should appear in the top scorers list. The `_canOpenPublicProfile` guard is defense-in-depth.

**Verdict:** ✅ Only `player` and `guestPlayer` rows are tappable. `matchSidePlayer` and empty IDs are excluded. Triple-guarded (resolver filter + row guard + profile resolver).

---

## Review Axis 2: Does navigation use AppRoutes.playerProfileByKindAndId?

### Navigation call (lines 398–406)

```dart
void _openPublicProfile(ParticipantRef actor) {
  if (!_canOpenPublicProfile(actor)) return;
  Get.toNamed(
    AppRoutes.playerProfileByKindAndId(
      kind: actor.kind.name,
      id: actor.id.trim(),
    ),
  );
}
```

- Uses `AppRoutes.playerProfileByKindAndId` — the typed helper from Task 2
- Passes `actor.kind.name` (enum `.name` → `'player'` or `'guestPlayer'`)
- Trims the ID before passing
- Double-checks `_canOpenPublicProfile` before navigating

### Route resolution

`playerProfileByKindAndId(kind: 'player', id: 'abc')` → `/player/player/abc`  
`playerProfileByKindAndId(kind: 'guestPlayer', id: 'xyz')` → `/player/guestPlayer/xyz`

These match the route pattern `/player/:kind/:id` registered in `app_pages.dart` with `PublicPlayerProfileBinding`.

**Verdict:** ✅ Uses the correct typed route helper. No raw route strings.

---

## Review Axis 3: Are invalid/unsupported actors guarded safely?

### Guard chain

1. **`_canOpenPublicProfile`** — returns `false` for `matchSidePlayer` or empty ID → `InkWell.onTap = null`
2. **`_openPublicProfile`** — re-checks `_canOpenPublicProfile` before `Get.toNamed` (double guard)
3. **Route binding** — `PublicPlayerProfileBinding` passes `kind` and `id` from route params (defaults to `''` if missing)
4. **Resolver** — `_parseKind` returns `null` for invalid kinds, `resolve` returns `null` for empty IDs
5. **Controller** — shows "تعذر العثور على هذا اللاعب." for `null` profile

### Edge cases

| Scenario | Result |
|---|---|
| `matchSidePlayer` in top scorers (impossible per resolver) | Row not tappable |
| Actor with empty ID after trim | Row not tappable |
| Navigating to profile of deleted player | Profile screen shows Arabic error |
| Route params somehow missing | Binding defaults to `''`, resolver returns `null` |

**Verdict:** ✅ Five layers of defense. No crash path.

---

## Review Axis 4: Is the UI still clean, Arabic-first, and not cluttered?

### What changed visually

**Before (Task 8):**
```
[rank]  Name  [ضيف]  ...  X أهداف
```
Static row, no interaction.

**After (Task 3):**
```
[rank]  Name  [ضيف]  ...  X أهداف  <
```
Interactive row with:
- `InkWell` — provides ripple feedback on tap
- Chevron indicator (`chevron_left_rounded`, 20px, 72% opacity) — RTL-correct arrow pointing left (toward the detail screen)

### Chevron visibility

```dart
if (canOpenProfile) ...[
  const SizedBox(width: 6),
  Icon(
    Icons.chevron_left_rounded,
    size: 20,
    color: AppColors.textSecondary.withValues(alpha: 0.72),
  ),
],
```

The chevron only appears on tappable rows. Non-tappable rows (if any `matchSidePlayer` somehow appeared) would not show a chevron — no false affordance.

### Chevron direction: RTL-correct

`chevron_left_rounded` points left. In RTL layout, "forward" navigation arrows point left (the opposite of LTR). This is the correct direction.

### Inner padding

The `InkWell` wraps an inner `Padding(vertical: 6)` which combines with the outer `Padding(vertical: 6)` for a total of 12px vertical padding per row. This gives comfortable tap targets (~40px height) without feeling bloated.

### Arabic text unchanged

All existing labels (rank, display name, "ضيف" badge, goal count) remain untouched. No English text was added. The section title "هدافو البطولة" is unchanged.

**Verdict:** ✅ Clean addition. The chevron is subtle, RTL-correct, and only shows when the row is actionable. No clutter.

---

## Review Axis 5: Does the share CTA remain intact?

### Share button code (lines 277–285)

```dart
const SizedBox(height: AppDimensions.sm),
Align(
  alignment: AlignmentDirectional.centerStart,
  child: OutlinedButton.icon(
    onPressed: onShare,
    icon: const Icon(Icons.ios_share_rounded),
    label: const Text('شارك الهدافين'),
  ),
),
```

Still present, still in the `else` branch (only when scorers exist), still receives `onShare` callback from `_shareTopScorers`.

### Test evidence

The test diff includes:
```dart
// Empty state test:
expect(find.text('شارك الهدافين'), findsNothing);     // ← share hidden when empty

// Data state test:
expect(find.text('شارك الهدافين'), findsOneWidget);    // ← share visible with scorers
```

Both assertions were added in this task, confirming share CTA visibility is tested alongside the new navigation.

### Share flow in `_shareTopScorers`

The `_shareTopScorers` method (lines 153–211) is untouched from Task 9. It still uses `TopScorersShareController`, `ShareCardCaptureService`, and the overlay capture pattern.

**Verdict:** ✅ Share CTA fully intact. New test assertions confirm it.

---

## Review Axis 6: Did it avoid protected components?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_controller.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Untouched | ✅ 0 diff |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `share_card_capture_service.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Untouched | ✅ 0 diff |
| `match_event_service.dart` | Modified in Task 2 only | ✅ No additional changes |
| Any MatchEvent write call | None | ✅ 0 occurrences of `createEvent`/`voidEvent`/`writeEvent` |

### Scope of changes

Only one production file was modified: `tournament_detail_screen.dart`. The change is purely UI: wrapping an existing `_TopScorerRow` in an `InkWell` and adding a navigation callback. No data writes, no service calls, no state mutations.

**Verdict:** ✅ Perfect isolation. One screen file modified with read-only navigation.

---

## Review Axis 7: Are tests sufficient or manual QA documented?

### Test inventory: 2 new widget tests + 2 new assertions

**Widget test 1:** "registered top scorer row opens public player profile"
- Seeds goal events via `_seedTopScorerGoals`
- Pumps tournament detail screen
- Scrolls to and taps "Ali Scorer" text
- Asserts navigation reached profile screen: `'profile:player:player-scorer'`

**Widget test 2:** "guest top scorer row opens public guest profile"
- Same seeding
- Taps "ضيف هداف" text
- Asserts navigation: `'profile:guestPlayer:guest-scorer'`

**Assertion 1 (existing test):** Empty state → `find.text('شارك الهدافين'), findsNothing`

**Assertion 2 (existing test):** Data state → `find.text('شارك الهدافين'), findsOneWidget`

### Test infrastructure

A stub route was added to the test app:
```dart
GetPage(
  name: AppRoutes.playerProfile,
  page: () => Scaffold(
    body: Text(
      'profile:${Get.parameters['kind']}:${Get.parameters['id']}',
    ),
  ),
),
```

This captures both `kind` and `id` parameters, allowing the test to verify that navigation passes the correct values through to the route.

### Coverage matrix

| Scenario | Covered? | How |
|---|---|---|
| Registered player row → opens profile | ✅ | Test 1 |
| Guest player row → opens profile | ✅ | Test 2 |
| Share button visible with scorers | ✅ | Assertion 2 |
| Share button absent without scorers | ✅ | Assertion 1 |
| matchSidePlayer row not tappable | ❌ | Not tested directly — but MSP is excluded from leaderboard by resolver (Task 7 tests) |
| Empty ID row not tappable | ❌ | Not tested — edge case |
| Chevron visible only on tappable rows | ❌ | Not tested — visual |
| RTL chevron direction | ❌ | Not tested — visual |

### Missing: matchSidePlayer row not tappable

This is not directly tested, but it's triple-guarded:
1. `TournamentTopScorersResolver` excludes MSP from results (tested in Task 7)
2. `_canOpenPublicProfile` returns `false` for MSP
3. `PublicPlayerProfileResolver` returns `null` for MSP (tested in Task 2)

**Verdict:** ✅ Both happy paths (player + guest navigation) are tested with real route parameter verification. Share CTA visibility also tested. Minor gaps are covered by upstream guards.

---

## Findings

### F1: Inner padding doubles the vertical spacing — LOW

**Severity:** Low

The row now has:
- Outer `Padding(vertical: 6)` (line 307, from original design)
- Inner `Padding(vertical: 6)` (line 314, inside InkWell)

Total: 12px vertical padding per row. The original design had 6px. This makes each row slightly taller.

This is likely intentional — the `InkWell` needs adequate touch target height (minimum ~48px is recommended by Material). With 12px padding + row content (~28px), the tap target is ~52px, which is good.

**Action:** Verify on device that spacing between rows looks natural. Not blocking.

### F2: Chevron icon could be confused with navigation "back" — INFO

**Severity:** Info

`Icons.chevron_left_rounded` in an RTL layout means "go forward/deeper." This is the correct convention, but users unfamiliar with RTL conventions might briefly interpret it as "go back." This is a standard Material Design pattern in RTL apps and not a real issue.

### F3: No test for non-tappable row — LOW

**Severity:** Low

No test explicitly verifies that a `matchSidePlayer` row (if it appeared) would not trigger navigation. In practice, MSPs never appear in the top scorers list (filtered by resolver), so this is purely theoretical.

**Action:** Could add a unit test for `_canOpenPublicProfile` if it were extracted to a testable function, but it's a private method inside a widget. Not worth testing directly.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Only player + guestPlayer tappable | ✅ Pass | Guard checks kind + non-empty ID |
| 2. Uses AppRoutes helper | ✅ Pass | `playerProfileByKindAndId(kind:, id:)` |
| 3. Invalid actors guarded | ✅ Pass | Five-layer defense chain |
| 4. UI clean, Arabic, not cluttered | ✅ Pass | Subtle chevron, proper tap targets, RTL-correct |
| 5. Share CTA intact | ✅ Pass | Unchanged code + new test assertions |
| 6. Protected files untouched | ✅ Pass | All 0 diff, no event writes |
| 7. Tests sufficient | ✅ Pass | 2 navigation tests + 2 share visibility assertions |

### Before production

1. Verify row spacing (F1) on a real device — visual check only.
2. Ensure the Firestore composite index `(actor.kind ASC, actor.id ASC, status ASC)` from Task 2 is deployed (the profile route must work when tapped).
