import 'package:uuid/uuid.dart';

import '../errors/app_exceptions.dart';
import '../utils/app_logger.dart';
import 'cloud_sensitive_ops_service.dart';
import '../../core/enums/audit_action.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/repositories/audit_repository.dart';

/// خدمة التدقيق — نقطة واحدة لتسجيل كل العمليات الحساسة
///
/// تُستدعى من الخدمات الأخرى (MatchSettlement, GuestClaim, Fantasy, etc.)
/// لإنشاء سجلات audit موحدة وقابلة للاستعلام.
class AuditService {
  final AuditRepository _repository;
  final Uuid _uuid;
  final CloudSensitiveOpsService _cloudSensitiveOps;

  AuditService({
    required AuditRepository repository,
    Uuid? uuid,
    CloudSensitiveOpsService? cloudSensitiveOps,
  }) : _repository = repository,
       _uuid = uuid ?? const Uuid(),
       _cloudSensitiveOps = cloudSensitiveOps ?? CloudSensitiveOpsService();

  /// تسجيل حدث تدقيق عام
  Future<AuditEvent> record({
    required AuditEntityType entityType,
    required String entityId,
    required AuditAction action,
    required String actorId,
    Map<String, dynamic>? beforePayload,
    Map<String, dynamic>? afterPayload,
    Map<String, dynamic>? metadata,
    DateTime? now,
  }) async {
    final event = AuditEvent(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: metadata,
      createdAt: now ?? DateTime.now(),
    );

    final remoteHandled = await _cloudSensitiveOps.recordAuditEvent(
      _toCloudPayload(event),
    );
    if (remoteHandled) {
      return event;
    }

    try {
      await _repository.createAuditEvent(event);
    } on AppException catch (error) {
      AppLogger.warning('AuditService.record', error);
    } catch (error, stackTrace) {
      AppLogger.warning('AuditService.record', error);
      AppLogger.error('AuditService.record', error, stackTrace);
    }
    return event;
  }

  // ── Convenience Methods ──

  /// تسجيل حدث مباراة
  Future<AuditEvent> recordMatchEvent({
    required String matchId,
    required AuditAction action,
    required String actorId,
    Map<String, dynamic>? beforePayload,
    Map<String, dynamic>? afterPayload,
    Map<String, dynamic>? metadata,
    DateTime? now,
  }) {
    return record(
      entityType: AuditEntityType.match,
      entityId: matchId,
      action: action,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: metadata,
      now: now,
    );
  }

  /// تسجيل حدث بطولة
  Future<AuditEvent> recordTournamentEvent({
    required String tournamentId,
    required AuditAction action,
    required String actorId,
    Map<String, dynamic>? metadata,
    DateTime? now,
  }) {
    return record(
      entityType: AuditEntityType.tournament,
      entityId: tournamentId,
      action: action,
      actorId: actorId,
      metadata: metadata,
      now: now,
    );
  }

  /// تسجيل حدث claim
  Future<AuditEvent> recordClaimEvent({
    required AuditEntityType entityType,
    required String entityId,
    required AuditAction action,
    required String actorId,
    Map<String, dynamic>? beforePayload,
    Map<String, dynamic>? afterPayload,
    DateTime? now,
  }) {
    return record(
      entityType: entityType,
      entityId: entityId,
      action: action,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      now: now,
    );
  }

  /// تسجيل حدث نزاع
  Future<AuditEvent> recordDisputeEvent({
    required String disputeId,
    required AuditAction action,
    required String actorId,
    Map<String, dynamic>? metadata,
    DateTime? now,
  }) {
    return record(
      entityType: AuditEntityType.dispute,
      entityId: disputeId,
      action: action,
      actorId: actorId,
      metadata: metadata,
      now: now,
    );
  }

  // ── Query Methods ──

  /// جلب سجل تدقيق كيان محدد
  Future<List<AuditEvent>> getEntityTimeline({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 50,
  }) {
    return _repository.getEntityAuditEvents(
      entityType: entityType,
      entityId: entityId,
      limit: limit,
    );
  }

  /// جلب سجل تدقيق ممثل (actor) محدد
  Future<List<AuditEvent>> getActorHistory(String actorId, {int limit = 50}) {
    return _repository.getActorAuditEvents(actorId, limit: limit);
  }

  Map<String, dynamic> _toCloudPayload(AuditEvent event) {
    return {
      'id': event.id,
      'entityType': event.entityType.name,
      'entityId': event.entityId,
      'action': event.action.name,
      'actorId': event.actorId,
      'beforePayload': event.beforePayload,
      'afterPayload': event.afterPayload,
      'metadata': event.metadata,
      'createdAt': event.createdAt.millisecondsSinceEpoch,
    };
  }
}
