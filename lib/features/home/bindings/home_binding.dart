import 'package:get/get.dart';
import '../../../features/profile/controllers/profile_controller.dart';
import '../../../features/team/controllers/team_controller.dart';
import '../../../features/match/controllers/match_controller.dart';
import '../../../features/tournament/controllers/tournament_controller.dart';
import '../../../features/social/controllers/activity_feed_controller.dart';

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
  }
}
