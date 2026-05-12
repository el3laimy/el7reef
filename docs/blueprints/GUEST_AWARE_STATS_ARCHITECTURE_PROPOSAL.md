# Guest-Aware Stats Architecture Proposal

**Date:** 2026-05-02  
**Updated:** 2026-05-02 — product decisions finalized  
**Scope:** V1 Tournament Ego MVP — smallest safe architecture  
**Status:** ✅ APPROVED — product decisions locked, ready for implementation

---

## 1. Current State Summary

### What exists and works

| Component | Location | Status |
|---|---|---|
| `PlayerMatchStats` entity | `lib/domain/entities/player_match_stats.dart` | Registered players only. Uses `playerId` (string, no kind). |
| `PlayerMatchStatsModel` | `lib/data/models/player_match_stats_model.dart` | Serializes to `matches/{matchId}/player_stats/{playerId}` subcollection. |
| `Match.mvpPlayerId` | `lib/domain/entities/match.dart:18` | Single `String?` — assumed to be a registered `Player.id`. |
| `MatchSidePlayer` | `lib/domain/entities/match_side_player.dart` | Has `kind` field (`registered` / `temporary`), `playerId` nullable. Already identity-aware. |
| `MatchLineupEntry` | `lib/domain/entities/match_lineup_entry.dart` | Has `playerId`, `guestPlayerId`, `matchSidePlayerId` — exactly one set. Already tri-kind. |
| `GuestPlayer` | `lib/domain/entities/guest_player.dart` | Full entity with `linkedPlayerId`, `claimStatus`, `claimCode`. |
| `ScoreSubmitController` | `lib/features/match/controllers/score_submit_controller.dart` | Loads only registered roster via `OfficialMatchRosterService.loadRegisteredRoster`. Builds `PlayerMatchStats` for registered `Player` objects only. |
| `MatchSettlementService.submitScore` | `lib/core/services/match_settlement_service.dart:53-146` | Filters `detailedStats` to `eligiblePlayerIds` (registered only). Validates MVP against registered roster. Writes `player_stats` subcollection for registered only. |
| `MatchSettlementService.approveScore` | Same file, line 148-284 | Applies rating deltas to registered `Player` documents only. Skips if either side has no registered players (line 206-216). |
| `OfficialMatchRosterService` | `lib/core/services/official_match_roster_service.dart` | `_projectRegisteredPlayerIds` explicitly filters out guests (line 120-123 comment: "guest players remain display-only"). |
| `GuestClaimService` | `lib/core/services/guest_claim_service.dart` | Links `guestPlayer.linkedPlayerId`, relinks memberships, syncs team rosters. **Does NOT migrate stats or match events.** |
| `FirebasePaths` | `lib/core/constants/firebase_paths.dart` | No `matchEvents` collection defined. |

### The critical gap

The entire stats pipeline — from `ScoreSubmitController` through `MatchSettlementService` to `player_stats` subcollection — is **registered-player-only by design**. Guest players and temporary match-side players are systematically excluded at every layer:

1. **Controller layer:** loads only `Player` objects from `OfficialMatchRosterService`.
2. **Service layer:** filters stats to `eligiblePlayerIds` (registered roster).
3. **MVP validation:** rejects any ID not in `eligiblePlayerIds`.
4. **Storage layer:** writes to `matches/{matchId}/player_stats/{playerId}` keyed by registered player ID.
5. **Claim layer:** `GuestClaimService` links identity but does not migrate any stats data.

---

## 2. Problem Statement

For Tournament Ego MVP, a guest player must be able to:

1. Score a goal and appear in the match result.
2. Be selected as MVP.
3. Appear in tournament top scorers leaderboard.
4. Appear in share cards (Result, MVP, Player, Top Scorers).
5. Later claim their profile and retain all historical stats.

None of these are possible with the current architecture.

---

## 3. Recommended Identity Model: `ParticipantRef`

A lightweight embedded struct that identifies **who** an event belongs to, regardless of registration status.

```
ParticipantRef
├── kind: 'player' | 'guestPlayer' | 'matchSidePlayer'
├── id: String              // Player.id or GuestPlayer.id or MatchSidePlayer.id
├── displayName: String     // snapshot at time of recording
└── linkedPlayerId: String? // set after claim (for guestPlayer kind)
```

**Why not just use `playerId` everywhere?**
- Guest players don't have a `Player` document.
- Temporary match-side players don't have either.
- After claim, the `guestPlayer` ID doesn't change — only `linkedPlayerId` is set.
- Share cards and leaderboards need `displayName` without a join.

**Why embedded, not a reference to a separate collection?**
- Avoids extra reads for every leaderboard/card render.
- `displayName` is a snapshot — it won't change retroactively.
- Matches the existing pattern in `MatchLineupEntry` (tri-kind with `participantId` getter).

---

## 4. Decision: Extend PlayerMatchStats vs. Introduce MatchEvent

### Option A: Extend `PlayerMatchStats` to support guest identity

- Add `participantKind` + nullable `guestPlayerId` / `matchSidePlayerId` to existing entity.
- Keep subcollection `matches/{matchId}/player_stats/{participantId}`.
- Pros: fewer new files, reuses existing model.
- Cons: the entity was designed for fantasy scoring (saves, tackles, cleanSheet, rating, position). This is heavy for a simple "who scored?" record. The document ID becomes ambiguous (player ID vs guest ID vs MSP ID).

### Option B: Introduce `MatchEvent` as a new lightweight entity

- New top-level collection `matchEvents`.
- Each document = one discrete event (goal, mvp, assist).
- Contains `ParticipantRef` for the actor.
- `PlayerMatchStats` stays as-is for fantasy/rating (out of V1 scope).

### ✅ Recommendation: Option B — Introduce `MatchEvent`

**Rationale:**

1. `PlayerMatchStats` carries fantasy-oriented fields (saves, tackles, cleanSheet, rating, position) that are irrelevant to "who scored goal #3."
2. V1 needs only: goals, MVP, optional assists. Not detailed per-player performance stats.
3. A goal event needs: matchId, sideKey, actor (ParticipantRef), eventType, minute. That's it.
4. Top scorers = `query matchEvents where eventType == goal, group by actor.id`.
5. MVP = `query matchEvents where eventType == mvp, matchId == X`.
6. The existing `player_stats` subcollection can continue to serve registered-player rating settlement without interference.
7. Separating events from aggregate stats avoids contaminating the existing rating engine.

**What happens to `PlayerMatchStats`?**
- Keep it. Don't touch it. It stays as the registered-player rating/fantasy data source.
- `MatchEvent` becomes the source of truth for goals, MVP, assists — the pride data.
- In V1, `approveScore` continues to use `PlayerMatchStats` for rating deltas (registered only). This is acceptable because rating is not guest-facing in V1.

---

## 5. Backward Compatibility Strategy

| Concern | Strategy |
|---|---|
| Existing `player_stats` subcollection | Keep writing it for registered players in `submitScore`. No migration needed. |
| Existing `Match.mvpPlayerId` | Keep field. In V1 phase 1, store the `ParticipantRef.id` here (may be a guestPlayer ID). Settlement service validates against expanded roster, not just registered. |
| Existing `approveScore` rating engine | No change for V1. Ratings still apply to registered players only. Guest rating is out of scope. |
| Old matches without `matchEvents` | No events = no goals/MVP in new leaderboards. Acceptable for V1. Optional: write a one-time backfill script post-launch for important matches. |
| `OfficialMatchRosterService` | Create parallel method `loadFullParticipantRoster` that returns registered + guest + MSP. Keep `loadRegisteredRoster` for rating engine. |

---

## 6. Firestore Structure Recommendation

### New collection: `matchEvents`

```
matchEvents/{eventId}
├── matchId: string
├── tournamentId: string?
├── eventType: 'goal' | 'mvp' | 'assist' | 'ownGoal'
├── sideKey: 'A' | 'B'
├── actor: {                    // ParticipantRef
│   ├── kind: string
│   ├── id: string
│   ├── displayName: string
│   └── linkedPlayerId: string?
│   }
├── assistedBy: ParticipantRef?  // V1: optional, can skip initially
├── minute: int?                 // optional, nice to have
├── createdBy: string            // actorId of the person recording
├── createdAt: timestamp
├── status: 'active' | 'voided'
```

### Required Firestore indexes

```
matchEvents: matchId + eventType + status (composite)
matchEvents: tournamentId + eventType + status (composite, for top scorers)
```

### New constant in `FirebasePaths`

```dart
static const String matchEvents = 'matchEvents';
```

### Firestore rules (matchEvents)

```
match /matchEvents/{eventId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
    && request.resource.data.createdBy == request.auth.uid;
  allow update: if request.auth != null
    && resource.data.createdBy == request.auth.uid
    && request.resource.data.matchId == resource.data.matchId
    && request.resource.data.createdBy == resource.data.createdBy;
  allow delete: if false; // use status = voided
}
```

> **Note:** V1 simplification. Production would check organizer/tournament permission. For V1, client-side validation in services is sufficient; rules prevent anonymous and cross-user tampering.

---

## 7. Claim-Later Continuity Strategy

### Current gap

`GuestClaimService.claimGuestPlayer`:
- Sets `guestPlayer.linkedPlayerId = playerId`.
- Relinks `teamMemberships`.
- Updates `Player.teamIds`.
- **Does NOT touch `matchEvents`, `player_stats`, or `Match.mvpPlayerId`.**

### V1 strategy: query-time resolution, not write-time migration

When a guest player is claimed (`guestPlayer.linkedPlayerId` is set):

1. **matchEvents are NOT rewritten.** The `actor.kind` stays `guestPlayer`, `actor.id` stays the guestPlayer ID.
2. **Add `actor.linkedPlayerId`** to the matchEvent at claim time (batch update).
3. **Leaderboard/profile queries** resolve both:
   - Direct: `where actor.id == playerId && actor.kind == player`
   - Linked: `where actor.linkedPlayerId == playerId`
   - Or: pre-aggregate at claim time into a snapshot.

### Recommended V1 approach: claim-time batch update

When `GuestClaimService.claimGuestPlayer` completes:

```
1. Query matchEvents where actor.kind == 'guestPlayer' AND actor.id == guestPlayerId
2. Batch update each: set actor.linkedPlayerId = playerId
3. Query matches where mvpPlayerId == guestPlayerId
   → optionally update or leave (MVP card can resolve via ParticipantRef)
```

**Why batch update at claim time instead of query-time join?**
- Simpler leaderboard queries (single `where` clause).
- Firestore doesn't support OR across different fields efficiently.
- Batch is bounded: a guest player will have at most ~50 events across a tournament. Safe for one batch.

### Addition to `GuestClaimService`

Add a post-claim step (outside the main transaction, as it touches a different collection):

```dart
Future<void> _relinkMatchEvents({
  required String guestPlayerId,
  required String linkedPlayerId,
}) async {
  final events = await _firestore
      .collection(FirebasePaths.matchEvents)
      .where('actor.kind', isEqualTo: 'guestPlayer')
      .where('actor.id', isEqualTo: guestPlayerId)
      .get();
  
  if (events.docs.isEmpty) return;
  
  final batch = _firestore.batch();
  for (final doc in events.docs) {
    batch.update(doc.reference, {
      'actor.linkedPlayerId': linkedPlayerId,
    });
  }
  await batch.commit();
}
```

---

## 8. MVP Attribution Strategy

### Current problem

`Match.mvpPlayerId` is a plain `String?`. `MatchSettlementService.submitScore` validates it against `eligiblePlayerIds` (registered only). If a guest is MVP, the service throws.

### V1 fix

**Phase 1 (minimum):** Change `mvpPlayerId` validation in `submitScore` to accept any participant in the match (registered + guest + MSP), not just registered roster.

Concretely:
1. Load full participant list (registered players + guest players + matchSidePlayers).
2. Validate `mvpPlayerId` against this full list.
3. Store `mvpPlayerId` as-is (the guest/MSP ID).
4. Write a `MatchEvent` with `eventType: mvp` and `actor: ParticipantRef`.

**Phase 2 (if needed post-V1):** Replace `Match.mvpPlayerId` with `Match.mvpParticipantRef` map. For V1, the string field is sufficient because the MatchEvent is the authoritative record.

### MVP in share cards

The MVP card reads from `matchEvents where matchId == X && eventType == mvp`, not from `Match.mvpPlayerId`. This way the card always has the full `ParticipantRef` with `displayName`.

---

## 9. Tournament Top Scorers Strategy

### Data source

```
Query: matchEvents
  where tournamentId == X
  where eventType == 'goal'
  where status == 'active'
  where actor.kind in ['player', 'guestPlayer']   // exclude matchSidePlayer
```

Group by `actor.id`, count, sort descending.

> **Product rule:** Only `player` and `guestPlayer` kinds appear in tournament leaderboards. `matchSidePlayer` goals are recorded for match-level display (result cards, friendly share) but are excluded from persistent tournament rankings because they are unclaimable.

### Read strategy for V1

**Option A: Client-side aggregation**  
- Query all goal events for the tournament (bounded: ~50 matches × ~5 goals = ~250 docs max for a small tournament).
- Group and sort in Dart.
- Pros: no extra collection, always fresh.
- Cons: reads scale with tournament size.

**Option B: Server-side snapshot**  
- After each score approval, write/update `tournamentScorerSnapshots/{tournamentId}` with pre-aggregated list.
- Pros: single doc read for leaderboard.
- Cons: extra write path, denormalization.

### ✅ Recommendation: Option A for V1, Option B later

V1 targets 4-8 team tournaments. 250 event docs is well within Firestore read budget. Client-side aggregation is simpler and avoids denormalization bugs.

Add a utility:

```dart
class TournamentTopScorersResolver {
  Future<List<ScorerEntry>> getTopScorers(String tournamentId, {int limit = 10});
}
```

Where `ScorerEntry` = `{ParticipantRef actor, int goals, String? teamDisplayName}`.

---

## 10. Migration Risk

| Risk | Severity | Mitigation |
|---|---|---|
| Old matches have no `matchEvents` | Low | Old matches won't appear in tournament leaderboards. Acceptable for V1 — tournaments are new. |
| `Match.mvpPlayerId` contains guest ID after change | Medium | Code that reads `mvpPlayerId` and assumes it's a `Player.id` (e.g. `activity_feed_service.dart:191`) will fail silently. Must audit all readers. |
| `player_stats` subcollection still registered-only | Low | Keep it. Rating engine uses it. No user-facing dependency in V1 tournament flow. |
| `GuestClaimService` batch update fails mid-way | Low | `_relinkMatchEvents` runs outside main transaction. Partial failure = some events unlinked. Idempotent retry is safe. |
| Firestore rules block new collection | Low | Add rules before deploying. Test with emulator. |

### `mvpPlayerId` readers to audit

| File | Line | Impact |
|---|---|---|
| `match_settlement_service.dart` | 223, 237, 249, 263 | Compares `mvpPlayerId` to registered `player.id` for rating bonus. If MVP is guest, no match → no bonus. **Acceptable.** |
| `activity_feed_service.dart` | 191 | `recentMatch.mvpPlayerId == actor.id` — only triggers for registered player. Guest MVP won't trigger feed item. **Fix later.** |
| `fantasy_round_settlement_service.dart` | 267-281 | Fantasy is gated. **No impact.** |

---

## 11. Step-by-Step Implementation Plan

### Step 1: ParticipantRef value object
- Create `lib/domain/entities/participant_ref.dart`
- Create `lib/data/models/participant_ref_model.dart` (toJson/fromJson)
- Unit test serialization

### Step 2: MatchEvent entity + model + repository
- Create `lib/domain/entities/match_event.dart`
- Create `lib/data/models/match_event_model.dart`
- Create `lib/domain/repositories/match_event_repository.dart` (interface)
- Create `lib/data/repositories/match_event_repository_impl.dart`
- Add `FirebasePaths.matchEvents`
- Unit test CRUD

### Step 3: MatchEventService
- Create `lib/core/services/match_event_service.dart`
- Methods: `recordGoals`, `recordMvp`, `voidEvent`, `getMatchEvents`, `getTournamentGoalEvents`
- Validate: actor belongs to match side, goals ≤ score
- Unit test

### Step 4: Full participant roster loader
- Add `loadFullParticipantRoster` to `OfficialMatchRosterService` (or new service)
- Returns list of `ParticipantRef` for all players in a match (registered + guest + MSP)
- Keep existing `loadRegisteredRoster` untouched

### Step 5: ScoreSubmitController v2
- Load full participant roster instead of registered-only
- Build unified participant picker UI data
- On submit: call `MatchEventService.recordGoals` + `MatchEventService.recordMvp`
- Remove registered-only filtering

### Step 6: MatchSettlementService MVP validation fix
- Expand `submitScore` MVP validation to accept full participant list
- Keep `approveScore` rating engine registered-only (no change)

### Step 7: Tournament top scorers
- Create `TournamentTopScorersResolver`
- Query `matchEvents` by tournamentId + goal + active
- Client-side aggregation
- Wire into Tournament Detail UI (Scorers tab)

### Step 8: Claim-later stat relink
- Add `_relinkMatchEvents` to `GuestClaimService`
- Call after successful claim transaction
- Unit test: events get `linkedPlayerId` set

### Step 9: Firestore rules + indexes
- Add `matchEvents` rules to `firestore.rules`
- Add composite indexes
- Test with emulator

### Step 10: Share cards wiring
- MVP Card reads from `matchEvents` (mvp event for match)
- Top Scorers Card reads from `TournamentTopScorersResolver`
- Result Card enhanced with goal scorers from `matchEvents`

---

## 12. Files Likely Affected

### New files

| File | Purpose |
|---|---|
| `lib/domain/entities/participant_ref.dart` | Identity value object |
| `lib/data/models/participant_ref_model.dart` | Serialization |
| `lib/domain/entities/match_event.dart` | Event entity |
| `lib/data/models/match_event_model.dart` | Event model |
| `lib/domain/repositories/match_event_repository.dart` | Interface |
| `lib/data/repositories/match_event_repository_impl.dart` | Firestore impl |
| `lib/core/services/match_event_service.dart` | Event business logic |
| `lib/core/services/tournament_top_scorers_resolver.dart` | Leaderboard query |
| `test/core/services/match_event_service_test.dart` | Tests |
| `test/data/models/match_event_model_test.dart` | Tests |
| `test/core/services/tournament_top_scorers_resolver_test.dart` | Tests |

### Modified files

| File | Change |
|---|---|
| `lib/core/constants/firebase_paths.dart` | Add `matchEvents` constant |
| `lib/features/match/controllers/score_submit_controller.dart` | Load full roster, build events, wire MVP to all participants |
| `lib/core/services/match_settlement_service.dart` | Expand MVP validation, call MatchEventService |
| `lib/core/services/official_match_roster_service.dart` | Add `loadFullParticipantRoster` method |
| `lib/core/services/guest_claim_service.dart` | Add `_relinkMatchEvents` post-claim step |
| `firestore.rules` | Add `matchEvents` rules |

### Untouched (intentionally)

| File | Reason |
|---|---|
| `lib/domain/entities/player_match_stats.dart` | Stays for rating/fantasy. Not part of V1 event flow. |
| `lib/data/models/player_match_stats_model.dart` | Same. |
| `lib/core/services/rating_engine.dart` | Registered-only rating is acceptable for V1. |
| `lib/core/services/fantasy_round_settlement_service.dart` | Fantasy is gated. |

---

## 13. Test Plan

### Unit tests (new)

| Test | What it verifies |
|---|---|
| `ParticipantRef` serialization round-trip | All three kinds serialize/deserialize correctly |
| `MatchEventModel` fromJson/toJson | Field mapping, nullable handling |
| `MatchEventService.recordGoals` | Creates goal events with correct ParticipantRef |
| `MatchEventService.recordGoals` with guest | Guest player accepted as goal scorer |
| `MatchEventService.recordMvp` with guest | Guest player accepted as MVP |
| `MatchEventService.voidEvent` | Sets status to voided, not deleted |
| `MatchEventService` goal count validation | Warns if assigned goals ≠ score; does not block submission |
| `TournamentTopScorersResolver` | Correct aggregation and ordering |
| `TournamentTopScorersResolver` with mixed players | Guest and registered appear together |
| `GuestClaimService._relinkMatchEvents` | Sets `linkedPlayerId` on all matching events |
| `GuestClaimService._relinkMatchEvents` idempotency | Re-running doesn't break |

### Existing tests (verify no regression)

| Test file | Expectation |
|---|---|
| `match_settlement_service_test.dart` | All existing tests pass unchanged |
| `guest_claim_service_test.dart` | All existing tests pass; new relink test added |
| `official_match_roster_service_test.dart` | Existing tests pass; new full-roster test added |

### Manual QA scenario

1. Create tournament with 2 guest teams, each with 2 guest players.
2. Generate fixture, start match.
3. Submit score: 2-1. Assign 1 goal to guest player A, 1 goal to guest player B, 1 goal to guest player C.
4. Assign MVP to guest player A.
5. Verify: tournament top scorers shows all three guest players.
6. Verify: MVP card shows guest player A by name.
7. Guest player A claims profile via link.
8. Verify: player profile shows 1 goal, 1 MVP.
9. Verify: tournament top scorers still correct (no duplicates, no missing).

---

## 14. Final Product Decisions for V1

All five open questions have been resolved. These decisions are **locked** and must not be revisited during implementation.

### D1: Goal attribution — encouraged but optional

After score input, the UI shows a "من سجل؟" section. The organizer can assign individual goal scorers or skip entirely. If skipped, no `matchEvent` goal documents are written and the tournament top scorers leaderboard stays empty for that match. This matches street reality — the organizer may not know who scored.

### D2: Assists — deferred to V1.1

V1 records goals and MVP only. The `MatchEvent` schema already includes `assistedBy: ParticipantRef?` as a nullable field, so adding assists later requires zero migration. The scoring UI is simpler without an assist picker.

### D3: MVP — dual-write to `Match.mvpPlayerId` AND `MatchEvent`

On score submission:
1. Write `Match.mvpPlayerId` with the participant's ID (may be a guestPlayer or matchSidePlayer ID).
2. Write a `MatchEvent` with `eventType: mvp` containing the full `ParticipantRef`.

MVP share cards read from the `MatchEvent` (has `displayName`). Existing code that reads `Match.mvpPlayerId` continues to work for registered players. Guest MVP gracefully degrades in legacy surfaces (no crash, just no match).

### D4: Goal-count mismatch — warn, do not block

If assigned goals ≠ score, show a yellow indicator:
> "الأهداف المسجلة (2) أقل من النتيجة (3)"

The submission proceeds regardless. Street football reality: own goals, disputed counts, and late corrections are common. Blocking would frustrate organizers.

### D5: MatchSidePlayer goals — display-only, excluded from tournament leaderboards

`matchSidePlayer` (temporary, no `GuestPlayer` record) **can** receive goal attribution in friendlies for display in result cards and friendly share cards. However:

- **Tournament leaderboards** query only `actor.kind in ['player', 'guestPlayer']`.
- `matchSidePlayer` goals are **not claimable** and do not appear in persistent rankings.
- This prevents phantom entries in leaderboards from unnamed pickup players.

---

## 15. Implementation Order — What Must Come Before UI

The implementation is split into three tiers: **foundation** (no UI dependency), **integration** (wires foundation into existing flows), and **UI** (user-facing changes).

### Tier 1: Foundation (must complete before any UI work)

These produce no visible change but are prerequisites for everything else.

| Order | Task | Output | Depends on |
|:---:|---|---|---|
| 1 | `ParticipantRef` entity + model | Value object, serialization, tests | Nothing |
| 2 | `MatchEvent` entity + model + repository | CRUD layer, `FirebasePaths.matchEvents` | Step 1 |
| 3 | `MatchEventService` | Business logic: `recordGoals`, `recordMvp`, `voidEvent`, validation | Step 2 |
| 4 | Full participant roster loader | `loadFullParticipantRoster` on `OfficialMatchRosterService` | Step 1 |
| 5 | Firestore rules + indexes for `matchEvents` | Security rules, composite indexes | Step 2 |

**Gate:** All Tier 1 tasks must pass unit tests before proceeding.

### Tier 2: Integration (connects foundation to existing flows)

| Order | Task | Output | Depends on |
|:---:|---|---|---|
| 6 | `MatchSettlementService` MVP validation fix | Accepts guest/MSP MVP IDs | Steps 3, 4 |
| 7 | `ScoreSubmitController` v2 | Loads full roster, calls `MatchEventService`, dual-writes MVP | Steps 3, 4, 6 |
| 8 | `TournamentTopScorersResolver` | Client-side aggregation from `matchEvents`, excludes MSP from tournament boards | Step 3 |
| 9 | Claim-later relink in `GuestClaimService` | `_relinkMatchEvents` post-claim batch | Steps 2, 3 |

**Gate:** Integration tests pass. Manual test: guest player scores goal → appears in `matchEvents` → claim → `linkedPlayerId` set.

### Tier 3: UI (user-facing, depends on Tiers 1+2)

| Order | Task | Depends on |
|:---:|---|---|
| 10 | Score submit screen: unified participant picker | Step 7 |
| 11 | Score submit screen: goal attribution section ("من سجل؟") | Step 7 |
| 12 | Score submit screen: MVP picker showing all participants | Step 7 |
| 13 | Score submit screen: goal-count mismatch warning indicator | Step 7 |
| 14 | Tournament detail: Top Scorers tab | Step 8 |
| 15 | Share cards: MVP Card from `MatchEvent` | Steps 7, 8 |
| 16 | Share cards: Top Scorers Card | Step 8 |
| 17 | Share cards: Result Card with goal scorers | Step 7 |

---

## 16. Deferred to V1.1

These items are explicitly **out of scope** for V1. The architecture supports them without migration.

| Item | Why deferred | Migration needed later? |
|---|---|---|
| Assists | Adds UI complexity (scorer → assister picker). Schema ready (`assistedBy` nullable). | No — just populate the existing field. |
| Server-side scorer snapshots (`tournamentScorerSnapshots`) | Client-side aggregation is sufficient for 4-8 team tournaments. | No — additive write path. |
| `Match.mvpParticipantRef` map field | `mvpPlayerId` string + `MatchEvent` dual-write is sufficient. | Optional — can replace field later without breaking events. |
| Guest player rating deltas | Rating engine stays registered-only. Guest rating is not user-facing in V1. | Moderate — requires `approveScore` changes. |
| Activity feed for guest MVP | `activity_feed_service.dart:191` silently skips guest MVP. Low priority. | Low — add `MatchEvent` lookup in feed builder. |
| Backfill old matches into `matchEvents` | Old matches predate the tournament focus. No user expectation. | Low — one-time script. |
| `MatchSidePlayer` → `GuestPlayer` upgrade path | If a friendly MSP player later joins a tournament, they need a `GuestPlayer` record. Not V1. | Low — create `GuestPlayer` from MSP data. |
| Own goal tracking | `eventType: ownGoal` is in the schema but no UI or business logic in V1. | No — just add UI + service method. |

---

## Summary

The smallest safe path to guest-aware stats for V1:

1. **New `MatchEvent` collection** — don't extend `PlayerMatchStats`.
2. **`ParticipantRef` value object** — tri-kind identity, embedded in events.
3. **Expand MVP validation** — accept all participants, not just registered.
4. **Client-side top scorers** — query events, aggregate in Dart. Exclude `matchSidePlayer` from tournament boards.
5. **Claim-time batch relink** — set `linkedPlayerId` on events after claim.
6. **Keep `player_stats` untouched** — rating engine stays registered-only.
7. **Keep `Match.mvpPlayerId` field** — dual-write to both field and event.
8. **Goal attribution optional** — encouraged via UI nudge, not required.
9. **Warn on mismatch** — never block score submission.

Total new files: ~11. Modified files: ~6. Existing test regression risk: low.

**Build order:** Foundation (steps 1-5) → Integration (steps 6-9) → UI (steps 10-17). No UI work should begin before Tier 1 passes all tests.
