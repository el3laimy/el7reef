import '../../core/enums/audit_action.dart';
import '../../domain/entities/audit_event.dart';

class AuditEventModel {
  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String actorId;
  final Map<String, dynamic>? beforePayload;
  final Map<String, dynamic>? afterPayload;
  final Map<String, dynamic>? metadata;
  final String? source;
  final int? verificationVersion;
  final String? requestId;
  final DateTime createdAt;

  const AuditEventModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorId,
    this.beforePayload,
    this.afterPayload,
    this.metadata,
    this.source,
    this.verificationVersion,
    this.requestId,
    required this.createdAt,
  });

  factory AuditEventModel.fromJson(Map<String, dynamic> json, String docId) {
    return AuditEventModel(
      id: docId,
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      beforePayload: json['beforePayload'] as Map<String, dynamic>?,
      afterPayload: json['afterPayload'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      source: json['source'] as String?,
      verificationVersion: (json['verificationVersion'] as num?)?.toInt(),
      requestId: json['requestId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'actorId': actorId,
      'beforePayload': beforePayload,
      'afterPayload': afterPayload,
      'metadata': metadata,
      if (source != null) 'source': source,
      if (verificationVersion != null)
        'verificationVersion': verificationVersion,
      if (requestId != null) 'requestId': requestId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  AuditEvent toEntity() {
    return AuditEvent(
      id: id,
      entityType: _parseEntityType(entityType),
      entityId: entityId,
      action: _parseAction(action),
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: metadata,
      source: source,
      verificationVersion: verificationVersion,
      requestId: requestId,
      createdAt: createdAt,
    );
  }

  factory AuditEventModel.fromEntity(AuditEvent event) {
    return AuditEventModel(
      id: event.id,
      entityType: event.entityType.name,
      entityId: event.entityId,
      action: event.action.name,
      actorId: event.actorId,
      beforePayload: event.beforePayload,
      afterPayload: event.afterPayload,
      metadata: event.metadata,
      source: event.source,
      verificationVersion: event.verificationVersion,
      requestId: event.requestId,
      createdAt: event.createdAt,
    );
  }

  static AuditEntityType _parseEntityType(String value) {
    return AuditEntityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AuditEntityType.match,
    );
  }

  static AuditAction _parseAction(String value) {
    return AuditAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => AuditAction.matchCreated,
    );
  }
}
