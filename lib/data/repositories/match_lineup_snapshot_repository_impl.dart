import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/repositories/match_lineup_snapshot_repository.dart';
import '../models/match_lineup_snapshot_model.dart';

class MatchLineupSnapshotRepositoryImpl
    implements MatchLineupSnapshotRepository {
  final FirebaseFirestore _firestore;

  MatchLineupSnapshotRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);

  @override
  Future<MatchLineupSnapshot?> getSnapshot(String snapshotId) async {
    final doc = await _snapshotsRef.doc(snapshotId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return MatchLineupSnapshotModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createSnapshot(MatchLineupSnapshot snapshot) async {
    final model = MatchLineupSnapshotModel.fromEntity(snapshot);
    await _snapshotsRef.doc(snapshot.id).set(model.toJson());
  }

  @override
  Future<List<MatchLineupSnapshot>> getMatchSnapshots(String matchId) async {
    final snapshot = await _snapshotsRef.where('matchId', isEqualTo: matchId).get();
    final lineups = snapshot.docs
        .map((doc) => MatchLineupSnapshotModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: true);
    lineups.sort((left, right) => left.lockedAt.compareTo(right.lockedAt));
    return lineups;
  }

  @override
  Future<MatchLineupSnapshot?> getSnapshotByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return MatchLineupSnapshotModel.fromJson(doc.data(), doc.id).toEntity();
  }

  @override
  Future<MatchLineupSnapshot?> getSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return MatchLineupSnapshotModel.fromJson(doc.data(), doc.id).toEntity();
  }

  @override
  Future<void> deleteSnapshot(String snapshotId) async {
    await _snapshotsRef.doc(snapshotId).delete();
  }
}
