import 'package:get/get.dart';

import '../controllers/tournament_assistants_controller.dart';

class TournamentAssistantsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TournamentAssistantsController>(
      () => TournamentAssistantsController(),
    );
  }
}
