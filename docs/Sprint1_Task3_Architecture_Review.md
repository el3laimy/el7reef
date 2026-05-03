# Sprint 1 / Task 3 — Architecture Review

**Reviewed:** 2026-05-03  
**Scope:** Full Participant Roster Loader (Tier 1, Step 4)  
**Verdict:** ✅ PASS — well-structured, two minor findings

---

## Files Reviewed

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `lib/domain/entities/match_participant_roster.dart` | 62 | Roster entity with side membership helpers |
| `test/core/services/official_match_roster_service_test.dart` | 344 | Integration tests with FakeFirestore |

### Modified files

| File | Change |
|---|---|
| `lib/core/services/official_match_roster_service.dart` | +432 lines — added `loadParticipantRoster`, new dependencies, private helpers |

### Verified untouched (git diff = 0 lines)

| File | Status |
|---|---|
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/guest_claim_service.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/features/match/controllers/score_submit_controller.dart` | ✅ Clean |

---

## Review Axis 1: Does it keep existing `loadRegisteredRoster` behavior intact?

### Method preservation

The original `loadRegisteredRoster` method (lines 82–121) is **completely unchanged**:
- Same signature: `({required String matchId, Match? match})`
- Same logic: loads snapshots → `_resolveSidePlayerIds` → `_projectRegisteredPlayerIds` → fetch `Player` objects
- Same return type: `OfficialMatchRegisteredRoster`
- Same helper methods preserved: `_findSnapshotForSide`, `_projectRegisteredPlayerIds`, `_normalizeIds`

### Constructor compatibility

The constructor was extended with new optional parameters:

```dart
// Before
OfficialMatchRosterService({
  FirebaseFirestore? firestore,
  PlayerRepositoryImpl? playerRepository,
})

// After (all new params are optional with defaults)
OfficialMatchRosterService({
  FirebaseFirestore? firestore,
  PlayerRepositoryImpl? playerRepository,
  GuestPlayerRepository? guestPlayerRepository,      // NEW
  TeamMembershipRepository? membershipRepository,     // NEW
  MatchSideRepositoryImpl? matchSideRepository,       // NEW
  MatchSidePlayerRepositoryImpl? matchSidePlayerRepository, // NEW
})
```

**All new parameters are optional with sensible defaults.** Existing callers that use `OfficialMatchRosterService()` or `OfficialMatchRosterService(firestore: firestore)` continue to work without changes.

Verified callers:
| Caller | Instantiation | Breaks? |
|---|---|---|
| `ScoreSubmitController` | `OfficialMatchRosterService()` | ✅ No |
| `FanVotingController` | `OfficialMatchRosterService()` | ✅ No |
| `FanVotingService` | `OfficialMatchRosterService(firestore: firestore)` | ✅ No |
| `MatchSettlementService` | `OfficialMatchRosterService(firestore: firestore)` | ✅ No |

**Verdict:** ✅ Existing behavior fully preserved. Zero risk of regression on `loadRegisteredRoster`.

---

## Review Axis 2: Does it correctly map all participant types to ParticipantRef?

### Mapping matrix

| Source | Kind assigned | ID used | DisplayName source | linkedPlayerId |
|---|---|---|---|---|
| `MatchLineupEntry.playerId` | `player` | playerId | Player.name → entry.displayName fallback | null |
| `MatchLineupEntry.guestPlayerId` | `guestPlayer` | guestPlayerId | GuestPlayer.displayName → entry.displayName fallback | GuestPlayer.linkedPlayerId |
| `MatchLineupEntry.matchSidePlayerId` (with MSP.playerId set) | `player` | MSP.playerId | MSP.displayName → entry.displayName fallback | null |
| `MatchLineupEntry.matchSidePlayerId` (no MSP.playerId) | `matchSidePlayer` | matchSidePlayerId | MSP.displayName → entry.displayName fallback | null |
| `TeamMembership.playerId` (no lineup) | `player` | playerId | Player.name | null |
| `TeamMembership.guestPlayerId` (no lineup) | `guestPlayer` | guestPlayerId | GuestPlayer.displayName | GuestPlayer.linkedPlayerId |
| `MatchSidePlayer.playerId` (side player) | `player` | playerId | MSP.displayName → Player.name | null |
| `MatchSidePlayer` (temporary, no playerId) | `matchSidePlayer` | MSP.id | MSP.displayName | null |

### Key design decisions verified

1. **Registered MSP → player kind:** When a `MatchSidePlayer` has `kind: 'registered'` and a `playerId`, it correctly maps to `ParticipantRefKind.player` (line 370–376). This avoids duplicate identity for the same real player.

2. **Guest player `linkedPlayerId` propagation:** The `_resolveParticipantRef` method (line 500–512) correctly reads `guestPlayer.linkedPlayerId` from the loaded entity and embeds it into the `ParticipantRef`. This means claimed guest players will already have their link set when the roster is loaded.

3. **Fallback display names:** Every mapping has a fallback chain (loaded entity name → snapshot entry display name). Candidates without any display name are filtered out (`return null` at lines 492–494, 504–506, 515–517).

4. **Guest team fallback path:** When no lineup snapshot exists and the side entity is a guest team (`TournamentParticipantSourceType.guestTeam`), the code loads guest players via `_guestPlayerRepository.getGuestTeamPlayers(entityId)` (line 400). This covers the case where a guest team was added to a tournament without a lineup being created.

**Verdict:** ✅ All three participant kinds are correctly mapped with proper identity resolution.

---

## Review Axis 3: Does it preserve side A/B membership?

### Side resolution flow

1. `loadParticipantRoster` calls `_buildSideContext` twice — once for `'A'`, once for `'B'`.
2. Each call uses `_findFullSnapshotForSide` which matches by `sideKey`, then `teamId`/`guestTeamId`, then `matchSideId`.
3. `matchSidePlayers` are filtered by `player.sideKey == normalizedSide` (line 282).
4. The resulting `MatchParticipantRoster` has separate `sideA` and `sideB` lists.

### Cross-side isolation

- Each side is built independently in `_buildSideContext`.
- The `_ParticipantSideContext` collects candidates per-side.
- `_resolveParticipantRefs` deduplicates within a side only (line 466–480).
- If a player appears on both sides (edge case), they will appear in both lists. This is technically possible but unlikely in practice. The `allParticipants` getter deduplicates across sides (line 15–24).

### `MatchParticipantRoster` helpers

| Method | Behavior | Correct? |
|---|---|---|
| `participantsForSide('A')` | Returns `sideA` | ✅ |
| `participantsForSide('B')` | Returns `sideB` | ✅ |
| `participantsForSide('C')` | Returns empty list | ✅ Safe |
| `isParticipantOnSide(participant, sideKey)` | Checks `kind:id` key match | ✅ |
| `sideKeyFor(participant)` | Returns 'A', 'B', or null | ✅ |
| `allParticipants` | Deduplicated union of both sides | ✅ |

### `participantRosterKey` function

```dart
String participantRosterKey(ParticipantRef participant) {
  return '${participant.kind.name}:${participant.id}';
}
```

Uses `kind:id` composite key. This means a `player:123` and `guestPlayer:123` are treated as different participants — correct, since they are different entities with the same string ID.

**Verdict:** ✅ Side membership is correctly preserved and queryable.

---

## Review Axis 4: Does it avoid duplicates safely?

### Deduplication strategy

1. **Within-side deduplication:** `_resolveParticipantRefs` uses a `Set<String> seen` with `participantRosterKey` as the dedup key (line 466–480). First occurrence wins.

2. **Cross-side deduplication:** NOT applied to `sideA`/`sideB` — each side keeps its full list. Only `allParticipants` deduplicates.

3. **Candidate sources that could produce duplicates:**
   - A player in `match.teamAPlayerIds` AND in a `TeamMembership` AND in a `MatchSidePlayer` with `playerId` set — all three would produce `_ParticipantCandidate.player('same-id')`. The `seen` set prevents duplicates.
   - Test coverage: the "de-duplicates participants" test (line 136–169) verifies exactly this scenario.

### Edge case: MSP with `playerId` appearing alongside the same player from roster

The code adds candidates from both the snapshot/roster AND from `matchSidePlayers` (line 303–305). If a player appears in both, the dedup ensures only one `ParticipantRef` per `kind:id` combination.

**Verdict:** ✅ Deduplication is safe and tested.

---

## Review Axis 5: Is it suitable for ScoreSubmit and MVP validation integration?

### What Step 7 (ScoreSubmitController v2) will need

1. **Load all participants for a match** → `loadParticipantRoster(matchId: matchId)` ✅
2. **Get participants for a specific side** → `roster.participantsForSide('A')` ✅
3. **Validate MVP belongs to match** → `roster.allParticipants.any((p) => p.id == mvpId)` ✅
4. **Get side for a participant (for goal event)** → `roster.sideKeyFor(participantRef)` ✅
5. **Display name for picker UI** → `participant.displayName` ✅
6. **Distinguish guest from registered in UI** → `participant.kind` ✅

### What Step 6 (MatchSettlementService MVP fix) will need

The settlement service will need to validate `mvpPlayerId` against the full participant list. It can:
```dart
final roster = await _officialRosterService.loadParticipantRoster(matchId: matchId);
final isValidMvp = roster.allParticipants.any(
  (p) => p.id == mvpPlayerId,
);
```

This is straightforward. No additional methods needed.

**Verdict:** ✅ The API surface is complete for all planned Tier 2 integrations.

---

## Review Axis 6: Did it accidentally touch UI, settlement, rating, fantasy, or PlayerMatchStats?

### Git diff verification

| File | Diff lines |
|---|---|
| `match_settlement_service.dart` | 0 |
| `rating_engine.dart` | 0 |
| `guest_claim_service.dart` | 0 |
| `fantasy_round_settlement_service.dart` | 0 |
| `player_match_stats.dart` | 0 |
| `score_submit_controller.dart` | 0 |
| Any UI screen file | 0 |

The only modified file is `official_match_roster_service.dart` itself. All changes are additive — no existing line was modified or removed.

**Verdict:** ✅ Clean isolation. No collateral changes.

---

## Review Axis 7: Are tests sufficient?

### Coverage matrix

| Scenario | Covered? | Test |
|---|---|---|
| Registered player from team membership → `player` kind | ✅ | "maps registered team players" |
| Guest player from membership → `guestPlayer` kind with `linkedPlayerId` | ✅ | "maps guest team members" |
| Temporary MSP → `matchSidePlayer` kind | ✅ | "maps temporary match-side players" |
| Registered MSP (with playerId) → promoted to `player` kind | ✅ | "maps registered match-side players" |
| Deduplication within a side | ✅ | "de-duplicates participants" |
| Empty sides (no participants) | ✅ | "returns empty side lists" |
| Side membership helpers (`isParticipantOnSide`, `sideKeyFor`, `participantsForSide`) | ✅ | "side membership helper checks" |
| Invalid sideKey returns empty | ✅ | `participantsForSide('C')` |
| Arabic display names | ✅ | All tests use Arabic names |
| Guest player with existing claim link | ✅ | "maps guest team members" — `linkedPlayerId: 'claimed-player-1'` |

### Test gaps

| Missing scenario | Severity | Notes |
|---|---|---|
| Lineup snapshot path (starters + bench) | Medium | All tests use the no-snapshot fallback path (membership/fallback IDs). No test with a `MatchLineupSnapshot` seeded. See F1. |
| Guest team fallback via `TournamentParticipant` | Low | The `_candidatesFromOfficialRoster` path for `guestTeam` source type is untested. Requires seeding `tournamentParticipants` collection. See F2. |
| Multiple participants on both sides simultaneously | Low | Tests only seed one side at a time. A mixed test (2 on A, 2 on B) would strengthen confidence. |
| `allParticipants` deduplication across sides | Low | `allParticipants` is called in the empty test but not verified with data in both sides. The helper test uses `sideA.single` and `sideB.single` but doesn't test `allParticipants` dedup. |

**Verdict:** ⚠️ Good fundamental coverage, but the lineup-snapshot code path is untested. See F1.

---

## Findings

### F1: Lineup snapshot code path untested — SHOULD FIX

**Severity:** Medium

The `_candidatesFromSnapshot` method (lines 342–387) parses `MatchLineupEntry` objects from a `MatchLineupSnapshot` and produces `_ParticipantCandidate` objects. This is the primary code path for tournament matches that have locked lineups.

**All 6 tests** operate without seeding any `matchLineupSnapshots` documents, so they all exercise the fallback path (team membership + fallback player IDs). The snapshot path — which handles the tri-kind `playerId`/`guestPlayerId`/`matchSidePlayerId` logic — has zero test coverage in this file.

**Risk:** The snapshot path contains the most complex logic (cross-referencing lineup entries with match side players, promoting registered MSPs). A bug here would affect tournament matches with lineups.

**Action:** Add at least one test that seeds a `MatchLineupSnapshot` with starters containing a mix of registered, guest, and MSP entries. Verify correct `ParticipantRef` kinds.

### F2: Guest team via TournamentParticipant untested — LOW RISK

**Severity:** Low

`_candidatesFromOfficialRoster` (lines 389–417) has a special branch for `TournamentParticipantSourceType.guestTeam` that loads guest players via `getGuestTeamPlayers`. This is untested.

**Risk:** Low because the fallback produces guest players the same way other code paths do. But the `_loadParticipant` method does a Firestore read that hasn't been verified under test.

**Action:** Consider adding a test if time permits. Not blocking.

### F3: `_buildSideContext` adds MSP candidates unconditionally — ACCEPTABLE

**Severity:** Info

Lines 303–305:
```dart
entries.addAll(
  sidePlayers.map((player) => _candidateFromMatchSidePlayer(player)),
);
```

This runs regardless of whether a snapshot was found. If a lineup snapshot already included these same MSPs via `_candidatesFromSnapshot`, they'll be added twice — but the dedup in `_resolveParticipantRefs` filters them. The duplication is harmless but could be avoided by skipping this step when a snapshot is present.

**Action:** None needed. Dedup handles it correctly. If performance becomes a concern (unlikely with small rosters), optimize later.

### F4: `participantRosterKey` is a top-level function — DESIGN NOTE

**Severity:** Info

`participantRosterKey` is defined as a top-level function in `match_participant_roster.dart` (line 59). It's used by both the roster entity and the roster service. Making it top-level is correct for shared access, but it's worth noting that it creates a public API surface.

If `ParticipantRef` gains an `==` and `hashCode` override later, this function becomes redundant. For now, it's the right approach since `ParticipantRef` is a simple value object without equality.

**Action:** None needed.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. `loadRegisteredRoster` intact | ✅ Pass | Zero lines changed. All callers compatible. |
| 2. Correct ParticipantRef mapping | ✅ Pass | All three kinds handled with proper identity resolution and fallbacks |
| 3. Side A/B membership preserved | ✅ Pass | Separate context per side, queryable helpers |
| 4. Deduplication safe | ✅ Pass | `kind:id` composite key, tested |
| 5. Suitable for ScoreSubmit/MVP integration | ✅ Pass | All needed API methods present |
| 6. No UI/settlement/rating/fantasy changes | ✅ Pass | Zero diff on all protected files |
| 7. Tests sufficient | ⚠️ Gap | Lineup snapshot code path untested |

### Before proceeding to Tier 2

1. **Add lineup-snapshot test** — seed `MatchLineupSnapshot` with mixed entry kinds, verify correct `ParticipantRef` output.
2. Run `flutter test` to confirm all tests pass.
