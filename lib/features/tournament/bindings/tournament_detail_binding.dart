import 'package:get/get.dart';

import '../controllers/tournament_detail_controller.dart';

class TournamentDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TournamentDetailController>(() => TournamentDetailController());
  }
}
