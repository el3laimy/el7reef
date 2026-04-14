import 'package:get/get.dart';
import '../controllers/tournament_controller.dart';
import '../../team/controllers/team_controller.dart';

class TournamentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TournamentController>(() => TournamentController());
    // مطلوب من TournamentDetailScreen (سطر 354)
    if (!Get.isRegistered<TeamController>()) {
      Get.lazyPut<TeamController>(() => TeamController());
    }
  }
}
