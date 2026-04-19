import 'package:get/get.dart';

import '../../../core/enums/audit_action.dart';
import '../controllers/audit_timeline_controller.dart';

class AuditTimelineBinding extends Bindings {
  @override
  void dependencies() {
    final entityId = Get.parameters['entityId'] ?? '';
    final entityTypeName = Get.parameters['entityType'] ?? 'match';
    final entityType = AuditEntityType.values.firstWhere(
      (value) => value.name == entityTypeName,
      orElse: () => AuditEntityType.match,
    );
    Get.lazyPut<AuditTimelineController>(
      () => AuditTimelineController(
        entityId: entityId,
        entityType: entityType,
      ),
    );
  }
}
