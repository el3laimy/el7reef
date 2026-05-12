import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../data/models/tournament_group_model.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/repositories/tournament_group_repository.dart';

class TournamentGroupRepositoryImpl implements TournamentGroupRepository {
  final FirebaseFirestore _firestore;

  TournamentGroupRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection(FirebasePaths.tournamentGroups);

  @override
  Future<TournamentGroup?> getGroup(String groupId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _groupsRef.doc(groupId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TournamentGroupModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createGroup(TournamentGroup group) async {
    return FirebaseErrorHandler.guard(() async {
      await _groupsRef
          .doc(group.id)
          .set(TournamentGroupModel.fromEntity(group).toJson());
    });
  }

  @override
  Future<void> updateGroup(TournamentGroup group) async {
    return FirebaseErrorHandler.guard(() async {
      await _groupsRef
          .doc(group.id)
          .update(TournamentGroupModel.fromEntity(group).toJson());
    });
  }

  @override
  Future<List<TournamentGroup>> getTournamentGroups(
    String tournamentId, {
    String? groupStageId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      Query<Map<String, dynamic>> query = _groupsRef.where(
        'tournamentId',
        isEqualTo: tournamentId,
      );
      if (groupStageId != null && groupStageId.isNotEmpty) {
        query = query.where('groupStageId', isEqualTo: groupStageId);
      }
      final snapshot = await query.get();
      final groups = snapshot.docs
          .map(
            (doc) => TournamentGroupModel.fromJson(doc.data(), doc.id).toEntity(),
          )
          .toList(growable: true);
      groups.sort((left, right) => left.order.compareTo(right.order));
      return groups;
    });
  }
}
