# Sprint 2 / Task 10: Claim Flow End-to-End QA & Release Checklist

## Executive Summary

The V1 guest identity and claim loop is ready for guarded release from a QA standpoint.

The implemented flow keeps public guest profiles safe by default, only shows claim entry when a route already carries a matching token payload, and gives organizers/managers a controlled team-roster action to resend claim links. Firestore rules now block broad `claimCodes` listing while preserving exact-code proof-of-possession and creator-scoped active-code reuse.

Recommendation: **GO for V1 guarded release**, provided the Android manual QA checklist below is completed on a real or emulator device before Play Store rollout.

## Current Accepted Baseline

- `dart analyze lib/` passes.
- `flutter test` passes with `+348`.
- `npm run test:rules:emulator` passes with `7 passing`.
- Plain public guest profile has no active claim CTA.
- Token-aware public guest profile shows claim CTA only for valid matching guest-player payloads.
- Team roster managers can share/resend guest player claim links.
- Unauthorized roster viewers cannot access the resend action.
- Claimed/linked guests do not show active resend actions.
- `claimCodes` broad list/query is denied by emulator rules tests.
- Creator-scoped active-code reuse query is allowed by emulator rules tests.

## Automated Checks and Commands

Run before release:

```bash
npm run test:rules:emulator
dart analyze lib/
flutter test test/features/team/team_roster_screen_test.dart
flutter test test/features/profile/public_player_profile_test.dart
flutter test test/core/services/share_link_service_test.dart
flutter test test/core/services/guest_claim_service_test.dart
flutter test test/features/guest_claim/guest_claim_screen_test.dart
flutter test
```

Commands run for this QA pass:

- `npm ci`
  - Result: passed.
  - Note: installed Node dev dependencies needed by the rules test harness.
  - npm reported dependency audit findings: `5 vulnerabilities (1 low, 2 moderate, 2 high)`. No package changes were made in this task.
- `npm run test:rules:emulator`
  - Result: passed, `7 passing`.
  - Note: the first sandboxed attempt could not bind emulator ports. The approved rerun passed.
- `dart analyze lib/`
  - Result: passed, `No issues found!`
- `flutter test test/features/team/team_roster_screen_test.dart`
  - Result: passed, `+8`.
- `flutter test test/features/profile/public_player_profile_test.dart`
  - Result: passed, `+17`.
- `flutter test test/core/services/share_link_service_test.dart`
  - Result: passed, `+5`.
- `flutter test test/core/services/guest_claim_service_test.dart`
  - Result: passed, `+14`.
- `flutter test test/features/guest_claim/guest_claim_screen_test.dart`
  - Result: passed, `+6`.
- `flutter test`
  - Result: passed, `+348`.

## QA Flow 1: Organizer/Manager Resend Link

Automated coverage:

- `test/features/team/team_roster_screen_test.dart`

Manual checklist:

- Log in as a team owner.
- Open the team roster screen.
- Confirm an unclaimed guest player row exposes **"مشاركة رابط الاستلام"** from the row actions.
- Tap the action and confirm the platform share sheet opens.
- Confirm the roster UI does not display raw claim code text.
- Repeat as a vice-captain if this role is expected to manage the roster in the test data.
- Mark or seed the guest as linked/claimed.
- Confirm the row shows **"تم ربط هذا الضيف بالفعل ببروفايل لاعب مسجل."**
- Confirm the active resend action is no longer visible.
- Log in as an ordinary viewer.
- Confirm guest row actions and the resend action are not visible.

Expected result:

- Authorized roster managers can share the claim link.
- Unauthorized viewers cannot access the action.
- Claimed/linked guests cannot be resent from the active UI.
- Raw `claimCode` is never displayed in the roster UI.

## QA Flow 2: Public Profile No-token

Automated coverage:

- `test/features/profile/public_player_profile_test.dart`

Manual checklist:

- Open `/player/guestPlayer/<guestPlayerId>` with no query string.
- Confirm no active claim CTA appears.
- Confirm placeholder copy tells the guest to request an invite link from the organizer or captain:
  - **"ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق."**
- Confirm no raw exception text appears.
- Confirm no raw claim code appears.

Expected result:

- Plain public guest profiles are identity/read-only surfaces and do not amplify claim-code exposure.

## QA Flow 3: Public Profile Token-aware Entry

Automated coverage:

- `test/features/profile/public_player_profile_test.dart`

Manual checklist:

- Open `/player/guestPlayer/<id>?code=<code>&type=guestPlayer&targetId=<id>`.
- Confirm the claim CTA appears:
  - **"استلم البروفايل"** or the currently configured Arabic claim label.
- Tap CTA and confirm it routes to the existing guest-player claim route.
- Open the same route with `targetId` for a different guest.
- Confirm no active claim CTA appears and any warning is safe Arabic copy.
- Open with missing `code`.
- Confirm no active claim CTA appears.
- Open with wrong `type`.
- Confirm no active claim CTA appears.
- Open with expired `expiresAt`.
- Confirm no active claim CTA appears.
- Open with inactive or non-active `status`.
- Confirm no active claim CTA appears.
- Open for an already linked/claimed guest.
- Confirm no active claim CTA appears.

Expected result:

- Route token is treated as a proof-of-possession UX gate only.
- Existing claim screen and service remain final validation authority.

## QA Flow 4: Claim Route

Automated coverage:

- `test/core/services/guest_claim_service_test.dart`
- `test/features/guest_claim/guest_claim_screen_test.dart`

Manual checklist:

- Open `/guest-player/<id>/claim?code=<code>` while authenticated.
- Confirm a valid active code loads safely.
- Submit claim.
- Confirm the guest player links to the registered identity.
- Confirm guest roster memberships relink where expected.
- Reopen or resubmit the same valid claim.
- Confirm duplicate/idempotent handling is safe.
- Try a wrong code.
- Confirm safe failure copy.
- Try an expired code.
- Confirm safe failure copy.
- Try a code for an already claimed/linked guest.
- Confirm conflict handling is safe.
- Confirm no raw exception text is shown.

Expected result:

- Authenticated user can claim with a valid route code.
- Wrong, expired, duplicate, and conflict states are handled without crashes or raw errors.

## QA Flow 5: Firestore Rules Validation

Automated coverage:

- `test/rules/**/*.test.js`
- Command: `npm run test:rules:emulator`

Validated behavior:

- Anonymous user cannot exact-get `claimCodes/{code}`.
- Authenticated user can exact-get `claimCodes/{knownCode}` as V1 proof-of-possession.
- Authenticated broad listing of `claimCodes` is denied.
- Creator-scoped active claim-code reuse query is allowed.
- Creator-scoped reuse query with tournament constraint is allowed.
- Non-creator query against another creator's claim-code scope is denied.
- Unauthorized claim-code creates and updates are denied.

Expected result:

- Broad claim-code discovery is blocked.
- Existing organizer link reuse flow still works under production Firestore query semantics.

## Regression Checklist

- Analyzer passes.
- Full Flutter test suite passes.
- Public profile token gate tests pass.
- Guest claim service tests pass.
- Guest claim screen tests pass.
- Share link service tests pass.
- Team roster resend-link tests pass.
- Firestore rules emulator tests pass.
- No public claim CTA appears on plain `/player/guestPlayer/:id`.
- No raw claim code appears in normal app UI.
- No raw exception text appears in claim/resend snackbars.

## Manual Android QA Checklist

- Install/run on Android emulator or physical device.
- Verify Arabic RTL layout on:
  - team roster guest row actions,
  - public guest profile no-token state,
  - public guest profile token-aware state,
  - guest claim route,
  - claim conflict/error states.
- Verify platform share sheet opens from **"مشاركة رابط الاستلام"**.
- Verify the shared payload includes the claim link/code as intended.
- Verify the raw claim code is not visible in the roster UI outside the shared link payload.
- Verify deep link opens the correct route if app links/deep links are configured in the build.
- Verify no raw exception text appears in snackbars or error panels.
- Verify network-off or bad-code states fail safely.
- Verify claimed/linked guests show linked info and no active resend action.

## Known Deferred Risks

- Exact `claimCodes/{code}` get remains allowed for authenticated users as V1 proof-of-possession. This is acceptable for token/link possession, but it is not as strong as server-mediated verification.
- Existing legacy `guestPlayers.claimCode` and `guestTeams.claimCode` fields may still exist on old documents and remain deferred.
- New claim completion is still client/service mediated, not Cloud Function mediated.
- Claim-code values are not hashed in Firestore yet.
- Tournament organizer level resend surfaces are not broad everywhere yet; current safe implementation is the team roster manager surface.
- Android deep link/app link configuration still needs manual device verification.
- npm audit reports dependency vulnerabilities in Node dev tooling; no runtime Flutter dependency changes were made for this QA task.

## V1.1 Backlog Items

- Server-mediated guest claim completion.
- Remove `guestPlayers.claimCode`.
- Remove `guestTeams.claimCode`.
- Private verifier/hash design for claim codes.
- Richer tournament organizer claim-link surface.
- Optional Cloud Function for claim-code validation and one-time use finalization.
- Rules tests for any future private/public guest document split.
- Device-level app-link test automation if release tooling supports it.

## Go/No-go Release Recommendation

**GO for V1 guarded release** after completing the manual Android QA checklist.

Rationale:

- Automated app tests pass.
- Firestore rules emulator tests pass.
- Broad claim-code listing is denied.
- Plain public guest profiles do not expose claim CTA.
- Token-aware claim entry is guarded by matching payload checks.
- Organizer/manager resend action exists on a controlled roster surface.
- Existing GuestClaimService remains the final claim authority.

Release should remain guarded by the documented V1 limitations until the V1.1 hardening backlog removes legacy raw code storage and moves claim verification server-side.
