import 'package:get/get.dart';

import '../controllers/audit_timeline_controller.dart';

class AuditTimelineBinding extends Bindings {
  @override
  void dependencies() {
    final entityId = Get.parameters['entityId'] ?? '';
    Get.lazyPut<AuditTimelineController>(
      () => AuditTimelineController(entityId: entityId),
    );
  }
}
