import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_check_in.dart';
import '../../domain/repositories/match_check_in_repository.dart';
import '../models/match_check_in_model.dart';

class MatchCheckInRepositoryImpl implements MatchCheckInRepository {
  final FirebaseFirestore _firestore;

  MatchCheckInRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _checkInsRef =>
      _firestore.collection(FirebasePaths.matchCheckIns);

  @override
  Future<MatchCheckIn?> getCheckIn(String checkInId) async {
    final doc = await _checkInsRef.doc(checkInId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return MatchCheckInModel.fromJson(doc.data()!, doc.id).toEntity();
  }

  @override
  Future<void> createCheckIn(MatchCheckIn checkIn) async {
    final model = MatchCheckInModel.fromEntity(checkIn);
    await _checkInsRef.doc(checkIn.id).set(model.toJson());
  }

  @override
  Future<void> updateCheckIn(MatchCheckIn checkIn) async {
    final model = MatchCheckInModel.fromEntity(checkIn);
    await _checkInsRef.doc(checkIn.id).update(model.toJson());
  }

  @override
  Future<List<MatchCheckIn>> getMatchCheckIns(String matchId) async {
    final snapshot = await _checkInsRef.where('matchId', isEqualTo: matchId).get();
    final checkIns = snapshot.docs
        .map((doc) => MatchCheckInModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: true);
    checkIns.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return checkIns;
  }

  @override
  Future<MatchCheckIn?> getCheckInByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return MatchCheckInModel.fromJson(doc.data(), doc.id).toEntity();
  }

  @override
  Future<MatchCheckIn?> getCheckInByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    return MatchCheckInModel.fromJson(doc.data(), doc.id).toEntity();
  }
}
