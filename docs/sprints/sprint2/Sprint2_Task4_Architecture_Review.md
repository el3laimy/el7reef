# Sprint 2 / Task 4 — Architecture Review

**Reviewed:** 2026-05-05  
**Scope:** Link MVP Result CTA to Public Player Profile  
**Verdict:** ✅ PASS — correct priority chain, all actor kinds handled, strong test suite

---

## Files Changed

### Modified files

| File | Delta | Summary |
|---|---|---|
| `lib/features/lineup/controllers/match_result_lineup_controller.dart` | +146 lines | `MvpPublicProfileTarget`, `mvpProfileTarget`, MVP share helpers, `_profileTargetForKindAndId` |
| `lib/features/lineup/views/match_result_lineup_screen.dart` | +123 lines | "شارك نجم المباراة" share CTA, "افتح بروفايل النجم" profile CTA, `_shareMvp`, `_buildMvpShareData`, `_openMvpProfile` |
| `lib/features/lineup/bindings/lineup_binding.dart` | +6 lines | `MatchEventService` + `TournamentRepositoryImpl` DI wiring |

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `test/features/lineup/match_result_lineup_controller_test.dart` | 476 | 17 tests: controller helpers + widget navigation |

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

## Review Axis 1: Does the MVP profile CTA appear only when a safe profile target exists?

### CTA rendering (screen lines 117–127)

```dart
if (_mvpProfileTarget != null) ...[
  const SizedBox(height: AppDimensions.xs),
  Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: _openMvpProfile,
      icon: const Icon(Icons.person_search_rounded),
      label: const Text('افتح بروفايل النجم'),
    ),
  ),
],
```

The profile CTA is gated on `_mvpProfileTarget != null`. This getter delegates to `controller.mvpProfileTarget`.

### `mvpProfileTarget` resolution (controller diff)

```dart
MvpPublicProfileTarget? get mvpProfileTarget {
  // Priority 1: MatchEvent actor
  final event = mvpEvent.value;
  if (event != null) {
    return _profileTargetForKindAndId(event.actor.kind, event.actor.id);
  }

  // Priority 2: Match.mvpPlayerId → lineup entry inference
  final mvpPlayerId = match.value?.mvpPlayerId?.trim();
  if (mvpPlayerId == null || mvpPlayerId.isEmpty) return null;
  final entry = _lineupEntryForParticipantId(mvpPlayerId);
  if (entry?.playerId != null) {
    return _profileTargetForKindAndId(
      ParticipantRefKind.player, entry!.playerId!);
  }
  if (entry?.guestPlayerId != null) {
    return _profileTargetForKindAndId(
      ParticipantRefKind.guestPlayer, entry!.guestPlayerId!);
  }
  return null;
}
```

### `_profileTargetForKindAndId` guard

```dart
MvpPublicProfileTarget? _profileTargetForKindAndId(
  ParticipantRefKind kind, String id,
) {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) return null;
  if (kind == ParticipantRefKind.player ||
      kind == ParticipantRefKind.guestPlayer) {
    return MvpPublicProfileTarget(kind: kind, id: normalizedId);
  }
  return null;
}
```

### What returns `null` (no CTA):

| Scenario | Why |
|---|---|
| No MVP event + no `mvpPlayerId` | No data at all |
| `matchSidePlayer` MVP event | Kind rejected by `_profileTargetForKindAndId` |
| Empty actor ID | ID rejected by trim check |
| Legacy `mvpPlayerId` not in any lineup snapshot | No `_lineupEntryForParticipantId` match → `null` |

### What returns a target (CTA visible):

| Scenario | Kind | ID source |
|---|---|---|
| Registered player MVP event | `player` | `event.actor.id` |
| Guest player MVP event | `guestPlayer` | `event.actor.id` |
| Legacy `mvpPlayerId` matching a `playerId` in snapshot | `player` | `entry.playerId` |
| Legacy `mvpPlayerId` matching a `guestPlayerId` in snapshot | `guestPlayer` | `entry.guestPlayerId` |

**Verdict:** ✅ CTA only appears when a navigable profile target exists. All non-profile actor kinds and missing IDs produce `null`.

---

## Review Axis 2: Does it prefer MVP MatchEvent actor kind/id?

### Priority order in `mvpProfileTarget`

```
1. mvpEvent != null → use event.actor.kind, event.actor.id
2. Match.mvpPlayerId → scan lineup entries → infer kind from entry fields
3. No match → return null
```

The MatchEvent path is checked **first**. Only if `mvpEvent.value` is `null` does the fallback kick in.

### Why this matters

The MatchEvent carries the authoritative `ParticipantRef` with the correct `kind`. The legacy `Match.mvpPlayerId` is a raw string that might be a `playerId`, `guestPlayerId`, or even a `matchSidePlayerId`. The snapshot inference (scanning `entry.playerId` / `entry.guestPlayerId`) is an educated guess. The event path avoids this ambiguity entirely.

### Test evidence

"mvpProfileTarget prefers registered MVP event actor" (test line 168–181):
```dart
controller.mvpEvent.value = _mvpEvent(
  kind: ParticipantRefKind.player, id: 'player-mvp');
final target = controller.mvpProfileTarget;
expect(target!.kind, ParticipantRefKind.player);
expect(target.id, 'player-mvp');
```

**Verdict:** ✅ MatchEvent is the primary source. Legacy `mvpPlayerId` is fallback only.

---

## Review Axis 3: Does it use AppRoutes.playerProfileByKindAndId?

### Navigation call (screen lines 197–203)

```dart
void _openMvpProfile() {
  final target = controller.mvpProfileTarget;
  if (target == null) return;
  Get.toNamed(
    AppRoutes.playerProfileByKindAndId(kind: target.kind.name, id: target.id),
  );
}
```

- Uses the typed `AppRoutes.playerProfileByKindAndId` helper
- Passes enum `.name` (e.g., `'player'` or `'guestPlayer'`)
- ID is already trimmed by `_profileTargetForKindAndId`
- Null guard at the top prevents navigation when no target exists

### Test evidence

The test app registers a stub route that captures parameters:
```dart
GetPage(
  name: AppRoutes.playerProfile,
  page: () => Scaffold(
    body: Text('profile:${Get.parameters['kind']}:${Get.parameters['id']}'),
  ),
),
```

Tests assert: `'profile:player:player-mvp'` and `'profile:guestPlayer:guest-mvp'`.

**Verdict:** ✅ Correct helper used, verified by test parameter capture.

---

## Review Axis 4: Are guest and registered MVPs supported?

### Registered player MVP

**Event path:** `event.actor.kind == player` → `_profileTargetForKindAndId(player, id)` → target
**Legacy path:** `entry.playerId != null` → `_profileTargetForKindAndId(player, entry.playerId)` → target

**Test:** "registered MVP event opens public player profile" (test line 256–279)

### Guest player MVP

**Event path:** `event.actor.kind == guestPlayer` → `_profileTargetForKindAndId(guestPlayer, id)` → target
**Legacy path:** `entry.guestPlayerId != null` → `_profileTargetForKindAndId(guestPlayer, entry.guestPlayerId)` → target

**Tests:**
- Controller: "mvpProfileTarget supports guest MVP event actor" (line 183–196)
- Controller: "mvpProfileTarget infers legacy guest MVP from snapshot" (line 228–244)
- Widget: "guest MVP event opens public guest profile" (line 281–299)

### Coverage

| Actor kind | Event path tested? | Legacy path tested? | Widget navigation tested? |
|---|---|---|---|
| `player` | ✅ | ✅ | ✅ |
| `guestPlayer` | ✅ | ✅ | ✅ |
| `matchSidePlayer` | ✅ (rejected) | N/A | ✅ (hidden) |

**Verdict:** ✅ Both kinds fully supported and tested via both data sources.

---

## Review Axis 5: Are matchSidePlayer/invalid IDs guarded?

### `_profileTargetForKindAndId` rejection

```dart
if (kind == ParticipantRefKind.player ||
    kind == ParticipantRefKind.guestPlayer) {
  return MvpPublicProfileTarget(kind: kind, id: normalizedId);
}
return null;   // ← matchSidePlayer, or any unknown kind
```

### Empty ID rejection

```dart
final normalizedId = id.trim();
if (normalizedId.isEmpty) return null;
```

### `_openMvpProfile` null guard

```dart
void _openMvpProfile() {
  final target = controller.mvpProfileTarget;
  if (target == null) return;   // ← no navigation
  ...
}
```

### Test evidence for matchSidePlayer rejection

"mvpProfileTarget rejects match-side MVP event actor" (test line 198–208):
```dart
controller.mvpEvent.value = _mvpEvent(
  kind: ParticipantRefKind.matchSidePlayer, id: 'msp-mvp');
expect(controller.mvpProfileTarget, isNull);
expect(controller.hasShareableMvp, isTrue);  // ← share still works!
```

**Critical distinction:** A `matchSidePlayer` MVP can still be **shared** (via the share card) but cannot be **navigated to** (no profile). This is the correct behavior — temporary match-side players have no persistent identity but their achievement is still worth sharing.

"match-side MVP keeps share CTA but hides profile CTA" (test line 314–332):
```dart
expect(find.text('شارك نجم المباراة'), findsOneWidget);   // ← share visible
expect(find.text('افتح بروفايل النجم'), findsNothing);     // ← profile hidden
```

### Test for unknown legacy MVP

"mvpProfileTarget does not infer unknown legacy MVP kind" (test line 246–252):
```dart
controller.match.value = _match(mvpPlayerId: 'legacy-mvp');
expect(controller.mvpProfileTarget, isNull);    // ← no snapshot match → null
expect(controller.hasShareableMvp, isTrue);     // ← share still works
```

**Verdict:** ✅ `matchSidePlayer` explicitly rejected. Empty IDs rejected. Unknown legacy IDs produce `null`. All cases tested.

---

## Review Axis 6: Is the UI compact and Arabic-first?

### CTA placement

```
┌─────────────────────────────────────┐
│  [FilledButton.icon] شارك النتيجة   │  ← if scores exist
│  [OutlinedButton.icon] شارك نجم     │  ← if MVP exists (share)
│     المباراة                        │
│  [TextButton.icon] افتح بروفايل     │  ← if profile target exists
│     النجم                           │
└─────────────────────────────────────┘
```

Three CTAs, hierarchically styled:
1. **FilledButton** — primary action (share result)
2. **OutlinedButton** — secondary action (share MVP)
3. **TextButton** — tertiary action (open profile)

The profile CTA is intentionally the smallest, least prominent button. It uses `TextButton.icon` (no fill, no border) with `person_search_rounded` icon. This is compact and doesn't compete with the share buttons.

### Spacing

```dart
if (_hasShareableMvp) ...[
  const SizedBox(height: AppDimensions.sm),     // 8px above share MVP
  ...
],
if (_mvpProfileTarget != null) ...[
  const SizedBox(height: AppDimensions.xs),     // 4px above profile CTA
  ...
],
```

Profile CTA uses `xs` (4px) spacing vs. `sm` (8px) for the share CTA — keeping it visually grouped with the MVP section but not adding excessive height.

### Arabic text

| Element | Text |
|---|---|
| Share MVP button | 'شارك نجم المباراة' |
| Profile CTA | 'افتح بروفايل النجم' |
| No match error | 'لا توجد بيانات مباراة لمشاركتها.' |
| No MVP error | 'لا يوجد نجم مباراة لمشاركته بعد.' |
| Share overlay error | 'تعذر تجهيز نافذة المشاركة.' |
| Generic error | 'تعذر تجهيز بطاقة المشاركة.' |

All Arabic. No English labels in the user-facing UI.

### Alignment

```dart
Align(
  alignment: AlignmentDirectional.centerStart,
  child: TextButton.icon(...)
)
```

`AlignmentDirectional.centerStart` = right-aligned in RTL. The button starts at the natural reading origin for Arabic.

**Verdict:** ✅ Compact, hierarchical, Arabic-first. Profile CTA is the least prominent of three actions.

---

## Review Axis 7: Does "شارك نجم المباراة" remain intact?

### Share CTA code (screen lines 103–115)

```dart
if (_hasShareableMvp) ...[
  const SizedBox(height: AppDimensions.sm),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => _shareMvp(context),
      icon: const Icon(Icons.workspace_premium_rounded),
      label: const Text('شارك نجم المباراة'),
    ),
  ),
],
```

### `_hasShareableMvp` (screen line 193)

```dart
bool get _hasShareableMvp => controller.hasShareableMvp;
```

### `_shareMvp` (screen lines 256–306)

Full overlay capture/share flow with `MvpShareCard`, `ShareCardCaptureService`, error handling. Identical pattern to the match result share flow.

### Independence from profile CTA

The share CTA and profile CTA are **completely independent**:
- Share CTA: gated on `_hasShareableMvp` — requires MVP event OR `mvpPlayerId`
- Profile CTA: gated on `_mvpProfileTarget` — requires MVP event OR snapshot-inferred identity with `player`/`guestPlayer` kind

A `matchSidePlayer` MVP will show the share button but NOT the profile button. This is tested:
```dart
expect(find.text('شارك نجم المباراة'), findsOneWidget);    // share visible
expect(find.text('افتح بروفايل النجم'), findsNothing);      // profile hidden
```

### Test evidence

- "no MVP hides profile CTA" (test line 301–312): both buttons absent
- "match-side MVP keeps share CTA but hides profile CTA" (test line 314–332): share visible, profile hidden
- "registered MVP event opens public player profile" (test line 256–279): both buttons visible

**Verdict:** ✅ Share CTA fully intact and independent from the profile CTA. Both can appear, only share can appear, or neither.

---

## Review Axis 8: Did it avoid protected components?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_controller.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Untouched | ✅ 0 diff |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `share_card_capture_service.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Untouched | ✅ 0 diff |
| `match_event_service.dart` | Modified in Task 2 only | ✅ No additional changes from Task 4 |
| MatchEvent writes in screen | None | ✅ No `createEvent`/`voidEvent` calls |
| `firestore.indexes.json` | Modified in Task 2 | ✅ Actor query index (not from Task 4) |

### Binding changes

`lineup_binding.dart` adds `MatchEventService` and `TournamentRepositoryImpl` to the DI graph for `MatchResultLineupBinding`. This is required because the controller's constructor now expects them (added in the controller diff). No new services are created — existing ones are re-used via `Get.find`.

**Verdict:** ✅ Perfect isolation. All changes are read-only UI + controller logic. No data mutations.

---

## Review Axis 9: Are tests sufficient or manual QA documented?

### Test inventory: 17 tests (13 controller + 4 widget)

#### Controller helper tests (13)

| # | Test | Exercises |
|---|---|---|
| 1 | hasShareableMvp true when mvpEvent exists | Event-based detection |
| 2 | hasShareableMvp true when Match.mvpPlayerId exists | Legacy detection |
| 3 | hasShareableMvp false when no MVP exists | No false positives |
| 4 | displayNameForParticipantId resolves snapshot entry | Lineup entry lookup |
| 5 | displayNameForParticipantId resolves match-side player | Fallback lookup |
| 6 | isGuestParticipantId identifies guests safely | Guest detection |
| 7 | sideKeyForParticipantId resolves direct sideKey | Snapshot sideKey field |
| 8 | sideKeyForParticipantId resolves teamId mapping | Team A/B inference |
| 9 | sideKeyForParticipantId resolves matchSideId pattern | Pattern fallback |
| 10 | Unknown participants return null/false | No false positives |
| 11 | mvpProfileTarget prefers registered MVP event actor | Priority + registered |
| 12 | mvpProfileTarget supports guest MVP event actor | Priority + guest |
| 13 | mvpProfileTarget rejects match-side MVP event actor | matchSidePlayer guard |
| 14 | mvpProfileTarget infers legacy registered MVP | Snapshot inference |
| 15 | mvpProfileTarget infers legacy guest MVP | Snapshot inference |
| 16 | mvpProfileTarget does not infer unknown legacy MVP | No snapshot match |

#### Widget navigation tests (4)

| # | Test | Exercises |
|---|---|---|
| 17 | Registered MVP → opens player profile | Navigation + parameter capture |
| 18 | Guest MVP → opens guest profile | Navigation + parameter capture |
| 19 | No MVP → hides both CTAs | Absence check |
| 20 | matchSidePlayer MVP → share visible, profile hidden | Independent CTA behavior |

### Coverage matrix

| Scenario | Controller tested? | Widget tested? |
|---|---|---|
| Registered MVP (event) | ✅ | ✅ |
| Guest MVP (event) | ✅ | ✅ |
| matchSidePlayer MVP (event) | ✅ (rejected) | ✅ (hidden) |
| Legacy registered MVP | ✅ (inferred) | ❌ |
| Legacy guest MVP | ✅ (inferred) | ❌ |
| Unknown legacy MVP | ✅ (null) | ❌ |
| No MVP at all | ✅ | ✅ |
| sideKeyForParticipantId edge cases | ✅ (3 tests) | — |
| displayNameForParticipantId fallback | ✅ (2 tests) | — |

### Note on test infrastructure

The `_NoopMatchResultLineupController` subclass overrides `onInit()` to prevent auto-loading, allowing tests to set controller state directly. The stub route captures `kind` and `id` parameters to verify navigation correctness.

**Verdict:** ✅ Excellent test coverage. 17 tests covering all controller paths and 4 key widget behaviors. The controller helper tests from F1 in the Task 1 review are now addressed.

---

## Findings

### F1: Legacy MVP widget navigation not tested — LOW

**Severity:** Low

The widget tests only exercise the MatchEvent path (setting `controller.mvpEvent.value`). The legacy path (setting `controller.match.value = _match(mvpPlayerId: 'player-1')` + snapshots) is tested at the controller level but not as a full widget navigation test.

This is acceptable because the widget simply reads `controller.mvpProfileTarget` — the target resolution logic is the same regardless of source, and it's tested thoroughly at the controller level.

**Action:** Optional. Could add a widget test with legacy data for completeness.

### F2: `_readableShareError` changed to Arabic fallback — INFO

**Severity:** Info

```diff
-    return raw;
+    return 'تعذر تجهيز بطاقة المشاركة.';
```

The error message fallback changed from raw error string to a fixed Arabic message. This is an improvement — raw exceptions should not be shown to users.

### F3: `MvpPublicProfileTarget` is a simple struct — INFO

**Severity:** Info

```dart
class MvpPublicProfileTarget {
  final ParticipantRefKind kind;
  final String id;
  const MvpPublicProfileTarget({required this.kind, required this.id});
}
```

This could technically be replaced by a `({ParticipantRefKind kind, String id})` record type, but the named class is clearer and follows the existing codebase style. No action needed.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. CTA only when safe target exists | ✅ Pass | Null target → no CTA. Tested for all actor kinds |
| 2. Prefers MatchEvent actor | ✅ Pass | Event first, legacy snapshot inference second |
| 3. Uses AppRoutes helper | ✅ Pass | `playerProfileByKindAndId(kind:, id:)` |
| 4. Guest + registered supported | ✅ Pass | Both event and legacy paths. Tested |
| 5. matchSidePlayer/invalid guarded | ✅ Pass | Rejected by `_profileTargetForKindAndId`. Tested |
| 6. UI compact, Arabic-first | ✅ Pass | TextButton < OutlinedButton < FilledButton hierarchy |
| 7. Share CTA intact | ✅ Pass | Independent from profile CTA. Tested |
| 8. Protected files untouched | ✅ Pass | All 0 diff, no event writes |
| 9. Tests sufficient | ✅ Pass | 17 unit + 4 widget tests |

### Notable quality

This task also backfills the controller helper tests that were flagged as F1 in the Sprint 2 / Task 1 review (`sideKeyForParticipantId`, `hasShareableMvp`, `displayNameForParticipantId`). The test file contains 13 controller-level tests covering all the helpers that were previously untested.
