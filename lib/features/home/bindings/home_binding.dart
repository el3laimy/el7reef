import 'package:get/get.dart';
import '../../../features/profile/controllers/profile_controller.dart';
import '../../../features/team/controllers/team_controller.dart';
import '../../../features/match/controllers/match_controller.dart';
import '../../../features/tournament/controllers/tournament_controller.dart';
import '../../../features/social/controllers/activity_feed_controller.dart';
import '../../../features/match/controllers/challenge_controller.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../data/repositories/challenge_repository_impl.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../services/auth_service.dart';

/// HomeBinding — يسجل جميع Controllers المطلوبة لشاشة Home
/// بدلاً من تسجيلها يدوياً في HomeScreen.initState()
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ProfileController(), permanent: true);
    Get.put(TeamController(), permanent: true);
    Get.put(MatchController(), permanent: true);
    Get.put(TournamentController(), permanent: true);
    Get.put(ActivityFeedController(), permanent: true);
    if (!Get.isRegistered<ChallengeRepository>()) {
      Get.put<ChallengeRepository>(ChallengeRepositoryImpl(), permanent: true);
    }
    if (!Get.isRegistered<MatchRepository>()) {
      Get.put<MatchRepository>(MatchRepositoryImpl(), permanent: true);
    }
    Get.put(ChallengeController(
      challengeRepo: Get.find<ChallengeRepository>(),
      matchRepo: Get.find<MatchRepository>(),
      authService: Get.find<AuthService>(),
    ), permanent: true);
  }
}
