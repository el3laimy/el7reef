# Sprint 2 / Task 9: Organizer-only Resend Guest Claim Link Action

## Summary of Implementation

Added a safe organizer/manager-only resend action for guest player claim links from the team roster surface. Team roster managers can now open a guest player's row actions and choose **"مشاركة رابط الاستلام"** to generate/share the existing guest-player claim link through `ShareLinkService.createGuestPlayerClaimLink`.

The action remains hidden from unauthorized viewers, hidden for already claimed/linked guest players, and does not expose raw claim codes in the UI.

## Files Changed

- `lib/features/team/controllers/team_roster_controller.dart`
- `lib/features/team/views/team_roster_screen.dart`
- `test/features/team/team_roster_screen_test.dart`
- `docs/Sprint2_Task9_Organizer_Resend_Guest_Claim_Link_Report.md`

## UI Placement

- Added the resend/share action inside the existing team roster member overflow menu for guest players.
- Label: **"مشاركة رابط الاستلام"**
- Claimed/linked guests show safe Arabic info instead:
  - **"تم ربط هذا الضيف بالفعل ببروفايل لاعب مسجل."**

No public profile claim CTA was added or changed.

## Authorization Behavior

- The action is only shown when the current team roster controller reports `canManageRoster`.
- The controller also re-checks `canManageRoster` before generating a claim link.
- Current supported roster managers are the existing team owner / vice-captain path used by the team roster screen.
- `ShareLinkService` remains the final authority for creator/team/tournament claim-link permissions.

## ShareLinkService Reuse Behavior

- Reused `ShareLinkService.createGuestPlayerClaimLink`.
- The controller shares the returned `shareText`.
- No parallel claim-link generation path was added.
- No raw claim URL/code is manually assembled in production UI code.

## Claimed/Linked Guest Behavior

- The controller treats a guest player as unavailable for resend when:
  - `guestPlayer.isClaimed == true`, or
  - `guestPlayer.hasLinkedPlayer == true`
- The UI hides the active resend action for those guests and displays a safe linked-profile note.

## Error Handling

- Missing login shows Arabic login-required feedback.
- Unauthorized users receive safe Arabic denial feedback.
- Missing guest player shows safe Arabic not-found feedback.
- Link generation/share failure shows:
  - **"تعذر إنشاء رابط الاستلام الآن. تأكد من الصلاحيات وحاول مرة أخرى."**
- Raw exception text is not surfaced.

## Security Constraints Confirmed

- No public claim button was added on plain `/player/guestPlayer/:id`.
- Public player profile token-aware claim behavior was not changed.
- `GuestPlayer.claimCode` is not displayed.
- UI/controller code does not query `claimCodes` directly.
- `GuestClaimService` was not changed.
- Firestore rules and schema were not changed.
- ScoreSubmit, MatchEvents, settlement, rating, fantasy, and PlayerMatchStats were not changed.

## Tests Added/Updated

Updated `test/features/team/team_roster_screen_test.dart` with coverage for:

- Authorized manager sees and can share a guest player claim link.
- Tapping the action calls `ShareLinkService.createGuestPlayerClaimLink`.
- Claimed/linked guest shows linked info and no active resend action.
- Unauthorized viewer does not see the claim resend action.
- Claim-link generation failure shows safe Arabic feedback and no raw exception.

Existing public profile and ShareLinkService tests were also rerun to guard against regressions.

## Commands Run

- `flutter pub get`
  - Result: passed
- `dart format lib/features/team/controllers/team_roster_controller.dart lib/features/team/views/team_roster_screen.dart test/features/team/team_roster_screen_test.dart`
  - Result: passed
- `dart analyze lib/`
  - Result: passed, `No issues found!`
- `flutter test test/features/team/team_roster_screen_test.dart`
  - Result: passed, `+8`
- `flutter test test/core/services/share_link_service_test.dart`
  - Result: passed, `+5`
- `flutter test test/features/profile/public_player_profile_test.dart`
  - Result: passed, `+17`
- `flutter test`
  - Result: passed, `+348`

## Manual QA Checklist

- Log in as team owner or vice-captain.
- Open a team roster with an unclaimed guest player.
- Open the guest player's overflow menu and verify **"مشاركة رابط الاستلام"** appears.
- Tap the action and verify the platform share flow opens with a claim link.
- Verify the raw claim code is not visible in the roster UI.
- Mark/link the guest player and verify the resend action disappears.
- Log in as a non-manager viewer and verify guest resend actions are not visible.
- Open plain public guest profile without a token and verify no public claim CTA appears.

## Remaining Risks / Follow-ups

- The current UI placement covers the team roster manager surface. A richer tournament-operations organizer surface can reuse the same controller/service pattern later if needed.
- Existing legacy `guestPlayers.claimCode` storage remains deferred to the broader claim-code hardening roadmap.
- Platform share itself is best verified manually; widget tests inject a share callback to avoid platform-channel dependency.

## Final Result

Accepted baseline restored:

- `dart analyze lib/` passes.
- `flutter test` passes with `+348`.
- Authorized roster managers can resend/share guest player claim links.
- Unauthorized users and claimed/linked guests are guarded.
- No public claim CTA, schema, rules, settlement, rating, fantasy, or MatchEvent behavior changed.
