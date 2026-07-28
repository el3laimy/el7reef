# Sprint 2 / Task 6 — Architecture Security Review

**Reviewed:** 2026-05-06  
**Scope:** Claim Code Exposure Security Audit
**Verdict:** ✅ PASS — accurate threat model, correctly conservative recommendation

---

## Document Reviewed

| File | Lines | Type |
|---|---|---|
| `docs/sprints/sprint2/Sprint2_Task6_Claim_Code_Security_Audit.md` | 283 | Historical security analysis — no production code |

### Zero production code changed — VERIFIED

`git status` shows only the audit document as untracked. All `lib/`, `test/`, `firestore.rules`, `firestore.indexes.json` are clean against HEAD.

---

## Review Axis 1: Does the report accurately map where claimCode is stored?

### Claim 1: `guestPlayers/{id}.claimCode`

**Verified:**
- `lib/domain/entities/guest_player.dart` line 18: `final String? claimCode;`
- `lib/data/models/guest_player_model.dart` line 64: `claimCode: json['claimCode'] as String?`
- `lib/data/models/guest_player_model.dart` line 84: `'claimCode': claimCode` (writes to Firestore)
- `lib/core/services/share_link_service.dart` line 98: `claimCode: claimCode.code` (copies code to guest player doc on invite generation)

**Verdict:** ✅ Accurate.

### Claim 2: `guestTeams/{id}.claimCode`

**Verified:**
- `lib/domain/entities/guest_team.dart` line 16: `final String? claimCode;`
- `lib/core/services/share_link_service.dart` line 154: same pattern as guest players

**Verdict:** ✅ Accurate.

### Claim 3: `claimCodes/{code}` as document ID

**Verified:**
- `lib/domain/entities/claim_code.dart`: entity with `code` field
- `lib/data/repositories/claim_code_repository_impl.dart`: uses code as document ID
- `lib/core/services/guest_claim_service.dart` line 128: `_claimCodesRef.doc(claimCode)` — looks up by code as doc ID

**Verdict:** ✅ Accurate.

### Claim 4: Generated URLs and QR payloads

**Verified:**
- `lib/domain/entities/claim_payload.dart`: structured payload with `code` field
- `lib/core/services/share_link_service.dart`: builds `el7reef://claim` and `https://el7reef.app/claim` with query params

**Verdict:** ✅ Accurate.

---

## Review Axis 2: Does it correctly identify which Firestore documents are readable?

### Verified against `firestore.rules`

| Collection | Report says | Rule line | Verified |
|---|---|---|---|
| `players` | `allow read: if isAuthenticated()` | 423 | ✅ |
| `guestPlayers` | `allow read: if isAuthenticated()` | 430 | ✅ |
| `teams` | `allow read: if isAuthenticated()` | 440 | ✅ |
| `teamMemberships` | `allow read: if isAuthenticated()` | 450 | ✅ |
| `guestTeams` | `allow read: if isAuthenticated()` | 480 | ✅ |
| `matches` + subcollections | `allow read: if isAuthenticated()` | 490–500 | ✅ |
| `matchEvents` | `allow read: if isAuthenticated()` | 504 | ✅ |
| `claimCodes` | `allow read: if isAuthenticated()` | 596 | ✅ |

**Verdict:** ✅ All eight entries are accurate. The report correctly identifies the three most sensitive: `guestPlayers`, `guestTeams`, and `claimCodes`.

---

## Review Axis 3: Can another authenticated user read a guest player's claimCode today?

### Report answer: "Yes"

### Verification chain

1. `firestore.rules` line 430: `allow read: if isAuthenticated();` — any authenticated user can read any `guestPlayers/{id}` document.
2. The `guestPlayers` document contains `claimCode` as a plain string field (written by `ShareLinkService` line 98).
3. No field-level access control exists in Firestore Security Rules — if the document is readable, all fields are readable.

### Practical exploitation

An attacker who knows `guestPlayerId` (exposed via public profile URL `/player/guestPlayer/:id`, leaderboard rows, or MatchEvent actor data):
1. Reads `guestPlayers/<guestPlayerId>` via the Firestore SDK
2. If `claimCode` field is non-null, they now possess the secret token
3. Navigates to `/guest-player/<id>/claim?code=<claimCode>`

**Verdict:** ✅ Correct. The answer is definitively "yes." This is the core security concern.

---

## Review Axis 4: Does it correctly assess direct claimCodes readability?

### Report answer: "Yes. A normal authenticated user can read claimCodes directly today."

### Verification

`firestore.rules` line 595–596:
```
match /claimCodes/{claimCodeId} {
  allow read: if isAuthenticated();
```

This allows both:
- **`get`**: reading a specific `claimCodes/{code}` document if you know the code
- **`list`/`query`**: listing or querying the entire `claimCodes` collection

### Impact

Even without reading `guestPlayers.claimCode`, an attacker could:
1. Query `claimCodes` where `targetType == 'guestPlayer'` and `status == 'active'`
2. Get all active guest player claim codes with their `targetId` fields
3. Use any of them

The report correctly notes this as "the largest immediate rules issue."

**Verdict:** ✅ Correct. Both `get` and `list` are permitted, making the exposure broader than just the guest player document path.

---

## Review Axis 5: Does it identify UI/resolver paths that may fetch guestPlayers?

### Report lists 11 code paths

| # | Path | Fetches guest player? | Verified |
|---|---|---|---|
| 1 | `public_player_profile_resolver.dart` | ✅ `getGuestPlayer(guestPlayerId)` line 62 | ✅ File exists, call confirmed |
| 2 | `guest_player_claim_controller.dart` | ✅ Loads target guest player during claim | ✅ File exists |
| 3 | `team_roster_controller.dart` | ✅ Loads guest players for roster | ✅ File exists |
| 4 | `official_match_roster_service.dart` | ✅ Loads guest players for match rosters | ✅ File exists |
| 5 | `team_roster_service.dart` | ✅ Loads guest players for team roster | ✅ File exists |
| 6 | `guest_team_roster_service.dart` | ✅ Loads guest team guest players | ✅ File exists |
| 7 | `team_formation_service.dart` | ✅ Through team membership context | ✅ File exists |
| 8 | `matchday_controller.dart` | ✅ For matchday/lineup display | ✅ File exists |
| 9 | `team_lineup_editor_controller.dart` | ✅ Loads guest players by IDs | ✅ File exists |
| 10 | `share_link_service.dart` | ✅ Loads guest players to generate links | ✅ File exists |
| 11 | `guest_claim_service.dart` | ✅ During claim completion | ✅ File exists |

### Key nuance the report correctly identifies

> "The UI does not display `claimCode`, but the client receives the full entity."

**Verified:** `PublicPlayerProfileData` (the data model exposed to the UI) does NOT contain a `claimCode` field — it has only `kind`, `id`, `displayName`, `totalGoals`, `totalMvps`, `linkedPlayerId`, `isClaimed`. However, the intermediate `GuestPlayer` entity loaded by the resolver does contain `claimCode`. The secret lives in client memory even though it's not rendered.

Additionally, `hasClaimCode` is defined on both `GuestPlayer` and `GuestTeam` but is never called by any app code (0 callers outside the entity definitions themselves). This means no UI currently reads or displays the code, but it's available in the deserialized object.

**Verdict:** ✅ The report accurately maps all 11 fetch paths and correctly notes the memory-vs-display distinction.

---

## Review Axis 6: Are options A-G evaluated honestly?

### Option A: Remove `claimCode` from public-readable guest documents

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | High | ✅ Correct — removes the easiest discovery path |
| Complexity | Medium | ✅ Correct — requires updating `ShareLinkService`, model, rules |
| Migration | Clear existing `claimCode` from documents | ✅ Correct — one-time migration or gradual null-out |
| Rules impact | Update `canSelfClaimGuestPlayer` | ✅ Correct — this rule reads `resource.data.claimCode` (line 195) |
| V1 suitability | Strong step if scoped | ⚠️ I'd say "Strong V1.1, risky V1" — changing rules mid-launch is delicate |

### Option B: Split into public/private documents

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | Very high | ✅ Correct |
| Complexity | High | ✅ Correct — new collection, migration, dual reads |
| V1 suitability | Better V1.1 | ✅ Correct — too large for immediate sprint |

### Option C: Restrict `claimCodes` read rules

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | High | ✅ Correct — especially blocking `list`/`query` |
| Note | "Should pair with Option A" | ✅ Correct — restricting `claimCodes` alone doesn't help if guest docs leak the code |

### Option D: Hash claim codes

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | Very high | ✅ Correct |
| Complexity | High | ✅ Correct — needs server-side component |
| V1 suitability | Too large for Sprint 2 | ✅ Correct |

### Option E: Keep current system, no public CTA

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security improvement | Medium UX risk reduction, low data security | ✅ Correct — doesn't fix the data exposure, just avoids amplifying it |
| V1 suitability | Safe temporary behavior | ✅ Correct — this is the current state |

### Option F: Token-aware CTA only from route payload

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | Medium-high if strictly enforced | ✅ Correct — doesn't create new discovery path |
| Complexity | Low-medium | ✅ Correct |
| Key constraint | "never from plain `/player/guestPlayer/:id`" | ✅ Critical and correct |

### Option G: Organizer-only resend action

| Dimension | Report assessment | My assessment |
|---|---|---|
| Security | High for safe distribution | ✅ Correct — keeps token generation in authorized hands |
| Note | "claim secret read rules still need hardening" | ✅ Correct — this is a UX improvement, not a security fix |

### Finding: Option table is honest

The report does not oversell any option. Each option's limitations are stated clearly. The "V1 suitability" column correctly ranks E and F as most suitable for immediate use, A and C for near-term hardening, and B and D for longer-term.

**Verdict:** ✅ All seven options are evaluated honestly. No option is misrepresented.

---

## Review Axis 7: Is the go/no-go recommendation for Sprint 2 / Task 7 correct?

### Report recommendation

> **Go, conditionally:** Token-Aware Guest Profile Claim Entry is safe as the next implementation task only if:
> 1. No CTA on plain `/player/guestPlayer/:id`
> 2. No lookup of `guestPlayers/{id}.claimCode`
> 3. No lookup/query of `claimCodes` to discover a missing code
> 4. Use `AppRoutes.guestPlayerClaimById(id, queryParameters: existingPayload)`
> 5. Hide the CTA if token, type, or target id is missing/mismatched
> 6. Tests proving CTA absent without token and present only with matching token

> **No-go:** Direct Public Guest Profile Claim CTA from `guestPlayerId` alone.

### Assessment

This is the correct call because:

1. **Token-aware CTA doesn't expand the attack surface.** If the user already has the code (from a legitimate deep link/QR), letting them continue to claim from the profile is just UX convenience. The code was already in their hands.

2. **Plain profile CTA would expand the attack surface.** If the profile screen looked up `guestPlayers.claimCode` and pre-populated the claim, it would make the attack trivial — any user visiting the profile could claim.

3. **The constraints are specific and testable.** The 6 constraints listed are verifiable in unit/widget tests.

### Alternative path

The report also correctly offers a hardening-first alternative:

> If security hardening is prioritized before UX, the next task should be:
> Sprint 2 / Task 7: Firestore Claim Code Read Rules Hardening

This is honestly presented as an alternative, not forced. The decision is left to the team's risk appetite.

**Verdict:** ✅ The go/no-go recommendation is correct and well-constrained.

---

## Review Axis 8: Is Token-Aware Claim Entry safe without first changing rules/schema?

### The question

Can we safely build a token-aware CTA (Option F) while the underlying Firestore rules still allow any authenticated user to read claim codes?

### Analysis

The token-aware CTA by definition requires the user to already have the code in their route/deep link. The CTA itself does NOT:
- Read `guestPlayers.claimCode`
- Query `claimCodes`
- Generate a claim code
- Discover a code from any Firestore document

It simply checks: "Does my route contain `code`, `type`, and `targetId`? If yes and they match this profile, show a CTA that routes to the existing claim screen."

### Does this make the situation worse?

**No.** The token-aware CTA:
- Adds a UI convenience for legitimate link holders
- Does NOT create a new code discovery path
- Does NOT read secrets from Firestore
- Only activates when the code is already in the URL

The underlying rules weakness (readable claim codes) exists independently of this CTA. A malicious user could already exploit it via the Firestore SDK directly. Adding a UI CTA for legitimate holders doesn't change the attacker's capabilities.

### Residual risk

The residual risk is the same as today: any authenticated user CAN read claim codes from Firestore. This risk exists with or without the token-aware CTA. The report correctly identifies this as needing V1.1 hardening.

**Verdict:** ✅ Token-aware CTA is safe without first changing rules/schema. It does not amplify the existing exposure.

---

## Review Axis 9: If it recommends hardening first, is the proposed hardening minimal and realistic?

### Recommended V1.1 hardening sequence

1. Remove raw `claimCode` from `guestPlayers` and `guestTeams` documents
2. Restrict `claimCodes` rules (no list/query, exact `get` only with constraints)
3. Add private claim state documents if organizer-visible metadata is needed
4. Consider Cloud Function mediated claim with hashed tokens
5. Make resolvers claim-aware without rewriting MatchEvents

### Assessment of each step

**Step 1: Remove `claimCode` from guest docs**

This is the highest-impact, lowest-complexity fix. It requires:
- Stop writing `claimCode` in `ShareLinkService.createGuestPlayerClaimLink` (remove line 98)
- Update `canSelfClaimGuestPlayer` rule to not depend on `resource.data.claimCode`
- Migration: null out existing `claimCode` fields

But there's a catch: `canSelfClaimGuestPlayer` (line 195) reads `resource.data.claimCode` to validate the claim. If we remove `claimCode` from the document, this rule breaks. The report correctly identifies this dependency.

**Step 2: Restrict `claimCodes` rules**

Splitting `read` into `get` vs `list` is straightforward in Firestore rules. Blocking `list` while allowing `get` (for token holders who know the exact code) is the right approach.

**Steps 3-4: Private docs and hashing**

Correctly deferred. These are legitimate V1.1+ improvements but too large for an immediate fix.

**Step 5: Claim-aware resolvers**

Also correctly deferred. This is a data consistency improvement, not a security fix.

### Is this sequence realistic?

Steps 1+2 together are a realistic V1.1 milestone:
- Remove `claimCode` from guest docs → breaks `canSelfClaimGuestPlayer`
- Fix: make `canSelfClaimGuestPlayer` validate the code through the `claimCodes` collection instead of the guest doc field
- Restrict `claimCodes` rules to exact `get` only
- Result: claim code is only accessible if you already know it (from the link/QR)

This is a 1-2 day task, not a massive refactor.

**Verdict:** ✅ The proposed hardening is minimal and realistic. Steps 1+2 are achievable as a focused V1.1 task.

---

## Security Gaps and Incorrect Assumptions

### Gap 1: `canSelfClaimGuestPlayer` rule dependency not fully explored

**Severity:** Medium (analysis gap, not wrong)

The report mentions that `canSelfClaimGuestPlayer` depends on `resource.data.claimCode` and that rules would need updating. However, it doesn't explore the specific fix: making the rule take the `claimCode` as a field in `request.resource.data` (the update payload from the client) and validating it against the `claimCodes` collection directly, rather than reading it from the existing document.

This matters because the fix for Step 1 (remove `claimCode` from guest docs) depends on this rule rewrite. The report should have outlined the specific rule change path.

**Impact on recommendation:** None — the report correctly defers rule changes. But the hardening plan would benefit from a concrete rule snippet.

### Gap 2: Attack via `claimCodes` query/list is arguably more dangerous than the guest doc path

**Severity:** Low (correctly noted but underweighted)

The report lists the `claimCodes` list/query access as "the largest immediate rules issue" but spends more text on the guest doc path. In practice, the `claimCodes` query path is more dangerous because it allows:
- Batch discovery of ALL active claim codes (not just one guest player's)
- No need to know any `guestPlayerId` in advance

Restricting `list` on `claimCodes` is arguably even more urgent than removing `claimCode` from guest docs.

**Impact on recommendation:** None — both are identified. Priority ordering could be adjusted.

### No incorrect assumptions found

Every factual claim in the report was verified against the actual codebase. No file references are wrong. No rule interpretations are incorrect.

---

## Findings Summary

| ID | Finding | Severity | Status |
|---|---|---|---|
| F1 | `guestPlayers.claimCode` exposure is real and verified | P0 | ✅ Correctly identified |
| F2 | `claimCodes` list/query access is the broadest exposure vector | P0 | ✅ Correctly identified, could be weighted higher |
| F3 | `canSelfClaimGuestPlayer` rule dependency on `resource.data.claimCode` is real | P1 | ✅ Identified, fix path not detailed |
| F4 | Token-aware CTA does NOT amplify existing exposure | — | ✅ Correctly assessed |
| F5 | MatchEvent claim continuity is a real but separate concern | P2 | ✅ Correctly deferred |
| F6 | `PublicPlayerProfileData` does NOT contain `claimCode` | — | ✅ Verified — UI surface is clean |
| F7 | `hasClaimCode` has 0 callers in app code | Info | ✅ Dead code, but not a risk |

---

## GO / NO-GO Decision

### For Sprint 2 / Task 7: Token-Aware Guest Profile Claim Entry

**GO** — under the constraints listed in the report:

1. ❌ No CTA on plain `/player/guestPlayer/:id`
2. ❌ No lookup of `guestPlayers/{id}.claimCode`
3. ❌ No lookup/query of `claimCodes`
4. ✅ CTA only when `code` + `type` + `targetId` are present in route
5. ✅ CTA routes through `AppRoutes.guestPlayerClaimById` with the existing payload
6. ✅ Tests proving CTA absent without token

### For Public Profile Claim CTA from `guestPlayerId` alone

**NO-GO** — until Firestore rules hardening is complete (Steps 1+2 of V1.1 plan).

### For Firestore Rules Hardening

**DEFER to V1.1** — the current risk is real but operational (requires authenticated attacker + knowledge of guest player IDs). The token-aware CTA does not make it worse. Hardening should happen before the app gains significant user traction.

---

## Summary

| Review axis | Verdict | Notes |
|---|---|---|
| 1. ClaimCode storage map | ✅ Accurate | All 4 locations verified |
| 2. Readable documents | ✅ Accurate | All 8 rules verified line by line |
| 3. ClaimCode readable by other users | ✅ Correct: yes | Guest doc + rules confirm |
| 4. Direct claimCodes readability | ✅ Correct: yes | Both `get` and `list` permitted |
| 5. UI/resolver fetch paths | ✅ Accurate | 11 paths verified, all files exist |
| 6. Options A-G evaluation | ✅ Honest | No option oversold, limitations stated |
| 7. Go/no-go recommendation | ✅ Correct | Token-aware = go, plain CTA = no-go |
| 8. Token-aware safe without rule changes | ✅ Yes | Does not amplify existing exposure |
| 9. Hardening plan realistic | ✅ Yes | Steps 1+2 are a 1-2 day V1.1 task |
