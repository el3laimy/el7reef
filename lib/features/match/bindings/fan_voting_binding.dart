import 'package:get/get.dart';

import '../../../core/constants/feature_flags.dart';
import '../controllers/fan_voting_controller.dart';

class FanVotingBinding extends Bindings {
  @override
  void dependencies() {
    if (!FeatureFlags.fanVotingEnabled) return;

    final matchId = Get.parameters['matchId'];
    if (matchId == null || matchId.isEmpty) {
      throw StateError('matchId is required for fan voting');
    }

    Get.lazyPut<FanVotingController>(
      () => FanVotingController(matchId: matchId),
    );
  }
}
