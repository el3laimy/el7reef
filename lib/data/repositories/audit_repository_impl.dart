import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../core/enums/audit_action.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/repositories/audit_repository.dart';
import '../models/audit_event_model.dart';

/// تنفيذ مستودع سجل التدقيق مع Firestore
class AuditRepositoryImpl implements AuditRepository {
  final FirebaseFirestore _firestore;

  AuditRepositoryImpl({FirebaseFirestore? db, FirebaseFirestore? firestore})
    : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  CollectionReference get _auditRef =>
      _firestore.collection(FirebasePaths.auditEvents);

  @override
  Future<void> createAuditEvent(AuditEvent event) async {
    return FirebaseErrorHandler.guard(() async {
      final model = AuditEventModel.fromEntity(event);
      await _auditRef.doc(event.id).set(model.toJson());
    });
  }

  @override
  Future<List<AuditEvent>> getEntityAuditEvents({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 50,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _auditRef
          .where('entityType', isEqualTo: entityType.name)
          .where('entityId', isEqualTo: entityId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => AuditEventModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<List<AuditEvent>> getAuditEventsByType(
    String entityType, {
    int limit = 50,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _auditRef
          .where('entityType', isEqualTo: entityType)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => AuditEventModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<List<AuditEvent>> getActorAuditEvents(
    String actorId, {
    int limit = 50,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _auditRef
          .where('actorId', isEqualTo: actorId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (doc) => AuditEventModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }
}
