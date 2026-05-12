import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/tournament_assistant_permission.dart';
import '../../domain/repositories/tournament_assistant_permission_repository.dart';
import '../models/tournament_assistant_permission_model.dart';

class TournamentAssistantPermissionRepositoryImpl
    implements TournamentAssistantPermissionRepository {
  static const String _assistantsSubcollection = 'assistants';

  final FirebaseFirestore _firestore;

  TournamentAssistantPermissionRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _assistantsRef(
    String tournamentId,
  ) {
    return _firestore
        .collection(FirebasePaths.tournaments)
        .doc(tournamentId)
        .collection(_assistantsSubcollection);
  }

  DocumentReference<Map<String, dynamic>> _assistantDoc(
    String tournamentId,
    String userId,
  ) {
    return _assistantsRef(tournamentId).doc(userId);
  }

  @override
  Future<TournamentAssistantPermission?> getAssistantPermission(
    String tournamentId,
    String userId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _assistantDoc(tournamentId, userId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TournamentAssistantPermissionModel.fromJson(
        doc.data()!,
        doc.id,
      ).toEntity();
    });
  }

  @override
  Future<List<TournamentAssistantPermission>> listTournamentAssistants(
    String tournamentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _assistantsRef(tournamentId).get();
      final assistants = snapshot.docs
          .map(
            (doc) => TournamentAssistantPermissionModel.fromJson(
              doc.data(),
              doc.id,
            ).toEntity(),
          )
          .toList(growable: true);
      assistants.sort((left, right) {
        final createdCompare = left.createdAt.compareTo(right.createdAt);
        if (createdCompare != 0) {
          return createdCompare;
        }
        return left.userId.compareTo(right.userId);
      });
      return assistants;
    });
  }

  @override
  Future<void> createAssistantPermission(
    TournamentAssistantPermission permission,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TournamentAssistantPermissionModel.fromEntity(permission);
      await _assistantDoc(
        permission.tournamentId,
        permission.userId,
      ).set(model.toJson());
    });
  }

  @override
  Future<void> updateAssistantPermissions({
    required String tournamentId,
    required String userId,
    required TournamentAssistantPermissionPreset preset,
    required Map<TournamentAssistantPermissionKey, bool> permissions,
    required DateTime updatedAt,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      await _assistantDoc(tournamentId, userId).update({
        'preset': preset.name,
        'permissions': TournamentAssistantPermissionModel.permissionsToJson(
          permissions,
        ),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<void> revokeAssistant({
    required String tournamentId,
    required String userId,
    required DateTime revokedAt,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      await _assistantDoc(tournamentId, userId).update({
        'status': TournamentAssistantPermissionStatus.revoked.name,
        'updatedAt': revokedAt.millisecondsSinceEpoch,
        'revokedAt': revokedAt.millisecondsSinceEpoch,
      });
    });
  }
}
