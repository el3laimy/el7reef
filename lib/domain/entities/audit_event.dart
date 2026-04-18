import '../../core/enums/audit_action.dart';

/// كيان سجل التدقيق — يُسجل كل عملية حساسة في النظام
class AuditEvent {
  final String id;
  final AuditEntityType entityType;
  final String entityId;
  final AuditAction action;
  final String actorId;
  final Map<String, dynamic>? beforePayload;
  final Map<String, dynamic>? afterPayload;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorId,
    this.beforePayload,
    this.afterPayload,
    this.metadata,
    required this.createdAt,
  });

  /// هل الحدث يحتوي على payload مقارنة (before/after)؟
  bool get hasDiff => beforePayload != null && afterPayload != null;

  AuditEvent copyWith({
    String? id,
    AuditEntityType? entityType,
    String? entityId,
    AuditAction? action,
    String? actorId,
    Map<String, dynamic>? beforePayload,
    Map<String, dynamic>? afterPayload,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return AuditEvent(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      actorId: actorId ?? this.actorId,
      beforePayload: beforePayload ?? this.beforePayload,
      afterPayload: afterPayload ?? this.afterPayload,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
