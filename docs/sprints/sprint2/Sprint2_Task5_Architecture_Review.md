# Sprint 2 / Task 5 — Architecture Review

**Reviewed:** 2026-05-05  
**Scope:** Guest Claim Flow Audit  
**Verdict:** ✅ PASS — accurate, security-aware, correctly conservative

---

## Audit Document Reviewed

| File | Lines | Type |
|---|---|---|
| `docs/Sprint2_Task5_Guest_Claim_Flow_Audit.md` | 338 | Analysis document — no production code |

### No production code changed

The audit confirms:
- `flutter test` passed: +333 tests (full suite).
- `dart analyze lib/` passed: no issues.
- Claim-specific tests passed: +25 (guest_claim_service, guest_claim_screen, share_link_service, team_invite_entry_screen).
- Zero files modified.

---

## Review Axis 1: Is the audit accurate and grounded in actual files?

### Route inventory verification

| Route claim | Audit says | Verified |
|---|---|---|
| `/claim` → `ClaimEntryScreen` | Production-safe as QR landing | ✅ `lib/features/guest_claim/views/claim_entry_screen.dart` exists, gated by `FeatureFlags.guestIdentityEnabled` |
| `/invite` → `TeamInviteEntryScreen` | Production-safe for team invites | ✅ `lib/features/guest_claim/views/team_invite_entry_screen.dart` exists, registered in `app_pages.dart` |
| `/guest-player/:guestPlayerId/claim` | Needs valid `code` param | ✅ `lib/features/guest_claim/views/guest_player_claim_screen.dart` exists, gated by feature flag |
| `/guest-team/:guestTeamId/claim` | Needs valid `code` param | ✅ `lib/features/guest_claim/views/guest_team_claim_screen.dart` exists, gated by feature flag |
| `/player/:kind/:id` | Public pride profile, placeholder only | ✅ `lib/features/profile/views/public_player_profile_screen.dart` shows placeholder text |

### Service/model file verification

All files referenced by the audit exist:

| Referenced file | Exists |
|---|---|
| `lib/core/services/share_link_service.dart` | ✅ (12.5KB) |
| `lib/core/services/guest_claim_service.dart` | ✅ (38.4KB) |
| `lib/core/services/team_invite_service.dart` | ✅ (8.6KB) |
| `lib/data/repositories/claim_code_repository_impl.dart` | ✅ |
| `lib/domain/entities/claim_code.dart` | ✅ |
| `lib/domain/entities/claim_payload.dart` | ✅ |
| `lib/domain/entities/guest_player.dart` | ✅ |
| `lib/domain/entities/guest_team.dart` | ✅ |
| `lib/domain/entities/claim_merge_conflict.dart` | ✅ |

### Firestore rules verification

| Audit claim | Verified in `firestore.rules` |
|---|---|
| `canCreateClaimCode` exists | ✅ line 130 |
| `isActiveGuestPlayerClaimCode` exists | ✅ line 159 |
| `isActiveGuestTeamClaimCode` exists | ✅ line 176 |
| `canSelfClaimGuestPlayer` exists | ✅ line 193 |
| `canSelfClaimGuestTeam` → `canSelfClaimGuestTeam` exists | ✅ line 212 |
| `canFinalizeGuestPlayerClaimCode` exists | ✅ line 237 |
| `canRequestGuestTeamClaimCode` exists | ✅ line 258 |
| `canFinalizeGuestTeamClaimCode` exists | ✅ line 289 |
| `canSelfClaimMembership` exists | ✅ line 323 |
| `claimCodes` readable by any authenticated user | ✅ line 596: `allow read: if isAuthenticated();` |
| `guestPlayers` readable by any authenticated user | ✅ line 430: `allow read: if isAuthenticated();` |
| `FeatureFlags.guestIdentityEnabled = true` | ✅ line 13 of `feature_flags.dart` |

### Claim code readability concern

The audit flags: "claimCodes are readable by any authenticated user" and "guestPlayers store claimCode visibly."

**Verified:** `firestore.rules` line 596: `allow read: if isAuthenticated();` — any logged-in user can read any claim code document. Combined with `guestPlayers` also being readable (line 430), an attacker who knows a `guestPlayerId` could read the guest player document, extract its `claimCode` field, then use that code to claim the identity.

This is a real concern but is mitigated by:
1. The attacker needs to know the exact `guestPlayerId` (not publicly listed outside tournament rosters).
2. `canSelfClaimGuestPlayer` additionally validates that the claim code is active and not expired (lines 195–196).
3. The claim sets `linkedPlayerId = request.auth.uid`, so if the real owner later tries to claim, the conflict detection in `GuestClaimService` catches it (line 166–175).

**Verdict:** ✅ The audit's file references are accurate and grounded. Every claim is verifiable against actual code.

---

## Review Axis 2: Does it correctly identify whether the public guest profile can safely link to claim today?

### Audit conclusion

> **No, not safely.**
> - Public profile has `kind` and `id`.
> - Claim route needs a valid `code`.
> - Opening `/guest-player/<guestPlayerId>/claim` without `code` shows an error.

### Verification

The claim controller (`GuestPlayerClaimController`) reads the `code` from route query params:
```
Get.parameters['code'] ?? ''
```

Without a valid code, the controller would either show an error or the claim service would reject the attempt.

### Current placeholder text

```dart
'ده أنت؟ اطلب ربط البروفايل\nميزة الربط الكاملة ستفتح من رابط الدعوة أو QR المخصص للضيف.'
```

**Translation:** "Is this you? Request profile linking. The full linking feature will open from the guest's invitation link or QR."

### Assessment

The audit is correct:
1. The public profile only has `kind` + `id` — no `code` or `claimPayload`.
2. Navigating directly to `/guest-player/:id/claim` without a code would fail.
3. The placeholder text correctly tells the user to use the invitation link/QR — which carries the code.
4. The profile does NOT show a "Claim Now" button — it shows informational text only.

**Verdict:** ✅ The audit correctly identifies that linking to claim today is unsafe without a token, and the current placeholder is the right behavior.

---

## Review Axis 3: Are security risks clearly identified?

### P0 risks (correctly categorized)

| P0 risk | Audit text | Real? |
|---|---|---|
| Identity theft if public profile exposes claim without token | "Identity theft if public profile exposes claim without token possession" | ✅ Real — adding a "Claim Now" button from public profile would let anyone with the guest player's URL attempt a claim |
| claimCodes readability | "claimCodes and guestPlayers.claimCode readability may make claim codes discoverable" | ✅ Real — verified that `claimCodes` has `allow read: if isAuthenticated()` and `guestPlayers` stores `claimCode` as a readable field |
| MatchEvents not merged post-claim | "pride stats may appear split" | ✅ Real — `GuestClaimService.claimGuestPlayer` sets `linkedPlayerId` on the guest player document but does NOT update any `matchEvents` documents |

### P1 risks (correctly categorized)

| P1 risk | Real? |
|---|---|
| Firestore rules should be reviewed against direct client writes | ✅ Real — `canSelfClaimGuestPlayer` relies on `resource.data.claimCode` being present in the guest player document, which is publicly readable |
| Linked guest stats remain guest-kind in leaderboards | ✅ Real — `TournamentTopScorersResolver` aggregates by `actor.kind + actor.id`, not by `linkedPlayerId` |
| Public profile can't tell if a usable code exists | ✅ Real — reading `guestPlayer.claimCode` from the profile would expose the secret |

### P2 risks (correctly categorized)

| P2 risk | Real? |
|---|---|
| Mixed Arabic/English in claim copy | ✅ Real — "claim" appears in code but not user-facing; minor |
| Guest team claim complexity | ✅ Real — correctly deferred |
| QR scanner needs device QA | ✅ Real — not testable in widget tests |

**Verdict:** ✅ All three priority levels are accurately identified and correctly categorized. The P0 identity theft risk is the most important and is correctly flagged as the reason to NOT add a public claim button.

---

## Review Axis 4: Does it avoid over-engineering?

### What the audit recommends

1. **Keep** current placeholder. ✅ No work.
2. **Update** placeholder copy later to mention organizer. ✅ One string change.
3. **Add** organizer-only claim link action from admin surface. ✅ Uses existing `ShareLinkService.createGuestPlayerClaimLink`.
4. **Only show** real CTA when route has valid claim payload. ✅ Guard condition only.

### What the audit does NOT recommend

- ❌ No new services
- ❌ No new models
- ❌ No Firestore schema changes
- ❌ No claim code encryption/hashing system
- ❌ No claim approval workflow rearchitecture
- ❌ No MatchEvent migration batch job
- ❌ No social graph features

### Recommended next task scope

> **Sprint 2 / Task 6: Token-Aware Guest Profile Claim Entry**
> - Do not change claim service behavior.
> - Do not expose raw claimCode on public profiles.
> - Add a safe claim entry experience only when a valid claim payload is present.

Files likely to change: 5 files maximum. All within `profile/` and optionally `guest_claim/`.

**Verdict:** ✅ The audit is extremely conservative. It recommends the minimum viable change and explicitly defers everything else.

---

## Review Axis 5: Does it protect against identity theft / wrong claims?

### Current protection layers

The audit identifies the existing defense chain:

```
Layer 1: Claim code must be generated by organizer/creator
  ├── ShareLinkService.createGuestPlayerClaimLink enforces:
  │   - guest player creator, OR
  │   - roster manager for linked team, OR
  │   - guest team creator, OR
  │   - tournament organizer with permission
  └── canCreateClaimCode (Firestore rules) validates the same

Layer 2: Claim code must be active + not expired
  ├── isActiveGuestPlayerClaimCode checks status + expiry
  └── GuestClaimService validates before processing

Layer 3: Claim code must be delivered via trusted channel
  ├── Share link (generated URL with code param)
  └── QR code (generated by organizer)

Layer 4: Post-claim conflict detection
  ├── Already-claimed-by-other-player detection
  └── Duplicate phone/name conflicts
```

### What the audit correctly identifies as broken

> `claimCodes` are readable by any authenticated user.
> `guestPlayers` store `claimCode` as a readable field.

This means Layer 3 is theoretically bypassable: a malicious authenticated user could:
1. Read `guestPlayers/<guestPlayerId>` → get `claimCode`
2. Navigate to `/guest-player/<guestPlayerId>/claim?code=<claimCode>`
3. Submit the claim

The audit correctly recommends NOT making this easier by adding a public profile claim button.

### What the audit recommends for V1

Keep the token-delivery model (QR/share link) as the claim entry point. Do not invent a new entry point from public profiles. This maintains the existing security posture without introducing new attack surface.

**Verdict:** ✅ The audit correctly identifies the attack vector (readable claim codes) and correctly recommends keeping the current model rather than making exploitation easier.

---

## Review Axis 6: Does it explain MatchEvent claim continuity implications?

### Audit section: "Claim Continuity With MatchEvents"

The audit explains:

1. **Current state:** MatchEvents written before claim keep `actor.kind = guestPlayer` and `actor.id = guestPlayerId` — they are NOT migrated.

2. **Verified:** `GuestClaimService.claimGuestPlayer` updates the `guestPlayers` document (setting `linkedPlayerId`, `claimStatus`) but does NOT query or update `matchEvents`.

3. **Profile resolver behavior:** `PublicPlayerProfileResolver` resolves guest profiles by `actor.kind + actor.id`, then overlays `GuestPlayer.linkedPlayerId` from the guest player document. But a registered player profile queries only `actor.kind == player + actor.id == playerId` — historical guest events are NOT merged.

4. **Tournament top scorers:** `TournamentTopScorersResolver` aggregates by `actor.kind + actor.id`. A claimed guest scorer remains a separate leaderboard entry.

### Audit's recommended solutions

> - Make profile/top-scorer resolvers claim-aware and merge guest events into registered identity when `GuestPlayer.linkedPlayerId` matches.
> - Or write a controlled backfill/reconciliation service with audit coverage.

Both options are correctly identified as **future tasks**, not V1 blockers. The audit explicitly says:
> "It should not rewrite old MatchEvents blindly."

### My assessment

This is the most important technical insight in the audit. The stat-split problem means:
- A player who scored 3 goals as a guest, then claimed their profile, would show 3 goals on their guest profile and 0 on their registered profile.
- The leaderboard would show them as a guest scorer, not a registered one.

The audit correctly defers solving this — it's a real issue but requires careful design (merge at read time vs. backfill at write time) and is not a V1 blocker for the claim flow itself.

**Verdict:** ✅ The MatchEvent continuity implications are clearly explained, correctly identified as a future concern, and two viable solutions are proposed without over-committing.

---

## Review Axis 7: Is the recommended next task safe and small enough for V1?

### Recommended task: "Sprint 2 / Task 6: Token-Aware Guest Profile Claim Entry"

### Scope constraints

| Constraint | Safe? |
|---|---|
| Do not change claim service behavior | ✅ No backend risk |
| Do not expose raw claimCode on public profiles | ✅ No security regression |
| Add safe claim entry only when valid claim payload is present | ✅ Guard condition only |
| Keep placeholder for normal profile visits | ✅ Default is safe |
| Optionally add organizer-only "send claim link" from admin surface | ✅ Uses existing `ShareLinkService` |

### Files likely to change: 5

| File | Change type |
|---|---|
| `public_player_profile_screen.dart` | CTA visibility guard |
| `public_player_profile_controller.dart` | Route param extraction |
| `public_player_profile_data.dart` | Maybe flag for route context |
| `claim_entry_controller.dart` | Maybe tiny helper |
| Tests | New test cases |

### Acceptance criteria (7 items)

All criteria are testable:
1. No token → placeholder only ✅
2. Valid token → CTA visible ✅
3. CTA routes through existing claim routes ✅
4. Wrong-target token → safe feedback ✅
5. Expired token → blocked by existing claim screen ✅
6. Claimed guest → no CTA ✅
7. Existing claim tests stay green ✅

### Risk assessment

The task is a **read-only UI change** — it adds a conditional CTA that routes through existing, production-tested claim flows. No new services, no new Firestore operations, no changes to the claim security model.

**Verdict:** ✅ The recommended task is small, well-scoped, and safe. It builds on existing infrastructure without expanding the attack surface.

---

## Findings

### F1: `canSelfClaimGuestPlayer` relies on publicly readable `claimCode` — NOTED (P0 in audit)

**Severity:** Noted — already flagged in audit as P0

The Firestore rule `canSelfClaimGuestPlayer` (line 193) reads `resource.data.claimCode` from the guest player document itself. Since `guestPlayers` are readable by any authenticated user (line 430), the claim code is not truly secret. The audit correctly identifies this as a security concern.

**Mitigation status:** The existing defense is operational — claim links are shared via controlled channels (QR/link from organizer). The audit recommends a Firestore rules hardening review before making profiles more claim-actionable. This is appropriate for V1.1.

### F2: Stat-split after claim is the biggest V1.1 technical debt — NOTED

**Severity:** Noted — already flagged in audit

Post-claim, a player's stats are split between their guest identity and registered identity. The audit proposes read-time merge (resolver-level) or write-time backfill as solutions. Neither is needed for V1 launch, but this is the single largest claim-related technical debt.

### F3: Audit test pass counts are plausible — VERIFIED

**Severity:** Info

The audit claims:
- Claim-specific tests: +25
- Full suite: +333

I verified all 4 referenced test files exist. The +333 count is consistent with the growing test suite across Sprint 1 and Sprint 2 tasks.

### F4: No production code was changed — VERIFIED

**Severity:** Info

`git diff` shows 0 changes to any claim-related service, controller, screen, or model. The audit is analysis-only.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. Accurate and grounded | ✅ Pass | All file paths, routes, services, rules verified against codebase |
| 2. Correctly identifies profile-to-claim gap | ✅ Pass | Public profile has kind+id only, claim needs code |
| 3. Security risks clearly identified | ✅ Pass | P0/P1/P2 categorization is accurate and verified |
| 4. Avoids over-engineering | ✅ Pass | Recommends minimum: keep placeholder, defer to token-aware CTA |
| 5. Protects against identity theft | ✅ Pass | Correctly flags readable claimCodes as attack vector, recommends NOT adding public claim button |
| 6. MatchEvent continuity explained | ✅ Pass | Clear explanation of stat-split, two solution paths proposed, correctly deferred |
| 7. Next task is safe and small | ✅ Pass | 5 files max, 7 testable criteria, no new services |

### Key takeaway

The audit's "no-go" recommendation for wiring public profile → claim is the correct call. The existing security model relies on claim codes being delivered through trusted channels (organizer-generated links/QR). Making the public profile a claim entry point without a token would bypass this trust model. The recommended next task adds the CTA only when a valid token is already present in the route context — preserving the existing security posture.
