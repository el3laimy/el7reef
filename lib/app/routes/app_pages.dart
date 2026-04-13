import 'package:get/get.dart';
import 'app_routes.dart';
import '../../features/splash/views/splash_screen.dart';
import '../../features/splash/bindings/splash_binding.dart';
import '../../features/auth/views/onboarding_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/bindings/auth_binding.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/profile/bindings/profile_binding.dart';
import '../../features/team/views/my_teams_screen.dart';
import '../../features/team/bindings/team_binding.dart';
import '../../features/match/views/match_discover_screen.dart';
import '../../features/match/bindings/match_binding.dart';
import '../../features/tournament/views/tournament_list_screen.dart';
import '../../features/tournament/views/tournament_detail_screen.dart';
import '../../features/tournament/bindings/tournament_binding.dart';
import '../../features/social/views/username_screen.dart';
import '../../features/social/views/qr_scanner_screen.dart';
import '../../features/social/views/friends_screen.dart';
import '../../features/social/views/search_players_screen.dart';
import '../../features/social/bindings/friend_binding.dart';
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

    // ── Tournament Detail (يتطلب Tournament argument) ──
    GetPage(
      name: AppRoutes.tournamentDetail,
      page: () => TournamentDetailScreen(
        tournament: Get.arguments as Tournament,
      ),
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
      binding: FriendBinding(), // Uses SearchPlayersController from FriendBinding
      transition: Transition.fadeIn,
    ),
  ];
}
