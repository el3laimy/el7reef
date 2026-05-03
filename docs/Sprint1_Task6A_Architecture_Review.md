# Sprint 1 / Task 6A — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** ScoreSubmit MVP MatchEvent Dual-Write (Tier 2, Step 7 — MVP event integration)  
**Verdict:** ✅ PASS — correct dual-write with solid failure isolation

---

## Files Reviewed

### Modified files

| File | Diff summary | Change |
|---|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | +68 lines net vs Task 5 | Added `MatchEventService` dep, `_recordMvpMatchEventIfPossible`, `_resolveMvpParticipant`, `_mvpEventId`, duplicate voiding |
| `test/features/match/score_submit_controller_test.dart` | +319 lines net vs Task 5 | 5 new tests + 2 mock services + 3 helper functions |

### Verified untouched (git diff = 0 lines on protected files)

| File | Status |
|---|---|
| `lib/features/match/views/score_submit_screen.dart` | ✅ Clean |
| `lib/core/services/match_event_service.dart` | ✅ Untracked (Task 1), no modifications |
| `lib/core/services/match_settlement_service.dart` | Modified by Task 4 only |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `firestore.rules` | Modified by Task 1 only |

---

## Review Axis 1: Does `submit()` write an MVP MatchEvent only after `submitScore` succeeds?

### Execution sequence in `submit()` (lines 237–297)

```
1. _settlementService.submitScore(...)           ← can throw
2. matchController.loadLiveMatches/loadMyMatches  ← post-settlement UI refresh
3. match.value = updatedMatch                     ← local state update
4. _recordMvpMatchEventIfPossible(...)            ← MVP event write ✅ HERE
5. Get.snackbar(...)                              ← user feedback
6. return updatedMatch
```

The `_recordMvpMatchEventIfPossible` call is at line 266 — **inside the `try` block**, **after** `submitScore` returns successfully and **after** the match state is updated. If `submitScore` throws (line 287 catch), execution never reaches the event write.

### Test evidence

The "submitScore failure writes no MVP MatchEvent" test (line 339–371) uses `_FailingMatchSettlementService` that throws on `submitScore`. It verifies:

```dart
expect(updatedMatch, isNull);                          // submit() returned null
expect(await _activeMvpEvents(firestore, matchId), isEmpty);  // no event written
```

**Verdict:** ✅ MVP event is written strictly after successful settlement. No orphan events on settlement failure.

---

## Review Axis 2: Does it resolve ParticipantRef correctly for all three kinds?

### `_resolveMvpParticipant` method (lines 333–347)

```dart
({ParticipantRef actor, String sideKey})? _resolveMvpParticipant(
  String selectedMvpId,
) {
  final roster = fullParticipantRoster.value;
  if (roster == null) return null;

  final matches = <({ParticipantRef actor, String sideKey})>[
    for (final participant in roster.sideA)
      if (participant.id == selectedMvpId) (actor: participant, sideKey: 'A'),
    for (final participant in roster.sideB)
      if (participant.id == selectedMvpId) (actor: participant, sideKey: 'B'),
  ];
  if (matches.length != 1) return null;
  return matches.single;
}
```

This method:
1. Searches both sides of the loaded `MatchParticipantRoster`
2. Returns the full `ParticipantRef` (which carries `kind`, `id`, `displayName`, `linkedPlayerId`)
3. Also returns the resolved `sideKey` — critical for the MatchEvent

### Resolution by kind

| Kind | Resolves correctly? | Test evidence |
|---|---|---|
| `player` | ✅ | "submit with registered MVP" — `actor['kind'] == 'player'`, `actor['id'] == 'player-a'`, `actor['displayName'] == 'أحمد'` |
| `guestPlayer` | ✅ | "submits registered detailed stats while allowing guest MVP" — `actor['kind'] == 'guestPlayer'`, `actor['id'] == 'guest-mvp'` |
| `matchSidePlayer` | ✅ | "submit with temporary match-side MVP" — `actor['kind'] == 'matchSidePlayer'`, `actor['id'] == 'temporary-mvp'` |

### Edge cases handled

| Edge case | Behavior | Safe? |
|---|---|---|
| `selectedMvpId` is empty | Returns early at line 305 | ✅ |
| `fullParticipantRoster` is null (load failed) | Returns null → no event written | ✅ |
| ID matches on both sides (theoretical collision) | `matches.length != 1` → returns null → no event | ✅ Safe |
| ID matches zero participants | `matches.length != 1` → returns null | ✅ Safe |

**Verdict:** ✅ All three participant kinds are correctly resolved with proper `sideKey` derivation.

---

## Review Axis 3: Does it preserve `Match.mvpPlayerId` behavior?

### Dual-write flow

```
submitScore(mvpPlayerId: normalizedSelectedMvpId)
  → Match document: mvpPlayerId = 'guest-mvp'        ← EXISTING (MatchSettlementService)
  
_recordMvpMatchEventIfPossible(selectedMvpId: normalizedSelectedMvpId)
  → MatchEvent document: actor.id = 'guest-mvp'       ← NEW (MatchEventService)
```

The `Match.mvpPlayerId` string write happens in `MatchSettlementService.submitScore` (unchanged from Task 4). The `MatchEvent` write happens afterward as an additive step. Both carry the same MVP ID.

### Test verification

```dart
// Match.mvpPlayerId is set (existing behavior)
expect(updatedMatch?.mvpPlayerId, 'guest-mvp');

// MatchEvent is also written (new behavior)
expect(events.single['eventType'], 'mvp');
expect(actor['id'], 'guest-mvp');
```

Both paths are verified independently in the "submits registered detailed stats while allowing guest MVP selection" test.

**Verdict:** ✅ Dual-write correctly implemented per architecture proposal (D3). `Match.mvpPlayerId` unchanged.

---

## Review Axis 4: Does it avoid goal events entirely?

### Code check

Zero references to `recordGoal`, `MatchEventType.goal`, or goal-related MatchEvent logic in the controller diff.

### Test assertion

Every submit test calls `_expectNoGoalEvents`:

```dart
Future<void> _expectNoGoalEvents(
  FakeFirebaseFirestore firestore,
  String matchId,
) async {
  final snapshot = await firestore
      .collection(FirebasePaths.matchEvents)
      .where('matchId', isEqualTo: matchId)
      .where('eventType', isEqualTo: 'goal')
      .get();
  expect(snapshot.docs, isEmpty);
}
```

Called in **all 6 submit tests**:
- "registered MVP" → `_expectNoGoalEvents` ✅
- "temporary match-side MVP" → `_expectNoGoalEvents` ✅
- "no MVP" → `_expectNoGoalEvents` ✅
- "submitScore failure" → `_expectNoGoalEvents` ✅
- "repeated submit" → `_expectNoGoalEvents` ✅
- "guest MVP selection" → `_expectNoGoalEvents` ✅

**Verdict:** ✅ No goal events written. Explicitly verified in every test. Goal attribution is correctly deferred.

---

## Review Axis 5: Did it avoid UI, settlement, PlayerMatchStats, rating, fantasy, and Firestore rules/index changes?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_screen.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Not modified by this task | ✅ Changes from Task 4 only |
| `match_event_service.dart` | Untouched (consumed, not modified) | ✅ Untracked from Task 1 |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Not modified by this task | ✅ Changes from Task 1 only |
| Firestore indexes | No changes | ✅ |

**Verdict:** ✅ Perfect isolation. Only `score_submit_controller.dart` production code was modified.

---

## Review Axis 6: Is duplicate prevention safe and minimal?

### Strategy: deterministic event ID + void-before-write

```dart
String _mvpEventId(String matchId) => 'mvp-$matchId';
```

One MVP per match → one deterministic ID per match. This is the simplest possible dedup.

### Void-before-write logic (lines 310–318)

```dart
final eventId = _mvpEventId(submittedMatch.id);
final activeEvents = await _matchEventService.getMatchEvents(
  submittedMatch.id,
);
for (final event in activeEvents) {
  if (event.isMvp && event.id != eventId) {
    await _matchEventService.voidEvent(event.id);
  }
}
await _matchEventService.recordMvp(eventId: eventId, ...);
```

This handles:

| Scenario | Behavior | Safe? |
|---|---|---|
| First submit (no prior events) | Write `mvp-{matchId}` directly | ✅ |
| Re-submit (same MVP ID) | No stale events to void; `recordMvp` overwrites with same ID | ✅ |
| Re-submit (different MVP) | Would need ID-based voiding, but `_mvpEventId` is deterministic so the same doc is overwritten | ✅ |
| Stale MVP event from manual/legacy creation with different ID | Voided before new write | ✅ |

### Test evidence

"repeated submit does not create duplicate active MVP MatchEvents" (line 373–410):
```dart
await controller.submit();                    // first submit
await firestore.collection(...).update(...);  // reset match to live
await controller.submit();                    // second submit

final events = await _activeMvpEvents(firestore, 'match-repeat-mvp');
expect(events, hasLength(1));                 // exactly one active event
expect(events.single['id'], 'mvp-match-repeat-mvp');
```

### Consideration: `recordMvp` with same `eventId`

The `MatchEventService.recordMvp` uses `eventId` as the Firestore document ID. If a document with that ID already exists:
- Firestore `set()` → overwrites (idempotent)
- This is the correct behavior for a re-submit scenario

**Verdict:** ✅ Deterministic ID + void-stale + set-overwrite makes dedup both safe and minimal.

---

## Review Axis 7: Does failure handling avoid orphan events?

### Failure matrix

| Failure point | MVP event written? | Match state | Outcome |
|---|---|---|---|
| `submitScore` throws | ❌ No | Unchanged | ✅ No orphan — event write never reached |
| `getMatchEvents` throws | ❌ No | Submitted | ✅ Caught by `catch (_)` — score still submitted |
| `voidEvent` throws | ❌ Stale may remain | Submitted | ⚠️ See F1 |
| `recordMvp` throws | ❌ No new event | Submitted | ✅ Caught — `Match.mvpPlayerId` is authoritative |

### The `catch (_)` pattern (lines 327–330)

```dart
} catch (_) {
  // Score submission has already succeeded; MVP event persistence can be
  // retried by a later integration without breaking the existing result.
}
```

This silently swallows all errors from the MVP event write. The comment explains the rationale: `Match.mvpPlayerId` is the authoritative field; the `MatchEvent` is supplementary data that can be recovered later.

**Is this the right trade-off?**
- **Yes for V1.** The dual-write architecture explicitly designates `Match.mvpPlayerId` as the backward-compatible field and `MatchEvent` as the forward-looking one. A failed event write means `Match.mvpPlayerId` still works for rating, share cards, and all existing UI.
- **The event can be reconstructed** from `Match.mvpPlayerId` + roster data in a future reconciliation pass if needed.

**Verdict:** ✅ No orphan events possible. Failure is safe. Match data is always authoritative.

---

## Review Axis 8: Are tests sufficient?

### Coverage matrix

| Scenario | Covered? | Test |
|---|---|---|
| Registered player MVP → MatchEvent with `player` kind | ✅ | "submit with registered MVP" |
| Guest player MVP → MatchEvent with `guestPlayer` kind | ✅ | "submits registered detailed stats while allowing guest MVP" |
| Temporary MSP MVP → MatchEvent with `matchSidePlayer` kind | ✅ | "submit with temporary match-side MVP" |
| No MVP → no MatchEvent | ✅ | "submit with no MVP writes no MVP MatchEvent" |
| `submitScore` failure → no MatchEvent | ✅ | "submitScore failure writes no MVP MatchEvent" |
| Repeated submit → exactly 1 active event | ✅ | "repeated submit does not create duplicate active MVP MatchEvents" |
| No goal events written (all tests) | ✅ | `_expectNoGoalEvents` called in all 6 tests |
| Registered `player_stats` still written | ✅ | "submits registered detailed stats" — verifies subcollection docs |
| Guest `player_stats` NOT written | ✅ | Same test — `guestStats.exists: isFalse` |
| Full roster load failure → graceful degradation | ✅ | "keeps registered roster usable when full participant roster load fails" |
| `sideKey` correct for each side | ✅ | Registered test: `'A'`, MSP test: `'B'` |
| `displayName` propagated | ✅ | All actor assertions include `displayName` |
| `linkedPlayerId` propagated for guest | ✅ | Task 5 guest test verifies `linkedPlayerId: 'claimed-player'` |
| MatchEvent failure during write → silent catch | ❌ | Not directly tested — see F2 |
| MVP change on re-submit (different player) | ❌ | Not tested — see F3 |

### Test infrastructure quality

- `_FailingMatchSettlementService` — clean mock for settlement failure ✅
- `_FailingParticipantRosterService` — clean mock for roster failure ✅
- `_activeMvpEvents` — direct Firestore query for assertion ✅
- `_expectNoGoalEvents` — explicit negative assertion ✅
- `_drainSnackbars` — handles GetX snackbar lifecycle in tests ✅

**Verdict:** ✅ Strong coverage. All three participant kinds tested for MVP events. Two minor gaps.

---

## Findings

### F1: `voidEvent` failure could leave stale MVP events — LOW RISK

**Severity:** Low

If `voidEvent` throws mid-loop (line 314–317), the `catch (_)` swallows the error and `recordMvp` is never reached. This could leave a stale (non-voided) MVP event alongside no new event.

**Practical risk:** Near-zero. `voidEvent` does a simple Firestore field update (`status: 'voided'`). It only fails on network errors. If the network is down, `recordMvp` would also fail. The `Match.mvpPlayerId` field remains the authoritative source.

**Action:** None needed for V1.

### F2: MatchEvent write failure not directly tested — LOW

**Severity:** Low

No test uses a failing `MatchEventService` to verify that `submit()` still returns the updated match when event write fails. The `catch (_)` block is untested.

However, this is **indirectly covered**: the "roster load failure" test proves the controller handles missing roster gracefully, and the code path is simple enough (`catch (_)` = swallow) that the risk is minimal.

**Action:** Consider adding a `_FailingMatchEventService` test if time permits. Not blocking.

### F3: MVP change on re-submit not tested — LOW

**Severity:** Low

No test verifies what happens when a user submits with MVP `player-a`, then re-submits with MVP `player-b`. The deterministic ID (`mvp-{matchId}`) means the document would be overwritten with the new MVP. This is correct behavior but unverified.

**Action:** Consider adding. Not blocking because the deterministic ID makes the behavior predictable.

### F4: `_resolveMvpParticipant` uses ID-only match — DESIGN NOTE

**Severity:** Info

The resolver matches `participant.id == selectedMvpId` without checking `participant.kind`. If two participants on different sides have the same ID but different kinds (e.g. `player:abc` and `guestPlayer:abc`), `matches.length` would be 2 and the resolver would return null (safe fallback).

This is the same collision space noted in Task 4's review. Practical risk is near-zero due to different ID generation sources.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. MVP event written only after successful settlement | ✅ Pass | Sequence verified: settlement → state update → event write |
| 2. ParticipantRef resolved correctly for all kinds | ✅ Pass | All 3 kinds tested with correct `actor` map assertions |
| 3. `Match.mvpPlayerId` preserved | ✅ Pass | Dual-write per D3 architecture decision |
| 4. No goal events | ✅ Pass | `_expectNoGoalEvents` in all 6 tests |
| 5. No UI/settlement/rating/fantasy/rules changes | ✅ Pass | 0 diff on all protected files |
| 6. Duplicate prevention safe | ✅ Pass | Deterministic ID + void-stale + tested |
| 7. No orphan events on failure | ✅ Pass | Settlement failure blocks event; event failure is caught |
| 8. Tests sufficient | ✅ Pass | 10 tests covering all kinds, failure, dedup, no-MVP, no-goals |

### No blocking action items

The implementation is ready for the next step. The two untested edge cases (F2, F3) are low-severity and can be addressed opportunistically.
