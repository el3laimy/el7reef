# V1 Release Risk Review

**Date:** 2026-05-02
**Role:** QA and Release-Risk Reviewer
**Context:** Play Store V1 Release for El7reef (Tournament Ego MVP)

This document outlines the primary risks, blockers, and testing flows for the V1 release, based on an audit of the current scope, architecture, and Firebase rules.

---

## 1. Top 10 Release Risks
1. **Guest Stat Ownership Gap:** Guest players and temporary match sides cannot be selected for MVP or receive official goals in the current `MatchSettlementService`. This breaks the core "Claim Profile" viral loop.
2. **Fantasy Feature Leakage:** Despite `fantasyUiEnabled = false`, fantasy buttons and toggles are still visible on tournament creation and detail screens, muddying the MVP focus.
3. **Missing Public Ego Surfaces:** There is no public player profile route (`/player/:id`) or tournament top-scorer leaderboard, severely limiting the "Pride/Ego" aspect of the app.
4. **Navigational Misalignment:** The bottom navigation tabs and Home screen highlight "Match Discover" (friendlies/social) over "Tournaments".
5. **Incomplete Claim Continuity:** When a guest claims a profile, there is no verified batch migration ensuring their previous match stats transfer cleanly.
6. **Admin/English Ops Surface:** The Tournament Operations dashboard features English labels (`Fixtures`, `Standings`) and complex admin UX, violating the Arabic-first street football aesthetic.
7. **Dead End Actions:** The Profile screen has non-functional "Settings" and "Share" buttons, and the Social/Friends features show "Coming Soon".
8. **Activity Feed Distraction:** The activity feed highlights social actions (following, etc.) rather than tournament highlights, confusing the V1 narrative.
9. **Share Card Missing Context:** The match result share card doesn't include the tournament name unless explicitly passed, missing an opportunity for tournament marketing.
10. **Tournament Assistant Permissions:** Firestore rules rely heavily on `isMatchOrganizer` or `isTournamentOrganizer`, potentially blocking designated Tournament Assistants from updating scores.

## 2. Top 10 UX Risks
1. **First-Run Confusion:** Opening the app to social feeds and friendly matches instead of a clear "Create/Find Tournament" CTA.
2. **Tournament Ops Overload:** The tournament management screens feel like internal admin tools rather than a consumer-facing mobile experience.
3. **Dead Profile Links:** Tapping a player's name in a match result might lead nowhere if the public profile route isn't implemented.
4. **Share Button Burying:** The "Share Card" actions might require too many taps to reach post-match. They need to be front-and-center.
5. **Non-Arabic Defaults:** Any English table headings or labels will break immersion for the target audience.
6. **Missing Empty States:** Navigating to an empty tournament bracket or lineup screen might look broken without clear "Add Team/Player" nudges.
7. **Lineup Hard-Blocks:** The UI must encourage optional lineups without blocking match progression if the organizer skips them.
8. **Claim Flow Friction:** If a guest scans a QR code but doesn't immediately see their past stats, they will assume the app is broken.
9. **Fantasy Switches:** Seeing a "Fantasy" toggle during tournament creation will confuse users about what kind of app this is.
10. **QR / Link Overlap:** Multiple ways to invite users (QR vs Link vs Guest Claim) might cause UX confusion if not clearly differentiated.

## 3. Top 10 Technical Risks
1. **Stat Migration Logic:** Linking a guest profile to a registered user requires a robust backend batch update to migrate historical stats without duplicating or losing data.
2. **MatchEvent Refactor Danger:** Attempting to rewrite the stat system into an event-sourced (`MatchEvent`) model right before V1 is highly risky and could break existing rating logic.
3. **Firestore Rule Gaps:** `firestore.rules` may inadvertently block authorized users (like vice-captains or tournament assistants) from performing necessary match operations.
4. **Route Sprawl:** `app_routes.dart` contains many unused or missing paths (`/achievements`, `/leaderboard`). Deep-link crashes could occur if these are accidentally hit.
5. **Feature Flag Tangles:** Relying purely on UI feature flags instead of omitting code can lead to accidentally exposing half-baked features in production.
6. **Firestore Read Costs:** Unoptimized queries for leaderboards or group standings could lead to O(N) read spikes as user bases grow.
7. **RepaintBoundary Share Failures:** The image capture service for Share Cards may fail or produce blank images on specific Android OEM devices due to hardware acceleration quirks.
8. **Deep Link Expiration:** Expired claim codes might crash the app or show raw exception strings instead of graceful UI errors.
9. **Aggregate Desync:** If score submission fails midway, match results might reflect 2-1 but player aggregates only show 1 goal.
10. **Missing Validation for Guests:** Guest players might be added with duplicate names or missing crucial identifiers, complicating future profile claims.

## 4. Top 10 Policy / Store Risks
1. **Broken/Dead Links:** Play Store reviewers will reject apps with visible "Coming Soon" buttons, empty settings menus, or dead profile links.
2. **Account Deletion Requirement:** Play Store mandates a clear, in-app way to delete user accounts and associated data.
3. **User-Generated Content (UGC):** Missing reporting/blocking mechanisms for offensive team names or profile photos.
4. **Data Safety Declaration:** Must accurately declare the collection of phone numbers, names, and guest player data.
5. **Camera/Storage Permissions:** App must handle runtime permission denials gracefully when uploading logos or scanning QRs.
6. **Privacy Policy Link:** Must be accessible from within the app and valid.
7. **Test Accounts for Reviewers:** Phone auth and claim flows require providing Google reviewers with a reliable test account and clear instructions.
8. **Feature Flag Flakiness:** If a reviewer accidentally triggers a disabled feature (like Fantasy) and it crashes, the app will be rejected.
9. **Target API Level:** Android bundle must target at least API 34 (Android 14) to be accepted.
10. **Age Restrictions:** Proper age ratings must be applied, especially given the social and UGC nature of the app.

## 5. Blockers Before Closed Testing
1. **Guest Stat Parity:** Update `PlayerMatchStats` and MVP selection to accept `PlayerIdentityRef` (guest or registered) so guests get first-class stats.
2. **Account Deletion:** Implement in-app account deletion to comply with Play Store policies.
3. **Remove Dead Routes:** Hide Settings, Friends, Fantasy, Golden Rating, and "Coming Soon" elements entirely.
4. **V1 Navigation Rework:** Set `البطولات` (Tournaments) as the default home tab and primary focus.
5. **Public Player Profile:** Implement the basic `/player/:id` screen to close the loop on player ego.
6. **Arabic Translation Sweep:** Replace all English labels in the Tournament Ops screens.

## 6. Suggested Manual QA Flows
1. **The Organizer Ego Loop:** Create Tournament -> Add 1 Registered Team & 1 Guest Team -> Generate Fixtures -> Play Match -> Submit Score (ensure a Guest gets MVP and scores a goal).
2. **The Guest Claim Loop:** Organizer shares the Guest Team Claim Link -> Guest installs app -> Clicks link -> Claims profile -> Verifies that the goal and MVP from the previous match now appear on their profile.
3. **The Share Loop:** Complete a match -> Navigate to Result Hub -> Tap Share -> Verify the generated image includes Arabic text correctly and displays the Tournament Name.
4. **The Assistant Loop:** Organizer assigns a Tournament Assistant -> Assistant logs in -> Tries to submit a match score (Verifies `firestore.rules` and UI allow this).
5. **The Empty State Flow:** Start a match without assigning lineups. Verify the UI nudges the user but allows the match to start anyway.

## 7. What Should Not Be Touched Before V1
1. **Fantasy Code:** Do not delete it; simply ensure `fantasyUiEnabled = false` and remove entry points. Deleting it will cause massive merge conflicts.
2. **Activity Feed/Social Graph:** Hide the UI, but do not rip out the backend repositories or models.
3. **Audits & Disputes:** Keep the backend logging, but hide the UI from standard users.
4. **Golden Rating / Advanced Rankings:** Leave the logic untouched and hidden.
5. **Complex Match Events:** See "Disagreements" below.

## 8. Disagreement With the Audit
**Regarding `MatchEvent` vs Aggregates:**
The audit suggests building a `MatchEvent` model/entity as a P1/P0 requirement. **I disagree for the V1 release.** 
Refactoring the entire statistical engine from the current `player_stats/{playerId}` aggregate model into a timeline-based event-sourcing model (`MatchEvent`) is extremely risky this close to V1. It requires rewriting settlement services, rating engines, and leaderboard queries. 

*Recommendation:* For V1, stick to the aggregate model but expand `PlayerMatchStats` to support a `guestPlayerId` or a union type (`PlayerIdentityRef`). Ensure MVP can accept a guest ID. Delay the full `MatchEvent` timeline refactor for V2.
