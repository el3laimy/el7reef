# Master Blueprint vs Current Code Gap Audit

Audit date: 2026-05-07  
Scope: non-implementation audit only. No production code, tests, or Firestore rules were changed.

Primary reference inspected at the time: the retired master blueprint recorded in `docs/archive/PLANNING_RETIREMENT_MANIFEST.md`, plus the retained V1 scope, lifecycle/scheduling, and role/permission references. Current execution authority is `docs/core/00_Master_Product_Development_Plan.md`.

## 1. Executive summary

Release decision: do not release the Tournament Ego MVP as-is.

The codebase has a meaningful tournament core: organizers can create tournaments, guest teams and guest players exist, tournament participants support registered and guest team sources, MatchEvent supports registered, guest, and match-side player identities, and group standings are based on settled official matches. That is the good news.

The release blocker is that the production permission and UX contract does not yet match the Master Blueprint. The current app mixes public tournament detail with operations/admin surfaces, exposes advanced group/knockout operations, leaves core admin services without service-layer actor checks, and lacks Firestore rules for several canonical tournament-operation collections. The current score submission UI still assumes registered-player stats for tournament score entry and still displays the old "temporary players do not get stats" message.

Focus-question verdicts:

| Question | Verdict | Risk |
|---|---|---|
| Can an organizer run a complete tournament with only guest/manual teams and guest players? | Not release-grade. Data/service pieces exist, but the live score UI and match-start path still contain registered-player/lineup assumptions. | P0 |
| Are public tournament views separated from organizer/admin operations? | No. Public detail links all users into operations screens. | P0 |
| Can account B see account A tournament only as public read-only? | Account B's owned list is filtered, but B can open account A's operations surfaces and see admin-shaped state. Some actions are blocked later, but route/surface separation is not clear. | P0 |
| Does scheduling satisfy V1? | Partial. `roundIndex`, `slotNumber`, `scheduledAt`, `publishedAt`, and `fixtureStatus` exist, but publish rules and conflict checks are missing. | P1 |
| Does every admin action have UI, controller/service, rules, and tests? | No. Multiple service guards and rules emulator tests are missing; some UI guards are inconsistent. | P0 |
| Are assistants active or deferred? | Active in models/routes/services despite V1 single-organizer expectations. | P1 |
| Are groups/knockout exposed or hidden? | Exposed and defaulted. | P1 |
| Are standings/top scorers official-only? | Standings are official-only; top scorers aggregate active MatchEvents without checking match approval/settlement. | P1 |
| Are session/account-switch safeguards enough? | Partial. Global/home controllers reset, but route-bound admin/match controllers are not covered by end-to-end A/B isolation tests. | P1 |
| What areas violate the blueprint? | Firestore rules, operations navigation, score submission UI, scheduling services, lifecycle services, assistant roles, and rules tests. | P0/P1 |

## 2. What already matches the Master Blueprint

- Tournament ownership is modeled with `organizerId` in `lib/domain/entities/tournament.dart`, and organizer lists are filtered by `organizerId` in `TournamentRepositoryImpl.getOrganizerTournaments`.
- Fantasy UI is globally gated off through `FeatureFlags.fantasyUiEnabled = false` in `lib/core/constants/feature_flags.dart`, and tournament detail also gates fantasy navigation behind that flag.
- Guest identity exists across the stack: `guestTeams`, `guestPlayers`, guest team roster services, guest claim services, and `TournamentParticipantSourceType.guestTeam`.
- `ParticipantRef` and `MatchEvent` support `player`, `guestPlayer`, and `matchSidePlayer` identities. `MatchEventService` writes goals and MVP with embedded participant refs, and tests cover guest goal/MVP events.
- Tournament participants support registered and guest team sources in `TournamentParticipantService.addManualParticipant`.
- Group standings are recalculated from official tournament results: `GroupStageBuilder.recalculateSnapshot` filters `match.isOfficialTournamentResult`, and `Match.isOfficialTournamentResult` requires `MatchStatus.settled` plus scores.
- Score approval has a service guard in `MatchSettlementService._assertCanManageScore`.
- Claim-code rules are much stronger than most other rules: exact-code gets are allowed for authenticated users, broad listing is denied, creator-scoped reuse queries are tested, and unauthorized claim-code creates/updates are denied.
- Session reset infrastructure exists: `SessionResetCoordinator`, `AuthService` UID-change handling, and `HomeBinding` reset callbacks cover the main home-level controllers.
- Result sharing appears at a pride moment: `ScoreSubmitScreen` opens a result-success sheet with a share result action after submission.

## 3. What partially matches but is risky

- Guest-only tournament support is partly real but not end-to-end safe. Backend pieces can represent guest teams and guest players, and controller tests prove guest MatchEvents can be written, but the user-facing score screen does not expose guest scorer/MVP controls for tournament matches.
- Public vs managed state is partly separated in controller booleans (`canManageTournament`), but not in navigation. Public detail gives all users operations links, and route-level guards are absent.
- Scheduling fields exist, but the semantics do not match the blueprint: `roundIndex`/`slotNumber` are not explicit `roundNumber`/`matchNumber`, `scheduledAt` is nullable at publish time, and no conflict checks exist.
- Permission checks are scattered. Controllers often guard organizer-only actions, some services guard, Firestore rules guard some collections, and tests cover happy paths. The blueprint requires all layers for every admin action.
- Assistants are implemented in entities and permission service, but controller logic often ignores them and Firestore rules often do not allow them. That creates product and permission mismatch.
- Top scorers use the correct MatchEvent source-of-truth shape, but they do not filter by approved/settled matches or label provisional data.
- Rules tests are configured and pass, but they only cover claim codes. They do not prove tournament permission correctness.
- Session resets are strong for registered home controllers, but not proven for direct tournament operations, matchday, score submit, guest claim, and roster routes while an account switch occurs.

## 4. What contradicts the Master Blueprint

- `ScoreSubmitScreen` still displays: `لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.` in `lib/features/match/views/score_submit_screen.dart`. This directly contradicts the blueprint requirement that guest players receive goals, MVP, share-card presence, and leaderboard treatment.
- Tournament score UI calculates tournament scores from registered `Player` stat rows only. `ScoreSubmitController.totalTeamAGoals` and `totalTeamBGoals` sum `teamAPlayers`/`teamBPlayers`, while guest goal drafts are separate pride data written after score submission.
- Public tournament detail exposes operations links to all users through `_OperationsSnapshot` in `lib/features/tournament/views/tournament_detail_screen.dart`.
- Operations routes are registered without route-level ownership guards in `lib/app/routes/app_pages.dart`, including dashboard, participants, groups, fixtures, standings, bracket, assistants, and score approval routes.
- The tournament create flow exposes `TournamentFormat.values` and defaults to `groupsThenKnockout`, while the blueprint says V1 should avoid exposing advanced group+knockout complexity unless its dependency graph and schedule rules are production-ready.
- `TournamentLifecycleService` accepts `actorId` but does not check it for `finalizeParticipants`, `startGroupStage`, `publishFixtures`, `startKnockout`, or `completeTournament`.
- `TournamentParticipantService` accepts `actorId` but does not check it for manual add/withdraw/reactivate/replace/seed operations.
- `TournamentFixtureService.scheduleFixture` accepts `actorId` but does not check organizer/permission and does not enforce scheduling conflicts.
- `MatchEvent` Firestore rules allow any authenticated user to create active goal/MVP events for any `matchId`/`tournamentId` as long as the document shape is valid.
- Firestore rules do not define allow rules for several canonical tournament-operation collections used by the services: `tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, `knockoutTies`, plus temporary side collections such as `matchSides` and `matchSidePlayers`.
- Firestore `tournamentRegistrations` update rules allow the team/guest-team owner to update an existing registration without freezing organizer-owned fields such as status/verification.

Exact code hotspots:

- `firestore.rules:390-410` and `firestore.rules:503-506` - `matchEvents` create validates document shape but not match ownership, side membership, tournament organizer, or match status.
- `firestore.rules:554-560` - `tournamentRegistrations.update` allows team/guest-team owners to update broad registration fields.
- `firestore.rules:740-742` - catch-all deny means canonical tournament operation collections without explicit matches are blocked in production.
- `firestore.rules:574-577` - `organizerActions.create` is open to any authenticated user.
- `lib/features/match/views/score_submit_screen.dart:81-113` - tournament score UI renders registered players only and hides MVP when no registered players exist.
- `lib/features/match/views/score_submit_screen.dart:287-294` - old temporary-player-no-stats message remains visible.
- `lib/features/match/controllers/score_submit_controller.dart:256-262` - tournament scores are summed from registered-player stat maps rather than all participant goal drafts.
- `lib/features/tournament/views/tournament_detail_screen.dart:117-120` and `:588-632` - public detail exposes operations links to all viewers.
- `lib/app/routes/app_pages.dart:258-290`, `:337-347`, and `:215-220` - operations, assistant, dashboard, and score routes are registered without route-level ownership guards.
- `lib/features/tournament/controllers/tournament_controller.dart:35-39`, `:97-114`, and `:139` - tournament create defaults to `groupsThenKnockout` and does not model V1 visibility/scheduling fields.
- `lib/features/tournament/views/tournament_list_screen.dart:350-399` - create sheet exposes every `TournamentFormat`.
- `lib/core/services/tournament_lifecycle_service.dart:73-236`, `:238-316`, and `:508-548` - lifecycle admin methods accept `actorId` but do not enforce actor permission.
- `lib/core/services/tournament_participant_service.dart:160-513` - participant admin methods accept `actorId` but do not enforce actor permission.
- `lib/core/services/tournament_fixture_service.dart:62-100` - scheduling accepts `actorId` without permission/conflict checks.
- `lib/core/services/tournament_fixture_service.dart:116-149` and `:302-322` - start match hard-requires check-in and locked lineup snapshots.
- `lib/core/services/group_stage_builder.dart:158-160` - group fixtures use `roundIndex` as group index rather than true match round ordering.
- `lib/core/services/tournament_top_scorers_resolver.dart:31-39` and `:62-65` - top scorers aggregate active goal events without match approval filtering and exclude `matchSidePlayer`.

## 5. P0 issues blocking any release

1. Core tournament-operation collections have no Firestore rules.

   `firestore.rules` has explicit matches for `tournaments`, `matches`, and `tournamentRegistrations`, then falls through to the deny-all catch-all. It does not allow `tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, `knockoutTies`, `matchSides`, or `matchSidePlayers`. Client-side services write these collections directly, so the real app can fail even though fake-Firestore tests pass.

2. MatchEvents can be forged by any authenticated user.

   `firestore.rules` allows `matchEvents` create through `canCreateMatchEvent`, which validates shape and `createdBy == request.auth.uid` but does not verify the actor can manage the match, belongs to the match side, or that the match is in the correct status. Because top scorers aggregate active MatchEvents by tournament id, account B can pollute account A's tournament pride data.

3. Registration status can be mutated by non-organizer owners at the rules layer.

   `tournamentRegistrations` update allows `canUpdateTournamentRegistration(resource.data)` when the requester owns the registered/guest team. The rule only keeps `tournamentId` stable; it does not restrict status, verified fields, notes, or source fields. That contradicts "organizer approves teams."

4. Guest-only score submission is not available in the production UI.

   The score screen shows only registered player stat rows for tournament matches, hides MVP selection when there are no registered players, and says temporary players do not get stats. Controller tests can manually set guest goal drafts, but the visible UX cannot safely record a guest-only 1-0 tournament result with guest scorer/MVP through the current screen.

5. Public and managed tournament surfaces are not separated.

   Account B can navigate from account A's public detail into operations screens. Tests even codify that a non-organizer sees "read-only operations state." The blueprint requires a public read-only surface and a separate organizer dashboard/admin surface.

6. Service-layer guards are missing on core admin services.

   `TournamentLifecycleService`, `TournamentParticipantService`, and `TournamentFixtureService.scheduleFixture` trust caller/controller guards. The blueprint requires sensitive operations to be guarded in UI, controller/service, Firestore rules/backend, and tests.

## 6. P1 issues blocking V1 completeness

- Scheduling publish rules are incomplete: fixtures can be published without `scheduledAt`, no conflict checks exist, no tournament start/registration close time bounds are enforced, and no venue/court name distinction exists.
- Group/knockout flow is exposed and defaulted before V1 has locked scheduling, dependency, and publish semantics.
- `startMatch` requires verified check-ins and locked lineup snapshots for both sides. The blueprint says lineups are optional and should be nudged, not a hard block.
- Top scorers are based on active MatchEvents, not approved/settled matches, and the UI does not label them provisional before approval.
- `TournamentTopScorersResolver` excludes `matchSidePlayer`, while the blueprint's identity model says stats/share cards should consistently use registered, guest, and match-side player refs where relevant.
- Assistant/co-organizer roles are active in entities, permission service, routes, and some services, but V1 scope says one organizer. Rules and controller behavior are inconsistent with those assistant permissions.
- Score action buttons in fixture operations are selected by match status, not by `canManageTournament`, so non-organizers can see admin-shaped score actions even when later layers block.
- Session/account switching lacks route-level isolation tests for tournament operations, score submission, matchday, guest claim, and roster screens.
- Firestore rules emulator coverage is missing for tournament writes, match writes, score approval, MatchEvents, participant/fixture collections, and account A/B isolation.

## 7. P2 later improvements

- Align tournament statuses with the blueprint lifecycle naming: draft/setup/fixtures/scheduled/in_progress/completed or the lifecycle doc's draft/registration/fixtures_draft/scheduled sequence. Current statuses are `upcoming`, `registration`, `groupStage`, `transferWindow`, `knockoutStage`, `completed`, `cancelled`.
- Add explicit `visibility`, `timezone`, `matchDurationMinutes`, `venueName`, and `courtName` instead of relying on public discovery plus `venueId`.
- Change `Tournament.isFantasyEnabled` default to false or otherwise ensure new V1 tournaments cannot carry fantasy-enabled state by default, even though the UI flag is currently false.
- Replace English operations-dashboard labels with Arabic-first copy and guided organizer language.
- Reduce or clearly hide legacy routes/fields such as `registeredTeamIds` registration helpers once canonical participants are fully protected by rules.
- Add public share-card state labels for official vs provisional stats.

## 8. Tournament ownership/public-vs-managed surface map

| Surface | Current behavior | Blueprint gap | Risk |
|---|---|---|---|
| `TournamentListScreen` | Shows create CTA and live tournaments. Discovery can include other organizers. | Does not clearly separate "my managed tournaments" from public discovery in the same flow. | P1 |
| `TournamentDetailScreen` | Computes `isOrganizer`, shows organizer panel only for owner, but always shows `_OperationsSnapshot`. | Public detail includes operations entry points. | P0 |
| `_OperationsSnapshot` | Links to Participants, Groups, Fixtures, Standings, Bracket for all users. | These are admin/operations surfaces, not a clean public read-only tournament page. | P0 |
| `AppPages` tournament ops routes | Dashboard/participants/groups/fixtures/standings/bracket are direct routes with operations binding. | No route-level ownership guard or public-vs-admin route split. | P0 |
| `TournamentOperationsController` | `canManageTournament` is false for non-organizers and many actions call `_currentTournamentManagerActorId`. | Read-only admin-shaped state still loads; some actions use weaker actor lookup. | P1 |
| Score approval route | Direct route exists for `/organizer/score/:matchId`; service later checks score permission. | Route/UI does not clearly prevent non-admin score operation entry. | P1 |
| Assistants route | Registered as a route and assistant model/service code exists. | Assistant roles are not a V1 public product promise. | P1 |

Decision: current Account B behavior is not "public read-only only." It is "admin dashboard read-only-ish with later action guards." That is not the blueprint.

## 9. Organizer dashboard/navigation gap analysis

The blueprint expects a guided organizer dashboard/wizard: tournament data, teams/participants, system, schedule, results/approval, scorers/MVP/share, and publishing/status.

Current gaps:

- The operations dashboard is technical and partly English: "Tournament Operations Dashboard", "Participants", "Groups", "Fixtures", "Standings", "Bracket", "Assistants", "Manual Add Participant", "Publish Fixtures", and similar labels.
- The dashboard exposes groups, bracket, assistants, regeneration, finalization, publishing, and stage transitions directly rather than guiding the organizer through a simple V1 path.
- The public tournament detail links to the same operations screens, so dashboard navigation is not reserved for organizers.
- Share actions exist after score submit and on top scorers, but pride-card sharing is not consistently surfaced after every core pride moment in the tournament operations path.
- The dashboard uses controller booleans to enable/disable some buttons, but user intent is still ambiguous for non-organizers because they are inside admin screens.

## 10. Guest/manual team/player support audit

What works:

- Guest teams and guest players are real collections/entities.
- Guest team roster management exists in `GuestTeamRosterService`.
- Registered team rosters can include guest players through `TeamRosterService` and `TeamRosterController`.
- `TournamentParticipantService.addManualParticipant` supports `TournamentParticipantSourceType.guestTeam`.
- Tournament registration supports registered and guest teams.
- `OfficialMatchRosterService.loadParticipantRoster` can return guest players as `ParticipantRefKind.guestPlayer`.
- `ScoreSubmitController` can write guest goal and MVP MatchEvents in tests.
- Claim links and claim-code rules exist for guest players/teams.

Blocking gaps:

- The score submit screen does not expose guest participant scoring or MVP selection for tournament matches.
- The score submit screen still tells users temporary players do not get stats.
- Tournament score totals for tournament matches are derived from registered player stat rows, not from guest goal drafts or direct score entry.
- `startMatch` hard-requires check-in and locked lineup snapshots; a guest-only tournament without a formal lineup cannot simply start and record a result.
- `OfficialMatchRosterService.loadRegisteredRoster` and `MatchSettlementService` keep detailed stats/ratings registered-player-only. That may be fine for ratings, but it must not be treated as the tournament stats source of truth.
- `TournamentTopScorersResolver` includes registered and guest players but excludes match-side players; this needs a clear V1 identity decision.

Answer to focus question 1: not yet. The data model is close, but the current user-facing flow does not reliably let one organizer run the full tournament with guest/manual teams and guest players only.

## 11. Scheduling/fixtures gap analysis

Blueprint requirement:

- round/order fields
- `scheduledAt`
- fixture status
- publish rules
- conflict checks

Current implementation:

- `Match` has `roundIndex`, `slotNumber`, `scheduledAt`, `publishedAt`, `venueId`, and `fixtureStatus`.
- `GroupStageBuilder` creates draft fixtures, but `roundIndex` is assigned from the group index, not a true chronological round number.
- `KnockoutBuilder` creates bracket fixtures with round/slot-like fields and placeholder future-round dependencies.
- `TournamentLifecycleService.publishFixtures` sets `fixtureStatus` to published and writes `publishedAt`.
- `TournamentFixtureService.scheduleFixture` updates `scheduledAt` and `venueId`.

Gaps:

- No explicit `roundNumber` and `matchNumber` fields matching the blueprint language.
- No required `scheduledAt` before publish.
- No schedule conflict checks for same team/same time.
- No checks against tournament start, registration close, match duration, venue/court overlap, or rescheduling completed matches except "official result" blocking.
- No publish rule in Firestore for fixture completeness.
- Fixture sorting prefers `scheduledAt ?? createdAt`, not round/order.
- `canPublishFixtures` only checks that fixtures exist and some are not published.
- Rules emulator tests do not cover schedule or publish behavior.

Decision: scheduling is structurally started but not V1-complete.

## 12. Permissions and Firestore rules gap analysis

Guard matrix:

| Admin action | UI guard | Controller/service guard | Firestore rules guard | Tests | Verdict |
|---|---|---|---|---|---|
| Create tournament | Present | Controller sets current user as organizer | `tournaments.create` requires organizerId auth uid | Some repository tests | Partial pass |
| Add manual participant | Mostly UI/controller guarded | Service lacks actor permission check | No rules for `tournamentParticipants` | Fake-Firestore only | P0 |
| Finalize participants | UI/controller guarded | Service lacks actor permission check | No rules for participant writes | Fake-Firestore only | P0 |
| Start group stage | UI/controller guarded | Service lacks actor permission check | No rules for groups/standings/fixtures beyond matches | Fake-Firestore only | P0 |
| Publish fixtures | UI/controller guarded | Service lacks actor permission and publish completeness checks | `matches.update` organizer-only, but no fixture completeness rule | Fake-Firestore only | P1 |
| Schedule fixture | UI/controller guarded | Service lacks actor permission/conflict checks | `matches.update` organizer-only | Fake-Firestore only | P1 |
| Start fixture | UI guard exists | Controller uses weaker actor lookup; service allows assistants | `matches.update` organizer-only, not assistant-aware | Fake-Firestore only | P1 |
| Submit/approve score | UI action visibility is status-based in operations; service guard exists | Service allows assistant result roles | `matches.update` organizer-only, not assistant-aware | Fake-Firestore only | P1 |
| Create MatchEvent goal/MVP | UI/controller uneven | `MatchEventService` has no actor permission check | Any authenticated user can create | No rules emulator tests | P0 |
| Approve/reject registration | UI/service organizer guard | Service checks organizer | Rules allow team/guest owners to update registration docs broadly | Fake-Firestore only | P0 |
| Claim links | UI/service guarded | Service and rules shape checks exist | Rules tested | Emulator tests pass | Pass with residual gaps |

Specific Firestore rules concerns:

- `matchEvents` create lacks match ownership, side membership, status, or tournament approval checks.
- `tournamentRegistrations.update` lets team/guest-team owners update broad fields.
- `organizerActions.create` allows any authenticated user, so audit/organizer action logs can be polluted.
- Core tournament operation collections and temporary match-side collections have no allow rules.
- Rules do not model assistant roles even though services do.
- Rules do not distinguish public read from organizer-managed data. Most reads are simply `isAuthenticated()`.

## 13. Missing rules emulator tests

Configured command: `npm run test:rules:emulator`.

Current rules suite: `test/rules/claim_codes.rules.test.js` only. It passed 7 tests.

Missing emulator coverage:

- Account A/B isolation for tournaments, operations routes, and writes.
- `tournaments` create/update/delete invariants.
- `tournamentRegistrations` create/update approval/status invariants.
- `tournamentParticipants` create/update/delete rules.
- `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, and `knockoutTies`.
- `matches` fixture publish/schedule/start/score approval writes.
- `matchEvents` create/void permissions, including attacker-created goals and MVPs.
- Matchday and temporary side collections: `matchCheckIns`, `matchAttendances`, `matchLineupSnapshots`, `matchSubstitutions`, `matchSides`, and `matchSidePlayers`.
- Guest team roster rules and claim completion flows beyond claim-code listing.
- Assistant-role denial/allowance, or explicit proof assistants are deferred.
- Public read-only tournament access vs managed/admin access.

Important: green fake-Firestore service tests do not exercise Firestore rules.

## 14. Session/account-switch isolation risks

What exists:

- `AuthService` clears current player state on sign-out and UID switch.
- `SessionResetCoordinator` resets registered user-scoped controllers.
- `HomeBinding` registers resets for profile, team, match, tournament, activity feed, and challenge controllers.
- Tests cover several coordinator-level reset cases and tournament controller reload by new UID.

Remaining risks:

- Route-bound controllers such as `TournamentOperationsController`, `TournamentRegistrationController`, `ScoreSubmitController`, `MatchdayController`, `TeamRosterController`, and guest-claim controllers are not proven by tests to reset while their routes remain mounted.
- There is no end-to-end test for account A opening a tournament admin route, switching to account B, and verifying B cannot see stale admin controls or mutate A data.
- Public-vs-managed route ambiguity makes stale state more dangerous because non-organizers can already enter operations-shaped screens.
- Direct route arguments can still point at account A data after a session change; controller refresh often reloads the data and computes `canManageTournament`, but the UI surface remains admin-shaped.

Decision: session handling is improved, but not yet enough to close the blueprint's A/B ownership risk.

## 15. Recommended next implementation sequence, but no code changes

1. P0: Define the V1 public-vs-managed route contract before editing behavior. Public tournament detail should be read-only; organizer dashboard/admin routes should be separate and ownership-guarded.

2. P0: Add rules emulator tests before changing rules. Cover account A/B isolation, tournament/registration/match/matchEvent writes, and all canonical tournament-operation collections.

3. P0: Fix Firestore rules for tournament operations. Add explicit rules for `tournamentParticipants`, `tournamentGroups`, `groupStandingSnapshots`, `knockoutBrackets`, and `knockoutTies`; tighten `matchEvents`; freeze non-organizer registration fields.

4. P0: Add service-layer permission checks to lifecycle, participant, fixture scheduling, and MatchEvent write paths. Keep the controller guards, but do not rely on them.

5. P0: Repair guest-first score submission UX. Remove the old temporary-player message, expose guest scorers/MVP in the actual screen, and make tournament scores work for guest-only teams.

6. P1: Decide assistant roles for V1. Either hide/deactivate them completely or make UI, services, rules, and tests consistently assistant-aware.

7. P1: Lock the V1 scheduling contract. Enforce round/order fields, scheduled time before publish, fixture status transitions, and conflict checks in service/rules/tests.

8. P1: Make top scorers official-only or explicitly provisional. If provisional is shown before approval, the UI and share cards must say so.

9. P1: Hide advanced group+knockout paths until the selected V1 format is fully supported by scheduling, standings, and progression tests.

10. P1: Add account-switch route tests for tournament operations, score submit, matchday, roster, and guest claim screens.

11. P2: Polish Arabic-first organizer UX, lifecycle naming, visibility/timezone fields, and legacy field cleanup after the P0/P1 permission contract is stable.

## Verification commands run

- `dart analyze lib/` - passed, no issues found.
- `flutter test` - passed, 361 tests.
- `npm run test:rules:emulator` - first sandboxed run failed because localhost emulator ports/config-store writes were blocked; rerun with escalated localhost access passed 7 claim-code rules tests.

## Files inspected heavily

- `lib/features/tournament/**`
- `lib/features/organizer/**`
- `lib/features/team/**`
- `lib/features/match/**`
- `lib/features/profile/**`
- `lib/features/guest_claim/**`
- `lib/core/services/**`
- `lib/domain/entities/**`
- `lib/data/repositories/**`
- `firestore.rules`
- `test/**`
- `docs/**`
