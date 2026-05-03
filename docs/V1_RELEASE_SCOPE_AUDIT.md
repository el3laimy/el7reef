# V1 Release Scope Audit - Popular Tournament Ego MVP

Date: 2026-05-02

Scope rule for this document: audit only. No product feature, schema, route, or business-logic changes were made.

## 1. Executive Summary

### Current Product Surface

The current app is a broad Arabic-first Flutter/GetX football app with these visible or registered surfaces:

- Home hub with 5 bottom tabs: Home, Match Discover, Tournaments, My Teams, Profile in `lib/features/home/views/home_screen.dart`.
- Tournament creation/list/detail/registration/guest-team/operations screens in `lib/features/tournament/**`.
- Friendly match creation, lobby, temporary players, optional lineups, matchday, score submit, fan MVP voting, and result sharing in `lib/features/match/**`, `lib/features/lineup/**`, and `lib/features/shareables/**`.
- Teams, registered roster, guest players, team invite links, formation templates, and roster snapshots in `lib/features/team/**`.
- Player identity/profile with rating, MVP count, username, QR, photo upload, and basic stats in `lib/features/profile/**` and `lib/features/social/views/username_screen.dart`.
- Guest/claim profile support through claim links, guest player/team claim, and team invite entry in `lib/features/guest_claim/**` and `lib/core/services/share_link_service.dart`.
- Fantasy implementation exists in routes, screens, controllers, models, repositories, and tests, but `FeatureFlags.fantasyUiEnabled = false` in `lib/core/constants/feature_flags.dart`.
- Social/friends/search/activity feed/challenges exist; `FeatureFlags.activityFeedEnabled = true`, so feed is visible on Home.

### Main Mismatch With Tournament Ego MVP

The product direction is now "Popular Tournament Ego MVP", but the current first-run surface still reads as a mixed app: friendly matches and social activity are first-class visible surfaces, while tournament ops exists but looks more like an internal admin console than a consumer-ready tournament ego loop.

Main mismatches:

- Tournament is visible, but not clearly the primary app axis. Home quick actions put matches, tournaments, and teams side by side.
- Tournament creation still exposes "Fantasy" (`isFantasyEnabled`) despite fantasy being out of V1 and globally route-gated.
- Tournament operations screens include English labels like `Tournament Operations Dashboard`, `Participants`, `Groups`, `Fixtures`, and `Standings`, conflicting with Arabic-first V1 polish.
- Player ego stats are partially present: rating, wins, losses, MVP count, match-level goals for registered players. There is no V1-ready public top-scorers or tournament player leaderboard surface.
- Guest/temporary identity is good for rosters/lineups/claim, but settlement and fan voting currently filter to registered official roster players, which weakens "claim later without losing stats" for guest scorers/MVP.
- There is no explicit route-registered generic player profile page despite `AppRoutes.playerProfile = '/player/:id'`.

### Highest-Risk Areas Before V1

- P0: Hide or remove visible fantasy entry points from tournament creation/detail. `FeatureFlags.fantasyUiEnabled` hides fantasy routes, but `TournamentListScreen` and `TournamentDetailScreen` still surface fantasy state/buttons.
- P0: Tournament operations UX needs Arabic-first, V1-safe surface review. It is functional, but visibly admin/English and probably too complex for first release.
- P0: Guest/temporary stat ownership gap. `MatchSettlementService` writes detailed stats only for registered official roster players. Guest player goals and MVP are not first-class in settlement.
- P0: V1 navigation is not tournament-first enough. Current bottom tabs make friendly matches equal to tournaments.
- P1: Player profile/leaderboard ego loops are incomplete. Basic profile stats exist; top scorers, tournament MVPs, tournament player cards, and public player pages need build/fix.
- P1: Firestore rules permit broad match updates only for match organizers and may not match tournament assistant/result flows without careful verification.

## 2. Route Inventory

Source files:

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`

| Route name/path | Screen/page | Status | Reason | V1 relevance |
|---|---|---:|---|---|
| `AppRoutes.splash` `/splash` | `SplashScreen` | keep | Initial route, sends user to Home or Onboarding. | Required app boot. |
| `AppRoutes.onboarding` `/onboarding` | `OnboardingScreen` | keep | Auth funnel. | Required. |
| `AppRoutes.login` `/login` | `LoginScreen` | keep | Auth funnel. | Required. |
| `AppRoutes.register` `/register` | Not registered | investigate | Constant exists, no `GetPage`. | Only needed if login flow references it. |
| `AppRoutes.home` `/home` | `HomeScreen` | fix | Works, but navigation is not tournament-first. | Primary V1 shell. |
| `AppRoutes.profile` `/profile` | `ProfileScreen` | fix | Useful ego identity; has dead settings/share/friends actions. | Core V1 identity. |
| `AppRoutes.editProfile` `/profile/edit` | Not registered | investigate | Constant exists, no page. | Avoid visible dead route. |
| `AppRoutes.playerProfile` `/player/:id` | Not registered | build | No public player profile route registered. | Core ego/claim/public identity. |
| `AppRoutes.teamProfile` `/team/:id` | `TeamRosterScreen` | keep | Team roster/profile and guest roster support. | Core V1 team identity. |
| `AppRoutes.createTeam` `/team/create` | Not registered | investigate | Creation is bottom sheet in `MyTeamsScreen`, not route. | Not blocker if no link uses route. |
| `AppRoutes.findMatch` `/match/find` | `MatchDiscoverScreen` | hide | Friendly/challenges are retention loops, not primary V1. | Keep accessible but not top-level first. |
| `AppRoutes.createMatch` `/match/create` | Not registered | investigate | Creation is bottom sheet in match discover. | Not blocker if hidden from top-level. |
| `AppRoutes.matchLobby` `/match/lobby/:id` | `MatchLobbyScreen` | keep | Friendly lobby, temporary players, start flow. | Retention loop, keep secondary. |
| `AppRoutes.matchDetails` `/match/details/:id` | `MatchdayScreen` gated by `matchdayUiEnabled` | fix | Matchday is relevant for tournament fixtures but needs V1 clarity/polish. | Core atomic match ops. |
| `AppRoutes.teamLineupEditor` `/match/:matchId/lineup/editor/:teamId` | `TeamLineupEditorScreen` | keep | Official team lineup editor. | Core shareable lineup. |
| `AppRoutes.matchSideLineupEditor` `/match/:matchId/lineup/side/:sideKey` | `MatchSideLineupEditorScreen` | keep | Temporary/friendly side lineup editor. | Secondary, useful for retention. |
| `AppRoutes.matchResultLineup` `/match/:matchId/lineup/result` | `MatchResultLineupScreen` | keep | Result/lineup presentation and result share entry point. | Core shareable result. |
| `AppRoutes.rating` `/rating/:matchId` | Not registered | investigate | Constant only. | Avoid dead route. |
| `AppRoutes.mvpVote` `/rating/mvp/:matchId` | `FanVotingScreen` | fix | Fan voting exists but registered-player-only. | Core ego loop if tournament-ready. |
| `AppRoutes.createTournament` `/tournament/create` | Not registered | investigate | Creation is bottom sheet in `TournamentListScreen`. | Not blocker if no direct route needed. |
| `AppRoutes.tournamentList` `/tournament/list` | `TournamentListScreen` | keep | Main tournament list and create CTA. | Core V1. |
| `AppRoutes.tournaments` `/tournaments` | `TournamentListScreen` alias | keep | Alias used by QR scanner comment. | Core V1. |
| `AppRoutes.tournamentDetail` `/tournament/:id` | `TournamentDetailScreen` | fix | Core detail exists; fantasy button and English ops labels leak. | Core V1. |
| `AppRoutes.tournamentBracket` `/tournament/:id/bracket` | `TournamentBracketScreen` | fix | Bracket exists; UI includes English labels. | Core if knockout tournaments in V1. |
| `AppRoutes.tournamentParticipants` `/tournament/:id/participants` | `TournamentParticipantsScreen` | fix | Participants ops exist; admin-oriented. | Core organizer. |
| `AppRoutes.tournamentGroups` `/tournament/:id/groups` | `TournamentGroupsScreen` | fix | Groups exist. | Core tournament ops. |
| `AppRoutes.tournamentFixtures` `/tournament/:id/fixtures` | `TournamentFixturesScreen` | fix | Fixtures exist and link to matchday/start/result. | Core tournament ops. |
| `AppRoutes.tournamentStandings` `/tournament/:id/standings` | `TournamentStandingsScreen` | keep/fix | Standings model/screen exists; English table headings. | Core ego/team ranking. |
| `AppRoutes.tournamentAssistants` `/tournament/:id/assistants` | `TournamentAssistantsScreen` | investigate | Useful for organizer delegation, but may be advanced. | P1/P2 depending ops need. |
| `AppRoutes.teamRegistration` `/tournament/:id/register` | `TournamentRegistrationScreen` gated by `hybridTournamentRegistrationEnabled` | keep | Registered and guest team registration. | Core tournament signup. |
| `AppRoutes.tournamentGuestTeamCreate` `/tournament/:id/register/guest-team/create` | `TournamentGuestTeamCreateScreen` | keep | Organizer creates guest teams. | Core street-football reality. |
| `AppRoutes.tournamentRegistrationReview` `/tournament/:id/register/review/:registrationId` | `TournamentRegistrationReviewScreen` | keep | Registration approval/reject. | Core organizer. |
| `AppRoutes.organizerDashboard` `/organizer/dashboard/:tournamentId` | `TournamentOperationsDashboardScreen` | fix | Functional but admin/English-heavy. | Core but needs surface freeze/polish. |
| `AppRoutes.scoreApproval` `/organizer/score/:matchId` | `ScoreSubmitScreen` | fix | Score + MVP + registered stats. Guest stat gap. | Core result entry. |
| `AppRoutes.goldenRating` `/organizer/golden-rating/:matchId` | Not registered | hide | Constant only; "golden rating" may be advanced/out of V1. | Not V1 visible. |
| `AppRoutes.fantasyHome` `/fantasy` | `FantasyLeagueListScreen` or unavailable | hide | Route gated by `fantasyUiEnabled = false`. | Out of V1. |
| `AppRoutes.fantasyPickTeam` `/fantasy/pick/:leagueId` | `CreateFantasyTeamScreen` or unavailable | hide | Fantasy out of scope. | Out of V1. |
| `AppRoutes.fantasyTeam` `/fantasy/team/:leagueId` | `FantasyTeamScreen` or unavailable | hide | Fantasy out of scope. | Out of V1. |
| `AppRoutes.fantasyTransfers` `/fantasy/transfers/:leagueId` | `TransferMarketScreen` or unavailable | hide | Fantasy out of scope. | Out of V1. |
| `AppRoutes.fantasyLeaderboard` `/fantasy/leaderboard/:leagueId` | `FantasyLeaderboardScreen` or unavailable | hide | Fantasy out of scope. | Out of V1. |
| `AppRoutes.leaderboard` `/leaderboard` | Not registered | build | Constant exists; no V1 leaderboard screen. | Core ego gap. |
| `AppRoutes.achievements` `/achievements` | Not registered | hide/build later | Constant and `Player.achievementIds`, no page. | P2 V1 unless used in profile. |
| `AppRoutes.username` `/profile/username` | `UsernameScreen` | keep | User identity/handle. | Core identity. |
| `AppRoutes.qrScanner` `/qr/scan` | `QrScannerScreen` | keep/fix | QR identity/invites. | Useful for claim/invite growth. |
| `AppRoutes.myQrCode` `/profile/qr` | Not registered | investigate | Profile shows QR dialog, no route. | Not blocker. |
| `AppRoutes.friends` `/social/friends` | `FriendsScreen` | hide/fix | Social advanced; profile has "coming soon" snackbar. | Out or secondary for V1. |
| `AppRoutes.searchPlayers` `/social/search` | `SearchPlayersScreen` | fix | Useful for player identity/challenges, but social/challenge-heavy. | P1 discovery. |
| `AppRoutes.activityFeed` `/social/feed` | Not registered | hide | Feed widget exists on Home, no page. | Out of V1 primary. |
| `AppRoutes.claimEntry` `/claim` | `ClaimEntryScreen` gated by `guestIdentityEnabled` | keep | Deep link landing for claim profile. | Core claim profile. |
| `AppRoutes.inviteEntry` `/invite` | `TeamInviteEntryScreen` | keep | Team invite deep link. | Core growth/invite. |
| `AppRoutes.guestPlayerClaim` `/guest-player/:guestPlayerId/claim` | `GuestPlayerClaimScreen` | keep/fix | Claim profile exists. Need stat continuity audit. | Core claim profile. |
| `AppRoutes.guestTeamClaim` `/guest-team/:guestTeamId/claim` | `GuestTeamClaimScreen` | keep | Guest team claim exists. | Core team claim. |
| `AppRoutes.myTeams` `/teams` | `MyTeamsScreen` | keep | Team list/create. | Core V1. |
| `AppRoutes.auditTimeline` `/organizer/audit/:entityId` | `AuditTimelineScreen` | hide/investigate | Audit is ops/internal. | Not V1 public. |
| `AppRoutes.disputeViewer` `/organizer/disputes/:matchId` | `DisputeViewerScreen` | hide/investigate | Disputes are advanced unless organizer-only. | P2 or organizer-only. |

## 3. Navigation Inventory

### Current Bottom Tabs

Defined in `lib/features/home/views/home_screen.dart`:

1. `الرئيسية` -> `_HomeTab`
2. `اكتشاف` -> `MatchDiscoverScreen`
3. `دورات` -> `TournamentListScreen`
4. `فرقي` -> `MyTeamsScreen`
5. `بروفايل` -> `ProfileScreen`

### Current Home Cards / Entry Points

- Header/profile/rating card in `HomeScreen`.
- Quick actions: `المباريات`, `البطولات`, `فرقي`.
- Fantasy quick action only if `FeatureFlags.fantasyUiEnabled`, currently false.
- Activity feed widget always included, hidden only if `FeatureFlags.activityFeedEnabled` false.
- Live matches carousel.
- Recent/my matches list.

### Should Remain Visible in V1

- Tournaments list/detail/create/register.
- Teams list/detail/create.
- Profile/claim identity.
- Tournament fixtures/matchday/result/share.
- Result and lineup share actions.

### Should Be Hidden or Gated

- Fantasy surfaces and all tournament fantasy badges/buttons.
- Activity feed on Home for V1 unless reframed as tournament highlights.
- Friends/social feed as top-level surfaces.
- Challenges as a secondary match retention loop, not top-level.
- Audit/dispute routes from public navigation.
- Golden rating route/CTA unless product explicitly keeps it as an ego mechanic.

### Recommended V1 Navigation Structure

Recommended bottom tabs:

1. `البطولات` - default tab; list/live tournaments/create CTA.
2. `المباريات` - tournament fixtures first, then my/friendly matches.
3. `الفرق` - my teams and roster.
4. `اللاعبين` or `الترتيب` - public ego surface: top scorers/MVP/rating once built.
5. `أنا` - profile, QR, claim identity, settings.

Recommended Home/default screen:

- Default to tournament list or a tournament-first dashboard, not generic Home.
- Primary CTA: `أنشئ بطولة`.
- Secondary CTAs: `سجّل فريق`, `أضف نتيجة`, `شارك كارت`.
- Friendly match CTA should be secondary: `مباراة ودية`.

## 4. Feature Inventory

### Tournaments

Current implementation:

- List/create in `lib/features/tournament/views/tournament_list_screen.dart` and `lib/features/tournament/controllers/tournament_controller.dart`.
- Detail in `lib/features/tournament/views/tournament_detail_screen.dart`.
- Registration in `lib/features/tournament/views/tournament_registration_screen.dart`.
- Guest team create/review in `lib/features/tournament/views/tournament_guest_team_create_screen.dart` and `lib/features/tournament/views/tournament_registration_review_screen.dart`.
- Ops dashboard/participants/groups/fixtures/standings/bracket in `lib/features/tournament/views/tournament_operations_screens.dart`.
- Services: `lib/core/services/tournament_lifecycle_service.dart`, `tournament_fixture_service.dart`, `tournament_participant_service.dart`, `group_stage_builder.dart`, `knockout_builder.dart`.
- Models/entities: `lib/domain/entities/tournament.dart`, `tournament_participant.dart`, `tournament_group.dart`, `group_standing_snapshot.dart`, `knockout_bracket.dart`, `knockout_tie.dart`.

V1 decision: fix.

Blockers:

- Fantasy toggle/badge/button visible in tournament create/detail.
- Ops UI has English/admin labels.
- No player top scorer/MVP tournament leaderboard surface.
- Need verify Firestore rules for tournament assistant permissions.

### Teams

Current implementation:

- My teams/create in `lib/features/team/views/my_teams_screen.dart`.
- Team roster/profile in `lib/features/team/views/team_roster_screen.dart`.
- Team roster controller/services in `lib/features/team/controllers/team_roster_controller.dart`, `lib/core/services/team_roster_service.dart`, `team_formation_service.dart`, `team_invite_service.dart`.
- Team model in `lib/domain/entities/team.dart`.

V1 decision: keep/fix.

Blockers:

- Team profile is roster-management-heavy, not yet public ego/team identity.
- No tournament history/trophies/team ranking presentation.

### Players

Current implementation:

- Current-user profile in `lib/features/profile/views/profile_screen.dart`.
- Profile controller in `lib/features/profile/controllers/profile_controller.dart`.
- Username in `lib/features/social/views/username_screen.dart`.
- Player model in `lib/domain/entities/player.dart`.
- `PlayerRepositoryImpl.getLeaderboard()` exists but no general leaderboard page is registered.

V1 decision: fix/build.

Blockers:

- No registered public `/player/:id` screen despite route constant.
- Profile has dead or placeholder actions: settings empty, friends snackbar "قريباً", share empty.
- Player aggregates do not include goals/assists/top scorer totals.

### Matches

Current implementation:

- Match model supports organized/tournament fields, result, MVP, status, fixture status, group/knockout references in `lib/domain/entities/match.dart`.
- Matchday in `lib/features/match/views/matchday_screen.dart`.
- Score submit in `lib/features/match/views/score_submit_screen.dart`.
- Settlement in `lib/core/services/match_settlement_service.dart`.
- Start/cancel services in `lib/core/services/match_start_service.dart`, `match_cancellation_service.dart`.

V1 decision: keep/fix.

Blockers:

- Detailed stats are written only for eligible registered official roster players.
- MVP validation filters to official registered roster.
- Match events are not modeled as event rows; only aggregate stats and score exist.

### Friendly Matches

Current implementation:

- Discover/create/lobby in `lib/features/match/views/match_discover_screen.dart` and `match_lobby_screen.dart`.
- Temporary sides/players in `lib/domain/entities/match_side.dart`, `match_side_player.dart`.
- Optional lineup nudge exists in `MatchLobbyScreen`.

V1 decision: hide from primary nav, keep secondary.

Blockers:

- Currently a top-level bottom tab and major Home focus.
- Retention loop should not dominate first V1 release.

### Challenges

Current implementation:

- Challenge tab inside `MatchDiscoverScreen`.
- `ChallengeController` accepts challenge by creating a friendly `Match`.
- Models/repository in `lib/domain/entities/challenge.dart`, `lib/data/repositories/challenge_repository_impl.dart`.

V1 decision: hide/gate.

Blockers:

- Retention loop, not Tournament Ego MVP core.
- Social discovery/challenge flow may distract from tournament release.

### Lineups

Current implementation:

- Editors in `lib/features/lineup/views/team_lineup_editor_screen.dart`, `match_side_lineup_editor_screen.dart`.
- Snapshots in `lib/domain/entities/match_lineup_snapshot.dart` and `match_lineup_entry.dart`.
- Share-card data/controller/widgets in `lib/features/shareables/controllers/lineup_share_controller.dart`, `widgets/lineup_share_card.dart`.

V1 decision: keep/fix.

Blockers:

- Need ensure tournament fixture lineup creation is obvious from fixture/matchday screens.
- Need verify guest team tournament lineup flow end-to-end.

### Results

Current implementation:

- Score submit supports score, MVP, registered player goals/assists/saves/cards in `ScoreSubmitController`.
- Result presentation/share in `MatchResultLineupScreen`, `MatchResultShareController`, `MatchResultShareCard`.
- Tournament result approval/standings refresh in `MatchSettlementService.approveScore()`.

V1 decision: keep/fix.

Blockers:

- Guest player goal attribution missing.
- Match events timeline missing.
- Result card currently depends on loaded match/side/snapshot data; tournament name is only included when explicitly passed.

### Goals / Events / MVP

Current implementation:

- Registered-player match stats model has goals, assists, saves, tackles, cards, rating in `lib/domain/entities/player_match_stats.dart`.
- Score submit builds stats for registered official roster players.
- `Match.mvpPlayerId` exists.
- Fan MVP voting in `lib/core/services/fan_voting_service.dart`.

V1 decision: fix/build.

Blockers:

- No `MatchEvent` model/entity/repository.
- No guest scorer identity in `PlayerMatchStats`.
- No tournament top scorers aggregation/surface.
- Fan voting excludes guests/temporary players.

### Leaderboards

Current implementation:

- Fantasy leaderboard exists but out of scope.
- `PlayerRepositoryImpl.getLeaderboard()` returns rating leaderboard.
- Tournament standings exist as group standings snapshots.
- No general `AppRoutes.leaderboard` page registered.

V1 decision: build.

Blockers:

- Need V1 leaderboard definitions: tournament standings, top scorers, MVP race, player rating.
- Need data source for scorers/MVP beyond registered aggregates.

### Share Cards

Current implementation:

- Result and lineup share cards exist in `lib/features/shareables/widgets/match_result_share_card.dart` and `lineup_share_card.dart`.
- Capture/share service uses `RepaintBoundary`, `path_provider`, `share_plus`.
- Link/claim sharing exists in `ShareLinkService`.

V1 decision: keep/fix.

Blockers:

- Need make share CTAs central in tournament detail/fixture/result pages.
- Need tournament card/player card share surfaces if V1 wants public brag cards beyond lineup/result.

### Claim Profile

Current implementation:

- Claim code, payload, guest player/team claim models exist.
- Claim entry and guest claim screens exist.
- `GuestClaimService` links guest player/team to real player/team.
- `GuestPlayer` has `linkedPlayerId`; `MatchLineupEntry` has `claimedFromGuestPlayerId`.

V1 decision: keep/fix.

Blockers:

- Stats continuity is unclear/incomplete for guest goals/MVP because settlement stores registered-player stats under `matches/{matchId}/player_stats/{playerId}`.
- Need audit claim merge behavior for tournament stats once stats are guest-aware.

### Fantasy

Current implementation:

- Full fantasy package exists in `lib/features/fantasy/**`, `lib/core/services/fantasy_*`, `lib/data/models/fantasy_*`, tests.
- Routes are gated by `FeatureFlags.fantasyUiEnabled = false`.
- Tournament create/detail still surface fantasy enablement.

V1 decision: hide.

Blockers:

- Remove/gate tournament fantasy switch, list badge, and detail button from visible V1.

### Social / Feed

Current implementation:

- Activity feed widget is visible on Home if enabled.
- Friends, search, QR scanner, friendship repositories/services exist.
- Feed builds from friend/following activity, recent matches, tournaments.

V1 decision: hide/fix.

Blockers:

- Activity feed is advanced social feed, out of V1.
- Friends screen has a search action that shows "قيد التطوير".

### Settings / Auth / Profile

Current implementation:

- Splash/onboarding/login/auth service.
- Profile photo, username, QR, position, stats, sign out.

V1 decision: keep/fix.

Blockers:

- Settings icon is dead.
- Profile share action is dead.
- Public player profile route missing.

## 5. Data Model Audit

### Tournament

Files:

- `lib/domain/entities/tournament.dart`
- `lib/data/models/tournament_model.dart`
- `lib/domain/entities/tournament_participant.dart`
- `lib/domain/entities/tournament_group.dart`
- `lib/domain/entities/group_standing_snapshot.dart`

Supports:

- Tournament formats, team size, max teams, status, assistants, registration deadline, group/knockout IDs, winner participant.
- Tournament standings through `GroupStandingSnapshot`.

Gaps:

- `isFantasyEnabled` defaults true, conflicts with V1 product freeze.
- No tournament-level top scorer/MVP aggregates.
- No public tournament player leaderboard entity.

### Team

Files:

- `lib/domain/entities/team.dart`
- `lib/domain/entities/team_membership.dart`
- `lib/domain/entities/team_roster_snapshot.dart`
- `lib/domain/entities/team_formation_template.dart`

Supports:

- Team identity, owner/vice captains, players, wins/draws/losses, roster membership, guest memberships, snapshots/templates.

Gaps:

- Team ego surface is basic: no trophies, tournament history, public profile presentation.

### Player

Files:

- `lib/domain/entities/player.dart`
- `lib/domain/entities/player_match_stats.dart`
- `lib/data/models/player_match_stats_model.dart`

Supports:

- Rating, matches, W/D/L, MVP count, username, QR, photo/frame, trust, teams/friends.
- Registered player match goals/assists/saves/cards/rating.

Gaps:

- Player aggregate has no total goals/assists/clean sheets.
- No guest-aware stat identity.
- Public player profile route missing.

### Match

Files:

- `lib/domain/entities/match.dart`
- `lib/data/models/match_model.dart`
- `lib/domain/entities/match_side.dart`
- `lib/domain/entities/match_side_player.dart`
- `lib/domain/entities/match_lineup_snapshot.dart`

Supports:

- Friendly and tournament matches.
- Scores, MVP, status, start/complete/cancel.
- Tournament stage/group/knockout references.
- Temporary match sides and players.
- Lineup snapshots.

Gaps:

- No event timeline model.
- MVP is a single `playerId` string, not guest/registered typed identity.
- Score is aggregate only; no official scorer list.

### Temporary / Guest Player

Files:

- `lib/domain/entities/guest_player.dart`
- `lib/domain/entities/guest_team.dart`
- `lib/domain/entities/match_side_player.dart`
- `lib/core/services/guest_team_roster_service.dart`
- `lib/core/services/team_roster_service.dart`

Supports:

- Guest player/team identity, claim status/code, linked real player/team.
- Temporary friendly match side players.
- Guest roster membership.

Gaps:

- Temporary `MatchSidePlayer` has no claim code/link to player.
- Guest player stats are not first-class in `PlayerMatchStats`.

### Result

Files:

- `lib/domain/entities/match.dart`
- `lib/core/services/match_settlement_service.dart`
- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/features/shareables/models/match_result_share_data.dart`

Supports:

- Score A/B, status transition, anomaly review, approval, standings refresh.
- Result share data/card.

Gaps:

- Guest goals and event details missing.
- Result approval updates registered player aggregates only.

### Stats

Files:

- `lib/domain/entities/player_match_stats.dart`
- `lib/data/models/player_match_stats_model.dart`
- `matches/{matchId}/player_stats/{playerId}` subcollection in `MatchSettlementService`.

Supports:

- Registered player match stats.
- Fantasy points engines use stats.

Gaps:

- No guest ID fields.
- No tournament scorer aggregate.
- No stat migration/claim continuity mechanism.

### Share Card

Files:

- `lib/features/shareables/models/lineup_share_data.dart`
- `lib/features/shareables/models/match_result_share_data.dart`
- `lib/features/shareables/widgets/lineup_share_card.dart`
- `lib/features/shareables/widgets/match_result_share_card.dart`
- `lib/features/shareables/services/share_card_capture_service.dart`

Supports:

- Lineup/result image cards and sharing.

Gaps:

- No player card or tournament champion/top-scorer card yet.

### Claim Profile

Files:

- `lib/domain/entities/claim_code.dart`
- `lib/domain/entities/claim_payload.dart`
- `lib/domain/entities/generated_share_link.dart`
- `lib/core/services/guest_claim_service.dart`
- `lib/core/services/share_link_service.dart`

Supports:

- Claim codes for guest players, guest teams, team invites.
- Claim entry routing and link generation.

Gaps:

- Claim later without losing stats is only partially supported by identity links; stats do not yet attach to guest identity in match settlement.

### Capability Matrix

| Capability | Current support | Evidence | Decision |
|---|---|---|---|
| Guest player goals | partial/no | Guest players exist, but `PlayerMatchStats` requires `playerId`; settlement filters registered roster. | P0 fix/build. |
| Registered player goals | yes | `ScoreSubmitController` builds `PlayerMatchStats`; `MatchSettlementService` writes `player_stats`. | Keep/fix UX. |
| MVP selection | partial | `Match.mvpPlayerId` and fan voting; registered roster only. | Fix guest-aware MVP. |
| Match events | no | No `MatchEvent` entity/repository found. | P1 build if needed for V1. |
| Tournament standings | yes | `GroupStandingSnapshot`, `TournamentStandingsScreen`, lifecycle refresh. | Keep/fix UI. |
| Top scorers | no | No route/model/screen found; goals only per registered match stats. | P0/P1 build. |
| Claim later without losing stats | partial/no | Guest claim exists; stat ownership for guests missing. | P0 fix/build. |

## 6. Critical Gaps For Tournament Ego MVP

### P0 Blockers

- Hide fantasy from all visible V1 surfaces: `TournamentListScreen`, `TournamentDetailScreen`, `TournamentController`.
- Make navigation tournament-first: Home/default and bottom tabs.
- Fix tournament ops surface polish: Arabic labels, reduce admin feel, expose only V1-safe actions.
- Add/define guest-aware goal and MVP attribution before marketing claim-profile ego loops.
- Build or expose V1 leaderboards: standings, top scorers, MVP race.
- Register/build public player profile or remove deep links to missing route.

### P1 Important

- Add tournament/team/player share cards beyond lineup/result.
- Make result submit and approval flow clearer for tournament organizers.
- Verify tournament assistant permissions in Firestore rules and services.
- Fix profile dead actions: settings, share, friends placeholder.
- Hide or gate activity feed/social feed from Home.
- Decide whether fan voting is V1 or P2; if V1, make it tournament/guest-aware.

### P2 Later

- Challenges as retention loop.
- Friends/social graph beyond claim/invite basics.
- Audit/dispute UI for production organizer ops.
- Achievements.
- Golden rating.
- Advanced rankings.
- Fantasy.

## 7. Recommended V1 Visible Surface

### Tabs

Recommended:

1. `البطولات`
2. `المباريات`
3. `الفرق`
4. `الترتيب`
5. `أنا`

### Home Screen Sections

If Home remains as a dashboard:

- Featured/live tournaments.
- My active tournament fixtures.
- Recent results with share CTA.
- Top players: scorers/MVP/rating.
- My teams quick access.

### Main CTAs

- `أنشئ بطولة`
- `سجّل فريق`
- `أضف فريق ضيف`
- `ابدأ مباراة بطولة`
- `سجّل النتيجة`
- `شارك النتيجة`
- `شارك التشكيلة`
- `استلم بروفايلك`

### Hidden Sections

- Fantasy.
- Activity feed/social feed.
- Challenges as top-level tab.
- Friends as primary nav.
- Audit/disputes unless organizer-only and polished.
- Golden rating.

### Feature Flags Needed

Existing:

- `fantasyUiEnabled` should remain false.
- `activityFeedEnabled` should be false for V1 unless feed is rewritten as tournament highlights.
- `guestIdentityEnabled` should remain true.
- `hybridTournamentRegistrationEnabled` should remain true after QA.
- `matchdayUiEnabled` should remain true after QA.

Recommended new flags:

- `friendlyMatchTopLevelEnabled`
- `challengesUiEnabled`
- `socialUiEnabled`
- `organizerAdvancedOpsEnabled`
- `goldenRatingUiEnabled`
- `publicLeaderboardEnabled`
- `guestStatsEnabled`

## 8. First Implementation Backlog

Limit: 22 tickets.

### 1. Freeze V1 Feature Flags

Priority: P0

Affected files:

- `lib/core/constants/feature_flags.dart`
- `lib/features/home/views/home_screen.dart`
- `lib/features/tournament/views/tournament_list_screen.dart`
- `lib/features/tournament/views/tournament_detail_screen.dart`

Acceptance criteria:

- Fantasy, social feed, challenges top-level, golden rating, and advanced ops are hidden from normal V1 navigation.
- No V1-visible button opens `FeatureUnavailableScreen` for out-of-scope features.

Risk notes:

- Avoid deleting code; use flags/gates only.

### 2. Remove Fantasy From Tournament Create/Detail Surface

Priority: P0

Affected files:

- `lib/features/tournament/views/tournament_list_screen.dart`
- `lib/features/tournament/controllers/tournament_controller.dart`
- `lib/features/tournament/views/tournament_detail_screen.dart`
- `lib/domain/entities/tournament.dart`

Acceptance criteria:

- No visible fantasy switch, badge, or fantasy leaderboard CTA in V1.
- Existing data model remains unchanged.

Risk notes:

- Do not change Firestore schema; set UI default only.

### 3. Make Navigation Tournament-First

Priority: P0

Affected files:

- `lib/features/home/views/home_screen.dart`
- `lib/features/home/bindings/home_binding.dart`
- `lib/app/routes/app_pages.dart`

Acceptance criteria:

- First/default visible area is tournament-first.
- Friendly matches are secondary, not equal to tournaments.
- Bottom tabs match approved V1 structure.

Risk notes:

- Keep existing routes working for deep links.

### 4. Arabic-Polish Tournament Operations Labels

Priority: P0

Affected files:

- `lib/features/tournament/views/tournament_operations_screens.dart`
- `lib/features/tournament/controllers/tournament_operations_controller.dart`

Acceptance criteria:

- No English labels in V1 tournament ops screens.
- Organizer actions use Arabic user-facing labels.
- Advanced/maintenance tools are gated.

Risk notes:

- High surface area; keep text-only and visibility changes first.

### 5. Define Guest-Aware Stat Identity

Priority: P0

Affected files:

- `lib/domain/entities/player_match_stats.dart`
- `lib/data/models/player_match_stats_model.dart`
- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/core/services/match_settlement_service.dart`

Acceptance criteria:

- A match stat can identify registered player, guest player, or temporary match-side player.
- Existing registered stat behavior remains compatible.
- No Firestore collection name change.

Risk notes:

- Requires careful model migration/backward compatibility.

### 6. Tournament Top Scorers Data Source

Priority: P0

Affected files:

- `lib/core/services/match_settlement_service.dart`
- `lib/data/repositories/match_repository_impl.dart`
- `lib/domain/repositories/match_repository.dart`

Acceptance criteria:

- V1 can query top scorers for a tournament using existing match stats/event data.
- Guest and registered players can appear with display names.

Risk notes:

- Avoid denormalized schema unless explicitly approved.

### 7. Public Leaderboard Route

Priority: P0

Affected files:

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- New or existing leaderboard feature files.

Acceptance criteria:

- `/leaderboard` route is registered or route constant removed from visible use.
- Shows V1-safe standings/top scorers/MVP/rating as approved.

Risk notes:

- Need product decision: global vs tournament-scoped default.

### 8. Public Player Profile Route

Priority: P0

Affected files:

- `lib/app/routes/app_pages.dart`
- `lib/features/profile/**`
- `lib/data/repositories/player_repository_impl.dart`

Acceptance criteria:

- `/player/:id` opens a read-only player profile.
- Claimed guest identity can resolve to player profile.
- No dead actions.

Risk notes:

- Privacy rules need review before exposing too much.

### 9. Claim-Later Stats Continuity QA/Fix

Priority: P0

Affected files:

- `lib/core/services/guest_claim_service.dart`
- `lib/core/services/share_link_service.dart`
- `lib/domain/entities/guest_player.dart`
- stat model/service files from ticket 5.

Acceptance criteria:

- Guest player can score in a tournament and later claim without losing display/stat association.
- Claim flow documents conflict behavior.

Risk notes:

- Current claim links identity but not match stats.

### 10. Tournament Result Share Entry Points

Priority: P1

Affected files:

- `lib/features/tournament/views/tournament_operations_screens.dart`
- `lib/features/lineup/views/match_result_lineup_screen.dart`
- `lib/features/shareables/**`

Acceptance criteria:

- Settled tournament fixtures expose a clear Arabic `شارك النتيجة` CTA.
- Result card includes real tournament name when available.

Risk notes:

- Avoid inferring tournament names from flags.

### 11. Tournament Lineup Entry Points

Priority: P1

Affected files:

- `lib/features/tournament/views/tournament_operations_screens.dart`
- `lib/features/match/views/matchday_screen.dart`
- `lib/features/lineup/**`

Acceptance criteria:

- Fixture/matchday gives organizer/team manager an obvious lineup path.
- Lineup remains optional.

Risk notes:

- Permissions for guest teams and official teams must be verified.

### 12. Hide Activity Feed From V1 Home

Priority: P1

Affected files:

- `lib/core/constants/feature_flags.dart`
- `lib/features/social/widgets/activity_feed_widget.dart`
- `lib/features/home/views/home_screen.dart`

Acceptance criteria:

- Home has no advanced social feed in V1.
- No empty feed prompt asks users to add friends.

Risk notes:

- Keep service/tests intact.

### 13. Replace Profile Dead Actions

Priority: P1

Affected files:

- `lib/features/profile/views/profile_screen.dart`
- `lib/features/profile/controllers/profile_controller.dart`

Acceptance criteria:

- Settings/share/friends buttons either work or are hidden.
- No `قريباً` snackbar in V1 profile.

Risk notes:

- Keep auth/sign-out intact.

### 14. Tournament Assistant Permission Audit

Priority: P1

Affected files:

- `lib/core/services/tournament_permission_service.dart`
- `lib/core/services/match_settlement_service.dart`
- `firestore.rules`
- `lib/features/tournament/controllers/tournament_assistants_controller.dart`

Acceptance criteria:

- Assistants can/cannot edit results exactly as product decides.
- Firestore rules align with service-level permission checks.

Risk notes:

- Rules are not currently first deployment blocker, but mismatch can break production.

### 15. V1 Firestore Rules Review

Priority: P1

Affected files:

- `firestore.rules`
- `lib/core/constants/firebase_paths.dart`

Acceptance criteria:

- Rules cover guest players, guest teams, claim codes, match stats, tournament ops, fan voting.
- No V1 route requires denied writes in normal flow.

Risk notes:

- Do not deploy rules in this ticket unless explicitly requested.

### 16. Score Submit Guest UX

Priority: P1

Affected files:

- `lib/features/match/views/score_submit_screen.dart`
- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/core/services/official_match_roster_service.dart`

Acceptance criteria:

- Score submit can attribute scorers/MVP to all V1-eligible participants.
- Registered-only limitation is removed or clearly scoped by product.

Risk notes:

- Depends on guest-aware stat identity.

### 17. Tournament Detail V1 Layout

Priority: P1

Affected files:

- `lib/features/tournament/views/tournament_detail_screen.dart`
- `lib/features/tournament/controllers/tournament_detail_controller.dart`

Acceptance criteria:

- Tournament detail emphasizes teams, fixtures, standings, top players, results, share.
- Organizer panel is clear and Arabic.

Risk notes:

- Avoid adding unbuilt fake sections.

### 18. Shareable Tournament/Player Cards

Priority: P1

Affected files:

- `lib/features/shareables/**`
- `lib/features/tournament/**`
- `lib/features/profile/**`

Acceptance criteria:

- V1 can share at least result and lineup cards; optional top scorer/player card if data exists.
- Share CTAs are visible and textual, not hidden behind tiny icons only.

Risk notes:

- Requires design/product decision for card types.

### 19. Challenge Surface Gate

Priority: P2

Affected files:

- `lib/features/match/views/match_discover_screen.dart`
- `lib/features/match/controllers/challenge_controller.dart`
- `lib/core/constants/feature_flags.dart`

Acceptance criteria:

- Challenges are not top-level in V1 unless explicitly enabled.
- Existing challenge routes/controllers remain intact.

Risk notes:

- Hidden retention loop can return after V1.

### 20. Audit/Dispute Surface Gate

Priority: P2

Affected files:

- `lib/app/routes/app_pages.dart`
- `lib/features/organizer/**`
- `lib/core/constants/feature_flags.dart`

Acceptance criteria:

- Audit/dispute screens are not visible to normal V1 users.
- Organizer-only deep links still work if product wants them.

Risk notes:

- Do not remove services/tests.

### 21. Friendly Match Secondary Placement

Priority: P2

Affected files:

- `lib/features/home/views/home_screen.dart`
- `lib/features/match/views/match_discover_screen.dart`

Acceptance criteria:

- Friendly match create/discover remains available but secondary to tournaments.
- Temporary player support remains intact.

Risk notes:

- Preserve retention loop for after tournaments.

### 22. V1 QA Matrix

Priority: P1

Affected files:

- `docs/qa/**`
- Existing tests under `test/**`

Acceptance criteria:

- QA checklist covers tournament create, guest team, registration, fixtures, matchday, score, MVP, standings, share cards, claim profile.
- Includes tests to run: `flutter pub get`, `dart analyze lib/`, `flutter test`.

Risk notes:

- No code behavior change; documentation/test planning only.

## 9. Relevant Tests Found

Tournament:

- `test/core/services/tournament_fixture_service_test.dart`
- `test/core/services/tournament_lifecycle_service_test.dart`
- `test/core/services/tournament_participant_service_test.dart`
- `test/core/services/tournament_registration_service_test.dart`
- `test/features/tournament/tournament_operations_dashboard_test.dart`
- `test/features/tournament/tournament_registration_screen_test.dart`

Match/results:

- `test/core/services/match_settlement_service_test.dart`
- `test/core/services/matchday_service_test.dart`
- `test/data/models/match_model_test.dart`
- `test/data/repositories/match_repository_impl_test.dart`
- `test/data/repositories/match_attendance_repository_impl_test.dart`
- `test/data/repositories/match_check_in_repository_impl_test.dart`
- `test/data/repositories/match_lineup_snapshot_repository_impl_test.dart`
- `test/data/repositories/match_substitution_repository_impl_test.dart`
- `test/features/match/matchday_screen_test.dart`

Teams/guests/claim:

- `test/core/services/team_roster_service_test.dart`
- `test/core/services/team_formation_service_test.dart`
- `test/core/services/team_invite_service_test.dart`
- `test/core/services/guest_claim_service_test.dart`
- `test/core/services/guest_team_roster_service_test.dart`
- `test/data/repositories/guest_player_repository_impl_test.dart`
- `test/data/repositories/guest_team_repository_impl_test.dart`
- `test/features/guest_claim/guest_claim_screen_test.dart`
- `test/features/guest_claim/team_invite_entry_screen_test.dart`
- `test/features/team/team_roster_screen_test.dart`

Lineup/share:

- `test/core/lineup/formation_core_test.dart`
- `test/core/services/share_link_service_test.dart`
- `test/features/lineup/lineup_drag_targets_test.dart`

Fantasy/social/ranking related:

- `test/features/fantasy/**`
- `test/core/services/activity_feed_service_test.dart`
- `test/core/services/fan_voting_service_test.dart`
- `test/core/services/username_service_test.dart`

## 10. Audit Notes

- No tests or analyzers were run for this audit because the task requested a static surface report and no code changes beyond this document.
- Existing unrelated worktree changes were present before this audit; this task only added `docs/V1_RELEASE_SCOPE_AUDIT.md`.
