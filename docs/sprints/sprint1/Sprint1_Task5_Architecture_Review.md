# Sprint 1 / Task 5 — Architecture Review

**Reviewed:** 2026-05-03  
**Scope:** ScoreSubmit Full Participant Roster Wiring (Tier 2, Step 7 — partial)  
**Verdict:** ✅ PASS — clean wiring with appropriate scope restraint

---

## Files Reviewed

### Modified files

| File | Diff summary | Change |
|---|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | +80 / -15 lines | DI constructor, full roster loading, participant accessors, `selectMvp` |

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `test/features/match/score_submit_controller_test.dart` | 381 | Integration tests with FakeFirestore |

### Verified untouched (git diff = 0 lines)

| File | Status |
|---|---|
| `lib/features/match/views/score_submit_screen.dart` | ✅ Clean |
| `lib/core/services/match_event_service.dart` | ✅ Clean (untracked, no diff) |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `firestore.rules` | Modified by Task 1, not this task |
| `lib/core/services/match_settlement_service.dart` | Modified by Task 4, not this task |

---

## Review Axis 1: Does the controller now load/expose full MatchParticipantRoster?

### New observable state

```dart
final Rx<MatchParticipantRoster?> fullParticipantRoster =
    Rx<MatchParticipantRoster?>(null);
final RxString fullRosterErrorMessage = ''.obs;
```

### New computed getters

```dart
List<ParticipantRef> get teamAParticipants =>
    fullParticipantRoster.value?.sideA ?? const <ParticipantRef>[];
List<ParticipantRef> get teamBParticipants =>
    fullParticipantRoster.value?.sideB ?? const <ParticipantRef>[];
List<ParticipantRef> get allParticipants =>
    fullParticipantRoster.value?.allParticipants ?? const <ParticipantRef>[];
```

### Loading sequence

In `loadMatchAndPlayers()` (line 86–131):

```
1. Load match from repository
2. Load registered roster (teamAPlayers, teamBPlayers) — unchanged
3. Load full participant roster (new) → _loadFullParticipantRoster
4. Build playerStats for registered players — unchanged
```

Step 3 is additive — it runs after the existing registered roster load and does not alter any existing behavior.

### New public methods

| Method | Purpose | Returns |
|---|---|---|
| `selectMvp(String participantId)` | Sets MVP selection (any participant kind) | void |
| `isParticipantOnSide(participant, sideKey)` | Delegates to `MatchParticipantRoster` | bool |
| `sideKeyForParticipant(participant)` | Delegates to `MatchParticipantRoster` | String? |

**Verdict:** ✅ Full roster is loaded, exposed as reactive state, and queryable by side. Clean delegation to the entity.

---

## Review Axis 2: Does it preserve existing registered-player detailed stats behavior?

### `_buildDetailedStats` method

Completely unchanged (lines 371–390). Still:
- Takes `Player` objects (registered only)
- Builds `PlayerMatchStats` from `playerStats[player.id]`
- Writes to `matches/{matchId}/player_stats/{playerId}`

### `submit()` method

The detailed stats construction (lines 215–230) still iterates `teamAPlayers` and `teamBPlayers` — which are `RxList<Player>` populated from `loadRegisteredRoster`. Not from the full participant roster.

### Test evidence

The "submits registered detailed stats while allowing guest MVP selection" test (line 177–257) explicitly verifies:

```dart
// Registered player stats ARE written
expect(playerAStats.exists, isTrue);
expect(playerAStats.data()?['goals'], 1);
expect(playerBStats.exists, isTrue);

// Guest player stats are NOT written
expect(guestStats.exists, isFalse);
```

This is the exact behavioral contract: registered players get `player_stats` subcollection docs; guest/temporary players do not.

**Verdict:** ✅ Detailed stats behavior is 100% preserved. Guest exclusion from `player_stats` explicitly tested.

---

## Review Axis 3: Did it avoid ScoreSubmitScreen UI redesign?

`lib/features/match/views/score_submit_screen.dart`: **0 lines changed** (git diff = empty).

The controller changes are all data-layer additions. The UI screen has not been modified to show a participant picker, goal attribution section, or any new visual elements. Those are Tier 3 tasks (Steps 10–13 in the architecture proposal).

**Verdict:** ✅ No UI changes. The screen will be wired in Tier 3.

---

## Review Axis 4: Did it avoid writing MatchEvent documents?

### Import check

Zero references to `MatchEventService`, `match_event_service.dart`, or `MatchEvent` in the controller file.

### Submit flow

`submit()` calls `_settlementService.submitScore(...)` — the same call as before. No `MatchEventService.recordGoals()` or `MatchEventService.recordMvp()` call was added.

This is correct: MatchEvent writing belongs to Step 7's full integration (the UI-driven part), not the controller data-wiring. The current task is specifically "wiring the roster data into the controller" — the MatchEvent dual-write is a separate integration step.

**Verdict:** ✅ No MatchEvent documents are written. Correctly deferred.

---

## Review Axis 5: Did it avoid touching protected files?

| File | Expected | Actual |
|---|---|---|
| `match_settlement_service.dart` | Not this task (Task 4) | ✅ Changes are from Task 4 |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `match_event_service.dart` | Untouched | ✅ Untracked, no imports added |
| `firestore.rules` | Not this task (Task 1) | ✅ Changes are from Task 1 |

**Verdict:** ✅ Perfect isolation.

---

## Review Axis 6: Is the controller API suitable for future MVP/goal attribution UI?

### What Tier 3 UI will need

| UI requirement | Controller API | Ready? |
|---|---|---|
| Show all participants by side for goal picker | `teamAParticipants`, `teamBParticipants` | ✅ |
| Show all participants for MVP picker | `allParticipants` | ✅ |
| Select MVP (any kind) | `selectMvp(participantId)` | ✅ |
| Check which side a scorer is on | `sideKeyForParticipant(participant)` | ✅ |
| Verify participant is on correct side | `isParticipantOnSide(participant, sideKey)` | ✅ |
| Display name for each participant | `participant.displayName` | ✅ |
| Distinguish player kinds in UI (icon/badge) | `participant.kind` | ✅ |
| Handle full roster load failure gracefully | `fullRosterErrorMessage` | ✅ |

### What's NOT yet ready (correctly deferred)

| Future need | Status |
|---|---|
| Goal attribution list (`List<MatchGoalDraft>`) | Not in controller — will be added when goal attribution UI is built |
| Goal-count mismatch warning | Not in controller — belongs to UI layer |
| MatchEvent recording on submit | Not wired — separate integration step |

### DI constructor

The controller now accepts all dependencies via constructor injection:

```dart
ScoreSubmitController({
  required this.matchId,
  MatchRepositoryImpl? matchRepository,
  MatchSettlementService? settlementService,
  OfficialMatchRosterService? officialRosterService,
  MatchSideRepositoryImpl? sideRepository,
  MatchSidePlayerRepositoryImpl? sidePlayerRepository,
  TeamRepositoryImpl? teamRepository,
  String? Function()? currentUserIdProvider,
})
```

This is a significant testability improvement over the previous hard-coded `Get.find<AuthService>()` and `= MatchRepositoryImpl()` initializations. All tests now pass proper FakeFirestore instances without needing GetX service locator setup.

**Verdict:** ✅ API surface is complete for Tier 3 UI work. DI constructor is a valuable structural improvement.

---

## Review Axis 7: Are tests sufficient?

### Test coverage matrix

| Scenario | Covered? | Test |
|---|---|---|
| Registered players appear in `teamAParticipants`/`teamBParticipants` | ✅ | "loads full participants for registered players" |
| Guest players appear in `teamAParticipants` with correct kind | ✅ | "loads guest participants from the full roster" |
| Guest player `linkedPlayerId` is propagated | ✅ | Same test — `expect(linkedPlayerId, 'claimed-player')` |
| Temporary MSP appears in `teamBParticipants` | ✅ | "loads temporary match-side participants" |
| `isParticipantOnSide` returns correct side | ✅ | Guest test — `isParticipantOnSide(participant, 'A')` |
| `sideKeyForParticipant` returns correct key | ✅ | Temporary test — `sideKeyForParticipant(participant)` |
| `allParticipants` deduplication | ✅ | Registered test — `hasLength(2)` |
| Submit with guest MVP preserves `mvpPlayerId` | ✅ | "submits registered detailed stats" — `mvpPlayerId: 'guest-mvp'` |
| Submit writes registered `player_stats` only | ✅ | Same test — `playerAStats.exists: true`, `guestStats.exists: false` |
| `teamAPlayers` (registered-only list) empty when only guests | ✅ | Guest test — `teamAPlayers` is empty |
| Error handling when full roster fails | ❌ | Not tested — see F1 |
| `selectMvp` trims whitespace | ❌ | Not tested — trivial |
| Empty match (no participants on either side) | ❌ | Not tested — see F2 |
| `loadMatchAndPlayers` with cancelled match | ❌ | Not tested — existing behavior |

### Test structure quality

- Uses `FakeFirebaseFirestore` for real Firestore behavior simulation ✅
- Uses `Get.testMode = true` with proper `tearDown(Get.reset)` ✅
- Uses `testWidgets` for the submit test (needed for `Get.snackbar`) ✅
- DI constructor enables clean test setup without `Get.put` ✅
- Helper functions (`_controller`, `_match`, `_player`, etc.) are well-structured and reusable ✅

**Verdict:** ⚠️ Good coverage of happy paths. Missing error/edge case tests. See F1, F2.

---

## Review Axis 8: Are fallback/error behaviors safe?

### Full roster load failure

```dart
Future<void> _loadFullParticipantRoster(Match loadedMatch) async {
  try {
    final roster = await _officialRosterService.loadParticipantRoster(...);
    fullParticipantRoster.value = roster;
    fullRosterErrorMessage.value = '';
  } catch (error) {
    fullParticipantRoster.value = null;
    fullRosterErrorMessage.value =
        'تعذر تحميل قائمة المشاركين الكاملة: ${_readableError(error)}';
  }
}
```

**Safe.** If the full roster load fails:
- `fullParticipantRoster.value = null`
- `teamAParticipants` / `teamBParticipants` / `allParticipants` return `const <ParticipantRef>[]`
- The controller continues to function with registered-only data
- Score submission still works — `selectedMvpId` would be empty (no participant to select)
- An error message is available for the UI to display

### Null roster on side queries

```dart
bool isParticipantOnSide(ParticipantRef participant, String sideKey) {
  return fullParticipantRoster.value?.isParticipantOnSide(...) ?? false;
}

String? sideKeyForParticipant(ParticipantRef participant) {
  return fullParticipantRoster.value?.sideKeyFor(participant);
}
```

Both gracefully handle null roster — return `false` and `null` respectively. ✅

### Loading reset

`loadMatchAndPlayers()` resets both error messages at the start:
```dart
errorMessage.value = '';
fullRosterErrorMessage.value = '';
```

And `_loadFullParticipantRoster` is called inside `loadMatchAndPlayers`'s try block but has its own try/catch. This means a roster error does NOT block the rest of the load — registered players still load. ✅

### MVP submission with null roster

If roster failed to load, `selectedMvpId` remains empty (`''`). When `submit()` runs:
```dart
mvpPlayerId: selectedMvpId.value.isEmpty ? null : selectedMvpId.value,
```
Result: `mvpPlayerId = null`. The settlement service accepts null MVP. ✅

**Verdict:** ✅ All failure paths are safe. The controller degrades gracefully to registered-only behavior.

---

## Findings

### F1: Full roster load error not tested — SHOULD ADD

**Severity:** Low

The `_loadFullParticipantRoster` error path (catch block, line 296–300) is untested. The behavior is correct (sets `fullParticipantRoster = null`, stores error message), but a test would verify the graceful degradation.

**Suggested test:**
```
- Provide a matchId that doesn't exist in the matches collection
- Call loadMatchAndPlayers
- Verify fullRosterErrorMessage is non-empty
- Verify teamAParticipants/teamBParticipants are empty
- Verify allParticipants is empty
- Verify submit still works with registered players only
```

**Action:** Add test before Tier 3 UI work. Estimated effort: ~5 minutes.

### F2: Empty match (no participants) not tested — LOW RISK

**Severity:** Low

No test verifies the case where a match has no players on either side. The getters return `const <ParticipantRef>[]` which is safe, but it's unverified.

**Action:** Consider adding. Not blocking.

### F3: DI constructor refactor is a valuable structural improvement — INFO

**Severity:** Info (positive)

The old controller used hard-coded field initializers:
```dart
final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
final AuthService _authService = Get.find<AuthService>();
```

The new constructor uses dependency injection with optional parameters and sensible defaults. This makes the controller fully testable without GetX service locator, which is why the test file works cleanly with `FakeFirebaseFirestore` injection.

This refactor was necessary for testing the full roster integration and is a permanent improvement to the controller's architecture.

### F4: `loadMatchAndPlayers` made public — CORRECT

**Severity:** Info

Renamed from `_loadMatchAndPlayers()` (private) to `loadMatchAndPlayers()` (public). This is necessary because tests call it directly instead of relying on `onInit()`. The `onInit()` lifecycle still calls it automatically for production use.

### F5: Dual roster load (registered + full) is intentional — ACCEPTABLE

**Severity:** Info

The controller makes two roster loads:
1. `loadRegisteredRoster` → populates `teamAPlayers`/`teamBPlayers` for `playerStats` and `detailedStats`
2. `loadParticipantRoster` → populates `fullParticipantRoster` for participant accessors

This could theoretically be consolidated into one call, but:
- `teamAPlayers` needs `Player` objects (with `position`, `rating`, etc.) for `_buildDetailedStats`
- `fullParticipantRoster` provides `ParticipantRef` objects (lighter, no `Player` fields)
- Merging would require either embedding `Player` data into `ParticipantRef` (bloat) or restructuring the stats pipeline (scope creep)

The dual load is the correct trade-off for V1.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Loads/exposes full roster | ✅ Pass | Reactive state + computed getters + side queries |
| 2. Registered detailed stats preserved | ✅ Pass | `player_stats` written for registered only; tested |
| 3. No UI redesign | ✅ Pass | Screen file 0 diff |
| 4. No MatchEvent writing | ✅ Pass | No imports, no calls |
| 5. No protected file changes | ✅ Pass | 0 diff on all protected files |
| 6. API suitable for future UI | ✅ Pass | All needed methods present |
| 7. Tests sufficient | ⚠️ Minor gap | Error path untested |
| 8. Fallback/error behavior safe | ✅ Pass | Graceful degradation to registered-only |

### Before proceeding to Tier 3

1. Add error-path test for `_loadFullParticipantRoster` failure.
2. Run `flutter test` to confirm all tests pass.
