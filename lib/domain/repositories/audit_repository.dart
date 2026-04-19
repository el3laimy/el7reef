import '../../core/enums/audit_action.dart';
import '../entities/audit_event.dart';

/// عقد مستودع سجل التدقيق
abstract class AuditRepository {
  /// إنشاء حدث تدقيق جديد
  Future<void> createAuditEvent(AuditEvent event);

  /// جلب أحداث التدقيق لكيان محدد
  Future<List<AuditEvent>> getEntityAuditEvents({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 50,
  });

  /// جلب أحداث التدقيق حسب نوع الكيان
  Future<List<AuditEvent>> getAuditEventsByType(
    String entityType, {
    int limit = 50,
  });

  /// جلب أحداث التدقيق لممثل محدد (actor)
  Future<List<AuditEvent>> getActorAuditEvents(String actorId, {int limit = 50});
}
