# Sprint 2 / Task 2 — Architecture Review

**Reviewed:** 2026-05-05  
**Scope:** Public Player Profile Basic Route  
**Verdict:** ✅ PASS — pride-focused, guest-aware, well-isolated

---

## Files Reviewed

### New files (untracked)

| File | Lines | Role |
|---|---|---|
| `lib/features/profile/models/public_player_profile_data.dart` | 26 | Immutable data model for the profile |
| `lib/features/profile/services/public_player_profile_resolver.dart` | 131 | Resolves player identity + aggregates stats from MatchEvents |
| `lib/features/profile/controllers/public_player_profile_controller.dart` | 48 | GetX controller with loading/error/profile state |
| `lib/features/profile/bindings/public_player_profile_binding.dart` | 40 | DI binding for route |
| `lib/features/profile/views/public_player_profile_screen.dart` | 239 | Profile screen UI |
| `test/features/profile/public_player_profile_test.dart` | 250 | 5 tests (4 resolver + 1 widget) |

### Modified files

| File | Delta | Summary |
|---|---|---|
| `lib/app/routes/app_routes.dart` | +6 / -1 | Route changed from `/player/:id` to `/player/:kind/:id`, added `playerProfileByKindAndId` helper |
| `lib/app/routes/app_pages.dart` | +10 | Registered `GetPage` with binding |
| `lib/core/services/match_event_service.dart` | +10 | Added `getEventsForActor` method |
| `lib/data/repositories/match_event_repository_impl.dart` | +17 | Added `getEventsByActor` Firestore query |

### Verified untouched (0 diff)

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

## Review Axis 1: Is the profile focused on pride/identity and not social bloat?

### What the profile shows

```
┌──────────────────────────────────────┐
│  [Avatar]  أحمد النجم                │
│            [ لاعب | ضيف ]            │  ← kind badge
│                                      │
│  ┌──────────┐     ┌──────────┐      │
│  │  ⚽ 12    │     │  🏅 3    │      │
│  │  أهداف   │     │ نجومية   │      │
│  │          │     │ المباراة │      │
│  └──────────┘     └──────────┘      │
└──────────────────────────────────────┘
│  هذا الضيف مربوط ببروفايل لاعب مسجل. │  ← if linkedPlayerId
│  ده أنت؟ اطلب ربط البروفايل          │  ← if unclaimed guest
└──────────────────────────────────────┘
```

### What the profile does NOT show

| Social/bloat feature | Present? |
|---|---|
| Friends list | ❌ |
| Activity feed | ❌ |
| Match history | ❌ |
| Chat/messaging | ❌ |
| Rating/stars | ❌ |
| Fantasy teams | ❌ |
| Follow/unfollow button | ❌ |
| Challenge button | ❌ |
| Comments/reactions | ❌ |

### Fields on `PublicPlayerProfileData`

```dart
final ParticipantRefKind kind;
final String id;
final String displayName;
final int totalGoals;
final int totalMvps;
final String? linkedPlayerId;
final bool isClaimed;
```

Seven fields. Goals + MVPs = pride stats. `linkedPlayerId` / `isClaimed` = identity continuity. Nothing else.

**Verdict:** ✅ Laser-focused on pride and identity. Zero social bloat.

---

## Review Axis 2: Does it support both registered player and guestPlayer?

### Route structure

```
/player/:kind/:id
```

The route takes `kind` as a segment, which maps to `ParticipantRefKind`:
- `/player/player/abc123` → registered player
- `/player/guestPlayer/guest-456` → guest player

### `_parseKind` (resolver lines 86–95)

```dart
ParticipantRefKind? _parseKind(String value) {
  final normalized = value.trim();
  if (normalized == ParticipantRefKind.player.name) {
    return ParticipantRefKind.player;
  }
  if (normalized == ParticipantRefKind.guestPlayer.name) {
    return ParticipantRefKind.guestPlayer;
  }
  return null;
}
```

Two explicit matches. `matchSidePlayer` is NOT matched (returns `null`).

### Resolution dispatch (resolver lines 35–39)

```dart
return switch (actorKind) {
  ParticipantRefKind.player => _resolvePlayer(actorId, events),
  ParticipantRefKind.guestPlayer => _resolveGuestPlayer(actorId, events),
  ParticipantRefKind.matchSidePlayer => null,
};
```

Exhaustive switch. `matchSidePlayer` returns `null` → controller shows error.

### `_resolvePlayer` (lines 42–56)

Fetches `Player` from `PlayerRepositoryImpl`. Uses player's `name` if available, falls back to event display names, then Arabic default "لاعب". Returns `null` only if both player doc and events are empty.

### `_resolveGuestPlayer` (lines 58–83)

Fetches `GuestPlayer` from `GuestPlayerRepositoryImpl`. Uses guest player's `displayName`, falls back to event display names, then "لاعب ضيف". Resolves `linkedPlayerId` from either the guest player document or event actor data. Sets `isClaimed` if either `linkedPlayerId` exists or `guestPlayer.isClaimed` is true.

**Verdict:** ✅ Both kinds are fully supported with appropriate data sources.

---

## Review Axis 3: Are goals and MVPs aggregated from active MatchEvents?

### Firestore query (repository impl lines 37–51)

```dart
final snapshot = await _eventsRef
    .where('actor.kind', isEqualTo: actorKind)
    .where('actor.id', isEqualTo: actorId)
    .where('status', isEqualTo: MatchEventStatus.active.name)
    .get();
```

The query filters at the Firestore level:
1. `actor.kind` = exact kind match (player or guestPlayer)
2. `actor.id` = exact ID match
3. `status` = `'active'` **only** — voided events are excluded at the query layer

### In-memory counting (resolver lines 97–101)

```dart
int _countGoals(List<MatchEvent> events) =>
    events.where((event) => event.isActive && event.isGoal).length;

int _countMvps(List<MatchEvent> events) =>
    events.where((event) => event.isActive && event.isMvp).length;
```

Double filtering: `isActive` AND `isGoal`/`isMvp`. This is defense-in-depth — even if the Firestore query somehow returned voided events, they would be excluded by the in-memory filter.

### `isActive`, `isGoal`, `isMvp` (entity lines 32–34)

```dart
bool get isGoal => eventType == MatchEventType.goal;
bool get isMvp => eventType == MatchEventType.mvp;
bool get isActive => status == MatchEventStatus.active;
```

Correct and simple.

**Verdict:** ✅ Goals and MVPs are aggregated exclusively from active MatchEvents with double filtering.

---

## Review Axis 4: Are voided events ignored?

### Query-level exclusion

The `getEventsByActor` Firestore query includes `.where('status', isEqualTo: MatchEventStatus.active.name)`. Voided events never leave Firestore.

### In-memory exclusion

`_countGoals` and `_countMvps` both check `event.isActive`. Any event that somehow gets through with `status != active` is excluded.

### Test evidence

"ignores voided events" (test lines 84–107):
```dart
await fixture.seedEvent(
  id: 'active-goal',
  eventType: MatchEventType.goal,
  actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
);
await fixture.seedEvent(
  id: 'voided-goal',
  eventType: MatchEventType.goal,
  actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
  status: MatchEventStatus.voided,
);

final profile = await fixture.resolver.resolve(kind: 'player', id: 'player-1');
expect(profile!.totalGoals, 1);     // ← only active goal counted
expect(profile.totalMvps, 0);
```

**Verdict:** ✅ Voided events are excluded at both query and application layers. Tested.

---

## Review Axis 5: Is guest/unclaimed claim placeholder safe and not over-promising?

### `showClaimPlaceholder` (model line 24)

```dart
bool get showClaimPlaceholder => isGuest && !isClaimed;
```

Only shows for guest players that are NOT yet claimed. Registered players never see it. Already-claimed guests never see it.

### Placeholder text (screen lines 191–198)

```dart
class _ClaimPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      message:
          'ده أنت؟ اطلب ربط البروفايل\nميزة الربط الكاملة ستفتح من رابط الدعوة أو QR المخصص للضيف.',
    );
  }
}
```

**Translation:** "Is this you? Request profile linking. The full linking feature will be available from the guest's invitation link or QR."

### Over-promising analysis

| Claim | Accurate for V1? |
|---|---|
| "ده أنت؟ اطلب ربط البروفايل" | ✅ — positions claim as something the user should want |
| "ميزة الربط الكاملة ستفتح من رابط الدعوة أو QR" | ✅ — honestly states the mechanism is via invitation link/QR, which exists in V1 (`/claim`, `/guest-player/:id/claim`) |

The placeholder does NOT:
- Promise an in-app claim button (none exists on this screen)
- Show a fake "Claim Now" button
- Promise a timeline ("coming soon")
- Trigger any write operations

### Linked player info panel (screen lines 115–118)

```dart
if (profile.linkedPlayerId != null) ...[
  const SizedBox(height: AppDimensions.md),
  _InfoPanel(message: 'هذا الضيف مربوط ببروفايل لاعب مسجل.'),
],
```

When the guest IS linked, it shows "This guest is linked to a registered player profile." This is informational only — no navigation to the linked profile (correctly deferred).

**Verdict:** ✅ The claim placeholder is honest, safe, and does not over-promise. No fake buttons.

---

## Review Axis 6: Does the route handle invalid kind/id safely?

### Route parameter extraction (binding lines 31–36)

```dart
Get.lazyPut<PublicPlayerProfileController>(
  () => PublicPlayerProfileController(
    kind: Get.parameters['kind'] ?? '',
    id: Get.parameters['id'] ?? '',
    resolver: Get.find<PublicPlayerProfileResolver>(),
  ),
);
```

Missing parameters default to empty string — no crash.

### Controller error handling (controller lines 29–45)

```dart
Future<void> loadProfile() async {
  try {
    isLoading.value = true;
    errorMessage.value = '';
    final resolved = await _resolver.resolve(kind: kind, id: id);
    if (resolved == null) {
      profile.value = null;
      errorMessage.value = 'تعذر العثور على هذا اللاعب.';
      return;
    }
    profile.value = resolved;
  } catch (_) {
    profile.value = null;
    errorMessage.value = 'تعذر تحميل بروفايل اللاعب الآن.';
  } finally {
    isLoading.value = false;
  }
}
```

Any failure → Arabic error message. No crash.

### Resolver null returns (resolver lines 26–39)

```dart
final actorKind = _parseKind(kind);
final actorId = id.trim();
if (actorKind == null || actorId.isEmpty) return null;
```

| Input | Result |
|---|---|
| `kind: 'matchSidePlayer'` | `null` → "تعذر العثور على هذا اللاعب." |
| `kind: 'invalidKind'` | `null` → same error |
| `kind: ''` | `null` → same error |
| `id: '   '` | `null` → same error (empty after trim) |
| `kind: 'player', id: 'nonexistent'` | `null` (player not found + no events) → same error |

### Test evidence

"invalid kind or id returns safe null state" (test lines 109–117):
```dart
expect(
  await fixture.resolver.resolve(kind: 'matchSidePlayer', id: 'msp-1'),
  isNull,
);
expect(await fixture.resolver.resolve(kind: 'player', id: '   '), isNull);
```

### Screen error rendering (screen lines 31–36)

```dart
if (profile == null) {
  return _ProfileMessageState(
    message: controller.errorMessage.value.isEmpty
        ? 'تعذر العثور على هذا اللاعب.'
        : controller.errorMessage.value,
  );
}
```

Always shows an Arabic message. No crash, no empty screen.

**Verdict:** ✅ All invalid input paths return safe null, produce Arabic error messages, and never crash.

---

## Review Axis 7: Does it avoid protected components?

| Component | Expected | Actual | Notes |
|---|---|---|---|
| `score_submit_controller.dart` | Untouched | ✅ 0 diff | |
| `match_settlement_service.dart` | Untouched | ✅ 0 diff | |
| `rating_engine.dart` | Untouched | ✅ 0 diff | |
| `fantasy_round_settlement_service.dart` | Untouched | ✅ 0 diff | |
| `player_match_stats.dart` | Untouched | ✅ 0 diff | |
| `firestore.rules` | Untouched | ✅ 0 diff | |
| `match_event_service.dart` | **Extended** | ⚠️ +10 lines | Additive: new `getEventsForActor` method |
| `match_event_repository_impl.dart` | **Extended** | ⚠️ +17 lines | Additive: new `getEventsByActor` query |
| `app_routes.dart` | **Modified** | ⚠️ +6/-1 | Route changed from `/player/:id` to `/player/:kind/:id` |
| `app_pages.dart` | **Extended** | ⚠️ +10 lines | Additive: new `GetPage` registration |

### Analysis of event service/repository changes

The new `getEventsForActor` / `getEventsByActor` methods are **purely additive**. No existing methods were modified or removed. The new query fetches events by `actor.kind` + `actor.id` + `status: active` — this is a new access pattern needed for per-player profile aggregation.

### Firestore index requirement

The query `actor.kind` + `actor.id` + `status` on the `matchEvents` collection may need a composite index:
```
(actor.kind ASC, actor.id ASC, status ASC)
```

This should be verified before production.

### Route change analysis

```diff
- static const String playerProfile = '/player/:id';
+ static const String playerProfile = '/player/:kind/:id';
```

This is a **breaking change** to the route. If any existing code navigates to `/player/:id`, it will now fail because the new route expects `/player/:kind/:id`.

However, this route was previously unregistered in `app_pages.dart` (no `GetPage` entry before this task), so no existing code could have been navigating to it. The route was defined but dead. This task brings it to life with the correct shape.

**Verdict:** ✅ All protected business logic files are untouched. Service/repository changes are additive. Route change is safe because the route was previously dead.

---

## Review Axis 8: Are tests sufficient?

### Test inventory: 5 tests

**Resolver test 1:** "aggregates goals and MVPs for registered player"
- Seeds player + 2 goals + 1 MVP → asserts `totalGoals: 2`, `totalMvps: 1`, `displayName: 'Registered Ali'`, `badgeLabel: 'لاعب'`

**Resolver test 2:** "aggregates goals and MVPs for guest player"
- Seeds guest player + 1 goal + 1 MVP → asserts correct counts, `badgeLabel: 'ضيف'`, `showClaimPlaceholder: true`

**Resolver test 3:** "ignores voided events"
- Seeds 1 active goal + 1 voided goal → asserts `totalGoals: 1`, `totalMvps: 0`

**Resolver test 4:** "invalid kind or id returns safe null state"
- Tests `matchSidePlayer` → `null`, empty ID → `null`

**Widget test 5:** "screen shows Arabic labels and guest claim placeholder"
- Uses `_FakeResolver` to inject preset data
- Finds: title "بروفايل اللاعب", name, badge "ضيف", stat labels "أهداف" + "نجومية المباراة", stat values, claim placeholder text

### Coverage matrix

| Scenario | Covered? | How |
|---|---|---|
| Registered player profile | ✅ | Test 1 |
| Guest player profile | ✅ | Test 2 |
| Voided events excluded | ✅ | Test 3 |
| matchSidePlayer rejected | ✅ | Test 4 |
| Empty ID rejected | ✅ | Test 4 |
| Widget renders Arabic labels | ✅ | Test 5 |
| Guest claim placeholder visible | ✅ | Test 5 |
| Linked player info panel | ❌ | Not tested — see F1 |
| Display name fallback chain | ❌ | Not tested — see F2 |
| Controller error state | ❌ | Not tested |
| Loading state | ❌ | Not tested |

### Test infrastructure quality

The `_ResolverFixture` class uses `FakeFirebaseFirestore` and seeds real `MatchEvent` documents through the repository. This means the tests exercise the actual Firestore query filters (`actor.kind`, `actor.id`, `status`), not mocked returns.

The widget test uses a `_FakeResolver` that extends `PublicPlayerProfileResolver` (required because the super constructor demands real dependencies) but overrides `resolve` to return preset data. This isolates the widget test from Firestore.

**Verdict:** ✅ Strong coverage for core scenarios. Resolver is tested with real Firestore fakes. Minor gaps in fallback and error paths.

---

## Review Axis 9: Is UI Arabic-first and player-centric?

### Arabic text audit

| Element | Text | Language |
|---|---|---|
| App bar title | 'بروفايل اللاعب' | ✅ Arabic |
| Kind badge (player) | 'لاعب' | ✅ Arabic |
| Kind badge (guest) | 'ضيف' | ✅ Arabic |
| Goals stat label | 'أهداف' | ✅ Arabic |
| MVPs stat label | 'نجومية المباراة' | ✅ Arabic |
| Linked player info | 'هذا الضيف مربوط ببروفايل لاعب مسجل.' | ✅ Arabic |
| Claim placeholder | 'ده أنت؟ اطلب ربط البروفايل\nميزة الربط...' | ✅ Arabic (colloquial) |
| Not found error | 'تعذر العثور على هذا اللاعب.' | ✅ Arabic |
| Load error | 'تعذر تحميل بروفايل اللاعب الآن.' | ✅ Arabic |
| Player fallback name | 'لاعب' | ✅ Arabic |
| Guest fallback name | 'لاعب ضيف' | ✅ Arabic |

### RTL enforcement

```dart
Directionality(
  textDirection: TextDirection.rtl,
  child: Scaffold(...)
)
```

Explicit RTL wrapping at the top level.

### Design system compliance

- `GlassmorphicContainer` for cards
- `AppDimensions.pagePadding`, `radiusLg`, `radiusMd`, etc.
- `AppTextStyles.headlineSmall`, `labelSmall`, `headlineMedium`, etc.
- `AppColors.primary`, `secondary`, `surface`, `surfaceBorder`, `textSecondary`

All consistent with the established design system.

### Player-centric vs admin-like

No IDs visible. No technical terms. No organizer-only data. A player seeing this screen would see their name, a badge, and their achievement stats. The claim placeholder uses colloquial Arabic ("ده أنت؟") which feels personal and street-friendly.

**Verdict:** ✅ Fully Arabic, RTL-first, player-centric. Uses design system correctly.

---

## Findings

### F1: Linked player info panel not widget-tested — LOW

**Severity:** Low

The `_InfoPanel` for `linkedPlayerId != null` is not covered by the widget test. The test uses a `PublicPlayerProfileData` with `linkedPlayerId: null` (default), so the panel condition is never exercised.

**Action:** Add a widget test case with `linkedPlayerId: 'some-id'` and assert `find.text('هذا الضيف مربوط ببروفايل لاعب مسجل.')`.

### F2: Display name fallback chain not tested — LOW

**Severity:** Low

The `_displayName` method has a 3-level fallback: source name → event display name → fallback. Only the first level (source name) is tested. A player with no document but events only would exercise the second level, and a player with neither would exercise the third.

**Action:** Add a resolver test with no player document + events only, and one with no player + no events (already covered by the invalid test returning null, but the fallback string is not asserted).

### F3: Firestore composite index required — IMPORTANT

**Severity:** Important

The `getEventsByActor` query uses:
```
.where('actor.kind', ...)
.where('actor.id', ...)
.where('status', ...)
```

This requires a Firestore composite index on the `matchEvents` collection:
```
(actor.kind ASC, actor.id ASC, status ASC)
```

Without this index, the query will fail in production.

**Action:** Verify the composite index exists or create it before deploying this feature.

### F4: Route change is technically breaking but safe — INFO

**Severity:** Info

The route path changed from `/player/:id` to `/player/:kind/:id`. This is a breaking change to the route signature. However, the old route had no `GetPage` entry in `app_pages.dart`, so it was unreachable. Any code that previously tried to navigate to `/player/:id` was already broken.

The new `playerProfileByKindAndId` helper provides a type-safe way to build the new route.

### F5: `_FakeResolver` super constructor is verbose — INFO

**Severity:** Info

The `_FakeResolver` test helper requires passing real (but unused) `FakeFirebaseFirestore` instances because the super constructor demands them. This is a minor test ergonomic issue. A future refactor could make the resolver constructor accept interfaces or use a factory.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Pride/identity focused | ✅ Pass | Goals + MVPs + kind badge only. Zero social bloat |
| 2. Both player and guestPlayer | ✅ Pass | Separate resolution paths with appropriate data sources |
| 3. Stats from active MatchEvents | ✅ Pass | Firestore query + in-memory double filter |
| 4. Voided events ignored | ✅ Pass | Query-level + application-level exclusion. Tested |
| 5. Claim placeholder safe | ✅ Pass | Honest text, no fake buttons, correct condition |
| 6. Invalid kind/id safe | ✅ Pass | All paths → Arabic error message. Tested |
| 7. Protected files untouched | ✅ Pass | Service extension is additive only |
| 8. Tests sufficient | ✅ Pass | 5 tests with real Firestore fakes |
| 9. Arabic-first, player-centric | ✅ Pass | All text Arabic, RTL enforced, design system used |

### Before production

1. **Create Firestore composite index** `(actor.kind ASC, actor.id ASC, status ASC)` on `matchEvents` collection (F3 — required).
2. Add widget test for linked player info panel (F1 — optional).
3. Verify profile loads on real device with registered and guest players.
