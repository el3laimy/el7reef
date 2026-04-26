import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_side_player.dart';
import '../models/match_side_player_model.dart';

class MatchSidePlayerRepositoryImpl {
  final FirebaseFirestore _firestore;

  MatchSidePlayerRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _playersRef =>
      _firestore.collection(FirebasePaths.matchSidePlayers);

  Future<List<MatchSidePlayer>> getMatchPlayers(String matchId) async {
    final snapshot = await _playersRef
        .where('matchId', isEqualTo: matchId)
        .get();
    final players = snapshot.docs
        .map(
          (doc) => MatchSidePlayerModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    players.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return players;
  }

  Future<List<MatchSidePlayer>> getTemporaryPlayersForMatch(
    String matchId,
  ) async {
    final players = await getMatchPlayers(matchId);
    return players
        .where((player) => player.isTemporary)
        .toList(growable: false);
  }

  Future<List<MatchSidePlayer>> getPlayersForSide({
    required String matchId,
    required String sideKey,
  }) async {
    final normalizedSide = sideKey.trim().toUpperCase();
    final players = await getMatchPlayers(matchId);
    return players
        .where(
          (player) => player.sideKey.trim().toUpperCase() == normalizedSide,
        )
        .toList(growable: false);
  }

  Future<MatchSidePlayer> addTemporaryPlayer({
    required String matchId,
    required String sideKey,
    required String sideId,
    required String displayName,
    required String addedBy,
    String? position,
    int? shirtNumber,
  }) async {
    final now = DateTime.now();
    final playerRef = _playersRef.doc();
    final player = MatchSidePlayer(
      id: playerRef.id,
      matchId: matchId,
      sideKey: sideKey.trim().toUpperCase(),
      sideId: sideId,
      kind: 'temporary',
      displayName: displayName,
      position: _nonEmpty(position),
      shirtNumber: shirtNumber,
      ratingEligible: false,
      addedBy: addedBy,
      createdAt: now,
    );
    await playerRef.set(MatchSidePlayerModel.fromEntity(player).toJson());
    return player;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
