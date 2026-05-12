import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/team_roster_snapshot.dart';
import '../../domain/repositories/team_roster_snapshot_repository.dart';
import '../models/team_roster_snapshot_model.dart';

class TeamRosterSnapshotRepositoryImpl implements TeamRosterSnapshotRepository {
  final FirebaseFirestore _firestore;

  TeamRosterSnapshotRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.teamRosterSnapshots);

  @override
  Future<TeamRosterSnapshot?> getSnapshot(String snapshotId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _snapshotsRef.doc(snapshotId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TeamRosterSnapshotModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<List<TeamRosterSnapshot>> getTeamSnapshots(
    String teamId, {
    int limit = 10,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _snapshotsRef
          .where('teamId', isEqualTo: teamId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => TeamRosterSnapshotModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: false);
    });
  }

  @override
  Future<void> createSnapshot(TeamRosterSnapshot snapshot) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TeamRosterSnapshotModel.fromEntity(snapshot);
      await _snapshotsRef.doc(snapshot.id).set(model.toJson());
    });
  }
}
