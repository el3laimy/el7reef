import 'package:get/get.dart';

import '../controllers/score_submit_controller.dart';

class ScoreSubmitBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['matchId'];
    if (matchId == null || matchId.isEmpty) {
      throw StateError('matchId is required for score submission');
    }

    Get.lazyPut<ScoreSubmitController>(
      () => ScoreSubmitController(matchId: matchId),
    );
  }
}
