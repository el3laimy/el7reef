import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../../core/constants/feature_flags.dart';
import '../../core/widgets/feature_unavailable_screen.dart';
import '../../features/splash/views/splash_screen.dart';
import '../../features/splash/bindings/splash_binding.dart';
import '../../features/auth/views/onboarding_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/bindings/auth_binding.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/home/bindings/home_binding.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/profile/bindings/profile_binding.dart';
import '../../features/team/views/my_teams_screen.dart';
import '../../features/team/bindings/team_binding.dart';
import '../../features/team/views/team_roster_screen.dart';
import '../../features/team/bindings/team_roster_binding.dart';
import '../../features/match/views/match_discover_screen.dart';
import '../../features/match/views/matchday_screen.dart';
import '../../features/match/views/score_submit_screen.dart';
import '../../features/match/views/fan_voting_screen.dart';
import '../../features/match/views/match_lobby_screen.dart';
import '../../features/match/bindings/match_binding.dart';
import '../../features/match/bindings/matchday_binding.dart';
import '../../features/match/bindings/score_submit_binding.dart';
import '../../features/match/bindings/fan_voting_binding.dart';
import '../../features/match/bindings/match_lobby_binding.dart';
import '../../features/tournament/views/tournament_list_screen.dart';
import '../../features/tournament/views/tournament_detail_screen.dart';
import '../../features/tournament/views/tournament_registration_screen.dart';
import '../../features/tournament/views/tournament_guest_team_create_screen.dart';
import '../../features/tournament/views/tournament_registration_review_screen.dart';
import '../../features/tournament/views/tournament_assistants_screen.dart';
import '../../features/tournament/views/tournament_operations_screens.dart';
import '../../features/tournament/bindings/tournament_binding.dart';
import '../../features/tournament/bindings/tournament_detail_binding.dart';
import '../../features/tournament/bindings/tournament_registration_binding.dart';
import '../../features/tournament/bindings/tournament_guest_team_create_binding.dart';
import '../../features/tournament/bindings/tournament_registration_review_binding.dart';
import '../../features/tournament/bindings/tournament_assistants_binding.dart';
import '../../features/tournament/bindings/tournament_operations_binding.dart';
import '../../features/social/views/username_screen.dart';
import '../../features/social/views/qr_scanner_screen.dart';
import '../../features/social/views/friends_screen.dart';
import '../../features/social/views/search_players_screen.dart';
import '../../features/social/bindings/friend_binding.dart';
import '../../features/guest_claim/bindings/claim_entry_binding.dart';
import '../../features/guest_claim/bindings/guest_player_claim_binding.dart';
import '../../features/guest_claim/bindings/guest_team_claim_binding.dart';
import '../../features/guest_claim/bindings/team_invite_entry_binding.dart';
import '../../features/guest_claim/views/claim_entry_screen.dart';
import '../../features/guest_claim/views/guest_player_claim_screen.dart';
import '../../features/guest_claim/views/guest_team_claim_screen.dart';
import '../../features/guest_claim/views/team_invite_entry_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_league_list_screen.dart';
import '../../features/fantasy/presentation/screens/create_fantasy_team_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_team_screen.dart';
import '../../features/fantasy/presentation/screens/transfer_market_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_leaderboard_screen.dart';
import '../../features/fantasy/presentation/bindings/fantasy_home_binding.dart';
import '../../features/fantasy/presentation/bindings/fantasy_create_team_binding.dart';
import '../../features/fantasy/presentation/bindings/fantasy_team_binding.dart';
import '../../features/fantasy/presentation/bindings/transfer_market_binding.dart';
import '../../features/fantasy/presentation/bindings/fantasy_leaderboard_binding.dart';
import '../../features/organizer/views/audit_timeline_screen.dart';
import '../../features/organizer/views/dispute_viewer_screen.dart';
import '../../features/organizer/bindings/audit_timeline_binding.dart';
import '../../features/organizer/bindings/dispute_viewer_binding.dart';

/// GetX Page Route Definitions — جميع الشاشات مسجلة
class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = <GetPage>[
    // ══════════════════════════════════════════
    // Phase 1–2: Core Navigation
    // ══════════════════════════════════════════

    // ── Splash ──
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
    ),

    // ── Onboarding ──
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 500),
    ),

    // ── Login (Google Sign-In) ──
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
    ),

    // ── Home (5-tab hub) ──
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
    ),

    // ══════════════════════════════════════════
    // Phase 3: Profile & Teams
    // ══════════════════════════════════════════

    // ── Profile ──
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileScreen(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── My Teams ──
    GetPage(
      name: AppRoutes.myTeams,
      page: () => const MyTeamsScreen(),
      binding: TeamBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Team Roster / Team Profile ──
    GetPage(
      name: AppRoutes.teamProfile,
      page: () => const TeamRosterScreen(),
      binding: TeamRosterBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ══════════════════════════════════════════
    // Phase 4: Matches
    // ══════════════════════════════════════════

    // ── Match Discovery ──
    GetPage(
      name: AppRoutes.findMatch,
      page: () => const MatchDiscoverScreen(),
      binding: MatchBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Match Lobby ──
    GetPage(
      name: AppRoutes.matchLobby,
      page: () => const MatchLobbyScreen(),
      binding: MatchLobbyBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Matchday Operations ──
    GetPage(
      name: AppRoutes.matchDetails,
      page: () => FeatureFlags.matchdayUiEnabled
          ? const MatchdayScreen()
          : const FeatureUnavailableScreen(
              title: 'يوم المباراة غير متاح',
              message:
                  'واجهة الحضور والتشكيل والتبديلات ما زالت متوقفة في هذا البناء.',
            ),
      binding: MatchdayBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Score Submission ──
    GetPage(
      name: AppRoutes.scoreApproval,
      page: () => const ScoreSubmitScreen(),
      binding: ScoreSubmitBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fan Voting ──
    GetPage(
      name: AppRoutes.mvpVote,
      page: () => const FanVotingScreen(),
      binding: FanVotingBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ══════════════════════════════════════════
    // Phase 5: Tournaments
    // ══════════════════════════════════════════

    // ── Tournament List ──
    GetPage(
      name: AppRoutes.tournamentList,
      page: () => const TournamentListScreen(),
      binding: TournamentBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament List (alias — مُستخدم في QR Scanner) ──
    GetPage(
      name: AppRoutes.tournaments,
      page: () => const TournamentListScreen(),
      binding: TournamentBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament Detail (FIX-05: safe casting) ──
    GetPage(
      name: AppRoutes.tournamentDetail,
      page: () => const TournamentDetailScreen(),
      binding: TournamentDetailBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentParticipants,
      page: () => const TournamentParticipantsScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentGroups,
      page: () => const TournamentGroupsScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentFixtures,
      page: () => const TournamentFixturesScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentStandings,
      page: () => const TournamentStandingsScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentBracket,
      page: () => const TournamentBracketScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament Registration Hub ──
    GetPage(
      name: AppRoutes.teamRegistration,
      page: () => FeatureFlags.hybridTournamentRegistrationEnabled
          ? const TournamentRegistrationScreen()
          : const FeatureUnavailableScreen(
              title: 'تسجيل البطولة غير متاح',
              message:
                  'واجهات التسجيل الهجين ما زالت متوقفة في هذا البناء حتى يتم تفعيلها بشكل كامل.',
            ),
      binding: TournamentRegistrationBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Create Guest Team For Tournament ──
    GetPage(
      name: AppRoutes.tournamentGuestTeamCreate,
      page: () => FeatureFlags.hybridTournamentRegistrationEnabled
          ? const TournamentGuestTeamCreateScreen()
          : const FeatureUnavailableScreen(
              title: 'إنشاء فريق ضيف غير متاح',
              message:
                  'هذه الشاشة تعتمد على تدفقات التسجيل الهجين التي ما زالت غير مفعلة في هذا البناء.',
            ),
      binding: TournamentGuestTeamCreateBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament Registration Review ──
    GetPage(
      name: AppRoutes.tournamentRegistrationReview,
      page: () => FeatureFlags.hybridTournamentRegistrationEnabled
          ? const TournamentRegistrationReviewScreen()
          : const FeatureUnavailableScreen(
              title: 'مراجعة التسجيل غير متاحة',
              message:
                  'تم إيقاف واجهة مراجعة التسجيلات مؤقتًا لحين تفعيل التسجيل الهجين بالكامل.',
            ),
      binding: TournamentRegistrationReviewBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament Assistants ──
    GetPage(
      name: AppRoutes.organizerDashboard,
      page: () => const TournamentOperationsDashboardScreen(),
      binding: TournamentOperationsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    GetPage(
      name: AppRoutes.tournamentAssistants,
      page: () => const TournamentAssistantsScreen(),
      binding: TournamentAssistantsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ══════════════════════════════════════════
    // Phase 7: Audit & Disputes
    // ══════════════════════════════════════════

    // ── Audit Timeline ──
    GetPage(
      name: AppRoutes.auditTimeline,
      page: () => const AuditTimelineScreen(),
      binding: AuditTimelineBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Dispute Viewer ──
    GetPage(
      name: AppRoutes.disputeViewer,
      page: () => const DisputeViewerScreen(),
      binding: DisputeViewerBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ══════════════════════════════════════════
    // Phase 6: Social & Identity
    // ══════════════════════════════════════════

    // ── Username Selection ──
    GetPage(
      name: AppRoutes.username,
      page: () => const UsernameScreen(),
      binding: ProfileBinding(),
      transition: Transition.downToUp,
    ),

    // ── QR Scanner ──
    GetPage(
      name: AppRoutes.qrScanner,
      page: () => const QrScannerScreen(),
      transition: Transition.downToUp,
    ),

    // ── Friends ──
    GetPage(
      name: AppRoutes.friends,
      page: () => const FriendsScreen(),
      binding: FriendBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Search Players ──
    GetPage(
      name: AppRoutes.searchPlayers,
      page: () => const SearchPlayersScreen(),
      binding: FriendBinding(),
      transition: Transition.fadeIn,
    ),

    // ── Generic Claim Entry (deep link / QR landing) ──
    GetPage(
      name: AppRoutes.claimEntry,
      page: () => FeatureFlags.guestIdentityEnabled
          ? const ClaimEntryScreen()
          : const FeatureUnavailableScreen(
              title: 'خاصية الـ claim غير متاحة',
              message:
                  'تم إيقاف شاشات استلام اللاعبين والفرق الضيوف مؤقتًا في هذا البناء.',
            ),
      binding: ClaimEntryBinding(),
    ),

    // ── Generic Invite Entry (deep link / QR landing) ──
    GetPage(
      name: AppRoutes.inviteEntry,
      page: () => const TeamInviteEntryScreen(),
      binding: TeamInviteEntryBinding(),
    ),

    // ── Guest Player Claim ──
    GetPage(
      name: AppRoutes.guestPlayerClaim,
      page: () => FeatureFlags.guestIdentityEnabled
          ? const GuestPlayerClaimScreen()
          : const FeatureUnavailableScreen(
              title: 'استلام اللاعب غير متاح',
              message:
                  'شاشات استلام اللاعبين الضيوف ما زالت غير مفعلة في هذا البناء.',
            ),
      binding: GuestPlayerClaimBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Guest Team Claim ──
    GetPage(
      name: AppRoutes.guestTeamClaim,
      page: () => FeatureFlags.guestIdentityEnabled
          ? const GuestTeamClaimScreen()
          : const FeatureUnavailableScreen(
              title: 'استلام الفريق غير متاح',
              message:
                  'شاشات استلام الفرق الضيوف ما زالت غير مفعلة في هذا البناء.',
            ),
      binding: GuestTeamClaimBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ══════════════════════════════════════════
    // Phase 8: Fantasy League
    // ══════════════════════════════════════════

    // ── Fantasy League List ──
    GetPage(
      name: AppRoutes.fantasyHome,
      page: () => FeatureFlags.fantasyUiEnabled
          ? const FantasyLeagueListScreen()
          : const FeatureUnavailableScreen(
              title: 'الفانتازي غير متاح حالياً',
              message:
                  'واجهات الفانتازي ما زالت قيد الإنهاء، لذلك تم إخفاؤها مؤقتاً لحين ربطها بالكامل بالـ backend.',
            ),
      binding: FantasyHomeBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Create Fantasy Team ──
    GetPage(
      name: AppRoutes.fantasyPickTeam,
      page: () {
        final leagueId = Get.parameters['leagueId'];
        if (!FeatureFlags.fantasyUiEnabled) {
          return const FeatureUnavailableScreen(
            title: 'إنشاء فريق فانتازي غير متاح',
            message:
                'تم إيقاف هذه الواجهة مؤقتاً حتى يكتمل ربط سوق اللاعبين والتشكيلة وعمليات الحفظ.',
          );
        }
        if (leagueId == null || leagueId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تحديد الدوري')),
          );
        }
        return const CreateFantasyTeamScreen();
      },
      binding: FantasyCreateTeamBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fantasy Team ──
    GetPage(
      name: AppRoutes.fantasyTeam,
      page: () {
        final leagueId = Get.parameters['leagueId'];
        if (!FeatureFlags.fantasyUiEnabled) {
          return const FeatureUnavailableScreen(
            title: 'إدارة الفريق غير متاحة',
            message:
                'إدارة فريق الفانتازي ما زالت غير مفعلة في هذا البناء مؤقتاً.',
          );
        }
        if (leagueId == null || leagueId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تحديد الدوري')),
          );
        }
        return const FantasyTeamScreen();
      },
      binding: FantasyTeamBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fantasy Transfers ──
    GetPage(
      name: AppRoutes.fantasyTransfers,
      page: () {
        final leagueId = Get.parameters['leagueId'];
        if (!FeatureFlags.fantasyUiEnabled) {
          return const FeatureUnavailableScreen(
            title: 'الانتقالات غير متاحة',
            message:
                'سوق انتقالات الفانتازي ما زال قيد التفعيل الكامل في هذا البناء.',
          );
        }
        if (leagueId == null || leagueId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تحديد الدوري')),
          );
        }
        return const TransferMarketScreen();
      },
      binding: TransferMarketBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fantasy Leaderboard ──
    GetPage(
      name: AppRoutes.fantasyLeaderboard,
      page: () {
        final leagueId = Get.parameters['leagueId'];
        if (!FeatureFlags.fantasyUiEnabled) {
          return const FeatureUnavailableScreen(
            title: 'ترتيب الفانتازي غير متاح',
            message:
                'سيعود هذا القسم بمجرد اكتمال تدفقات الفانتازي وبيانات الجولات الحقيقية.',
          );
        }
        if (leagueId == null || leagueId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تحديد الدوري')),
          );
        }
        return const FantasyLeaderboardScreen();
      },
      binding: FantasyLeaderboardBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
  ];
}
