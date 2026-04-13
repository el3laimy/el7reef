import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/entities/player_match_stats.dart';
import '../models/player_model.dart';
import '../models/player_match_stats_model.dart';

/// تنفيذ مستودع اللاعب مع Firebase Firestore
class PlayerRepositoryImpl implements PlayerRepository {
  final FirebaseFirestore _firestore;

  PlayerRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _playersRef =>
      _firestore.collection(FirebasePaths.players);

  @override
  Future<Player?> getPlayer(String playerId) async {
    final doc = await _playersRef.doc(playerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return PlayerModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
        .toEntity();
  }

  @override
  Future<void> createPlayer(Player player) async {
    final model = PlayerModel.fromEntity(player);
    await _playersRef.doc(player.id).set(model.toJson());
  }

  @override
  Future<void> updatePlayer(Player player) async {
    final model = PlayerModel.fromEntity(player);
    await _playersRef.doc(player.id).update(model.toJson());
  }

  @override
  Future<List<Player>> searchPlayers(String query) async {
    if (query.isEmpty) return [];

    final isUsername = query.startsWith('@');
    final searchTerm = isUsername ? query.substring(1).toLowerCase() : query;

    Query targetQuery;

    if (isUsername) {
      targetQuery = _playersRef
          .where('usernameLower', isGreaterThanOrEqualTo: searchTerm)
          .where('usernameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff');
    } else {
      targetQuery = _playersRef
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: '$searchTerm\uf8ff');
    }

    final snapshot = await targetQuery.limit(20).get();

    return snapshot.docs
        .map((doc) =>
            PlayerModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();
  }

  @override
  Future<List<Player>> getLeaderboard({int limit = 50}) async {
    final snapshot = await _playersRef
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) =>
            PlayerModel.fromJson(doc.data()! as Map<String, dynamic>, doc.id)
                .toEntity())
        .toList();
  }

  @override
  Future<void> updateRating(String playerId, int newRating) async {
    await _playersRef.doc(playerId).update({
      'rating': newRating,
      'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> updateMatchStats({
    required String playerId,
    required bool isWin,
    required bool isDraw,
    required bool isMvp,
    PlayerMatchStats? detailedStats,
  }) async {
    final batch = _firestore.batch();
    
    final playerDoc = _playersRef.doc(playerId);
    final updates = <String, dynamic>{
      'totalMatches': FieldValue.increment(1),
      'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (isWin) updates['wins'] = FieldValue.increment(1);
    if (isDraw) updates['draws'] = FieldValue.increment(1);
    if (!isWin && !isDraw) updates['losses'] = FieldValue.increment(1);
    if (isMvp) updates['mvpCount'] = FieldValue.increment(1);

    batch.update(playerDoc, updates);

    // Save detailed match statistics to subcollection if provided: matches/{matchId}/player_stats/{playerId}
    if (detailedStats != null) {
      final statModel = PlayerMatchStatsModel.fromEntity(detailedStats);
      final statsDoc = _firestore
          .collection(FirebasePaths.matches)
          .doc(detailedStats.matchId)
          .collection('player_stats')
          .doc(detailedStats.playerId);
          
      batch.set(statsDoc, statModel.toJson());
    }

    await batch.commit();
  }
}
