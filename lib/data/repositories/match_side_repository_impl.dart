import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_side.dart';
import '../models/match_side_model.dart';

class MatchSideRepositoryImpl {
  final FirebaseFirestore _firestore;

  MatchSideRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sidesRef =>
      _firestore.collection(FirebasePaths.matchSides);

  Future<MatchSide?> getSide({
    required String matchId,
    required String sideKey,
  }) async {
    final snapshot = await _sidesRef.doc(sideDocId(matchId, sideKey)).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return MatchSideModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<List<MatchSide>> getMatchSides(String matchId) async {
    final snapshots = await Future.wait([
      _sidesRef.doc(sideDocId(matchId, 'A')).get(),
      _sidesRef.doc(sideDocId(matchId, 'B')).get(),
    ]);
    return snapshots
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map(
          (snapshot) =>
              MatchSideModel.fromJson(snapshot.data()!, snapshot.id).toEntity(),
        )
        .toList(growable: false);
  }

  Future<void> ensureFriendlySides({
    required Match match,
    required String actorId,
    required String teamADisplayName,
    required String teamBDisplayName,
  }) async {
    if (match.tournamentId != null || actorId.trim().isEmpty) {
      return;
    }
    await Future.wait([
      _createSideIfMissing(
        match: match,
        sideKey: 'A',
        displayName: teamADisplayName,
        actorId: actorId,
      ),
      _createSideIfMissing(
        match: match,
        sideKey: 'B',
        displayName: teamBDisplayName,
        actorId: actorId,
      ),
    ]);
  }

  Future<MatchSide> upsertSide({
    required Match match,
    required String sideKey,
    required String displayName,
    required String actorId,
  }) async {
    final normalizedSide = _normalizeSide(sideKey);
    final sideId = sideDocId(match.id, normalizedSide);
    final sideRef = _sidesRef.doc(sideId);
    final sideSnapshot = await sideRef.get();
    final now = DateTime.now();
    final officialTeamId = normalizedSide == 'A'
        ? match.teamAId
        : match.teamBId;
    final type = officialTeamId == null || officialTeamId.trim().isEmpty
        ? 'temporary'
        : 'officialTeam';

    final side = sideSnapshot.exists && sideSnapshot.data() != null
        ? MatchSideModel.fromJson(
            sideSnapshot.data()!,
            sideSnapshot.id,
          ).toEntity().copyWith(
            type: type,
            displayName: displayName,
            officialTeamId: officialTeamId,
            managedByUserIds: _managedBy(actorId),
            updatedAt: now,
          )
        : MatchSide(
            id: sideId,
            matchId: match.id,
            sideKey: normalizedSide,
            type: type,
            displayName: displayName,
            officialTeamId: officialTeamId,
            managedByUserIds: _managedBy(actorId),
            createdBy: actorId,
            createdAt: now,
            updatedAt: now,
          );

    await sideRef.set(MatchSideModel.fromEntity(side).toJson());
    return side;
  }

  static String sideDocId(String matchId, String sideKey) {
    return '${matchId}_${_normalizeSide(sideKey)}';
  }

  static String _normalizeSide(String sideKey) {
    final normalized = sideKey.trim().toUpperCase();
    if (normalized != 'A' && normalized != 'B') {
      throw ArgumentError('Invalid match side "$sideKey".');
    }
    return normalized;
  }

  List<String> _managedBy(String actorId) {
    return actorId.trim().isEmpty ? const [] : <String>[actorId];
  }

  Future<void> _createSideIfMissing({
    required Match match,
    required String sideKey,
    required String displayName,
    required String actorId,
  }) async {
    final normalizedSide = _normalizeSide(sideKey);
    final sideId = sideDocId(match.id, normalizedSide);
    final sideRef = _sidesRef.doc(sideId);
    final snapshot = await sideRef.get();
    if (snapshot.exists) {
      return;
    }
    final now = DateTime.now();
    final officialTeamId = normalizedSide == 'A'
        ? match.teamAId
        : match.teamBId;
    final side = MatchSide(
      id: sideId,
      matchId: match.id,
      sideKey: normalizedSide,
      type: officialTeamId == null || officialTeamId.trim().isEmpty
          ? 'temporary'
          : 'officialTeam',
      displayName: displayName.trim().isEmpty
          ? 'فريق $normalizedSide'
          : displayName.trim(),
      officialTeamId: officialTeamId,
      managedByUserIds: _managedBy(actorId),
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
    );
    await sideRef.set(MatchSideModel.fromEntity(side).toJson());
  }
}
