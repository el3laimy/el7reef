# Sprint 2 / Task 6: Claim Code Exposure Security Audit

**Status:** `HISTORICAL SECURITY EVIDENCE — NOT AN ACTIVE PLAN`&rlm;

**Current authority:** `docs/core/00_Master_Product_Development_Plan.md`&rlm;, especially `ELR-SEC-*` and `ELR-IDN-*`&rlm;.

## Executive Summary

Decision: **do not wire a public guest profile claim CTA from only `guestPlayerId`.**

The existing claim flow is safest when the user arrives through a generated claim link or QR payload that already contains a `code`. However, the current Firestore read model exposes claim secrets too broadly:

- `guestPlayers/{guestPlayerId}` is readable by any authenticated user and can contain `claimCode`.
- `guestTeams/{guestTeamId}` is readable by any authenticated user and can contain `claimCode`.
- `claimCodes/{claimCodeId}` is readable by any authenticated user.
- Public guest profiles expose `guestPlayerId`, and `PublicPlayerProfileResolver` fetches the full guest player document.

This means a malicious authenticated user may be able to discover another guest player's active claim code and attempt the same token-based claim flow. The UI is not showing the code, but Firestore delivers it to the client when the document is read.

Sprint 2 / Task 7 recommendation: **go only for a token-aware claim entry if the token is already present in the route/deep link and the implementation never looks up `claimCode` from `guestPlayers`, `guestTeams`, or a public profile.** No-go for a plain public profile "claim this guest" button.

## Current Exposure Map

### Where `claimCode` Is Stored

| Location | Evidence | Stored data | Current exposure |
|---|---|---|---|
| `guestPlayers/{id}.claimCode` | `lib/domain/entities/guest_player.dart`, `lib/data/models/guest_player_model.dart`, `lib/core/services/share_link_service.dart` | Active guest player claim code copied onto the guest player after link generation. | `firestore.rules` allows `guestPlayers` read for any authenticated user. |
| `guestTeams/{id}.claimCode` | `lib/domain/entities/guest_team.dart`, `lib/data/models/guest_team_model.dart`, `lib/core/services/share_link_service.dart` | Active guest team claim code copied onto the guest team after link generation. | `firestore.rules` allows `guestTeams` read for any authenticated user. |
| `claimCodes/{code}` document id | `lib/domain/entities/claim_code.dart`, `lib/data/models/claim_code_model.dart`, `lib/data/repositories/claim_code_repository_impl.dart` | The secret code is the document id. Document fields include target type, target id, scope, creator, status, expiry, and claim fields. | `firestore.rules` allows `claimCodes` read for any authenticated user. |
| Claim/invite URLs and QR payloads | `lib/domain/entities/claim_payload.dart`, `lib/domain/entities/generated_share_link.dart`, `lib/core/services/share_link_service.dart` | Query params include `code`, `type`, `targetId`, scope metadata, expiry, and status. | Intended exposure to the recipient of a link or QR. |

`ShareLinkService.createGuestPlayerClaimLink` creates/reuses a `ClaimCode`, updates the guest player to `claimStatus: invited`, stores `claimCode`, and builds `el7reef://claim` plus `https://el7reef.app/claim` links.

`ShareLinkService.createGuestTeamClaimLink` does the same for guest teams.

`ShareLinkService.createTeamInviteLink` creates a `claimCodes/{code}` document and puts the code in invite links, but does not copy the code onto a guest player/team document.

### Documents Readable By Ordinary Authenticated Users

From `firestore.rules`:

- `players/{playerId}`: `allow read: if isAuthenticated();`
- `guestPlayers/{guestPlayerId}`: `allow read: if isAuthenticated();`
- `teams/{teamId}`: `allow read: if isAuthenticated();`
- `teamMemberships/{membershipId}`: `allow read: if isAuthenticated();`
- `guestTeams/{guestTeamId}`: `allow read: if isAuthenticated();`
- `matches/{matchId}` and `matches/{matchId}/player_stats/{playerId}`: `allow read: if isAuthenticated();`
- `matchEvents/{eventId}`: `allow read: if isAuthenticated();`
- `claimCodes/{claimCodeId}`: `allow read: if isAuthenticated();`

The most sensitive entries for this task are `guestPlayers`, `guestTeams`, and `claimCodes`.

### Direct Answers

1. `claimCode` is stored in:
   - `guestPlayers/{id}.claimCode`
   - `guestTeams/{id}.claimCode`
   - `claimCodes/{code}` as the document id, with related metadata in the document
   - generated claim/invite links and QR payloads as the `code` query parameter

2. Ordinary authenticated users can read `guestPlayers`, `guestTeams`, and `claimCodes` today.

3. Yes. A normal authenticated user can read another guest player's `claimCode` today if that field exists on the guest player document.

4. Yes. A normal authenticated user can read `claimCodes` directly today because `claimCodes/{claimCodeId}` has `allow read: if isAuthenticated();`.

5. Current app paths that fetch `guestPlayers` and may deliver `claimCode` to the client:
   - `lib/features/profile/services/public_player_profile_resolver.dart`
     - Fetches a guest profile through `GuestPlayerRepositoryImpl.getGuestPlayer`.
     - The UI does not display `claimCode`, but the client receives the full entity.
   - `lib/features/guest_claim/controllers/guest_player_claim_controller.dart`
     - Fetches the target guest player during token-based claim.
   - `lib/features/team/controllers/team_roster_controller.dart`
     - Fetches guest players for roster and claim-link actions.
   - `lib/core/services/official_match_roster_service.dart`
     - Loads guest players for full match participant rosters.
   - `lib/core/services/team_roster_service.dart`
     - Loads guest players for team roster behavior.
   - `lib/core/services/guest_team_roster_service.dart`
     - Loads guest team guest players.
   - `lib/core/services/team_formation_service.dart`
     - Loads guest players through team membership context.
   - `lib/features/match/controllers/matchday_controller.dart`
     - Loads guest players for matchday/lineup display paths.
   - `lib/features/lineup/controllers/team_lineup_editor_controller.dart`
     - Loads guest players by ids for lineup editing.
   - `lib/core/services/share_link_service.dart`
     - Loads guest players to generate claim links.
   - `lib/core/services/guest_claim_service.dart`
     - Loads guest players during claim completion.

## Attack Scenario Analysis

1. Attacker signs in with a normal account.
2. Attacker opens a public guest profile or leaderboard row and learns `guestPlayerId`.
3. Attacker reads `guestPlayers/{guestPlayerId}` because rules allow any authenticated read.
4. If the guest player has an active invited state, the attacker sees `claimCode`.
5. Alternatively, the attacker reads or enumerates `claimCodes` because rules allow authenticated reads.
6. Attacker opens `/guest-player/{guestPlayerId}/claim?code={claimCode}` or calls the same service path from a client.
7. `GuestClaimService` correctly validates the code and target, but the attacker now possesses the code because it was readable.
8. If no merge conflict blocks the claim, the guest identity may be linked to the attacker's registered player account.

Impact:

- Guest identity theft.
- Goals and MVP pride surfaces point to the wrong account after claim.
- Public profile trust is damaged.
- Existing `matchEvents` are not rewritten, so cleanup/reconciliation is manual or future resolver work.

Current mitigating checks:

- Claims require authentication.
- `GuestClaimService` checks active/expired/claimed status.
- Duplicate name, phone, roster, and already-linked conflicts are handled.
- Guest team claims have ownership/approval checks.

Core weakness:

- Token possession is supposed to prove invitation, but the token is currently readable from public-readable documents.

## Option Evaluation

| Option | Security improvement | Complexity | Migration impact | Rules impact | App code impact | V1 suitability | Tests required |
|---|---:|---:|---:|---:|---:|---:|---|
| A. Remove `claimCode` from public-readable `guestPlayers` documents | High for guest player exposure; removes the easiest public-profile-to-code path. | Medium | Clear existing `guestPlayers.claimCode`; preserve `claimStatus` or replace with non-secret `hasActiveClaimInvite`. | Update `canSelfClaimGuestPlayer` and any helper that depends on `resource.data.claimCode`. | Update `ShareLinkService`, guest player model/entity, claim flow assumptions, roster UI if it uses `hasClaimCode`. | Strong V1 hardening step if scoped. | Rules tests proving ordinary auth cannot discover code from guest player; service tests for link generation and claim completion. |
| B. Split guest public identity into public/private documents | Very high; separates profile/roster display from private claim secrets. | High | Requires creating private docs for existing guest players/teams and removing secrets from public docs. | Add private doc rules for creator/organizer/admin/server only. | New repositories or safe DTOs for public vs private reads. | Better V1.1 than immediate V1 unless release risk is acceptable. | Migration tests, public resolver tests, private rules tests, claim link generation tests. |
| C. Restrict `claimCodes` read rules to createdBy / target owner / valid claimant | High, especially if list/query is denied. | Medium | Low if code document ids remain. | Replace blanket `allow read`. Prefer no list for ordinary users. Consider allowing `get` by exact code for token holders while preventing broad query/list. | Claim entry screens and invite services must still load by exact code; organizer/admin tools need explicit permissions. | Good V1 hardening, but should pair with Option A because guest docs currently reveal the code. | Rules tests: no list, no read by unrelated user, exact-code claim path still works, expired/wrong target blocked. |
| D. Hash claim codes in Firestore and compare server-side or via Cloud Function | Very high; raw token not stored as readable secret. | High | Requires migrating existing claim code docs or supporting dual format. | Rules become simpler if claim completion moves server-side; client cannot compare hash safely alone. | Add Cloud Function/service endpoint or robust hashing/verifier flow. | Best V1.1+ security posture, likely too large for immediate Sprint 2. | Function tests, hash migration tests, replay/expiry/idempotency tests. |
| E. Keep current system but do not expose claim CTA from public profile | Medium UX risk reduction, low data security improvement. | Low | None | None | None | Safe temporary V1 behavior, already the current decision. | Widget tests confirming placeholder only; security TODO/rules tests pending. |
| F. Token-aware claim CTA only when token is already in route, with no lookup of `claimCode` | Medium-high if strictly enforced; does not create a new discovery path. | Low-medium | None | None immediately, though rules still need hardening. | Public/profile controller can expose CTA only from trusted route query payload; never from plain `/player/guestPlayer/:id`. | Conditionally suitable for Sprint 2 / Task 7. | Tests for CTA hidden without token, visible with token+matching target, route forwards exact query, no guest doc code lookup. |
| G. Organizer-only resend claim link action | High for safe distribution; keeps invitation under authorized organizer/captain control. | Medium | None | Existing create/update rules may be enough, but claim secret read rules still need hardening. | Add organizer roster action that calls `ShareLinkService`, not public profile. | Good V1 UX after hardening or as an organizer-only action. | Permission tests, share-link reuse tests, unauthorized actor tests, no public CTA tests. |

## Recommended V1 Safe Path

1. Keep the plain public guest profile placeholder only:
   - Do not link `/player/guestPlayer/:id` directly to claim.
   - Keep copy oriented around asking the organizer/captain for the invite link.

2. Allow a **token-aware** entry only when the current route already contains a claim payload:
   - `code`
   - `type = guestPlayer`
   - `targetId = guestPlayerId`
   - optional existing payload metadata

3. The token-aware implementation must not:
   - read `guestPlayers/{id}.claimCode`,
   - query `claimCodes` to discover a code,
   - expose a claim CTA on ordinary public profiles,
   - infer invitation from `claimStatus: invited` alone.

4. Add rules/security tests before broad rollout:
   - Current production rules are not hardened enough for broad public claim discovery.

## Recommended V1.1 Hardening Path

Recommended sequence:

1. Remove raw `claimCode` from public-readable `guestPlayers` and `guestTeams` documents.
2. Restrict `claimCodes` rules:
   - no ordinary authenticated list/query,
   - exact-code `get` only where needed for token holders, or server-mediated claim validation,
   - creator/organizer permissions for management reads.
3. Add private claim state documents if the app needs organizer-visible claim metadata that should not be public.
4. Consider Cloud Function mediated claim completion with hashed/verifier tokens for stronger token secrecy.
5. Make profile/top-scorer resolvers claim-aware without rewriting old `matchEvents` blindly.

## Firestore Rules Changes Needed Later

Do not apply these in this task, but they should be part of a follow-up implementation:

- Change `match /claimCodes/{claimCodeId}` from blanket `allow read` to more granular rules.
- Disallow ordinary authenticated `list`/query on `claimCodes`.
- Decide whether exact `get` by document id remains allowed as proof of token possession, or move to server-side validation.
- Remove rule dependency on public `resource.data.claimCode` in:
  - `canSelfClaimGuestPlayer`
  - `canSelfClaimGuestTeam`
  - `canSelfClaimMembership`
- Split private claim secrets from public guest identity if claim codes remain visible to clients at all.
- Preserve organizer/captain ability to generate and resend links through permission-checked service paths.

## Data Model Changes Needed Later

Recommended:

- Remove or deprecate `GuestPlayer.claimCode` from the public entity/document.
- Remove or deprecate `GuestTeam.claimCode` from the public entity/document.
- Add a non-secret public status if needed:
  - `claimStatus`
  - `hasActiveClaimInvite`
  - `lastInviteSentAt`
- Store secret material in:
  - `claimCodes/{code}` with restricted reads, or
  - a private sub/document collection, or
  - hashed token records validated by a server endpoint.
- Keep `linkedPlayerId` and `linkedTeamId` public only if product privacy accepts that public identity linkage.

## Claim Continuity With MatchEvents

Claim completion does not update existing `matchEvents`.

Today:

- Guest goals/MVPs remain `actor.kind == guestPlayer` and `actor.id == guestPlayerId`.
- If `actor.linkedPlayerId` was null when the event was written, it stays null.
- `PublicPlayerProfileResolver` overlays current `GuestPlayer.linkedPlayerId` for guest profiles.
- Registered player profiles do not automatically merge historical guest events.

Follow-up needed:

- A resolver-level claim merge strategy can show guest history under a linked registered profile without rewriting events.
- A backfill should be considered only with audit coverage.

## Tests Required Before Enabling Public Profile Claim CTA

Rules/security tests:

- Anonymous users cannot read `guestPlayers`, `guestTeams`, or `claimCodes`.
- Ordinary authenticated users cannot list/query `claimCodes`.
- Ordinary authenticated users cannot discover `claimCode` from a public guest player identity document after hardening.
- Exact token holder can still open a valid claim flow.
- Wrong target id + code pair is rejected.
- Expired code is rejected and marked expired only through allowed paths.
- Already claimed code is idempotent for the same player and blocked for another player.
- Guest team approval-required flow remains enforced.

App tests:

- Public guest profile without token shows placeholder only.
- Public guest profile with route token shows token-aware claim CTA only when `targetId` matches the profile id.
- Token-aware CTA routes with `AppRoutes.guestPlayerClaimById(..., queryParameters: payload)`.
- Token-aware CTA does not read `GuestPlayer.claimCode`.
- Share/deep-link claim entry still redirects correctly.
- Organizer resend action, if built, is visible only to authorized organizers/captains.

## Sprint 2 / Task 7 Go / No-Go

**Go, conditionally:** Token-Aware Guest Profile Claim Entry is safe as the next implementation task only if the user already has a claim token in the route/deep link and the CTA uses that provided token directly.

Required Task 7 constraints:

- No CTA on plain `/player/guestPlayer/:id`.
- No lookup of `guestPlayers/{id}.claimCode`.
- No lookup/query of `claimCodes` to discover a missing code.
- Use `AppRoutes.guestPlayerClaimById(id, queryParameters: existingPayload)`.
- Hide the CTA if token, type, or target id is missing/mismatched.
- Add tests proving the CTA is absent without token and present only with a matching token.

**No-go:** Direct Public Guest Profile Claim CTA from `guestPlayerId` alone.

If security hardening is prioritized before UX, the next task should instead be:

> Sprint 2 / Task 7: Firestore Claim Code Read Rules Hardening

Scope:

- Remove public claim code exposure from `guestPlayers`/`guestTeams` or split private docs.
- Restrict `claimCodes` reads/listing.
- Add rules tests for claim code confidentiality and token claim success.

## Commands Run

| Command | Result |
|---|---|
| `flutter pub get` | Passed. Dependencies resolved; 56 packages reported newer incompatible versions. |
| `dart analyze lib/` | Failed with 4 pre-existing analyzer issues in `lib/features/shareables/services/share_card_capture_service.dart`: one unused local variable and three `use_build_context_synchronously` infos. No production code was changed in this docs-only task. |
| `flutter test test/core/services/guest_claim_service_test.dart test/features/guest_claim/guest_claim_screen_test.dart test/core/services/share_link_service_test.dart test/features/profile/public_player_profile_test.dart` | Passed, `+32`. |
| `flutter test` | Passed, `+333`. |

## Final Result

Created this security hardening plan only. No production code, Firestore rules, services, UI, claim flow, or schema were changed.

The concrete recommendation is:

- keep the public guest profile placeholder for plain profiles,
- allow only a token-aware claim entry as the next UX task,
- prioritize claim code read-rule/data-model hardening before any broad public claim CTA.

## Risks / Follow-Ups

- Current rules still expose claim secrets to authenticated clients until hardening is implemented.
- `claimCodes` query/list access is the largest immediate rules issue.
- `guestPlayers.claimCode` and `guestTeams.claimCode` make public identity documents carry secret material.
- Existing MatchEvents are not reconciled after claim; resolver-level merge is needed later.
- Analyzer is not currently clean because of existing share card capture service issues outside this task.
