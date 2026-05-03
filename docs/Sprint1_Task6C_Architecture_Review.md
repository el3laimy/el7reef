# Sprint 1 / Task 6C — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** ScoreSubmit Goal MatchEvent Write (Tier 2, Step 7 — goal event persistence)  
**Verdict:** ✅ PASS — correct best-effort persistence with clean dedup

---

## Files Reviewed

### Modified files (cumulative from baseline)

| File | Diff vs baseline | This task's delta |
|---|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | +295 / -17 total | +65 lines net vs Task 6B — `_recordGoalMatchEventsIfPossible`, `_goalEventId`, `_safeEventIdSegment`, inline comment |
| `test/features/match/score_submit_controller_test.dart` | ~1181 total | +233 lines net vs Task 6B — 5 new goal event tests + `_activeGoalEvents` helper |

### Verified untouched (git diff = 0 lines on protected files)

| File | Status |
|---|---|
| `lib/features/match/views/score_submit_screen.dart` | ✅ Clean |
| `lib/core/services/match_event_service.dart` | ✅ Untracked (Task 1), consumed not modified |
| `lib/core/services/match_settlement_service.dart` | Modified by Task 4 only |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `firestore.rules` | Modified by Task 1 only |

---

## Review Axis 1: Are goal MatchEvents written only after submitScore succeeds?

### Execution sequence in `submit()` (lines 316–380)

```
1. _settlementService.submitScore(...)              ← can throw
2. MatchController.loadLiveMatches/loadMyMatches     ← UI refresh
3. match.value = updatedMatch                        ← local state
4. _recordMvpMatchEventIfPossible(...)               ← MVP event (Task 6A)
5. _recordGoalMatchEventsIfPossible(...)             ← GOAL events ✅ HERE
6. Get.snackbar(...)                                 ← user feedback
7. return updatedMatch
```

`_recordGoalMatchEventsIfPossible` is at line 350 — **inside the `try` block**, **after** successful `submitScore` return, **after** MVP event. If `submitScore` throws, execution jumps to `catch` at line 370 and goal events are never written.

### Test evidence

"submitScore failure writes no MVP MatchEvent" test (line 760–793):
```dart
controller.setParticipantGoals(controller.teamAParticipants.single, 1);  // drafts exist
final updatedMatch = await controller.submit();

expect(updatedMatch, isNull);
expect(await _activeMvpEvents(firestore, ...), isEmpty);
await _expectNoGoalEvents(firestore, ...);  // ← NO goal events
```

The test now seeds both goal drafts AND MVP, then confirms neither is written when settlement fails.

**Verdict:** ✅ Goal events written strictly after successful settlement. No orphan events on failure.

---

## Review Axis 2: Are goal events written correctly for all three participant kinds?

### `_recordGoalMatchEventsIfPossible` method (lines 383–420)

```dart
Future<void> _recordGoalMatchEventsIfPossible({
  required Match submittedMatch,
  required String actorId,
}) async {
  final drafts = allGoalDrafts.where((draft) => draft.goals > 0).toList();
  if (drafts.isEmpty) return;

  try {
    // Void existing goal events
    final activeEvents = await _matchEventService.getMatchEvents(submittedMatch.id);
    for (final event in activeEvents) {
      if (event.isGoal) {
        await _matchEventService.voidEvent(event.id);
      }
    }
    // Write one event per goal per participant
    for (final draft in drafts) {
      for (var index = 1; index <= draft.goals; index += 1) {
        await _matchEventService.recordGoal(
          eventId: _goalEventId(matchId: submittedMatch.id, draft: draft, index: index),
          matchId: submittedMatch.id,
          tournamentId: submittedMatch.tournamentId,
          sideKey: draft.sideKey,
          actor: draft.actor,
          createdBy: actorId,
        );
      }
    }
  } catch (_) {
    // Best-effort — score submission has already succeeded.
  }
}
```

### Key design: one MatchEvent per goal

If a player scores 2 goals, two separate MatchEvent documents are written (index 1 and 2). This is the correct granularity for:
- Tournament top scorers (count events per actor)
- Leaderboard queries (sum events with `eventType == goal`)
- Share cards (show individual goal attribution)

### Kind-specific test evidence

| Kind | Test | Event ID pattern | Actor assertions |
|---|---|---|---|
| `player` | "submit with registered goal drafts writes goal MatchEvents" | `goal-{matchId}-A-player-player-a-1` | `kind: player`, `id: player-a`, `displayName: أحمد` |
| `guestPlayer` | "submit with guest goal drafts writes goal MatchEvents" | `goal-{matchId}-A-guestPlayer-guest-scorer-1` | `kind: guestPlayer`, `id: guest-scorer`, `linkedPlayerId: claimed-scorer` |
| `matchSidePlayer` | "submit with temporary match-side goal drafts writes goal MatchEvents" | `goal-{matchId}-B-matchSidePlayer-temporary-scorer-1` | `kind: matchSidePlayer`, `id: temporary-scorer` |

### Multi-goal test

The registered test verifies 2 goals = 2 events:
```dart
controller.setParticipantGoals(controller.teamAParticipants.single, 2);
// ...
expect(goals, hasLength(2));
expect(goals.map((event) => event['id']), containsAll([
  'goal-match-registered-goal-events-A-player-player-a-1',
  'goal-match-registered-goal-events-A-player-player-a-2',
]));
```

**Verdict:** ✅ All three kinds produce correct goal events with proper actor data and `sideKey`.

---

## Review Axis 3: Does empty goalDrafts write no goal events?

### Guard clause (line 387–388)

```dart
final drafts = allGoalDrafts.where((draft) => draft.goals > 0).toList();
if (drafts.isEmpty) return;
```

If no drafts exist or all drafts have `goals <= 0`, the method exits immediately without calling `getMatchEvents` or `recordGoal`.

### Test evidence

Multiple tests verify empty goal events when no drafts are present:

| Test | Drafts? | Result |
|---|---|---|
| "submit with no MVP writes no MVP MatchEvent" | No | `_expectNoGoalEvents` ✅ |
| "submit with registered MVP writes one MVP MatchEvent" | No | `_expectNoGoalEvents` ✅ |
| "submit with temporary match-side MVP writes one MVP MatchEvent" | No | `_expectNoGoalEvents` ✅ |
| "submits registered detailed stats while allowing guest MVP selection" | No | `_expectNoGoalEvents` ✅ |

**Verdict:** ✅ Empty drafts produce zero goal events.

---

## Review Axis 4: Does mismatch remain advisory and non-blocking?

### `goalDraftMismatchForSide` — unchanged from Task 6B

Still a pure computation (lines 226–235). Not called inside `submit()`.

### Mismatch test now also verifies goal events ARE written

"goal draft mismatch warns by helper but does not block submit" (line 607–645):

```dart
controller.teamAScoreController.text = '2';           // team score: 2
controller.setParticipantGoals(..., 1);                // draft total: 1

expect(controller.goalDraftMismatchForSide('A'), isTrue);  // mismatch detected
final updatedMatch = await controller.submit();

expect(updatedMatch?.scoreTeamA, 2);                   // submit succeeded
expect(await _activeGoalEvents(firestore, ...), hasLength(1));  // 1 goal event written
```

This is the key behavioral proof: even with a mismatch, **both the score submission AND goal event writes proceed**. The mismatch is purely informational for the UI.

**Verdict:** ✅ Mismatch is advisory. Does not block submission or event writes.

---

## Review Axis 5: Is duplicate prevention safe and minimal?

### Strategy: void-all-then-rewrite

```dart
// 1. Void all existing active goal events
for (final event in activeEvents) {
  if (event.isGoal) {
    await _matchEventService.voidEvent(event.id);
  }
}
// 2. Write fresh goal events with deterministic IDs
for (final draft in drafts) {
  for (var index = 1; index <= draft.goals; index += 1) {
    await _matchEventService.recordGoal(eventId: _goalEventId(...), ...);
  }
}
```

### `_goalEventId` — deterministic composite (lines 473–486)

```dart
String _goalEventId({
  required String matchId,
  required ScoreSubmitGoalDraft draft,
  required int index,
}) {
  return [
    'goal',
    _safeEventIdSegment(matchId),
    draft.sideKey,
    draft.actor.kind.name,
    _safeEventIdSegment(draft.actor.id),
    index.toString(),
  ].join('-');
}
```

Components: `goal-{matchId}-{sideKey}-{kind}-{actorId}-{goalIndex}`

This produces deterministic, unique IDs:
- `goal-match123-A-player-p1-1`
- `goal-match123-A-player-p1-2`
- `goal-match123-B-guestPlayer-g1-1`

### `_safeEventIdSegment` — defensive encoding (lines 488–491)

```dart
String _safeEventIdSegment(String value) {
  final encoded = Uri.encodeComponent(value.trim());
  return encoded.isEmpty ? 'unknown' : encoded;
}
```

Handles special characters in IDs (e.g., Firestore auto-IDs with slashes). Good defensive measure.

### Dedup on re-submit test

"repeated submit does not create duplicate active goal MatchEvents" (line 795–837):

```dart
await controller.submit();                    // first submit
await firestore.collection(...).update({'status': MatchStatus.live.name});
await controller.submit();                    // second submit

final goals = await _activeGoalEvents(firestore, 'match-repeat-goals');
expect(goals, hasLength(2));                  // exactly 2 (not 4)
expect(goals.map((event) => event['id']), containsAll([
  'goal-match-repeat-goals-A-player-player-a-1',
  'goal-match-repeat-goals-A-player-player-a-2',
]));
```

The void-then-rewrite strategy works because:
1. First submit: writes 2 goal events
2. Second submit: voids 2 existing → writes 2 fresh → net = 2 active

### Comparison to MVP dedup

| Aspect | MVP | Goals |
|---|---|---|
| Strategy | Deterministic ID + void stale | Void ALL active goals + deterministic IDs |
| ID scheme | `mvp-{matchId}` | `goal-{matchId}-{side}-{kind}-{id}-{index}` |
| Per-match count | Always 1 | Variable (one per goal scored) |

The difference makes sense: MVP is always 1 per match (simple overwrite), goals are N per match (must void-and-rewrite).

**Verdict:** ✅ Dedup is safe. Deterministic IDs prevent phantom duplicates; void-first prevents stale events.

---

## Review Axis 6: Is failure handling best-effort without breaking saved results?

### `catch (_)` pattern (lines 416–419)

```dart
} catch (_) {
  // Score submission has already succeeded; goal event persistence can be
  // retried by a later integration without breaking the existing result.
}
```

Same pattern as MVP event write. All failures during goal event creation are silently swallowed.

### Failure matrix

| Failure point | Goal events written? | Match state | Outcome |
|---|---|---|---|
| `submitScore` throws | ❌ No | Unchanged | ✅ No orphans |
| `getMatchEvents` throws | ❌ No | Submitted | ✅ Caught, score saved |
| `voidEvent` throws mid-loop | Partial voids | Submitted | ⚠️ Stale events may remain — see F1 |
| `recordGoal` throws mid-loop | Partial events | Submitted | ⚠️ Partial set — see F2 |
| All event writes succeed | ✅ Complete | Submitted | ✅ Ideal |

### Is partial failure acceptable?

**Yes for V1.** Goal events are supplementary data:
- `Match.scoreTeamA/scoreTeamB` is the authoritative score
- `PlayerMatchStats` (registered-only) is the authoritative per-player record
- Goal MatchEvents are pride data for leaderboards/share cards

A partial set of events is better than no events, and a future reconciliation can reconstruct from match scores + drafts.

**Verdict:** ✅ Best-effort is the correct trade-off. No result corruption possible.

---

## Review Axis 7: Does MVP dual-write remain intact?

### MVP method — unchanged from Task 6A

`_recordMvpMatchEventIfPossible` (lines 422–453) is unchanged. Same deterministic ID, same void-before-write, same `catch (_)`.

### Execution order

```
4. _recordMvpMatchEventIfPossible(...)   ← runs first
5. _recordGoalMatchEventsIfPossible(...)  ← runs second
```

The MVP method fetches all events via `getMatchEvents` and only voids events where `event.isMvp`. The goal method similarly only voids events where `event.isGoal`. They don't interfere because they check different `eventType` values.

### Test evidence

All 7 MVP-specific tests from Tasks 6A remain:

| Test | Present? | Modified? |
|---|---|---|
| "submit with registered MVP writes one MVP MatchEvent" | ✅ line 647 | No |
| "submit with temporary match-side MVP writes one MVP MatchEvent" | ✅ line 689 | No |
| "submit with no MVP writes no MVP MatchEvent" | ✅ line 732 | No |
| "submitScore failure writes no MVP MatchEvent" | ✅ line 760 | Goal drafts added to test |
| "repeated submit does not create duplicate active MVP MatchEvents" | ✅ line 839 | No |
| "submits registered detailed stats while allowing guest MVP selection" | ✅ line 878 | No |

The "submitScore failure" test (line 760) was enhanced: it now seeds goal drafts alongside MVP to verify **both** are blocked on settlement failure. This strengthens the test.

### Coexistence test

"submit with registered goal drafts writes goal MatchEvents" (line 437) also sets an MVP:
```dart
controller.selectMvp('player-a');
controller.setParticipantGoals(controller.teamAParticipants.single, 2);
await controller.submit();

// Both written
expect(await _activeMvpEvents(...), hasLength(1));
expect(await _activeGoalEvents(...), hasLength(2));
```

**Verdict:** ✅ MVP dual-write intact. Goal and MVP events coexist without interference.

---

## Review Axis 8: Did the patch avoid UI, settlement, PlayerMatchStats, rating, fantasy, and Firestore rules?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_screen.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Not this task (Task 4) | ✅ Changes from Task 4 only |
| `match_event_service.dart` | Consumed, not modified | ✅ Untracked from Task 1, `recordGoal` already existed |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Not this task (Task 1) | ✅ Changes from Task 1 only |
| Leaderboard queries | Untouched | ✅ No leaderboard files changed |

The only production file modified is `score_submit_controller.dart`. All changes are additive methods.

**Verdict:** ✅ Perfect isolation.

---

## Review Axis 9: Are tests sufficient?

### Test inventory: 24 tests total

**Roster loading (4 — from Task 5):**
| Test | Status |
|---|---|
| Loads registered participants | ✅ |
| Loads guest participants | ✅ |
| Loads temporary MSP participants | ✅ |
| Graceful degradation on roster failure | ✅ |

**Goal draft state (7 — from Task 6B):**
| Test | Status |
|---|---|
| Registered goal drafts | ✅ |
| Guest goal drafts | ✅ |
| MSP goal drafts | ✅ |
| Invalid participant rejected | ✅ |
| Null roster prevents drafts | ✅ |
| Clear individual and all drafts | ✅ |
| Mismatch doesn't block submit | ✅ |

**MVP events (7 — from Task 6A, preserved):**
| Test | Status |
|---|---|
| Registered MVP event | ✅ |
| Temporary MSP MVP event | ✅ |
| No MVP = no event | ✅ |
| Settlement failure = no event | ✅ (enhanced with goal drafts) |
| Repeated submit = no duplicate | ✅ |
| Guest MVP with registered stats | ✅ |
| Goal mismatch with submit | ✅ (now checks goal events written) |

**Goal events (5 — new in Task 6C):**
| Test | Status |
|---|---|
| Registered player goal events (2 goals = 2 events) | ✅ |
| Guest player goal events with `linkedPlayerId` | ✅ |
| Temporary MSP goal events | ✅ |
| Settlement failure = no goal events | ✅ |
| Repeated submit = no duplicate goal events | ✅ |

### Missing test scenarios

| Scenario | Risk | Note |
|---|---|---|
| Multiple participants with goals on same side | Low | Aggregation code is simple; individual kinds are tested |
| Goal events from both sides in same match | Low | `sideKey` is verified per-kind; cross-side would be a composition test |
| Partial event write failure (`recordGoal` throws mid-loop) | Low | `catch (_)` swallows — behavior is defined |
| `_safeEventIdSegment` with special characters | Low | Defensive encoding exists but untested |

**Verdict:** ✅ Strong coverage. 24 tests across all layers. No critical gaps.

---

## Findings

### F1: Partial void failure could leave stale + fresh goal events — LOW RISK

**Severity:** Low

If `voidEvent` throws mid-loop (line 394–397), the `catch (_)` fires and `recordGoal` calls are never reached. Old (non-voided) events remain. However, on re-submit they will be voided again.

If `voidEvent` succeeds for some but `recordGoal` throws, there will be fewer active events than expected. But `Match.scoreTeamA/B` remains authoritative.

**Action:** None for V1.

### F2: Void-all strategy requires `getMatchEvents` to return ALL active events — ASSUMPTION

**Severity:** Low

The void-before-write pattern depends on `getMatchEvents` returning all active events for the match. If the service has pagination or filtering that limits results, stale events could survive.

Looking at `MatchEventService.getMatchEvents` (from Task 1), it queries by `matchId` with `status == active`. No pagination. This assumption holds.

**Action:** None. Document if the query ever gains pagination.

### F3: Goal events are NOT gated behind mismatch — BY DESIGN

**Severity:** Info

Per architecture decision D4: "Goal-count mismatch warns but does not block." The mismatch test (line 607) now verifies that 1 goal event IS written even though the team score is 2. This is correct: the drafts represent what the organizer attributed, the score is what they declared. The mismatch is advisory.

### F4: Inline comment added in `submit()` — ADDRESSED from Task 6B review

**Severity:** Info (resolved)

Line 297–298:
```dart
// goalDrafts are ParticipantRef-based pride data written best-effort below;
// detailedStats stays registered-player-only for the current rating path.
```

This addresses F3 from the Task 6B review. The separation between `PlayerMatchStats` and goal MatchEvents is now documented inline.

### F5: `_safeEventIdSegment` produces URL-encoded segments — DESIGN NOTE

**Severity:** Info

`Uri.encodeComponent` turns special characters into `%XX` sequences. For Firestore document IDs this is fine (Firestore allows most characters). The encoding ensures no `-` characters in the segment break the `join('-')` ID structure.

Example: actor ID `abc-123` → `abc-123` (unchanged, `-` is safe in URI components)
Example: actor ID `abc/123` → `abc%2F123` (encoded)

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Goal events after settlement only | ✅ Pass | Sequence verified + settlement failure test |
| 2. All 3 kinds produce correct goal events | ✅ Pass | player, guestPlayer, matchSidePlayer — all tested |
| 3. Empty drafts = no goal events | ✅ Pass | Multiple tests confirm via `_expectNoGoalEvents` |
| 4. Mismatch advisory, non-blocking | ✅ Pass | Submit succeeds + events written with mismatch |
| 5. Duplicate prevention safe | ✅ Pass | Void-all + deterministic IDs + re-submit test |
| 6. Best-effort failure handling | ✅ Pass | `catch (_)` after successful settlement |
| 7. MVP dual-write intact | ✅ Pass | All 7 MVP tests unchanged, coexistence tested |
| 8. No protected file changes | ✅ Pass | 0 diff on all protected files |
| 9. Tests sufficient | ✅ Pass | 24 tests total, all kinds covered |

### No blocking action items

Tier 2 (Steps 5–7) is now complete. The controller has:
- Full participant roster loading ✅
- MVP dual-write (`Match.mvpPlayerId` + MatchEvent) ✅
- Goal draft state management ✅
- Goal MatchEvent persistence ✅
- `PlayerMatchStats` registered-only behavior preserved ✅

Ready for Tier 3 UI integration.
