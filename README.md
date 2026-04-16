# EL7REEF

EL7REEF is a Flutter + Firebase football community app with match management,
ratings, tournaments, social activity, and a fantasy layer built on top of
league lifecycles.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Fantasy Lifecycle Bootstrap

Fantasy flows now depend on a lifecycle document in
`fantasyLeagues/{leagueId}`. This document is the source of truth for:

- `currentGameweek`
- `phase`
- `deadlineAt`
- `isLocked`
- `openedAt`
- `settledAt`
- `updatedAt`

The `global` league is special:

- The app falls back to `leagueId = global` when a fantasy route is not tied to
  a tournament.
- If the document is missing, the app can still render with service fallbacks,
  but write flows and lock-sensitive UX are more predictable when the document
  exists explicitly.

### Required Firestore Shape

Example document for `fantasyLeagues/global`:

```json
{
  "currentGameweek": 1,
  "phase": "draft",
  "deadlineAt": 1776200400000,
  "isLocked": false,
  "isGlobal": true,
  "openedAt": 1776114000000,
  "settledAt": null,
  "updatedAt": 1776114000000
}
```

### Phase Guidance

- `upcoming`: fantasy league exists but user actions should remain limited.
- `draft`: squad building and chip activation are allowed.
- `transferWindow`: transfers and chip activation are allowed between rounds.
- `live`: scoring context is active; user edits should be blocked.
- `locked`: explicit hard lock for round actions.
- `settled`: round results were finalized.
- `completed` / `cancelled`: no further user actions should be accepted.

### Bootstrap Rules For New Leagues

When enabling fantasy for a new tournament-backed league:

1. Create the tournament document first.
2. Create `fantasyLeagues/{tournamentId}` before exposing fantasy routes.
3. Set `currentGameweek` and `phase` explicitly instead of relying on UI
   defaults.
4. Set `deadlineAt` whenever the round should auto-lock after a known time.
5. Keep `updatedAt` fresh on every admin lifecycle change.

### Security Notes

- Client reads are allowed for `fantasyLeagues`.
- Client writes are blocked by Firestore rules; lifecycle writes must happen
  through trusted admin tooling or backend automation.

## Hybrid Identity Bootstrap

V2 introduces a guest identity layer so tournaments and teams can operate before
every participant is fully registered inside the app.

Current foundation collections:

- `guestPlayers`
- `guestTeams`
- `claimCodes`

Feature flags controlling rollout:

- `FeatureFlags.guestIdentityEnabled`
- `FeatureFlags.hybridTournamentRegistrationEnabled`

### `guestPlayers` Shape

Example document:

```json
{
  "displayName": "Mahmoud Ali",
  "normalizedName": "mahmoud ali",
  "phoneNumber": "01000000000",
  "jerseyNumber": 9,
  "preferredPosition": "FWD",
  "teamId": "team-1",
  "tournamentId": "tournament-1",
  "createdBy": "captain-1",
  "createdAt": 1776200400000,
  "updatedAt": 1776200400000,
  "claimStatus": "guest",
  "claimCode": null,
  "linkedPlayerId": null,
  "notes": "manual entry"
}
```

### `guestTeams` Shape

Example document:

```json
{
  "name": "El Mal3ab Guests",
  "normalizedName": "el mal3ab guests",
  "creatorId": "organizer-1",
  "contactName": "Captain Ahmed",
  "contactPhone": "01000000000",
  "logoUrl": null,
  "tournamentIds": ["tournament-1"],
  "captainGuestPlayerId": "guest-player-1",
  "claimStatus": "guest",
  "claimCode": null,
  "linkedTeamId": null,
  "createdAt": 1776200400000,
  "updatedAt": 1776200400000
}
```

### `claimCodes` Shape

Example document:

```json
{
  "targetType": "guestPlayer",
  "targetId": "guest-player-1",
  "scope": "team",
  "teamId": "team-1",
  "tournamentId": null,
  "createdBy": "captain-1",
  "requiresApproval": false,
  "status": "active",
  "createdAt": 1776200400000,
  "updatedAt": 1776200400000,
  "expiresAt": 1776805200000,
  "claimedByPlayerId": null,
  "claimedAt": null
}
```

### Claim Share Links

The app now has a share-link foundation for:

- guest player claim links
- guest team claim links
- team invite links

The transport contract is `ClaimPayload`, and the persisted contract is
`claimCodes/{code}`.

### Current Security Intent

- guest player creation is limited to the creator who also owns the target team
  or tournament scope
- guest team creation is limited to its creator
- claim code writes are now limited to authorized guest/team managers and team
  managers issuing invite or claim links
