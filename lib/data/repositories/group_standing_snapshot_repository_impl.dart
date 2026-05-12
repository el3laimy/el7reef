import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../data/models/group_standing_snapshot_model.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/repositories/group_standing_snapshot_repository.dart';

class GroupStandingSnapshotRepositoryImpl
    implements GroupStandingSnapshotRepository {
  final FirebaseFirestore _firestore;

  GroupStandingSnapshotRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.groupStandingSnapshots);

  @override
  Future<GroupStandingSnapshot?> getSnapshot(String snapshotId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _snapshotsRef.doc(snapshotId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return GroupStandingSnapshotModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createSnapshot(GroupStandingSnapshot snapshot) async {
    return FirebaseErrorHandler.guard(() async {
      await _snapshotsRef
          .doc(snapshot.id)
          .set(GroupStandingSnapshotModel.fromEntity(snapshot).toJson());
    });
  }

  @override
  Future<void> updateSnapshot(GroupStandingSnapshot snapshot) async {
    return FirebaseErrorHandler.guard(() async {
      await _snapshotsRef
          .doc(snapshot.id)
          .update(GroupStandingSnapshotModel.fromEntity(snapshot).toJson());
    });
  }

  @override
  Future<List<GroupStandingSnapshot>> getGroupStageSnapshots(
    String groupStageId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _snapshotsRef
          .where('groupStageId', isEqualTo: groupStageId)
          .get();
      final standings = snapshot.docs
          .map(
            (doc) => GroupStandingSnapshotModel.fromJson(
              doc.data(),
              doc.id,
            ).toEntity(),
          )
          .toList(growable: true);
      standings.sort((left, right) => left.groupId.compareTo(right.groupId));
      return standings;
    });
  }
}
