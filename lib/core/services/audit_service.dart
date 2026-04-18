import 'package:uuid/uuid.dart';

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

  AuditService({
    required AuditRepository repository,
    Uuid? uuid,
  })  : _repository = repository,
        _uuid = uuid ?? const Uuid();

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

    await _repository.createAuditEvent(event);
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
  Future<List<AuditEvent>> getEntityTimeline(
    String entityId, {
    int limit = 50,
  }) {
    return _repository.getEntityAuditEvents(entityId, limit: limit);
  }

  /// جلب سجل تدقيق ممثل (actor) محدد
  Future<List<AuditEvent>> getActorHistory(
    String actorId, {
    int limit = 50,
  }) {
    return _repository.getActorAuditEvents(actorId, limit: limit);
  }
}
