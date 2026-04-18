import 'package:get/get.dart';

import '../controllers/dispute_viewer_controller.dart';

class DisputeViewerBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['matchId'] ?? '';
    Get.lazyPut<DisputeViewerController>(
      () => DisputeViewerController(matchId: matchId),
    );
  }
}
