# Sprint 2 / Task 5: Guest Claim Flow Audit & Safe Wiring Plan

## Executive Summary

Go/no-go recommendation: **No-go for wiring the public guest profile claim placeholder directly to a claim route today.**

The existing guest claim flow is real and test-covered when entered through a generated claim link or QR payload. It expects a signed-ish claim code payload (`code`, `type`, `targetId`, scope metadata) and then routes to the correct claim screen. The public player profile currently only knows `kind = guestPlayer` and `id = guestPlayerId`; that is not enough proof that the viewer is the intended claimant.

The safest V1 behavior is to keep the current placeholder copy on `PublicPlayerProfileScreen` and, in the next implementation task, add a token-aware or organizer-mediated claim action rather than a raw `/guest-player/:guestPlayerId/claim` button.

## Existing Claim Routes Inventory

| Route | Helper | Page / Controller / Binding | Status |
|---|---|---|---|
| `/claim` | `AppRoutes.claimEntryWithQuery(...)` | `ClaimEntryScreen`, `ClaimEntryController`, `ClaimEntryBinding` | Production-safe as a deep-link/QR landing when `code`, `type`, and `targetId` are present. Shows safe error for incomplete links. |
| `/invite` | `AppRoutes.inviteEntryWithQuery(...)` | `TeamInviteEntryScreen`, `TeamInviteEntryController`, `TeamInviteEntryBinding` | Production-safe for team invites with `code` and `targetId`. |
| `/guest-player/:guestPlayerId/claim` | `AppRoutes.guestPlayerClaimById(...)` | `GuestPlayerClaimScreen`, `GuestPlayerClaimController`, `GuestPlayerClaimBinding` | Production-safe only when a valid `code` query param is present. Unsafe/confusing to open from public profile without code. |
| `/guest-team/:guestTeamId/claim` | `AppRoutes.guestTeamClaimById(...)` | `GuestTeamClaimScreen`, `GuestTeamClaimController`, `GuestTeamClaimBinding` | Production-safe only with a valid `code`; supports approval-required guest team claim. |
| `/player/:kind/:id` | `AppRoutes.playerProfileByKindAndId(...)` | `PublicPlayerProfileScreen`, `PublicPlayerProfileController`, `PublicPlayerProfileBinding` | Public pride profile. Currently shows safe claim placeholder only; does not attempt claim. |

Route declarations:

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`

Claim route pages are gated by `FeatureFlags.guestIdentityEnabled`, which is currently `true` in `lib/core/constants/feature_flags.dart`.

## Existing Services / Models Inventory

Core claim services:

- `lib/core/services/share_link_service.dart`
  - Generates guest player claim links, guest team claim links, and team invite links.
  - Builds app links and web links using `el7reef://claim`, `el7reef://invite`, `https://el7reef.app/claim`, and `https://el7reef.app/invite`.
  - Reuses active claim codes instead of minting duplicates.
  - Marks guest players / guest teams as `invited` and stores `claimCode`.
- `lib/core/services/guest_claim_service.dart`
  - Claims guest players into registered player identities.
  - Claims guest teams into registered teams.
  - Handles idempotency, conflicts, expiry, approval-required guest team claims, and roster relinking.
- `lib/core/services/team_invite_service.dart`
  - Handles regular team invite acceptance.

Repositories:

- `lib/data/repositories/claim_code_repository_impl.dart`
- `lib/data/repositories/guest_player_repository_impl.dart`
- `lib/data/repositories/guest_team_repository_impl.dart`

Models/entities:

- `lib/domain/entities/claim_code.dart`
- `lib/domain/entities/claim_payload.dart`
- `lib/domain/entities/guest_player.dart`
- `lib/domain/entities/guest_team.dart`
- `lib/domain/entities/claim_merge_conflict.dart`

Firestore paths:

- `claimCodes`
- `guestPlayers`
- `guestTeams`
- `teamMemberships`
- `matchEvents`

Defined in `lib/core/constants/firebase_paths.dart`.

## What The Current Claim Flow Requires

Guest player claim requires:

- `guestPlayerId` in route path.
- `code` query parameter.
- A `claimCodes/{code}` document where:
  - `targetType == guestPlayer`
  - `targetId == guestPlayerId`
  - `status == active`
  - `expiresAt` has not passed.
- Authenticated user for submit.
- A registered `players/{currentUserId}` document.

Guest team claim requires:

- `guestTeamId` in route path.
- `code` query parameter.
- An authenticated user.
- A registered team chosen by the user.
- For approval-required links, either:
  - target team owner submits a request, then guest team creator approves, or
  - the guest team creator owns the registered team and can complete directly.

Generic `/claim` requires:

- `code`
- `type`
- `targetId`
- Optional payload metadata like `scope`, `teamId`, `tournamentId`, `requiresApproval`, `expiresAt`, `status`.

QR/share support is already present through `ShareLinkService`, which stores the same payload in generated web/app URIs and `qrData`.

## Current Security Model

Application/service level:

- `ShareLinkService.createGuestPlayerClaimLink` only allows claim link generation by:
  - guest player creator,
  - roster manager for linked team,
  - guest team creator,
  - or tournament user with permission to issue guest claims.
- `ShareLinkService.createGuestTeamClaimLink` requires the actor to be the guest team creator.
- `GuestPlayerClaimController.submitClaim` requires login and calls `GuestClaimService.claimGuestPlayer(claimCode, playerId: currentUserId)`.
- `GuestClaimService.claimGuestPlayer` validates:
  - claim code exists,
  - claim code target type is `guestPlayer`,
  - claim code is active and not expired,
  - target guest player exists,
  - target registered player exists,
  - already-claimed-by-other-player conflicts,
  - duplicate phone/name conflicts,
  - roster conflicts,
  - idempotent re-claim by the same player.
- `GuestClaimService.claimGuestTeam` validates:
  - claim code exists,
  - target type is `guestTeam`,
  - target guest team and registered team exist,
  - actor owns the registered team or is the guest team creator,
  - duplicate name conflicts,
  - pending request conflicts,
  - idempotency.

Firestore rules:

- `firestore.rules` has helpers for:
  - `canCreateClaimCode`
  - `isActiveGuestPlayerClaimCode`
  - `isActiveGuestTeamClaimCode`
  - `canSelfClaimGuestPlayer`
  - `canSelfClaimGuestTeam`
  - `canFinalizeGuestPlayerClaimCode`
  - `canRequestGuestTeamClaimCode`
  - `canFinalizeGuestTeamClaimCode`
  - `canSelfClaimMembership`
- `guestPlayers`, `guestTeams`, `teamMemberships`, and `claimCodes` rules include claim-specific update paths.

Security concern:

- `claimCodes` are readable by any authenticated user.
- `guestPlayers` are readable by any authenticated user and store `claimCode`.
- `canSelfClaimGuestPlayer` appears to rely on `resource.data.claimCode` being active, not on the requester proving they received the secret code through the route.

This means the existing UI path is token-driven and safe enough operationally, but the underlying read model/rules deserve a security hardening review before making public profiles more claim-actionable. Do not add a public profile "claim now" button yet.

## Current Data Model

Guest player identity:

- `GuestPlayer.id`
- `displayName`
- `normalizedName`
- optional `phoneNumber`
- optional `teamId`
- optional `guestTeamId`
- optional `tournamentId`
- `createdBy`
- `claimStatus`
- optional `claimCode`
- optional `linkedPlayerId`

Guest team identity:

- `GuestTeam.id`
- `name`
- `normalizedName`
- `creatorId`
- optional contact fields
- `tournamentIds`
- `claimStatus`
- optional `claimCode`
- optional `linkedTeamId`

Claim code:

- `code`
- `targetType`
- `targetId`
- `scope`
- optional `teamId`
- optional `tournamentId`
- `createdBy`
- `requiresApproval`
- `status`
- `expiresAt`
- optional `claimedByPlayerId`
- optional `claimedAt`

## Claim Continuity With MatchEvents

Current claim does **not** update existing `matchEvents`.

What happens today:

- If a goal/MVP MatchEvent was written before claim, its actor remains:
  - `kind = guestPlayer`
  - `id = guestPlayerId`
  - `linkedPlayerId` whatever was known at event creation time, often null.
- `PublicPlayerProfileResolver` resolves a guest profile by `actor.kind + actor.id`, then overlays `GuestPlayer.linkedPlayerId` from the current guest player document where available.
- Registered player public profiles query only `actor.kind == player` and `actor.id == playerId`; they do not merge historical guest events after claim.
- Tournament top scorers aggregate by `kind + id`; claimed guest scorers remain guest entries unless a future resolver intentionally merges by `linkedPlayerId`.

Conclusion: a follow-up reconciliation/claim continuity task is needed. It should not rewrite old MatchEvents blindly. Safer options are:

- make profile/top-scorer resolvers claim-aware and merge guest events into registered identity when `GuestPlayer.linkedPlayerId` matches,
- or write a controlled backfill/reconciliation service with audit coverage.

## Can PublicPlayerProfileScreen Link To Claim Today?

No, not safely.

Reason:

- Public profile has `kind` and `id`.
- Claim route needs a valid `code`.
- Opening `/guest-player/<guestPlayerId>/claim` without `code` shows an error.
- Exposing a direct claim action from public profile would make identity takeover easier unless the user arrived with a verified token or the action is organizer-mediated.
- Existing public profile placeholder is correct:
  - `ده أنت؟ اطلب ربط البروفايل`
  - `ميزة الربط الكاملة ستفتح من رابط الدعوة أو QR المخصص للضيف.`

If a future screen has a valid claim payload, the exact safe route is:

```dart
AppRoutes.guestPlayerClaimById(
  guestPlayerId,
  queryParameters: {'code': claimCode},
)
```

or through the generic landing:

```dart
AppRoutes.claimEntryWithQuery(payload.toQueryParameters())
```

But the public profile should not invent or expose that payload for every viewer.

## Recommended V1 Claim UX

Recommended smallest safe V1 behavior:

1. Keep public guest profile placeholder.
2. Update the placeholder copy later to be more explicit:
   - `اطلب رابط الدعوة من منظم البطولة أو قائد الفريق`
3. Add an organizer/manager-only action later:
   - generate or resend a guest player claim link using `ShareLinkService.createGuestPlayerClaimLink`.
4. Only show a real player-facing claim CTA when the current route/session includes a valid claim payload.

Do not add a public "claim this profile" button for all viewers.

## P0 / P1 / P2 Risks

P0:

- Identity theft if public profile exposes claim without token possession.
- `claimCodes` and `guestPlayers.claimCode` readability may make claim codes discoverable to authenticated users.
- Existing MatchEvents are not migrated or merged into registered profiles after claim, so pride stats may appear split.

P1:

- Duplicate claims and pending target conflicts are handled in service tests, but Firestore rules should be reviewed against direct client writes.
- Linked guest stats remain guest-kind leaderboard entries after claim unless resolvers become claim-aware.
- Claim code expiry is enforced by service and rules, but public profile cannot tell whether a usable code exists without reading sensitive state.

P2:

- Mixed Arabic/English claim copy uses "claim" in several user-facing strings.
- Guest team claim is more complex than player claim; avoid mixing team claim UX into public player profile.
- QR scanner/deep-link handling should be manually QA'd on device before launch.

## Recommended Next Implementation Task

Title:

**Sprint 2 / Task 6: Token-Aware Guest Profile Claim Entry**

Scope:

- Do not change claim service behavior.
- Do not expose raw claimCode on public profiles.
- Add a safe claim entry experience only when a valid claim payload is present.
- Keep public guest profile placeholder for normal profile visits.
- Optionally add organizer-only "send claim link" from a roster/admin surface, not from public player profile.

Files likely to change:

- `lib/features/profile/views/public_player_profile_screen.dart`
- `lib/features/profile/controllers/public_player_profile_controller.dart`
- `lib/features/profile/models/public_player_profile_data.dart` only if adding safe route context flags
- `lib/features/guest_claim/controllers/claim_entry_controller.dart` only if token parsing needs a tiny helper
- tests under `test/features/profile/` and `test/features/guest_claim/`

Acceptance criteria:

- Public guest profile without claim token still shows placeholder only.
- Public guest profile with a valid token in route/query can show a CTA to continue claim.
- CTA routes through `AppRoutes.claimEntryWithQuery(...)` or `AppRoutes.guestPlayerClaimById(..., code: ...)`.
- Missing/expired/wrong-target token shows safe Arabic feedback.
- No claim service behavior changes.
- No Firestore rules changes unless separately audited.

Tests required before enabling CTA:

- Public guest profile without token does not show active claim button.
- Public guest profile with valid guestPlayer token shows claim CTA.
- CTA routes to the correct guest player claim screen with `code`.
- Wrong-target token does not show CTA or shows safe error.
- Expired token is blocked by existing claim screen.
- Linked/claimed guest profile does not show claim CTA.
- Existing `GuestClaimService` idempotency/conflict tests remain green.

## Commands Run

- `flutter pub get`
  - Passed.
- `dart analyze lib/`
  - Passed: `No issues found!`
- `flutter test test/core/services/guest_claim_service_test.dart test/features/guest_claim/guest_claim_screen_test.dart test/core/services/share_link_service_test.dart test/features/guest_claim/team_invite_entry_screen_test.dart`
  - Passed: `+25`.
- `flutter test`
  - Passed: `+333`.

## Final Result

- Audit completed.
- No production code changed.
- No tests were added or modified.
- Public profile claim CTA remains unwired by design.
- Clear recommendation: keep placeholder until a token-aware or organizer-mediated claim entry is implemented.
