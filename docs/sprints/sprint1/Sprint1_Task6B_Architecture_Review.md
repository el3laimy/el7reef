# Sprint 1 / Task 6B — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** ScoreSubmit Goal Draft State (Tier 2, Step 7 — goal attribution state)  
**Verdict:** ✅ PASS — clean state management, correctly deferred persistence

---

## Files Reviewed

### Modified files

| File | Diff summary vs Task 6A | Change |
|---|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | +89 lines net | `ScoreSubmitGoalDraft` class, `setParticipantGoals`, `clearParticipantGoals`, `clearGoalDrafts`, `goalDraftsForSide`, `totalDraftGoalsForSide`, `goalDraftMismatchForSide`, `_rosterParticipantFor` |
| `test/features/match/score_submit_controller_test.dart` | +248 lines net | 7 new tests for goal draft CRUD, mismatch, invalid input, null roster |

### Verified untouched (git diff = 0 lines)

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

## Review Axis 1: Does the controller support goal drafts for player, guestPlayer, and matchSidePlayer?

### `ScoreSubmitGoalDraft` value class (lines 24–36)

```dart
class ScoreSubmitGoalDraft {
  final ParticipantRef actor;
  final String sideKey;
  final int goals;
  final int? minute;

  const ScoreSubmitGoalDraft({
    required this.actor,
    required this.sideKey,
    required this.goals,
    this.minute,
  });
}
```

- `actor` is a full `ParticipantRef` — carries `kind`, `id`, `displayName`, `linkedPlayerId`
- `sideKey` is resolved from the roster at creation time
- `goals` is a count (not per-event, aggregated per participant)
- `minute` is optional and deferred — included in the type for forward compatibility

### `setParticipantGoals` method (lines 177–199)

```dart
void setParticipantGoals(ParticipantRef participant, int goals) {
  if (goals <= 0) { clearParticipantGoals(participant); return; }
  final sideKey = sideKeyForParticipant(participant);
  if (sideKey == null) return;                          // ← guard: not in roster

  final key = participantRosterKey(participant);
  final existingIndex = goalDrafts.indexWhere(
    (draft) => participantRosterKey(draft.actor) == key,
  );
  final draft = ScoreSubmitGoalDraft(
    actor: _rosterParticipantFor(participant, sideKey) ?? participant,
    sideKey: sideKey,
    goals: goals,
  );
  if (existingIndex == -1) { goalDrafts.add(draft); }
  else { goalDrafts[existingIndex] = draft; }
}
```

Key behaviors:
1. **Side resolution:** Uses `sideKeyForParticipant` which delegates to `MatchParticipantRoster.sideKeyFor`. Rejects participants not in the roster.
2. **Identity normalization:** `_rosterParticipantFor` looks up the canonical `ParticipantRef` from the loaded roster. This ensures the draft's `actor` has the freshest `displayName` and `linkedPlayerId`.
3. **Upsert logic:** Uses `participantRosterKey` (`kind:id` composite) to find existing drafts. Replaces if found, appends if not.
4. **Zero/negative guard:** `goals <= 0` → clear instead of adding a zero-goal draft.

### Kind support matrix

| Kind | Tested? | Test name |
|---|---|---|
| `player` | ✅ | "adds goal drafts for registered participants" |
| `guestPlayer` | ✅ | "adds goal drafts for guest participants" |
| `matchSidePlayer` | ✅ | "adds goal drafts for temporary match-side participants" |

### Test assertions verified

| Test | Kind check | ID check | Side check | Count check | Extra |
|---|---|---|---|---|---|
| Registered | `ParticipantRefKind.player` | `player-a` | `A` | `goals: 2` | `totalDraftGoalsForSide('B') == 0` |
| Guest | `ParticipantRefKind.guestPlayer` | `guest-scorer` | `A` | `goals: 1` | `linkedPlayerId: 'claimed-scorer'` ✅ |
| MSP | `ParticipantRefKind.matchSidePlayer` | `temporary-scorer` | `B` | `goals: 3` | |

**Verdict:** ✅ All three participant kinds are fully supported with correct identity and side resolution.

---

## Review Axis 2: Does it preserve existing PlayerMatchStats registered-only behavior?

### `playerStats` map — unchanged

The `playerStats` map (line 83) is still populated only from `teamAPlayers`/`teamBPlayers` (registered `Player` objects, lines 137–146). Goal drafts are stored separately in `goalDrafts` (line 84).

### `_buildDetailedStats` — unchanged

The method (lines 523–541) still builds `PlayerMatchStats` from `playerStats[player.id]` — only registered players. It has no reference to `goalDrafts`.

### `submit()` — detailedStats unchanged

Lines 297–312 still build `detailedStats` from `teamAPlayers.map(...)` and `teamBPlayers.map(...)`. Goal drafts are not consumed during submission.

### The two parallel systems

| System | Source | Written to Firestore? | Used by |
|---|---|---|---|
| `playerStats` | Registered players only | ✅ `player_stats/{playerId}` | Rating engine, legacy stats |
| `goalDrafts` | All participant kinds | ❌ Not yet (deferred to goal event integration) | Future: MatchEvent goal records |

These are intentionally separate. The `playerStats` system is the V1 registered-only path. The `goalDrafts` system is the guest-aware path that will eventually produce `MatchEvent` goal documents.

### Test evidence

The "submits registered detailed stats while allowing guest MVP selection" test (line 660–750) still verifies:
```dart
expect(playerAStats.exists, isTrue);
expect(playerAStats.data()?['goals'], 1);
expect(playerBStats.exists, isTrue);
expect(guestStats.exists, isFalse);
```

**Verdict:** ✅ `PlayerMatchStats` behavior is 100% preserved. Goal drafts are a parallel, non-interfering system.

---

## Review Axis 3: Does it avoid writing goal MatchEvents?

### Code check

Zero references to `recordGoal`, `MatchEventType.goal`, or goal-related MatchEvent creation in the controller.

The `submit()` method (lines 264–374) only writes:
1. `_settlementService.submitScore(...)` → Match doc + `player_stats` subcollection (existing)
2. `_recordMvpMatchEventIfPossible(...)` → MVP `MatchEvent` only (from Task 6A)

### Test assertion

The `_expectNoGoalEvents` helper is called in **all 7 submit tests** (lines 468, 511, 553, 582, 616, 654, 746). Every test explicitly verifies zero goal events in Firestore after submission.

The goal mismatch test (line 437–472) is particularly important:
```dart
controller.setParticipantGoals(controller.teamAParticipants.single, 1);
// ... goal drafts exist but...
final updatedMatch = await controller.submit();
expect(updatedMatch?.scoreTeamA, 2);           // score submitted
await _expectNoGoalEvents(firestore, ...);     // NO goal events written
```

**Verdict:** ✅ Goal drafts are purely in-memory state. No goal events are persisted.

---

## Review Axis 4: Did it avoid UI changes?

`lib/features/match/views/score_submit_screen.dart`: **0 lines changed** (git diff = empty).

No new widgets, no new import references to goal draft types. The UI integration belongs to Tier 3.

**Verdict:** ✅ No UI changes.

---

## Review Axis 5: Does invalid participant input fail safely?

### Guard: participant not in roster

```dart
final sideKey = sideKeyForParticipant(participant);
if (sideKey == null) return;  // ← silent rejection
```

If a `ParticipantRef` is not in the loaded `MatchParticipantRoster`, `sideKeyFor` returns null and the method exits without adding a draft.

### Guard: negative/zero goals

```dart
if (goals <= 0) {
  clearParticipantGoals(participant);
  return;
}
```

Negative or zero goals clear any existing draft rather than creating an invalid one.

### Guard: null roster

If `fullParticipantRoster.value` is null (load failed), `sideKeyForParticipant` returns null → silent rejection.

### Guard: invalid side key in query

```dart
List<ScoreSubmitGoalDraft> goalDraftsForSide(String sideKey) {
  final normalizedSideKey = sideKey.trim().toUpperCase();
  if (normalizedSideKey != 'A' && normalizedSideKey != 'B') {
    return const <ScoreSubmitGoalDraft>[];
  }
  ...
}
```

### Test evidence

| Scenario | Test | Result |
|---|---|---|
| Participant not in roster | "ignores invalid goal draft participants safely" | `allGoalDrafts` is empty ✅ |
| Negative goals | Same test — `setParticipantGoals(participant, -1)` | `allGoalDrafts` is empty ✅ |
| Null roster | "full roster null prevents adding goal drafts safely" | `allGoalDrafts` is empty ✅ |

**Verdict:** ✅ All invalid inputs are silently rejected. No exceptions, no corrupt state.

---

## Review Axis 6: Does mismatch helper warn/compute only and not block submit?

### `goalDraftMismatchForSide` method (lines 226–235)

```dart
bool goalDraftMismatchForSide(String sideKey) {
  final normalizedSideKey = sideKey.trim().toUpperCase();
  final score = normalizedSideKey == 'A'
      ? totalTeamAGoals
      : normalizedSideKey == 'B'
      ? totalTeamBGoals
      : null;
  if (score == null) return false;
  return totalDraftGoalsForSide(normalizedSideKey) != score;
}
```

This is a **pure computation** — no side effects, no blocking, no error throwing. It returns `true` when the sum of goal drafts for a side doesn't equal the team's score.

### How `submit()` uses it

It **doesn't**. There is no call to `goalDraftMismatchForSide` inside `submit()`. The mismatch check is purely an API for the UI to display a warning. This matches architecture proposal decision D1: "Goal-count mismatch warns but does not block."

### Test evidence

"goal draft mismatch warns by helper but does not block submit" (line 437–472):

```dart
controller.teamAScoreController.text = '2';         // team score: 2
controller.setParticipantGoals(..., 1);              // draft total: 1

expect(controller.goalDraftMismatchForSide('A'), isTrue);  // mismatch detected

final updatedMatch = await controller.submit();
expect(updatedMatch?.scoreTeamA, 2);                 // submit succeeded anyway
```

**Verdict:** ✅ Mismatch is advisory only. Submit proceeds regardless. Per D1.

---

## Review Axis 7: Are MVP dual-write tests still intact?

### Task 6A MVP tests preserved

All 6 MVP-related tests from Task 6A are still present and unchanged:

| Test | Status |
|---|---|
| "submit with registered MVP writes one MVP MatchEvent" | ✅ Present (line 474) |
| "submit with temporary match-side MVP writes one MVP MatchEvent" | ✅ Present (line 516) |
| "submit with no MVP writes no MVP MatchEvent" | ✅ Present (line 559) |
| "submitScore failure writes no MVP MatchEvent" | ✅ Present (line 587) |
| "repeated submit does not create duplicate active MVP MatchEvents" | ✅ Present (line 621) |
| "submits registered detailed stats while allowing guest MVP selection" | ✅ Present (line 660) |

No existing test was modified, removed, or weakened.

**Verdict:** ✅ All Task 6A tests intact.

---

## Review Axis 8: Are tests sufficient?

### New goal draft tests (7 tests)

| Scenario | Covered? | Test |
|---|---|---|
| Registered player goal draft | ✅ | "adds goal drafts for registered participants" |
| Guest player goal draft with `linkedPlayerId` | ✅ | "adds goal drafts for guest participants" |
| MSP goal draft | ✅ | "adds goal drafts for temporary match-side participants" |
| Non-roster participant rejected | ✅ | "ignores invalid goal draft participants safely" |
| Negative goals rejected | ✅ | Same test — `setParticipantGoals(participant, -1)` |
| Null roster prevents drafts | ✅ | "full roster null prevents adding goal drafts safely" |
| `clearParticipantGoals` removes one | ✅ | "clears individual and all goal drafts" |
| `clearGoalDrafts` removes all | ✅ | Same test |
| Mismatch detection | ✅ | "goal draft mismatch warns by helper but does not block submit" |
| Mismatch doesn't block submit | ✅ | Same test — submit succeeds with mismatch |
| No goal events written on submit with drafts | ✅ | Mismatch test — `_expectNoGoalEvents` |
| `totalDraftGoalsForSide` aggregation | ✅ | Registered test — `totalDraftGoalsForSide('A') == 2` |
| `goalDraftsForSide` filtering | ✅ | Registered test — `totalDraftGoalsForSide('B') == 0` |
| Upsert existing draft (same participant, different count) | ❌ | Not tested — see F1 |
| Multiple participants with drafts on same side | ❌ | Not directly tested — see F2 |

### Test total: 17 tests

- 4 roster loading tests (from Task 5)
- 6 MVP dual-write tests (from Task 6A)
- 7 goal draft tests (this task)

**Verdict:** ✅ Strong coverage. Two minor gaps. See F1, F2.

---

## Review Axis 9: Is the temporary separation between PlayerMatchStats goals and ParticipantRef goal drafts documented?

### In-code documentation

The `ScoreSubmitGoalDraft` class has no doc comment explaining its role relative to `PlayerMatchStats`.

The `submit()` method has no comment explaining why `goalDrafts` are not consumed during submission.

### Architectural documentation

The architecture proposal (§7, §8) documents the separation:
> "Step 7: Update ScoreSubmitController... Build a List<GoalDraft> from participant picker input... V1 writes goal MatchEvents as best-effort."

And the final decisions (§15):
> "D1: Goal attribution is encouraged but optional in V1. D4: Goal-count mismatch warns but does not block."

### Is the separation clear enough?

The naming convention helps:
- `playerStats` → clearly registered-player-only (uses `Player.id` as key)
- `goalDrafts` → clearly participant-based (stores `ParticipantRef`)

However, a future developer reading `submit()` might wonder why `goalDrafts` are populated but never consumed. A brief comment would clarify. See F3.

**Verdict:** ⚠️ Architecture docs are clear. Code lacks an inline explanation of the intentional separation.

---

## Findings

### F1: Goal draft upsert not tested — LOW

**Severity:** Low

No test verifies calling `setParticipantGoals(participant, 2)` followed by `setParticipantGoals(participant, 5)`. The code uses `indexWhere` with `participantRosterKey` and replaces the existing draft at the found index (line 197), which is correct. But the upsert path is unverified.

**Action:** Consider adding a quick test. ~3 lines of assertions.

### F2: Multiple participants on same side not tested — LOW

**Severity:** Low

No test seeds two participants on the same side and verifies `totalDraftGoalsForSide` aggregation across both. The aggregation logic (`fold`) is simple enough, but a multi-participant test would strengthen confidence.

**Action:** Consider adding. Not blocking.

### F3: Missing inline comment explaining why `goalDrafts` are not consumed in `submit()` — SHOULD ADD

**Severity:** Low

A developer reading `submit()` might be confused that `goalDrafts` exist as reactive state but are not sent anywhere during submission. Adding a brief comment would prevent misunderstanding:

```dart
// Goal drafts are in-memory state for UI display and mismatch warnings.
// Goal MatchEvent persistence is deferred to a future integration step.
// PlayerMatchStats (registered-only) remain the authoritative goal source for V1.
final detailedStats = <PlayerMatchStats>[
  ...
```

**Action:** Add ~2–3 line comment. Quick.

### F4: `_rosterParticipantFor` uses `firstWhereOrNull` from GetX — INFO

**Severity:** Info

```dart
ParticipantRef? _rosterParticipantFor(
  ParticipantRef participant,
  String sideKey,
) {
  final key = participantRosterKey(participant);
  return fullParticipantRoster.value
      ?.participantsForSide(sideKey)
      .firstWhereOrNull(
        (candidate) => participantRosterKey(candidate) == key,
      );
}
```

This method ensures the goal draft's `actor` is the canonical roster copy (with the latest `displayName` and `linkedPlayerId`). It falls back to the caller-provided participant if not found. This is a good defensive pattern.

The `firstWhereOrNull` extension comes from GetX's `get_utils`. This is an existing dependency so no new imports are needed.

### F5: `minute` field in `ScoreSubmitGoalDraft` — FORWARD COMPATIBILITY

**Severity:** Info

The `minute` field is declared as `int?` and always `null` in this implementation. No setter or test populates it. This is forward-compatible with per-goal-event minute tracking in a future step, and costs nothing at present.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Goal drafts for all 3 kinds | ✅ Pass | player, guestPlayer, matchSidePlayer — all tested |
| 2. PlayerMatchStats preserved | ✅ Pass | Separate systems, no cross-contamination |
| 3. No goal events written | ✅ Pass | `_expectNoGoalEvents` in all submit tests |
| 4. No UI changes | ✅ Pass | Screen file 0 diff |
| 5. Invalid input safety | ✅ Pass | Non-roster, negative, null roster — all silently rejected |
| 6. Mismatch warns, doesn't block | ✅ Pass | Pure computation, submit succeeds with mismatch |
| 7. MVP dual-write tests intact | ✅ Pass | All 6 Task 6A tests unchanged |
| 8. Tests sufficient | ✅ Pass | 7 new tests covering CRUD, validation, mismatch |
| 9. Separation documented | ⚠️ Partial | Architecture docs clear; code needs inline comment |

### Before proceeding to Tier 3

1. Add inline comment in `submit()` explaining why `goalDrafts` are not consumed (F3).
2. Run `flutter test` to confirm all 17 tests pass.
