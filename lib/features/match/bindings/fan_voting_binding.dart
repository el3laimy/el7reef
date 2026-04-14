import 'package:get/get.dart';

import '../controllers/fan_voting_controller.dart';

class FanVotingBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['matchId'];
    if (matchId == null || matchId.isEmpty) {
      throw StateError('matchId is required for fan voting');
    }

    Get.lazyPut<FanVotingController>(
      () => FanVotingController(matchId: matchId),
    );
  }
}
