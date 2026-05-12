# Sprint 2 / Task 7: Token-Aware Guest Profile Claim Entry

## Summary of Implementation

Added a token-aware guest claim CTA to the public player profile surface. The CTA appears only when the current route already contains a valid-looking guest-player claim payload for the same guest profile.

Plain public guest profiles still show placeholder copy only:

> ده أنت؟ اطلب رابط الدعوة من منظم البطولة أو قائد الفريق.

No claim code lookup, claim code generation, Firestore rule change, service change, or schema change was added.

## Files Changed

- `lib/features/profile/controllers/public_player_profile_controller.dart`
- `lib/features/profile/views/public_player_profile_screen.dart`
- `test/features/profile/public_player_profile_test.dart`
- `docs/Sprint2_Task7_Token_Aware_Guest_Profile_Claim_Report.md`

## Token Detection Rules

The controller reads only existing `Get.parameters` values for:

- `code`
- `type`
- `targetId`
- `scope`
- `teamId`
- `tournamentId`
- `requiresApproval`
- `expiresAt`
- `status`

It does not read `GuestPlayer.claimCode`, does not access `ClaimCodeRepository`, and does not query `claimCodes`.

## CTA Visibility Rules

The CTA is shown only when:

- loaded profile is `guestPlayer`,
- profile id is non-empty,
- profile is not claimed and has no `linkedPlayerId`,
- route has non-empty `code`,
- `type == guestPlayer`,
- `targetId == profile.id`,
- optional `status` is absent or `active`,
- optional `expiresAt` is parseable and not expired.

The CTA is hidden for:

- registered player profiles,
- missing code,
- missing target id,
- wrong target id,
- wrong type,
- inactive/claimed/expired status,
- expired `expiresAt`,
- claimed or linked guest profiles.

Wrong or incomplete token states show safe Arabic copy without exposing the raw code.

## Navigation Behavior

The CTA calls:

```dart
AppRoutes.guestPlayerClaimById(
  profile.id,
  queryParameters: safeClaimPayload,
)
```

Only the known claim payload keys are forwarded. Profile route params like `kind` and `id` are not forwarded unless they are part of the claim payload under the accepted keys.

## Safety Guards

- No raw code is displayed in the public profile UI.
- No CTA appears on plain `/player/guestPlayer/:id`.
- No CTA appears for `/player/player/:id`.
- No CTA appears for linked/claimed guests.
- Existing claim screen and `GuestClaimService` remain the final authority after navigation.

## What Was Intentionally Not Touched

- `GuestClaimService`
- `ShareLinkService`
- `ClaimCodeRepository`
- Firestore rules
- Firestore schema
- Guest claim generation/resend logic
- Public profile resolver data access
- ScoreSubmit, MatchEvents, rating, fantasy, PlayerMatchStats

## Tests Added / Updated

Updated `test/features/profile/public_player_profile_test.dart` with coverage for:

- guest profile without token shows placeholder and no CTA,
- valid matching token shows CTA,
- CTA navigates to `/guest-player/<guestId>/claim` and preserves `code`,
- wrong target id token is guarded,
- missing code is guarded,
- type mismatch is guarded,
- expired `expiresAt` is guarded,
- inactive status is guarded,
- claimed/linked guest does not show CTA,
- registered player profile never shows guest claim CTA,
- existing resolver tests remain green.

## Commands Run

| Command | Result |
|---|---|
| `flutter pub get` | Passed. Dependencies resolved; newer incompatible package versions were reported by Flutter. |
| `dart format lib/features/profile/controllers/public_player_profile_controller.dart lib/features/profile/views/public_player_profile_screen.dart test/features/profile/public_player_profile_test.dart` | Passed. |
| `dart analyze lib/` | Failed due existing analyzer issues in `lib/features/shareables/services/share_card_capture_service.dart`: one unused local variable and three `use_build_context_synchronously` infos. These files are outside the allowed changes for this task and were not modified. |
| `flutter test test/features/profile/public_player_profile_test.dart` | Passed, `+17`. |
| `flutter test` | Passed, `+342`. |

## Final Result

Token-aware public guest profile claim entry is implemented and tested. The CTA is strictly proof-of-possession UX based on an already-present route token; it does not amplify claim code exposure by discovering or fetching stored claim codes.

## Risks / Follow-Ups

- Firestore rules and claim code storage remain as documented in Sprint 2 / Task 6; claim secrets still need rules/data-model hardening before broad public claim UX.
- `dart analyze lib/` remains blocked by unrelated share card capture analyzer issues outside this task's allowed files.
- Future hardening should remove raw `claimCode` from public-readable guest documents and restrict `claimCodes` reads/listing.
