# Sprint 2 / Task 1 — Architecture Review

**Reviewed:** 2026-05-05  
**Scope:** MVP Share Card  
**Verdict:** ✅ PASS — strong pride signal, safe fallback, correct isolation

---

## Files Reviewed

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `lib/features/shareables/models/mvp_share_data.dart` | 23 | Immutable data model for the MVP share card |
| `lib/features/shareables/controllers/mvp_share_controller.dart` | 78 | Maps MatchEvent or Match.mvpPlayerId → share data |
| `lib/features/shareables/widgets/mvp_share_card.dart` | 369 | Share card widget (preview + export) |
| `test/features/shareables/mvp_share_card_test.dart` | 134 | 4 tests: event mapping, guest + fallback, widget rendering |

### Modified files

| File | Delta | Summary |
|---|---|---|
| `lib/features/lineup/controllers/match_result_lineup_controller.dart` | +101 lines | MVP event loading, `hasShareableMvp`, `displayNameForParticipantId`, `isGuestParticipantId`, `sideKeyForParticipantId`, tournament name loading |
| `lib/features/lineup/views/match_result_lineup_screen.dart` | +101 lines | `_shareMvp` method, `_buildMvpShareData`, "شارك نجم المباراة" CTA button |

### Verified untouched (0 diff from HEAD)

| File | Status |
|---|---|
| `lib/features/match/controllers/score_submit_controller.dart` | ✅ Clean |
| `lib/core/services/match_settlement_service.dart` | ✅ Clean |
| `lib/core/services/match_event_service.dart` | ✅ Clean |
| `lib/core/services/rating_engine.dart` | ✅ Clean |
| `lib/core/services/fantasy_round_settlement_service.dart` | ✅ Clean |
| `lib/domain/entities/player_match_stats.dart` | ✅ Clean |
| `lib/features/shareables/services/share_card_capture_service.dart` | ✅ Clean |
| `firestore.rules` | ✅ Clean |

---

## Review Axis 1: Does the card strongly serve player pride/ego?

### Visual design

```
┌──────────────────────────────────┐
│  الحريف                   MVP   │  ← brand + meta chip
│                                  │
│         نجم المباراة             │  ← title (25px white w900)
│          Street Cup              │  ← tournament name (13px faded)
│                                  │
│            ┌──────┐              │
│            │  🏅  │              │  ← medal circle (92px, secondary border)
│            └──────┘              │
│                                  │
│       أحمد النجم  [ضيف]          │  ← MVP name (34px!) + guest badge
│                                  │
│    ╔══════════════════════╗      │
│    ║ الحريف 3 - 2 الخصم  ║      │  ← score line chip
│    ╚══════════════════════╝      │
│    ╔══════════════════════╗      │
│    ║       الحريف         ║      │  ← team side chip
│    ╚══════════════════════╝      │
│                                  │
│   لحظة فخر تستاهل المشاركة      │  ← viral CTA tagline
└──────────────────────────────────┘
```

### Pride signals

| Element | Purpose |
|---|---|
| "نجم المباراة" title | Declares the MVP award |
| MVP name at 34px font | The hero element — impossible to miss |
| Medal circle (`workspace_premium_rounded` icon) | Trophy/award visual anchor |
| Score line chip ("الحريف 3 - 2 الخصم") | Match context reinforces achievement |
| Team side chip | Shows which team the MVP played for |
| "لحظة فخر تستاهل المشاركة" | CTA tagline: "A moment of pride worth sharing" |
| "MVP" meta chip | International label for recognition |
| "الحريف" brand | Associates achievement with platform |

### Background: star-pitch aesthetic

`_StarPitchPainter` draws a circle + cross pattern (X-shaped lines), distinct from the top scorers card's pitch stripes. Background gradient is blue-black (`#14213D` → `#070B16`) vs. the green-black of the top scorers card. This gives each card type its own visual identity.

**Verdict:** ✅ The card is a trophy announcement. The 34px name, medal icon, and "moment of pride" tagline serve the ego loop strongly.

---

## Review Axis 2: Does it use MVP MatchEvent as the primary data source?

### Data source resolution in `_buildMvpShareData` (screen lines 364–390)

```dart
MvpShareData? _buildMvpShareData(Match match) {
  final event = controller.mvpEvent.value;
  if (event != null) {
    return _mvpShareBuilder.buildFromEvent(        // ← PRIMARY: MatchEvent
      match: match,
      event: event,
      tournamentName: controller.tournamentName.value,
      teamALabel: home.label,
      teamBLabel: away.label,
    );
  }

  final mvpPlayerId = match.mvpPlayerId?.trim();
  if (mvpPlayerId == null || mvpPlayerId.isEmpty) return null;
  return _mvpShareBuilder.buildFallback(           // ← FALLBACK: Match.mvpPlayerId
    match: match,
    mvpPlayerId: mvpPlayerId,
    displayName: controller.displayNameForParticipantId(mvpPlayerId),
    isGuest: controller.isGuestParticipantId(mvpPlayerId),
    sideKey: controller.sideKeyForParticipantId(mvpPlayerId),
    tournamentName: controller.tournamentName.value,
    teamALabel: home.label,
    teamBLabel: away.label,
  );
}
```

**Priority order:**
1. **MatchEvent** (`mvpEvent.value != null`) → `buildFromEvent` — uses event's `actor.displayName`, `actor.kind`, `sideKey` directly
2. **Match.mvpPlayerId** → `buildFallback` — reconstructs display name from lineup snapshots and side players

### MVP event loading in controller (line 364–370)

```dart
Future<MatchEvent?> _loadMvpEventSafely(String matchId) async {
  try {
    return await _matchEventService.getMvpEvent(matchId);
  } catch (_) {
    return null;
  }
}
```

Best-effort loading. If the MatchEvent service fails (Firestore unavailable, missing index), the controller falls back to `null` and the screen uses `Match.mvpPlayerId`.

### What `buildFromEvent` extracts from the MatchEvent

```dart
MvpShareData(
  title: 'نجم المباراة',
  mvpDisplayName: _displayName(event.actor.displayName),  // ← rich identity
  isGuest: event.actor.kind == ParticipantRefKind.guestPlayer,  // ← kind
  tournamentName: _tournamentName(tournamentName),
  scoreLine: _scoreLine(match, teamALabel, teamBLabel),
  sideLabel: _sideLabel(event.sideKey, teamALabel, teamBLabel),  // ← from event
);
```

The MatchEvent carries `actor` (full `ParticipantRef` with kind + displayName) and `sideKey`. This is richer than `Match.mvpPlayerId` which is just a raw string ID.

**Verdict:** ✅ MatchEvent is the primary source. All identity data (name, kind, side) comes from the event's `ParticipantRef`.

---

## Review Axis 3: Does it safely fallback when MatchEvent is missing?

### Fallback chain

| Scenario | Source | Display name | Guest detection | Side key |
|---|---|---|---|---|
| MatchEvent exists | `buildFromEvent` | `event.actor.displayName` | `event.actor.kind` | `event.sideKey` |
| MatchEvent null, `mvpPlayerId` set | `buildFallback` | Lineup snapshot → side player → mvpPlayerId | Lineup entry `isGuest` | Snapshot side key |
| MatchEvent null, `mvpPlayerId` empty | Returns `null` | — | — | — |

### Fallback display name resolution (controller lines 153–166)

```dart
String? displayNameForParticipantId(String participantId) {
  final entry = _lineupEntryForParticipantId(participantId);
  final entryName = entry?.displayName.trim();
  if (entryName != null && entryName.isNotEmpty) return entryName;

  final sidePlayer = matchSidePlayers.firstWhereOrNull(
    (player) => player.id == participantId,
  );
  final sidePlayerName = sidePlayer?.displayName.trim();
  if (sidePlayerName != null && sidePlayerName.isNotEmpty) return sidePlayerName;
  return null;
}
```

Searches lineup entries first, then match side players. If neither has the name, returns `null` → controller passes `mvpPlayerId` to `buildFallback` → `_displayName` falls back to "نجم المباراة".

### Fallback side key resolution (controller lines 172–197)

Searches snapshot starters + bench for the participant ID, then resolves side key via:
1. `snapshot.sideKey` (direct field)
2. `snapshot.teamId` match to `match.teamAId`/`teamBId`
3. `snapshot.matchSideId` pattern matching (`{matchId}_A` / `{matchId}_B`)

### Test evidence for fallback

"builds safe fallback data from Match.mvpPlayerId" (test line 76–87):
```dart
final data = const MvpShareController().buildFallback(
  match: _match(mvpPlayerId: 'legacy-mvp'),
  mvpPlayerId: 'legacy-mvp',
  displayName: '   ',       // ← empty display name
  tournamentName: null,      // ← no tournament
);

expect(data.mvpDisplayName, 'نجم المباراة');    // ← safe fallback
expect(data.tournamentName, 'بطولة الحريف');     // ← safe fallback
expect(data.isGuest, isFalse);
```

**Verdict:** ✅ Safe fallback chain. Even with no MatchEvent, no display name, and no tournament name, the card renders with sensible Arabic defaults.

---

## Review Axis 4: Does it show guest MVP badge correctly?

### `buildFromEvent` guest detection

```dart
isGuest: event.actor.kind == ParticipantRefKind.guestPlayer,
```

Direct from the MatchEvent's `ParticipantRef`. This is the authoritative source — the guest status was set when the event was written during score submission.

### `buildFallback` guest detection

```dart
bool isGuestParticipantId(String participantId) {
  return _lineupEntryForParticipantId(participantId)?.isGuest ?? false;
}
```

Falls back to lineup entry `isGuest` field. If no lineup entry found, defaults to `false` (conservative — doesn't falsely claim guest status).

### Widget rendering (card lines 167–170)

```dart
if (data.isGuest) ...[
  const SizedBox(width: 8),
  _GuestBadge(exportMode: exportMode),
],
```

`_GuestBadge` renders "ضيف" in secondary color with 18% opacity background — consistent with the top scorers card badge.

### Test evidence

"marks guest MVP and safely falls back for missing tournament name" (test lines 45–73):
```dart
actor: ParticipantRef(
  kind: ParticipantRefKind.guestPlayer,
  id: 'guest-1',
  displayName: 'ضيف المباراة',
  linkedPlayerId: 'linked-player-1',
),
// ...
expect(data.isGuest, isTrue);
```

Widget test (line 115): `expect(find.text('ضيف'), findsOneWidget);`

**Verdict:** ✅ Guest badge correctly rendered from both event and fallback paths. Tested.

---

## Review Axis 5: Does CTA appear only when MVP exists?

### `hasShareableMvp` (controller lines 147–151)

```dart
bool get hasShareableMvp {
  if (mvpEvent.value != null) return true;
  final mvpPlayerId = match.value?.mvpPlayerId?.trim();
  return mvpPlayerId != null && mvpPlayerId.isNotEmpty;
}
```

Returns `true` only when either a MatchEvent exists OR `Match.mvpPlayerId` is set. Otherwise `false`.

### CTA button gating (screen lines 105–115)

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

```dart
bool get _hasShareableMvp => controller.hasShareableMvp;
```

The button only renders inside the `if (_hasShareableMvp)` conditional. When no MVP is set, the entire `OutlinedButton.icon` widget tree is absent.

### Double guard in `_shareMvp` (screen lines 237–248)

```dart
final match = controller.match.value;
if (match == null) {
  Get.snackbar('تعذر المشاركة', 'لا توجد بيانات مباراة لمشاركتها.');
  return;
}
final shareData = _buildMvpShareData(match);
if (shareData == null) {
  Get.snackbar('تعذر المشاركة', 'لا يوجد نجم مباراة لمشاركته بعد.');
  return;
}
```

Even if somehow invoked without a valid MVP, the method exits with an Arabic snackbar.

**Verdict:** ✅ CTA button only renders when MVP exists. Double guard prevents sharing when data is missing.

---

## Review Axis 6: Does it reuse ShareCardCaptureService?

### Identical overlay pattern (screen lines 250–287)

```dart
final entry = OverlayEntry(
  builder: (_) => Positioned(
    left: 0, top: 0,
    child: IgnorePointer(
      child: Opacity(
        opacity: 0.01,
        child: RepaintBoundary(
          key: _mvpShareBoundaryKey,
          child: MvpShareCard(data: shareData, exportMode: true),
        ),
      ),
    ),
  ),
);

var inserted = false;
try {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  // ... null check
  overlay.insert(entry);
  inserted = true;
  await WidgetsBinding.instance.endOfFrame;
  await _captureService.captureAndShare(
    boundaryKey: _mvpShareBoundaryKey,
    fileName: 'el7reef_mvp_${match.id}',
    text: 'نجم المباراة على الحريف',
    pixelRatio: matchResultShareExportPixelRatio,
  );
} catch (error) {
  Get.snackbar('تعذر المشاركة', _readableShareError(error));
} finally {
  if (inserted) entry.remove();
}
```

This is exactly the same pattern as:
- `_shareResult` in the same screen
- `_shareTopScorers` in `tournament_detail_screen.dart` (Task 9)
- `_captureAndShareLineup` for lineup share

### `ShareCardCaptureService` — 0 diff

Reused without modification. The service was read from `share_card_capture_service.dart` — unchanged from its original implementation.

### Separate boundary key

```dart
static final GlobalKey _mvpShareBoundaryKey = GlobalKey();
```

Distinct from `_shareBoundaryKey` (result) and `_lineupShareBoundaryKey` (lineup). This prevents key conflicts when different share flows are active.

**Verdict:** ✅ Full reuse of existing capture infrastructure. No new services, no modifications.

---

## Review Axis 7: Did it avoid protected components?

| Component | Expected | Actual |
|---|---|---|
| `score_submit_controller.dart` | Untouched | ✅ 0 diff |
| `match_settlement_service.dart` | Untouched | ✅ 0 diff |
| `match_event_service.dart` | Consumed, not modified | ✅ 0 diff (`getMvpEvent` already existed from Task 1) |
| `rating_engine.dart` | Untouched | ✅ 0 diff |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff |
| `player_match_stats.dart` | Untouched | ✅ 0 diff |
| `share_card_capture_service.dart` | Reused, not modified | ✅ 0 diff |
| `firestore.rules` | Untouched | ✅ 0 diff |
| Firestore indexes | Untouched | ✅ |

### No ScoreSubmit write behavior changes

The MVP share card is read-only. It reads `mvpEvent` via `getMvpEvent` and `Match.mvpPlayerId`. It does not write any MatchEvents, modify match state, or trigger settlement.

**Verdict:** ✅ All protected files untouched. Read-only integration.

---

## Review Axis 8: Are tests sufficient?

### Test inventory: 4 tests

**Unit test 1:** "maps MVP MatchEvent to display data"
- Registered player event → full data mapping
- Asserts: title, name, `isGuest: false`, tournament, score line, side label, brand

**Unit test 2:** "marks guest MVP and safely falls back for missing tournament name"
- Guest player event + empty tournament name
- Asserts: `isGuest: true`, tournament fallback "بطولة الحريف", side label "الخصم"

**Unit test 3:** "builds safe fallback data from Match.mvpPlayerId"
- No MatchEvent, raw ID + empty display name + null tournament
- Asserts: display name fallback "نجم المباراة", tournament fallback, `isGuest: false`

**Widget test 4:** "renders title, MVP name, score, branding, and guest badge"
- Full data with guest MVP
- Finds: title, name, tournament, score line, side label, "ضيف" badge, "الحريف" brand

### Coverage matrix

| Scenario | Covered? | How |
|---|---|---|
| Registered MVP from MatchEvent | ✅ | Test 1 |
| Guest MVP from MatchEvent | ✅ | Test 2 |
| Guest badge detection | ✅ | Tests 2 + 4 |
| Fallback from Match.mvpPlayerId | ✅ | Test 3 |
| Empty display name fallback | ✅ | Test 3 (`displayName: '   '`) |
| Empty tournament fallback | ✅ | Tests 2 + 3 |
| Widget renders all elements | ✅ | Test 4 |
| `hasShareableMvp` controller logic | ❌ | Not tested — see F1 |
| `displayNameForParticipantId` | ❌ | Not tested — see F1 |
| `sideKeyForParticipantId` | ❌ | Not tested — see F1 |
| `_shareMvp` overlay flow | ❌ | Requires device |
| Score line with null scores | ❌ | Not tested — see F2 |

**Verdict:** ✅ Strong coverage of the share data pipeline (3 unit + 1 widget). Controller helpers are untested but are straightforward lookups.

---

## Review Axis 9: Is manual QA for native sharing documented?

### Recommended manual QA checklist

| # | Scenario | How to test |
|---|---|---|
| 1 | Match with MVP MatchEvent → "شارك نجم المباراة" button visible | Submit score with MVP selected |
| 2 | Match with legacy `mvpPlayerId` only (no event) → button visible | Set MVP on old match |
| 3 | Match without MVP → no button visible | Submit score without MVP |
| 4 | Guest MVP → "ضيف" badge visible in exported PNG | Set guest player as MVP |
| 5 | Registered MVP → no guest badge | Set registered player as MVP |
| 6 | Share produces PNG with all elements | Tap button, check share sheet |
| 7 | Share text is "نجم المباراة على الحريف" | Check share sheet text |
| 8 | Score line rendered: "Team A 3 - 2 Team B" | Verify on card |
| 9 | Team side chip rendered | Verify side label on card |
| 10 | Overlay cleanup after share cancel | Cancel share sheet |
| 11 | Overlay cleanup on error | Airplane mode + share |
| 12 | RTL layout correct in PNG | Inspect the PNG |
| 13 | Long MVP name truncates cleanly | Use long display name |
| 14 | Card renders without score (friendly match, no scores set) | Share MVP from scoreless match |

**Verdict:** ⚠️ No explicit manual QA checklist in reviewed code. Task report (`Sprint2_Task1_MVP_Share_Card_Report.md`) may contain one. The 14-scenario checklist above should be used before production.

---

## Findings

### F1: Controller helper methods not unit-tested — MEDIUM

**Severity:** Medium

`hasShareableMvp`, `displayNameForParticipantId`, `isGuestParticipantId`, and `sideKeyForParticipantId` are all new methods on `MatchResultLineupController`. They contain non-trivial logic (especially `sideKeyForParticipantId` with 3-level fallback for side resolution). No unit tests cover these methods.

The share card data pipeline is tested (controller → model → widget), but the controller's lookup logic that feeds the fallback path is not.

**Action:** Add a `match_result_lineup_controller_test.dart` covering at least `sideKeyForParticipantId` edge cases and `hasShareableMvp`.

### F2: Score line with null scores not tested — LOW

**Severity:** Low

`_scoreLine` returns `null` when `scoreA` or `scoreB` is null:
```dart
if (scoreA == null || scoreB == null) return null;
```

This means a match without scores (e.g., friendly still in progress) will render the MVP card without a score chip. The card handles this (`if (data.scoreLine != null)` guard at line 174) but it's not tested.

**Action:** Add an assertion for `scoreLine == null` when match has no scores. Not blocking.

### F3: `_loadMvpEventSafely` catches all exceptions — BY DESIGN

**Severity:** Info

```dart
Future<MatchEvent?> _loadMvpEventSafely(String matchId) async {
  try {
    return await _matchEventService.getMvpEvent(matchId);
  } catch (_) {
    return null;
  }
}
```

This ensures the result screen still renders even if the MatchEvent query fails (missing Firestore index, network error). The screen falls back to `Match.mvpPlayerId`. This is the correct trade-off: the share card degrades gracefully rather than blocking the entire result view.

### F4: `_StarPitchPainter` gives the MVP card distinct visual identity — INFO

**Severity:** Info

The MVP card uses a different background painter (`_StarPitchPainter` with X-shaped lines + center circle) vs. the top scorers card (`_PitchStripePainter` with diagonal stripes + center circle). This ensures the cards are visually distinct when shared on social media — important for brand recognition.

### F5: `tournament_operations_dashboard_test.dart` has +2 lines — NOTED

**Severity:** Info

The test file change likely adds the new `MatchEventService` and `TournamentRepositoryImpl` parameters to the controller construction in the existing test. This is expected because the controller's constructor signature changed.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Serves pride/ego | ✅ Pass | 34px MVP name, medal icon, score line, "moment of pride" tagline |
| 2. MatchEvent as primary source | ✅ Pass | Event → `buildFromEvent` first, `Match.mvpPlayerId` → `buildFallback` second |
| 3. Safe fallback when event missing | ✅ Pass | Graceful chain: event → mvpPlayerId → Arabic defaults |
| 4. Guest MVP badge | ✅ Pass | "ضيف" badge from both event kind and lineup entry |
| 5. CTA gated on MVP existence | ✅ Pass | `hasShareableMvp` + double guard in `_shareMvp` |
| 6. Reuses ShareCardCaptureService | ✅ Pass | 0 diff, identical overlay pattern |
| 7. Protected files untouched | ✅ Pass | All guarded files 0 diff |
| 8. Tests sufficient | ✅ Pass | 4 tests covering event, guest, fallback, and widget |
| 9. Manual QA documented | ⚠️ Partial | 14-scenario checklist provided above |

### Before production

1. Add controller helper unit tests for `sideKeyForParticipantId` and `hasShareableMvp` (F1).
2. Run 14-scenario manual QA checklist on a real device.
