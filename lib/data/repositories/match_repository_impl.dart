import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
import '../models/match_model.dart';

/// تنفيذ مستودع المباراة مع Firestore
class MatchRepositoryImpl implements MatchRepository {
  final FirebaseFirestore _db;

  MatchRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _matchesRef => _db.collection(FirebasePaths.matches);

  @override
  Future<Match?> getMatch(String matchId) async {
    final doc = await _matchesRef.doc(matchId).get();
    if (!doc.exists || doc.data() == null) return null;
    return MatchModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
        .toEntity();
  }

  @override
  Future<void> createMatch(Match match) async {
    final model = MatchModel.fromEntity(match);
    await _matchesRef.doc(match.id).set(model.toJson());
  }

  @override
  Future<void> updateMatch(Match match) async {
    final model = MatchModel.fromEntity(match);
    await _matchesRef.doc(match.id).update(model.toJson());
  }

  @override
  Future<List<Match>> getPlayerMatches(String playerId, {int limit = 20}) async {
    // مباريات الفريق A
    final snapshotA = await _matchesRef
        .where('teamAPlayerIds', arrayContains: playerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    // مباريات الفريق B
    final snapshotB = await _matchesRef
        .where('teamBPlayerIds', arrayContains: playerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final all = <Match>{};
    for (final doc in [...snapshotA.docs, ...snapshotB.docs]) {
      all.add(
        MatchModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
            .toEntity(),
      );
    }

    final sorted = all.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Match>> getLiveMatches({
    double? lat,
    double? lng,
    double radiusKm = 5,
  }) async {
    final snapshot = await _matchesRef
        .where('status', whereIn: ['open', 'full', 'live'])
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    return snapshot.docs
        .map((doc) =>
            MatchModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();
  }

  @override
  Future<void> submitScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
  }) async {
    await _matchesRef.doc(matchId).update({
      'scoreTeamA': scoreA,
      'scoreTeamB': scoreB,
      'mvpPlayerId': mvpPlayerId,
      'status': MatchStatus.completed.name,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> approveScore(String matchId) async {
    await _matchesRef.doc(matchId).update({
      'status': MatchStatus.settled.name,
    });
  }

  @override
  Future<void> freezeMatch(String matchId) async {
    await _matchesRef.doc(matchId).update({
      'isFrozen': true,
      'status': MatchStatus.frozen.name,
    });
  }

  @override
  Future<void> unfreezeMatch(String matchId) async {
    await _matchesRef.doc(matchId).update({
      'isFrozen': false,
      'status': MatchStatus.pendingReview.name,
    });
  }

  @override
  Future<void> activateGoldenRating(String matchId) async {
    await _matchesRef.doc(matchId).update({
      'isGoldenRating': true,
    });
  }
}
