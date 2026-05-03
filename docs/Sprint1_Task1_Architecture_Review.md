# Sprint 1 / Task 1 — Architecture Review

**Reviewed:** 2026-05-03  
**Scope:** MatchEvent Foundation (Tier 1, Steps 1–3 + FirebasePaths)  
**Verdict:** ✅ PASS — minor findings, no blockers

---

## Files Reviewed

### New files (untracked, Sprint 1 output)

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/participant_ref.dart` | 34 | Identity value object |
| `lib/data/models/participant_ref_model.dart` | 59 | Serialization model |
| `lib/domain/entities/match_event.dart` | 66 | Event entity |
| `lib/data/models/match_event_model.dart` | 112 | Event serialization model |
| `lib/domain/repositories/match_event_repository.dart` | 10 | Repository interface |
| `lib/data/repositories/match_event_repository_impl.dart` | 90 | Firestore implementation |
| `lib/core/services/match_event_service.dart` | 180 | Business logic service |
| `test/data/models/participant_ref_model_test.dart` | 43 | ParticipantRef round-trip tests |
| `test/data/models/match_event_model_test.dart` | 70 | MatchEvent round-trip tests |
| `test/core/services/match_event_service_test.dart` | 185 | Service integration tests |

### Modified files

| File | Change |
|---|---|
| `lib/core/constants/firebase_paths.dart` | +1 line: `matchEvents` constant at line 11 |

### Verified untouched (git diff = empty)

| File | Status |
|---|---|
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/domain/entities/match.dart` | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/guest_claim_service.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |

---

## Review Axis 1: Does it follow the approved architecture?

### ParticipantRef entity

| Spec (proposal §3) | Implementation | Match? |
|---|---|---|
| `kind: 'player' \| 'guestPlayer' \| 'matchSidePlayer'` | `enum ParticipantRefKind { player, guestPlayer, matchSidePlayer }` | ✅ |
| `id: String` | `final String id` | ✅ |
| `displayName: String` | `final String displayName` | ✅ |
| `linkedPlayerId: String?` | `final String? linkedPlayerId` | ✅ |
| `copyWith` with sentinel for nullable | Uses `_unset` pattern consistent with codebase | ✅ |

### MatchEvent entity

| Spec (proposal §6) | Implementation | Match? |
|---|---|---|
| `matchId: string` | ✅ | |
| `tournamentId: string?` | ✅ | |
| `eventType: 'goal' \| 'mvp' \| 'assist' \| 'ownGoal'` | `enum MatchEventType { goal, mvp }` — assist and ownGoal omitted | ⚠️ See F1 |
| `sideKey: 'A' \| 'B'` | ✅ | |
| `actor: ParticipantRef` | ✅ embedded | |
| `assistedBy: ParticipantRef?` | Not present | ✅ Correct per D2 (assists deferred) |
| `minute: int?` | ✅ | |
| `createdBy: string` | ✅ | |
| `createdAt: timestamp` | ✅ (millisecondsSinceEpoch) | |
| `status: 'active' \| 'voided'` | `enum MatchEventStatus { active, voided }` | ✅ |

### MatchEventService

| Spec (proposal §11, step 3) | Implementation | Match? |
|---|---|---|
| `recordGoals` | ✅ `recordGoal` (single) + `recordGoals` (batch) | |
| `recordMvp` | ✅ | |
| `voidEvent` | ✅ | |
| `getMatchEvents` | ✅ | |
| `getTournamentGoalEvents` | ✅ | |
| `getMvpEvent` (not in proposal, but needed) | ✅ Added — good foresight | |
| Validation: actor belongs to match side | ❌ Not implemented — see F2 | |
| Validation: goals ≤ score | ❌ Not implemented — see F3 | |

### FirebasePaths

`matchEvents` constant added at line 11, grouped logically after `matches`. ✅

### Repository

| Method | Implementation | Notes |
|---|---|---|
| `createEvent` | ✅ Uses `doc(event.id).set()` | Idempotent — safe for retries |
| `getEventsByMatchId` | ✅ Filters by `status: active` | Correct |
| `getGoalEventsByTournamentId` | ✅ Filters by `eventType: goal` + `status: active` | Correct |
| `getMvpEventByMatchId` | ✅ Returns `events.last` (most recent) | Handles MVP re-selection gracefully |
| `voidEvent` | ✅ Updates `status` field only | Correct — soft delete per proposal |

---

## Review Axis 2: Did it accidentally refactor rating/fantasy/player_stats?

**No.** Git diff confirms zero changes to:
- `player_match_stats.dart` (entity + model)
- `match_settlement_service.dart`
- `rating_engine.dart`
- `fantasy_round_settlement_service.dart`
- `guest_claim_service.dart`
- `match.dart`

The `FirebasePaths` modification is a single additive line. No existing constant was renamed or moved.

**Verdict:** ✅ Clean isolation. The existing stats/rating/fantasy pipeline is completely untouched.

---

## Review Axis 3: Is the model safe for guest-player claim continuity?

### ParticipantRef.linkedPlayerId

- Field exists: ✅
- Nullable by default: ✅
- Serialized in both directions: ✅ (toJson always writes it, fromJson reads it as `String?`)
- The `_relinkMatchEvents` batch update (proposal §7) will set `actor.linkedPlayerId` via Firestore `update({'actor.linkedPlayerId': playerId})`. This writes into the nested map correctly because `actor` is serialized as a plain `Map<String, dynamic>`.

### Forward compatibility for claim

The `ParticipantRefModel.toJson()` always writes `linkedPlayerId` even when null:

```dart
'linkedPlayerId': linkedPlayerId,  // writes null explicitly
```

This is **safe**. When `GuestClaimService` later does:
```dart
batch.update(doc.reference, {'actor.linkedPlayerId': linkedPlayerId});
```

It will overwrite the null with the real player ID. No field mismatch.

### Risk: Firestore nested field update

Firestore `update({'actor.linkedPlayerId': value})` performs a dot-notation field update. It modifies only `linkedPlayerId` inside the `actor` map without overwriting the entire `actor` object. This is correct and safe.

**Verdict:** ✅ Claim continuity is structurally sound.

---

## Review Axis 4: Are serialization fields stable and explicit?

### ParticipantRefModel

| Field | Write | Read | Stable? |
|---|---|---|---|
| `kind` | `ref.kind.name` (enum name string) | `json['kind'] as String? ?? 'player'` | ✅ Fallback to player for unknown kinds |
| `id` | Direct string | `json['id'] as String? ?? ''` | ✅ |
| `displayName` | Direct string | `json['displayName'] as String? ?? ''` | ✅ |
| `linkedPlayerId` | Direct nullable string | `json['linkedPlayerId'] as String?` | ✅ |

### MatchEventModel

| Field | Write | Read | Stable? |
|---|---|---|---|
| `matchId` | Direct string | `json['matchId'] as String? ?? ''` | ✅ |
| `tournamentId` | Direct nullable string | `json['tournamentId'] as String?` | ✅ |
| `eventType` | Enum name string | `json['eventType'] as String? ?? 'goal'` | ✅ |
| `sideKey` | Direct string | `json['sideKey'] as String? ?? ''` | ✅ |
| `actor` | `actor.toJson()` (embedded map) | Type-checked `Map<String, dynamic>` with fallback | ✅ |
| `minute` | Direct nullable int | `(json['minute'] as num?)?.toInt()` | ✅ |
| `createdBy` | Direct string | `json['createdBy'] as String? ?? ''` | ✅ |
| `createdAt` | `millisecondsSinceEpoch` | Custom `_dateFromMs` with `DateTime.now()` fallback | ✅ |
| `status` | Enum name string | `json['status'] as String? ?? 'active'` | ✅ |

### Notes

- All fields have defensive fallbacks for corrupted/incomplete documents. Good.
- `toJson()` does NOT include `id` in the output (document ID is the Firestore doc key). Consistent with codebase convention (`MatchModel`, `PlayerModel` all do the same).
- `fromJson` takes `docId` as a separate parameter. Correct.

**Verdict:** ✅ Serialization is stable, explicit, and defensive.

---

## Review Axis 5: Are tests sufficient?

### Coverage matrix

| Scenario | Covered? | Test file |
|---|---|---|
| ParticipantRef round-trip (guestPlayer with linkedPlayerId) | ✅ | `participant_ref_model_test.dart` |
| ParticipantRef unknown kind fallback | ✅ | `participant_ref_model_test.dart` |
| ParticipantRef round-trip (registered player, no link) | ❌ Missing | — |
| ParticipantRef round-trip (matchSidePlayer) | ❌ Covered in model test via MatchEvent, not standalone | `match_event_model_test.dart` |
| MatchEvent goal round-trip with matchSidePlayer | ✅ | `match_event_model_test.dart` |
| MatchEvent MVP + voided status parsing | ✅ | `match_event_model_test.dart` |
| MatchEvent with null optional fields | Partial (minute null tested) | `match_event_model_test.dart` |
| Service: record goal + MVP, load by match + tournament | ✅ | `match_event_service_test.dart` |
| Service: guest player as goal scorer | ✅ | `match_event_service_test.dart` |
| Service: guest player as MVP | ❌ Covered only as goal scorer. MVP test uses registered player. | — |
| Service: recordGoals batch with sort verification | ✅ | `match_event_service_test.dart` |
| Service: voidEvent excludes from queries | ✅ | `match_event_service_test.dart` |
| Service: sideKey validation (rejects 'C') | ✅ | `match_event_service_test.dart` |
| Service: required field validation (empty matchId) | ✅ | `match_event_service_test.dart` |
| Service: negative minute validation | ✅ | `match_event_service_test.dart` |
| Service: empty actor.id validation | ✅ | `match_event_service_test.dart` |
| Service: sideKey normalization (lowercase → uppercase) | ✅ | `match_event_service_test.dart` (passes 'a', expects 'A') |

### Test gaps (minor, not blocking)

1. **No standalone ParticipantRef test for `player` kind** — the model test covers `guestPlayer` and `unknown` but not the basic `player` case. Low risk since the code path is trivial.
2. **No guest-player-as-MVP test** — the service test records MVP with a registered player. Should add a test with `guestActor` as MVP to complete the matrix from the architecture spec.

**Verdict:** ⚠️ Good coverage, two minor gaps. See F4.

---

## Review Axis 6: Is anything over-engineered for V1?

### Checked for excess

| Concern | Verdict |
|---|---|
| Extra event types beyond V1 (assist, ownGoal) | ✅ Not present — correctly scoped |
| Complex aggregation logic in service | ✅ Not present — service is thin |
| Pre-built TournamentTopScorersResolver | ✅ Not present — correctly deferred to Step 8 |
| Full participant roster loader in this task | ✅ Not present — correctly deferred to Step 4 |
| Claim relink logic in this task | ✅ Not present — correctly deferred to Step 9 |
| Over-complex event ID generation | Borderline — see F5 |

### MatchGoalDraft DTO

The `MatchGoalDraft` class in `match_event_service.dart` is a lightweight DTO for batch goal recording. It has 4 fields. Not over-engineered — it avoids passing 6+ named parameters per goal in a list.

### Event sorting in repository

`_compareEvents` sorts by minute → createdAt → id. This is fine for display ordering. The `1 << 30` sentinel for null minutes pushes events without a minute to the end, which is reasonable.

**Verdict:** ✅ Appropriately scoped. No YAGNI violations.

---

## Findings

### F1: Missing `ownGoal` enum value — ACCEPTABLE

**Severity:** None (design decision, not a bug)

The proposal schema listed `eventType: 'goal' | 'mvp' | 'assist' | 'ownGoal'`, but the implementation has only `{ goal, mvp }`. Both `assist` and `ownGoal` are explicitly deferred to V1.1 per decision D2 and the deferral table (§16).

The `_parseEventType` method in `MatchEventModel` has an `orElse` fallback to `goal`, so if a future version writes `ownGoal` events, old client code won't crash — it'll misinterpret them as goals, which is acceptable for forward compatibility.

**Action:** None needed. When V1.1 adds these, extend the enum. No migration.

### F2: No match-side membership validation in service — ACCEPTABLE FOR TIER 1

**Severity:** Low

The architecture proposal (§11, Step 3) specified: "Validate: actor belongs to match side." The service does NOT validate this — it validates field formats but not whether the actor is actually a participant in the match.

This is acceptable because:
1. Tier 1 is foundation only. The full participant roster loader (Step 4) doesn't exist yet.
2. The `ScoreSubmitController` v2 (Step 7) will be the integration point where the UI constrains choices to actual participants.
3. Adding match-side validation now would require loading match data inside the service, creating an unnecessary dependency.

**Action:** Add validation when integrating with `ScoreSubmitController` in Tier 2 (Step 7). The service stays thin.

### F3: No goal-count vs. score mismatch warning — ACCEPTABLE FOR TIER 1

**Severity:** Low

Per decision D4, the system should warn when assigned goals ≠ score but not block. The service has no such logic.

This is correct for Tier 1 because:
1. The warning is a UI concern (yellow indicator), not a service concern.
2. The service doesn't know the match score — it would need match data injection.
3. The `ScoreSubmitController` (Step 7) is the right place for this validation.

**Action:** Implement mismatch warning in `ScoreSubmitController` v2 (Tier 2, Step 7).

### F4: Two minor test gaps — SHOULD FIX

**Severity:** Low

Missing tests:
1. **Guest player as MVP:** `match_event_service_test.dart` tests MVP only with `registeredActor`. Add a test recording MVP with `guestActor` to match the spec: "Guest player accepted as MVP."
2. **Standalone `player` kind round-trip:** `participant_ref_model_test.dart` covers `guestPlayer` and `unknown` but not the basic `player` kind. Add for completeness.

**Action:** Add both tests before moving to Tier 2. Estimated effort: <10 minutes.

### F5: Event ID generation could be simpler — SUGGESTION

**Severity:** Cosmetic

The `_eventId` method generates IDs like `goal-match-1-1714762800000000`. This is functional but:
- The microsecond suffix could collide across devices (unlikely but theoretically possible).
- A UUID would be more conventional (and the project already uses `package:uuid` in `ShareLinkService`).

However, the method accepts an `eventId` parameter, so callers can provide their own ID (tests already do: `'goal-1'`, `'mvp-1'`). The auto-generated format is only a fallback.

**Action:** No change needed. If collisions become a concern in production, switch to UUID. Current approach is fine for V1.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Follows approved architecture | ✅ Pass | All entities, fields, and patterns match proposal |
| 2. No rating/fantasy/player_stats changes | ✅ Pass | Zero diff on all protected files |
| 3. Claim continuity safe | ✅ Pass | `linkedPlayerId` field present, serialized, dot-notation update compatible |
| 4. Serialization stable and explicit | ✅ Pass | Defensive fallbacks, consistent with codebase conventions |
| 5. Tests sufficient | ⚠️ Minor gaps | Add guest-MVP test and player-kind round-trip test |
| 6. Not over-engineered | ✅ Pass | No YAGNI violations, correctly deferred items |

### Before proceeding to Tier 2

1. Add guest-player-as-MVP test to `match_event_service_test.dart`.
2. Add `player` kind round-trip test to `participant_ref_model_test.dart`.
3. Run `flutter test` to confirm all tests pass.
