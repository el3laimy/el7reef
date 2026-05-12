# Sprint 1 / Task 7 — Architecture Review

**Reviewed:** 2026-05-04  
**Scope:** Tournament Top Scorers Resolver  
**Verdict:** ✅ PASS — minimal, correct, well-tested

---

## Files Reviewed

### New files (untracked — no existing code modified)

| File | Lines | Role |
|---|---|---|
| `lib/core/services/tournament_top_scorers_resolver.dart` | 98 | Resolver service + value objects |
| `test/core/services/tournament_top_scorers_resolver_test.dart` | 258 | 6 unit tests |

### Verified untouched (0 diff on all protected files)

| File | Status |
|---|---|
| `lib/features/match/views/` (any screen) | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | Modified by Task 4 only |
| `lib/core/services/match_event_service.dart` | Untracked from Task 1, not modified here |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `firestore.rules` | Modified by Task 1 only |

> This task adds **only two new files**. No existing file was modified.

---

## Review Axis 1: Does it aggregate only goal MatchEvents for the requested tournament?

### Query chain (resolver → service → repository)

```
TournamentTopScorersResolver.getTopScorers(tournamentId)
  → MatchEventService.getTournamentGoalEvents(tournamentId)
    → MatchEventRepository.getGoalEventsByTournamentId(tournamentId)
      → Firestore: matchEvents
          WHERE tournamentId == tournamentId
          AND   eventType   == 'goal'
          AND   status      == 'active'
```

The Firestore query (`match_event_repository_impl.dart` lines 40–44) applies three filters simultaneously:
1. `tournamentId` — scopes to this tournament only
2. `eventType == 'goal'` — filters out MVP events at the query layer
3. `status == 'active'` — excludes voided events at the query layer

This means MVP events and voided events are **never fetched** from Firestore. They are not filtered in Dart — they are excluded at the source.

### Resolver aggregation (lines 36–48)

```dart
for (final event in events) {
  final actor = event.actor;
  if (!_isTournamentLeaderboardActor(actor)) continue;  // ← MSP filter
  final key = _scorerKey(actor);
  totals.update(key, (acc) => acc.increment(),
                ifAbsent: () => _ScorerAccumulator(actor: actor, goals: 1));
}
```

Each event represents one goal. Aggregation counts events per `_scorerKey`.

**Verdict:** ✅ Only active goal events for the requested tournament are fetched and aggregated.

---

## Review Axis 2: Does it exclude matchSidePlayer from tournament leaderboards?

### `_isTournamentLeaderboardActor` guard (lines 62–65)

```dart
bool _isTournamentLeaderboardActor(ParticipantRef actor) {
  return actor.kind == ParticipantRefKind.player ||
      actor.kind == ParticipantRefKind.guestPlayer;
}
```

`matchSidePlayer` is explicitly excluded. If a `matchSidePlayer` scored goals in a tournament match (which is valid in the goal-draft system for V1 display-only purposes), those goals simply don't count toward the tournament leaderboard.

This matches the final product decision from the architecture proposal:
> "MatchSidePlayer can receive display-only goals in friendlies, but only GuestPlayer/registered players appear in long-term claimable tournament leaderboards."

### Why not filter at the Firestore query level?

Because Firestore doesn't know `actor.kind` — the actor is stored as a nested map inside the event document, and Firestore doesn't support nested field inequality on embedded objects without a composite index. Filtering in Dart is correct here.

### Test evidence

"excludes matchSidePlayer events from tournament leaderboard" (lines 91–116):
```dart
// Seed: 1 registered player goal + 5 matchSidePlayer goals
await _recordGoals(actor: registeredActor, count: 1, ...);
await _recordGoals(actor: matchSideActor, count: 5, ...);

final scorers = await resolver.getTopScorers('tournament-1');

expect(scorers, hasLength(1));
expect(scorers.single.actor.kind, ParticipantRefKind.player);
expect(scorers.single.actor.id, 'player-1');
expect(scorers.single.goals, 1);  // NOT 6
```

The `matchSideActor` with 5 goals is completely invisible to the leaderboard.

**Verdict:** ✅ `matchSidePlayer` excluded via `_isTournamentLeaderboardActor` — correct and tested.

---

## Review Axis 3: Does it include player and guestPlayer correctly?

### Registered player

"aggregates multiple goals for the same registered player" (lines 50–67):
```dart
await _recordGoals(actor: registeredActor, count: 3, ...);
final scorers = await resolver.getTopScorers('tournament-1');

expect(scorers.single.actor.kind, ParticipantRefKind.player);
expect(scorers.single.actor.id, 'player-1');
expect(scorers.single.actor.displayName, 'Ali');
expect(scorers.single.goals, 3);
```

### Guest player

"aggregates guest player goals and preserves linkedPlayerId" (lines 69–89):
```dart
await _recordGoals(actor: guestActor, count: 2, ...);
final scorers = await resolver.getTopScorers('tournament-1');

expect(scorers.single.actor.kind, ParticipantRefKind.guestPlayer);
expect(scorers.single.actor.id, 'guest-1');
expect(scorers.single.actor.displayName, 'Bassem');
expect(scorers.single.goals, 2);
```

### Mixed tournament

"sorts by goals descending and applies limit" (lines 144–187) uses:
- `oneGoalActor` → `player`
- `twoGoalActor` → `guestPlayer`
- `threeGoalActor` → `player`

Both registered and guest actors appear in the top scorers list, sorted correctly by goals.

**Verdict:** ✅ Both `player` and `guestPlayer` aggregated and returned correctly.

---

## Review Axis 4: Does it preserve ParticipantRef, including linkedPlayerId?

### Accumulator stores the full actor

```dart
_ScorerAccumulator(actor: actor, goals: 1)
```

The `actor` is the full `ParticipantRef` from the stored MatchEvent. The resolver doesn't reconstruct or truncate it.

### Accumulator key uses kind+id composite

```dart
String _scorerKey(ParticipantRef actor) => '${actor.kind.name}:${actor.id}';
```

This key (`player:player-1`, `guestPlayer:guest-1`) ensures different kinds with the same ID don't collide. When updating an existing accumulator, the stored actor (with its `linkedPlayerId`) is preserved intact via the immutable `_ScorerAccumulator` record.

### Output maps actor directly

```dart
TournamentTopScorerEntry(
  actor: accumulator.actor,  // ← full ParticipantRef, no truncation
  goals: accumulator.goals,
)
```

### Test evidence

"aggregates guest player goals and preserves linkedPlayerId" (line 86):
```dart
expect(scorers.single.actor.linkedPlayerId, 'claimed-player-1');
```

**Verdict:** ✅ Full `ParticipantRef` preserved end-to-end, including `linkedPlayerId` for claim continuity.

---

## Review Axis 5: Does it ignore voided and MVP events?

### Voided events

Excluded at the Firestore query layer:
```dart
.where('status', isEqualTo: MatchEventStatus.active.name)
```

The resolver never receives voided events from the repository.

### MVP events

Excluded at the Firestore query layer:
```dart
.where('eventType', isEqualTo: MatchEventType.goal.name)
```

MVP events have `eventType == 'mvp'` and are filtered before returning.

### Test evidence

"ignores MVP events and voided goal events" (lines 118–142):
```dart
// Write an MVP event
await matchEventService.recordMvp(eventId: 'mvp-1', ...actor: registeredActor...);

// Write a goal, then void it
await matchEventService.recordGoal(eventId: 'voided-goal-1', ...actor: registeredActor...);
await matchEventService.voidEvent('voided-goal-1');

final scorers = await resolver.getTopScorers('tournament-1');
expect(scorers, isEmpty);
```

Neither the MVP event nor the voided goal contributes to the leaderboard.

**Verdict:** ✅ Both exclusions happen at the query layer. No in-memory filtering needed for correctness.

---

## Review Axis 6: Is sorting deterministic?

### `_compareEntries` (lines 69–85) — 4-level tie-breaking

```dart
int _compareEntries(
  TournamentTopScorerEntry left,
  TournamentTopScorerEntry right,
) {
  // 1. Goals descending
  final goalsCompare = right.goals.compareTo(left.goals);
  if (goalsCompare != 0) return goalsCompare;

  // 2. Display name ascending (case-insensitive)
  final nameCompare = left.actor.displayName.toLowerCase().compareTo(
    right.actor.displayName.toLowerCase(),
  );
  if (nameCompare != 0) return nameCompare;

  // 3. Actor ID ascending
  final idCompare = left.actor.id.compareTo(right.actor.id);
  if (idCompare != 0) return idCompare;

  // 4. Kind name ascending
  return left.actor.kind.name.compareTo(right.actor.kind.name);
}
```

The four-level sort guarantees a total order for any combination of actors, assuming:
- Goals differ → sorted by goals ✅
- Same goals, different names → sorted alphabetically ✅
- Same goals, same name, different IDs → sorted by ID ✅
- Same goals, same name, same ID, different kinds → sorted by kind name ✅

The only case that produces identical sort keys is the same `goals + displayName + id + kind` — which is only possible for the same participant (can't happen in practice since `kind:id` is the accumulator key).

### Test evidence

"sorts by goals descending and applies limit" — verifies:
```dart
expect(scorers.map((e) => e.actor.id), ['player-3', 'guest-2']); // 3 goals, 2 goals
```

"uses displayName then id as deterministic tie-breaker" — verifies alphabetical ordering on ties:
```dart
// All 3 actors have 2 goals
// Adam (player-b) < Ali (guest-a) < Ali (player-z)  [name then id]
expect(scorers.map((e) => e.actor.id), ['player-b', 'guest-a', 'player-z']);
```

The tie-breaker test is rigorous: same goal count, same display name for two actors, with `id` being the final discriminator (`guest-a` < `player-z`).

**Verdict:** ✅ Sort is deterministic. 4-level tie-breaking with tested edge case.

---

## Review Axis 7: Is the API small and suitable for later Tournament UI?

### Public surface of `TournamentTopScorersResolver`

```dart
class TournamentTopScorersResolver {
  TournamentTopScorersResolver({MatchEventService? matchEventService});

  Future<List<TournamentTopScorerEntry>> getTopScorers(
    String tournamentId, {
    int limit = 10,
  }) async { ... }
}
```

One class, one method, one optional named parameter. The default `limit: 10` matches a typical leaderboard card.

### `TournamentTopScorerEntry` value object

```dart
class TournamentTopScorerEntry {
  final ParticipantRef actor;    // full identity (kind, id, displayName, linkedPlayerId)
  final int goals;               // total goals in tournament
  final String? teamDisplayName; // optional, null in V1 — placeholder for future
}
```

The `teamDisplayName` field is `null` in V1 (no population logic). It's present as a forward-compatibility slot for when team context is added to the UI. Its presence is harmless.

### What the Tournament UI will need

| UI element | API field | Ready? |
|---|---|---|
| Rank number | Index in list (1-based) | ✅ |
| Player display name | `actor.displayName` | ✅ |
| Player kind badge (registered / guest) | `actor.kind` | ✅ |
| Goals scored | `goals` | ✅ |
| Claim link for guests | `actor.linkedPlayerId` | ✅ |
| Team name | `teamDisplayName` | ⏳ V1.1 |
| Limit for "Top 5" card vs full list | `limit` parameter | ✅ |

**Verdict:** ✅ Minimal and complete API for V1 tournament leaderboard. No over-engineering.

---

## Review Axis 8: Did it avoid UI, settlement, rating, fantasy, PlayerMatchStats, and Firestore rules/index changes?

| Component | Expected | Actual |
|---|---|---|
| Any UI screen file | Untouched | ✅ No UI files changed |
| `match_settlement_service.dart` | Not this task | ✅ Changes from Task 4 only |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `firestore.rules` | Not this task | ✅ Changes from Task 1 only |
| Firestore indexes | New composite index needed | ⚠️ See F1 |
| Any existing service/repo modified | None | ✅ Only new files created |

> The `match_event_service.dart` already had `getTournamentGoalEvents` added in Task 1 (`??` untracked). The repository method `getGoalEventsByTournamentId` was also part of Task 1. This task only adds the resolver that **consumes** them.

**Verdict:** ✅ No existing file modified. Two new files only.

---

## Review Axis 9: Are tests sufficient?

### Test coverage matrix

| Scenario | Test | Covered? |
|---|---|---|
| Empty tournament, zero limit, negative limit | "returns empty list for no events and non-positive limits" | ✅ |
| Registered player — 3 goals aggregated | "aggregates multiple goals for the same registered player" | ✅ |
| Guest player — 2 goals + `linkedPlayerId` preserved | "aggregates guest player goals and preserves linkedPlayerId" | ✅ |
| MSP excluded even with more goals than others | "excludes matchSidePlayer events from tournament leaderboard" | ✅ |
| MVP event not counted | "ignores MVP events and voided goal events" | ✅ |
| Voided goal event not counted | Same test | ✅ |
| Goals sorted descending | "sorts by goals descending and applies limit" | ✅ |
| `limit` parameter respected | Same test — `limit: 2` from 3 actors | ✅ |
| Tie-breaking: name then id | "uses displayName then id as deterministic tie-breaker" | ✅ |
| Cross-tournament isolation | Not tested — see F2 | ❌ |
| `teamDisplayName` always null in V1 | Line 66: `expect(teamDisplayName, isNull)` | ✅ |
| Mixed registered + guest in same leaderboard | Limit test — `player + guestPlayer` both included | ✅ |

### Test infrastructure

- Uses `FakeFirebaseFirestore` for real Firestore query behavior ✅
- Uses actual `MatchEventService` + `MatchEventRepositoryImpl` (not mocks) — exercises the full query stack ✅
- `_recordGoals` helper cleanly creates N events with correct IDs ✅
- Tests are pure (no `setUp` side effects between tests — each uses fresh data) ✅

**Verdict:** ✅ 6 tests covering all critical axes. One minor gap (cross-tournament isolation).

---

## Findings

### F1: Composite Firestore index required for `getGoalEventsByTournamentId` — MUST TRACK

**Severity:** Medium

The query:
```
WHERE tournamentId == tournamentId
AND   eventType   == 'goal'
AND   status      == 'active'
```

Requires a composite index on `matchEvents`: `(tournamentId ASC, eventType ASC, status ASC)`.

Without this index, Firestore will reject the query in production (though `FakeFirebaseFirestore` doesn't enforce it). This index should be declared in `firestore.indexes.json` before the leaderboard is exposed in the app.

The `firestore.rules` file was extended in Task 1 — the indexes file may not have been updated.

**Action:** Verify `firestore.indexes.json` includes this composite index before Task 7 goes to production. Blocking for launch, not for development.

### F2: Cross-tournament isolation not explicitly tested — LOW

**Severity:** Low

No test seeds events for `tournament-1` and `tournament-2` and verifies that `getTopScorers('tournament-1')` does not count events from `tournament-2`. The Firestore `WHERE tournamentId == ...` filter makes this safe in practice, but a test would confirm it.

**Action:** Optional. Add a test with two tournaments and verify isolation. Not blocking.

### F3: `teamDisplayName` is always null — ACCEPTED PLACEHOLDER

**Severity:** Info

The `TournamentTopScorerEntry.teamDisplayName` field is declared but never populated. The test explicitly asserts `isNull`. This is an intentional V1 placeholder for V1.1 team-context enrichment.

The field's presence adds ~1 line of memory overhead per entry. Harmless.

### F4: `_scorerKey` composite is correct for V1 but has a known limitation — INFO

**Severity:** Info

`_scorerKey` = `'${actor.kind.name}:${actor.id}'`

If a guest player `guest-1` later claims and becomes registered player `p-123`, and if both appear in the same tournament (pre- and post-claim), they would be counted as two separate scorers. This is the claim-continuity limitation noted in the architecture proposal and expected to be resolved via the claim flow (which writes `linkedPlayerId` to existing events).

For V1 this is acceptable — `linkedPlayerId` provides the bridge for the UI to merge entries if needed.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Only goal events for requested tournament | ✅ Pass | Triple-filtered at Firestore query layer |
| 2. `matchSidePlayer` excluded from leaderboard | ✅ Pass | `_isTournamentLeaderboardActor` + tested |
| 3. `player` and `guestPlayer` included correctly | ✅ Pass | Both kinds tested individually and together |
| 4. `ParticipantRef` + `linkedPlayerId` preserved | ✅ Pass | End-to-end assertion in guest test |
| 5. Voided and MVP events ignored | ✅ Pass | Filtered at query layer, not in Dart |
| 6. Sorting deterministic | ✅ Pass | 4-level comparator + tie-breaker test |
| 7. API small and UI-ready | ✅ Pass | 1 method, 3-field value object, correct defaults |
| 8. No protected file changes | ✅ Pass | 0 diff, new files only |
| 9. Tests sufficient | ✅ Pass | 6 tests, all critical scenarios covered |

### Before connecting to Tournament UI

1. Verify `firestore.indexes.json` has the composite index for `(tournamentId, eventType, status)` — F1.
2. Optionally add cross-tournament isolation test — F2.
