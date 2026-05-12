import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../core/errors/firebase_error_handler.dart';
import '../../core/lineup/formation_library.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
import '../models/match_model.dart';

/// تنفيذ مستودع المباراة مع Firestore
class MatchRepositoryImpl implements MatchRepository {
  final FirebaseFirestore _firestore;

  MatchRepositoryImpl({FirebaseFirestore? db, FirebaseFirestore? firestore})
    : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);
  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);

  @override
  Future<Match?> getMatch(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _matchesRef.doc(matchId).get();
      if (!doc.exists || doc.data() == null) return null;
      return MatchModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createMatch(Match match) async {
    return FirebaseErrorHandler.guard(() async {
      final model = MatchModel.fromEntity(match);
      await _matchesRef.doc(match.id).set(model.toJson());
    });
  }

  @override
  Future<void> upsertMatches(List<Match> matches) async {
    return FirebaseErrorHandler.guard(() async {
      final batch = _firestore.batch();
      for (final match in matches) {
        batch.set(
          _matchesRef.doc(match.id),
          MatchModel.fromEntity(match).toJson(),
        );
      }
      await batch.commit();
    });
  }

  @override
  Future<void> updateMatch(Match match) async {
    return FirebaseErrorHandler.guard(() async {
      final currentDoc = await _matchesRef.doc(match.id).get();
      final currentData = currentDoc.data();
      if (currentData != null) {
        final currentTeamSize = normalizeMatchTeamSize(
          (currentData['teamSize'] as num?)?.toInt(),
        );
        final nextTeamSize = normalizeMatchTeamSize(match.teamSize);
        if (currentTeamSize != nextTeamSize) {
          final lockedSnapshots = await _snapshotsRef
              .where('matchId', isEqualTo: match.id)
              .limit(1)
              .get();
          if (lockedSnapshots.docs.isNotEmpty) {
            throw Exception(
              'لا يمكن تغيير عدد اللاعبين بعد قفل أي تشكيلة لهذه المباراة.',
            );
          }
        }
      }
      final model = MatchModel.fromEntity(match);
      await _matchesRef.doc(match.id).update(model.toJson());
    });
  }

  @override
  Future<List<Match>> getPlayerMatches(
    String playerId, {
    int limit = 20,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshotA = await _matchesRef
          .where('teamAPlayerIds', arrayContains: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final snapshotB = await _matchesRef
          .where('teamBPlayerIds', arrayContains: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final all = <Match>{};
      for (final doc in [...snapshotA.docs, ...snapshotB.docs]) {
        all.add(MatchModel.fromJson(doc.data(), doc.id).toEntity());
      }

      final sorted =
          all.where((match) => match.status != MatchStatus.cancelled).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(limit).toList();
    });
  }

  @override
  Future<List<Match>> getLiveMatches({
    double? lat,
    double? lng,
    double radiusKm = 5,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _matchesRef
          .where(
            'status',
            whereIn: [
              MatchStatus.open.name,
              MatchStatus.full.name,
              MatchStatus.live.name,
              MatchStatus.completed.name,
              MatchStatus.pendingReview.name,
            ],
          )
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      return snapshot.docs
          .map((doc) => MatchModel.fromJson(doc.data(), doc.id).toEntity())
          .toList();
    });
  }

  @override
  Future<List<Match>> getTournamentMatches({
    required String tournamentId,
    TournamentStageType? stageType,
    String? groupStageId,
    String? groupId,
    String? knockoutTieId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      Query<Map<String, dynamic>> query = _matchesRef.where(
        'tournamentId',
        isEqualTo: tournamentId,
      );
      if (stageType != null) {
        query = query.where('stageType', isEqualTo: stageType.name);
      }
      if (groupStageId != null && groupStageId.isNotEmpty) {
        query = query.where('groupStageId', isEqualTo: groupStageId);
      }
      if (groupId != null && groupId.isNotEmpty) {
        query = query.where('groupId', isEqualTo: groupId);
      }
      if (knockoutTieId != null && knockoutTieId.isNotEmpty) {
        query = query.where('knockoutTieId', isEqualTo: knockoutTieId);
      }
      final snapshot = await query.get();
      final matches = snapshot.docs
          .map((doc) => MatchModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      matches.sort((left, right) {
        final leftDate = left.scheduledAt ?? left.createdAt;
        final rightDate = right.scheduledAt ?? right.createdAt;
        return leftDate.compareTo(rightDate);
      });
      return matches;
    });
  }

  @override
  Future<void> submitScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({
        'scoreTeamA': scoreA,
        'scoreTeamB': scoreB,
        'mvpPlayerId': mvpPlayerId,
        'status': MatchStatus.completed.name,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<void> approveScore(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({
        'status': MatchStatus.settled.name,
      });
    });
  }

  @override
  Future<void> freezeMatch(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({
        'isFrozen': true,
        'status': MatchStatus.frozen.name,
      });
    });
  }

  @override
  Future<void> unfreezeMatch(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({
        'isFrozen': false,
        'status': MatchStatus.pendingReview.name,
      });
    });
  }

  @override
  Future<void> activateGoldenRating(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({'isGoldenRating': true});
    });
  }

  @override
  Future<void> cancelMatch(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      await _matchesRef.doc(matchId).update({
        'status': MatchStatus.cancelled.name,
      });
    });
  }

  @override
  Future<void> addPlayerToMatch({
    required String matchId,
    required String playerId,
    required String side,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final field = side == 'A' ? 'teamAPlayerIds' : 'teamBPlayerIds';
      await _matchesRef.doc(matchId).update({
        field: FieldValue.arrayUnion([playerId]),
      });
    });
  }

  @override
  Future<void> removePlayerFromMatch({
    required String matchId,
    required String playerId,
    required String side,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final field = side == 'A' ? 'teamAPlayerIds' : 'teamBPlayerIds';
      await _matchesRef.doc(matchId).update({
        field: FieldValue.arrayRemove([playerId]),
      });
    });
  }
}
