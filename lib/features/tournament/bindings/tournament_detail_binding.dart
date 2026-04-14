import 'package:get/get.dart';

import '../../team/controllers/team_controller.dart';
import '../controllers/tournament_controller.dart';
import '../controllers/tournament_detail_controller.dart';

class TournamentDetailBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentController>()) {
      Get.lazyPut<TournamentController>(() => TournamentController());
    }
    if (!Get.isRegistered<TeamController>()) {
      Get.lazyPut<TeamController>(() => TeamController());
    }
    Get.lazyPut<TournamentDetailController>(() => TournamentDetailController());
  }
}
