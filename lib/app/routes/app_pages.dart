import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'app_routes.dart';
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
import '../../features/tournament/views/tournament_list_screen.dart';
import '../../features/tournament/views/tournament_detail_screen.dart';
import '../../features/tournament/views/tournament_assistants_screen.dart';
import '../../features/tournament/bindings/tournament_binding.dart';
import '../../features/social/views/username_screen.dart';
import '../../features/social/views/qr_scanner_screen.dart';
import '../../features/social/views/friends_screen.dart';
import '../../features/social/views/search_players_screen.dart';
import '../../features/social/bindings/friend_binding.dart';
import '../../features/fantasy/presentation/screens/fantasy_league_list_screen.dart';
import '../../features/fantasy/presentation/screens/create_fantasy_team_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_leaderboard_screen.dart';
import '../../domain/entities/tournament.dart';

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
      binding: MatchBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fan Voting ──
    GetPage(
      name: AppRoutes.mvpVote,
      page: () => const FanVotingScreen(),
      binding: MatchBinding(),
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
      page: () {
        final args = Get.arguments;
        if (args is! Tournament) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تحديد الدورة')),
          );
        }
        return TournamentDetailScreen(tournament: args);
      },
      binding: TournamentBinding(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Tournament Assistants ──
    GetPage(
      name: AppRoutes.organizerDashboard,
      page: () => const TournamentAssistantsScreen(),
      binding: TournamentBinding(),
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
      page: () => const FantasyLeagueListScreen(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Create Fantasy Team ──
    GetPage(
      name: AppRoutes.fantasyPickTeam,
      page: () => const CreateFantasyTeamScreen(),
      transition: Transition.rightToLeftWithFade,
    ),

    // ── Fantasy Leaderboard ──
    GetPage(
      name: AppRoutes.fantasyLeaderboard,
      page: () => const FantasyLeaderboardScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
  ];
}

