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
import '../../features/match/views/match_discover_screen.dart';
import '../../features/match/views/score_submit_screen.dart';
import '../../features/match/views/fan_voting_screen.dart';
import '../../features/match/bindings/match_binding.dart';
import '../../features/match/bindings/score_submit_binding.dart';
import '../../features/match/bindings/fan_voting_binding.dart';
import '../../features/tournament/views/tournament_list_screen.dart';
import '../../features/tournament/views/tournament_detail_screen.dart';
import '../../features/tournament/views/tournament_assistants_screen.dart';
import '../../features/tournament/bindings/tournament_binding.dart';
import '../../features/tournament/bindings/tournament_detail_binding.dart';
import '../../features/tournament/bindings/tournament_assistants_binding.dart';
import '../../features/social/views/username_screen.dart';
import '../../features/social/views/qr_scanner_screen.dart';
import '../../features/social/views/friends_screen.dart';
import '../../features/social/views/search_players_screen.dart';
import '../../features/social/bindings/friend_binding.dart';
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

    // ── Tournament Assistants ──
    GetPage(
      name: AppRoutes.organizerDashboard,
      page: () => const TournamentAssistantsScreen(),
      binding: TournamentAssistantsBinding(),
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
