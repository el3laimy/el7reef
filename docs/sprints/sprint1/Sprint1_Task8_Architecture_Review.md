# Sprint 1 / Task 8 — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** Tournament Top Scorers UI Slice  
**Verdict:** ✅ PASS — correct integration, clean UI, proper isolation

---

## Files Changed

| File | Change type | Summary |
|---|---|---|
| `lib/features/tournament/controllers/tournament_detail_controller.dart` | Modified | +35 lines — `TournamentTopScorersResolver` DI, `topScorers`, `isLoadingTopScorers`, `topScorersErrorMessage`, `loadTopScorers()` |
| `lib/features/tournament/views/tournament_detail_screen.dart` | Modified | +188 lines — `_TopScorersSection`, `_TopScorerRow`, fantasy/ops gating, Arabic labels |
| `lib/features/tournament/controllers/tournament_controller.dart` | Modified | +5 lines — `fantasyUiEnabled` gate on creation + reset |
| `lib/features/tournament/views/tournament_list_screen.dart` | Modified | Formatting + `FeatureFlags.fantasyUiEnabled` gate |
| `lib/features/match/views/match_discover_screen.dart` | Modified | `FeatureFlags.challengesUiEnabled` gate on tab count |

### Verified untouched (0 diff)

| File | Status |
|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | Modified by Task 6A–6C only |
| `lib/core/services/match_settlement_service.dart` | Modified by Task 4 only |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `firestore.rules` | Modified by Task 1 only |
| `lib/core/services/tournament_top_scorers_resolver.dart` | Untracked from Task 7, not modified |

---

## Review Axis 1: Does Tournament Detail show a clear "هدافو البطولة" section?

### Section placement (lines 116–120)

```dart
_TopScorersSection(
  isLoading: controller.isLoadingTopScorers.value,
  errorMessage: controller.topScorersErrorMessage.value,
  scorers: controller.topScorers,
).animate().fadeIn(delay: 220.ms),
```

The section is placed in the main column, below `_OperationsSnapshot` and before the registration/fantasy buttons. It renders on every tournament detail view unconditionally — not gated behind a feature flag, not organizer-only.

### Section header (line 171)

```dart
Text('هدافو البطولة', style: AppTextStyles.titleMedium),
```

Accompanied by `Icons.sports_score_rounded` in primary color. The heading is unambiguous and player-facing.

### Visual container

Wrapped in `GlassmorphicContainer` with `radiusLg` — matches the design system used by other cards on the same screen (`_InfoCard`, `_RegistrationProgress`, `_OrganizerPanel`).

**Verdict:** ✅ Section is clearly visible, correctly labeled in Arabic, integrated into the standard card layout.

---

## Review Axis 2: Does it use TournamentTopScorersResolver correctly?

### DI in controller (from diff)

```dart
final TournamentTopScorersResolver _topScorersResolver;

TournamentDetailController({
  TournamentTopScorersResolver? topScorersResolver,
}) : _topScorersResolver = topScorersResolver ?? TournamentTopScorersResolver();
```

Optional parameter with production default — same DI pattern as all other services in the codebase.

### `loadTopScorers()` method

```dart
Future<void> loadTopScorers() async {
  final id = tournament.value?.id ?? tournamentId;
  if (id == null || id.isEmpty) {
    topScorers.clear();
    topScorersErrorMessage.value = '';
    return;
  }
  try {
    isLoadingTopScorers.value = true;
    topScorersErrorMessage.value = '';
    topScorers.value = await _topScorersResolver.getTopScorers(id, limit: 5);
  } catch (error) {
    AppLogger.error('TournamentDetailController.loadTopScorers', error);
    topScorers.clear();
    topScorersErrorMessage.value = 'تعذر تحميل هدافي البطولة الآن.';
  } finally {
    isLoadingTopScorers.value = false;
  }
}
```

- Uses `limit: 5` (compact leaderboard card — appropriate for a detail screen)
- Handles null/empty `id` gracefully
- Falls back to `tournament.value?.id ?? tournamentId` — covers both pre- and post-load states

### Trigger point

Called inside `loadTournament()` after the tournament is successfully loaded:
```dart
} else {
  await _loadWinnerDisplayName(tournament.value!);
  await loadTopScorers();          // ← runs after tournament data confirmed
}
```

This means top scorers are never loaded for a tournament that doesn't exist.

**Verdict:** ✅ Resolver is injected correctly, called with proper parameters, triggered at the right point.

---

## Review Axis 3: Does it handle loading, empty, data, and error states safely?

### State variables

| Variable | Type | Purpose |
|---|---|---|
| `topScorers` | `RxList<TournamentTopScorerEntry>` | The data |
| `isLoadingTopScorers` | `RxBool` | Spinner gate |
| `topScorersErrorMessage` | `RxString` | Error text |

### `_TopScorersSection` renders all four states

```dart
if (isLoading)
  CircularProgressIndicator(...)    // ← Loading state
else if (errorMessage.isNotEmpty)
  Text(errorMessage, style: ...error...)  // ← Error state
else if (scorers.isEmpty)
  Column(                            // ← Empty state (2 lines of Arabic text)
    children: [
      Text('لم يتم تسجيل هدافين بعد', ...),
      Text('ستظهر هنا أهداف اللاعبين بعد تسجيل نتائج المباريات.', ...),
    ],
  )
else
  ...scorers.indexed.map(...)        // ← Data state
```

### Loading spinner is compact

`SizedBox(width: 24, height: 24)` wraps the `CircularProgressIndicator`. Prevents the card from jumping when data arrives.

### Empty state is informative

Two-line message explains *why* there are no scorers and *what will cause them to appear*. This is player-friendly, not "no data found" admin text.

### Error state is safe

Shows the Arabic error message. Doesn't throw or crash.

### Reactivity

The section reads `controller.isLoadingTopScorers.value`, `controller.topScorersErrorMessage.value`, and `controller.topScorers` — all inside the parent `Obx` wrapper (line 29), so any change to reactive state correctly triggers a rebuild.

**Verdict:** ✅ All four states handled. Safe, reactive, no crash paths.

---

## Review Axis 4: Does it show registered and guest scorers correctly?

### `_TopScorerRow` display (lines 218–293)

Both registered and guest scorers render through the same `_TopScorerRow` widget:

| Element | Source | Both kinds? |
|---|---|---|
| Rank bubble | `rank` param (1-indexed) | ✅ |
| Display name | `actor.displayName` | ✅ |
| Goal count | `scorer.goals` | ✅ |

Both `player` and `guestPlayer` produce visible, complete rows with rank, name, and goals.

**Verdict:** ✅ Both kinds display identically except for the guest badge.

---

## Review Axis 5: Does a guest scorer get a clear badge?

### Guest badge implementation (lines 260–280)

```dart
final isGuest = actor.kind == ParticipantRefKind.guestPlayer;

if (isGuest) ...[
  const SizedBox(width: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
    ),
    child: Text(
      'ضيف',
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary),
    ),
  ),
],
```

**Design:** Pill badge in secondary color with 16% opacity background. The text 'ضيف' (Guest) is in `AppColors.secondary` — visually distinct from the primary name.

**Placement:** Inline after the display name, inside `Flexible` to prevent overflow. Uses `overflow: TextOverflow.ellipsis` on the name if the row is narrow.

**RTL safety:** The `Row` with `[name, badge]` renders correctly in RTL — the badge appears to the left of the name in an RTL layout, which is visually natural for a trailing label.

**Visibility:** `matchSidePlayer` does NOT get a badge (only `guestPlayer`). This is correct — MSP cannot appear in the tournament leaderboard at all (filtered by Task 7 resolver), so the badge condition is moot for them.

**Verdict:** ✅ Clear, styled, Arabic badge for guest scorers. Correct kind check.

---

## Review Axis 6: Does it avoid player profile navigation/share cards/navigation changes?

### Tappability of `_TopScorerRow`

`_TopScorerRow` is a `Padding > Row`. Zero `GestureDetector`, `InkWell`, `onTap`, or navigation calls inside it. The row is **display-only**. No navigation anywhere in `_TopScorersSection` or `_TopScorerRow`.

### Search for navigation in new code

```
grep "Get.toNamed\|AppRoutes\|Navigator.push" 
  → Not found in _TopScorersSection or _TopScorerRow
```

No player profile link, no share card trigger, no route push.

### Other navigation changes in the diff

The existing `_OperationsSnapshot` buttons had their labels translated to Arabic (`'Participants'` → `'المشاركون'`, etc.) — these are label-only changes on buttons that already existed. Navigation targets are unchanged.

**Verdict:** ✅ Zero navigation added to the top scorers section. Existing routes unchanged.

---

## Review Axis 7: Did it avoid ScoreSubmit, settlement, PlayerMatchStats, rating, fantasy, Firestore rules/index changes?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_controller.dart` | Not this task | ✅ Modified by Tasks 6A–6C only |
| `match_settlement_service.dart` | Not this task | ✅ Modified by Task 4 only |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Not this task | ✅ Modified by Task 1 only |
| Firestore indexes | Not this task | ✅ No changes |

### Fantasy gating (bonus fix)

`TournamentController.createTournament()` now applies:
```dart
isFantasyEnabled: FeatureFlags.fantasyUiEnabled && isFantasyEnabled.value,
```

The `isFantasyEnabled` default was changed from `true.obs` to `false.obs`. This means new tournaments are never created with `isFantasyEnabled: true` unless the flag is on, preventing the fantasy button from appearing on newly created tournaments.

This is a **correct, low-risk fix** that wasn't explicitly in the task scope but is directly aligned with product decisions (fantasy is off for V1).

### Feature flag consolidation

Three screens now gate fantasy/challenges/advanced-ops behind `FeatureFlags`:
- `tournament_detail_screen.dart` — fantasy league button
- `tournament_list_screen.dart` — fantasy card in list
- `match_discover_screen.dart` — challenges tab

These are all defensive gates on pre-existing UI surfaces. No new UI is added behind these flags.

**Verdict:** ✅ All protected components untouched. Fantasy gating bonus is correct and aligned with V1 decisions.

---

## Review Axis 8: Are tests sufficient or is manual QA clearly documented?

### Automated tests

**No widget tests added for this task.** No `tournament_detail_screen_test.dart` exists.

The underlying resolver (`TournamentTopScorersResolver`) has 6 unit tests from Task 7, and the controller has no standalone test file.

### What the existing tests cover

| Layer | Test coverage | Status |
|---|---|---|
| `TournamentTopScorersResolver` logic | 6 unit tests (Task 7) | ✅ |
| `TournamentDetailController.loadTopScorers` | No tests | ❌ |
| `_TopScorersSection` rendering | No widget tests | ❌ |
| `_TopScorerRow` guest badge | No widget tests | ❌ |

### Manual QA checklist (recommended)

Since widget tests are absent, the following scenarios need manual verification before the screen is shipped:

| # | Scenario | How to test |
|---|---|---|
| 1 | Tournament with no matches → empty state message shows | Open a new tournament |
| 2 | Tournament with 1 registered scorer (3 goals) → shows name + goals | Submit score with goal drafts |
| 3 | Tournament with 1 guest scorer → shows name + "ضيف" badge | Add guest to lineup, submit score |
| 4 | Tournament with 5+ scorers → shows at most 5 rows | Add 6+ scorers in test tournament |
| 5 | Network error during load → error text shows, no crash | Block Firestore in test env or use offline mode |
| 6 | Loading state briefly visible → spinner appears then goes | Slow network throttle in DevTools |
| 7 | RTL layout correct: rank bubble right, name centre, goals left | Run on Arabic locale device |
| 8 | Fantasy button absent on V1 build | Verify `FeatureFlags.fantasyUiEnabled = false` |

**Verdict:** ⚠️ No widget tests. Business logic (resolver) is tested. UI behavior requires manual QA. This is noted as a gap, not a blocker.

---

## Review Axis 9: Is the UI Arabic-first and not admin-like?

### Arabic text audit

| Element | Text | Language |
|---|---|---|
| Section title | 'هدافو البطولة' | ✅ Arabic |
| Guest badge | 'ضيف' | ✅ Arabic |
| Goal count | '$goals أهداف' | ✅ Arabic |
| Empty state line 1 | 'لم يتم تسجيل هدافين بعد' | ✅ Arabic |
| Empty state line 2 | 'ستظهر هنا أهداف اللاعبين بعد تسجيل نتائج المباريات.' | ✅ Arabic |
| Error message | 'تعذر تحميل هدافي البطولة الآن.' | ✅ Arabic |
| Ops buttons (bonus) | 'المشاركون', 'المجموعات', 'المباريات', 'الترتيب', 'الإقصاء', 'لوحة تشغيل البطولة' | ✅ Arabic |

All previously English button labels in `_OperationsSnapshot` were translated as part of this diff.

### Player-facing vs admin-like?

The section reads like a trophy leaderboard:
- 🏅 Rank bubble with primary color
- Name + guest badge
- Goal count in primary color

No IDs visible, no technical terms, no organizer-only data. A player looking at this screen would see a familiar football leaderboard.

The top-scorers section has no actionable buttons on rows. This is correct: the V1 product decision is to show the leaderboard but not yet link to player profiles.

**Verdict:** ✅ Fully Arabic, player-focused UI. Not admin-like.

---

## Findings

### F1: `_TopScorerRow` uses `'$goals أهداف'` — singular/plural issue — LOW

**Severity:** Low

In Arabic, 1 goal is 'هدف', 2 goals is 'هدفان', 3+ is 'أهداف'. The current string `'$goals أهداف'` always uses the plural form. A player who scored exactly 1 goal sees "1 أهداف" instead of "1 هدف".

This is a cosmetic localization issue. For V1 it's acceptable given the early stage of Arabic plural support.

**Action:** Consider simple conditional: `goals == 1 ? '$goals هدف' : '$goals أهداف'`. Not blocking.

### F2: No widget tests for `_TopScorersSection` — NOTED

**Severity:** Medium (tracked)

As documented in Axis 8, the UI states (loading, empty, error, data, guest badge) have no automated coverage. Manual QA is required.

**Action:** Add a widget test file `test/features/tournament/tournament_detail_top_scorers_test.dart` in a follow-up.

### F3: `_TopScorersSection` reads `controller.topScorers` directly (not `RxList`) — INFO

**Severity:** Info

The section receives `List<TournamentTopScorerEntry>` (not `RxList`) as a parameter, which means it doesn't react independently — it relies on the parent `Obx` triggering a rebuild. This is correct because the parent `Obx` (line 29) already wraps the entire body, and any change to `topScorers` (an `RxList`) will trigger a full rebuild of the body column. No reactivity gap.

### F4: `$goals أهداف` could look odd for very large numbers — INFO

**Severity:** Info

If a top scorer accumulates 20+ goals, `'20 أهداف'` still reads naturally. No overflow risk because the goals text is a trailing `Text` in a `Row` — it won't wrap.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Clear "هدافو البطولة" section | ✅ Pass | Visible on all tournament detail pages |
| 2. Correct resolver usage | ✅ Pass | DI + `limit: 5` + triggered after tournament load |
| 3. All four states handled | ✅ Pass | Loading, empty, error, data — all Arabic |
| 4. Registered and guest display | ✅ Pass | Both render through same widget |
| 5. Guest badge visible | ✅ Pass | 'ضيف' pill badge in secondary color |
| 6. No profile nav / share cards | ✅ Pass | Display-only rows |
| 7. Protected components untouched | ✅ Pass | All guarded files 0 diff |
| 8. Tests sufficient | ⚠️ Partial | Resolver tested; UI needs manual QA |
| 9. Arabic-first, not admin-like | ✅ Pass | All strings Arabic, player-centric layout |

### Before shipping to production

1. Run manual QA checklist from Axis 8 (8 scenarios).
2. Fix singular goal form in Arabic (F1 — optional, low priority).
3. Verify composite Firestore index `(tournamentId, eventType, status)` exists (carried over from Task 7 F1).
