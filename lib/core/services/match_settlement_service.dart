import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_match_stats.dart';
import 'rating_engine.dart';

class MatchSettlementResult {
  final MatchStatus status;
  final bool ratingsApplied;
  final bool alreadySettled;

  const MatchSettlementResult({
    required this.status,
    required this.ratingsApplied,
    this.alreadySettled = false,
  });
}

/// Handles score submission, fan-voting session bootstrap, and rating
/// settlement in one place so the match lifecycle stays atomic and idempotent.
class MatchSettlementService {
  final FirebaseFirestore _firestore;

  MatchSettlementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
  }) async {
    return _firestore.runTransaction((transaction) async {
      final matchRef =
          _firestore.collection(FirebasePaths.matches).doc(matchId);
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw StateError('المباراة غير موجودة');
      }

      final rawMatch = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();

      if (_isSettled(matchSnapshot)) {
        return const MatchSettlementResult(
          status: MatchStatus.settled,
          ratingsApplied: true,
          alreadySettled: true,
        );
      }

      final isAnomaly = RatingEngine.isAnomalousResult(
        scoreA: scoreA,
        scoreB: scoreB,
      );
      final submittedAt = DateTime.now();
      final updatedMatch = rawMatch.copyWith(
        scoreTeamA: scoreA,
        scoreTeamB: scoreB,
        mvpPlayerId: mvpPlayerId,
        completedAt: submittedAt,
        isAnomaly: isAnomaly,
        status: isAnomaly ? MatchStatus.pendingReview : MatchStatus.completed,
      );

      transaction.update(matchRef, {
        'scoreTeamA': scoreA,
        'scoreTeamB': scoreB,
        'mvpPlayerId': mvpPlayerId,
        'completedAt': submittedAt.millisecondsSinceEpoch,
        'isAnomaly': isAnomaly,
        'status': updatedMatch.status.name,
      });

      _writeDetailedStats(
        transaction: transaction,
        matchId: matchId,
        detailedStats: detailedStats,
      );
      await _ensureFanVotingSession(
        transaction: transaction,
        match: updatedMatch,
        openedAt: submittedAt,
      );

      return MatchSettlementResult(
        status: updatedMatch.status,
        ratingsApplied: false,
      );
    });
  }

  Future<MatchSettlementResult> approveScore({
    required String matchId,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final matchRef =
          _firestore.collection(FirebasePaths.matches).doc(matchId);
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw StateError('المباراة غير موجودة');
      }

      if (_isSettled(matchSnapshot)) {
        return const MatchSettlementResult(
          status: MatchStatus.settled,
          ratingsApplied: true,
          alreadySettled: true,
        );
      }

      final match = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();

      if (match.scoreTeamA == null || match.scoreTeamB == null) {
        throw StateError('لا يمكن اعتماد مباراة بدون نتيجة');
      }

      final fanVotingRef =
          _firestore.collection(FirebasePaths.fanVotingSessions).doc(matchId);
      final fanVotingSnapshot = await transaction.get(fanVotingRef);

      final fanWinnerId = _resolveFanWinner(
        transaction: transaction,
        fanVotingRef: fanVotingRef,
        fanVotingSnapshot: fanVotingSnapshot,
      );

      final playersById = await _loadPlayers(
        transaction: transaction,
        playerIds: [...match.teamAPlayerIds, ...match.teamBPlayerIds],
      );

      final teamAPlayers = match.teamAPlayerIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList();
      final teamBPlayers = match.teamBPlayerIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList();

      final avgA = _avgRating(teamAPlayers);
      final avgB = _avgRating(teamBPlayers);
      final winner = match.winner;
      final settledAt = DateTime.now();

      for (final player in teamAPlayers) {
        final delta = RatingEngine.calculateMatchDelta(
          player: player,
          match: match.copyWith(isAnomaly: false),
          isWinner: winner == 'A',
          isDraw: winner == 'draw',
          isMvp: match.mvpPlayerId == player.id,
          difficultyMultiplier: RatingEngine.computeDifficultyMultiplier(
            myTeamAvgRating: avgA,
            opponentAvgRating: avgB,
          ),
          recentEncounterCount: 0,
          isFanMvp: fanWinnerId == player.id,
        );
        if (delta.isBlocked) continue;
        _updatePlayerAggregate(
          transaction: transaction,
          player: player,
          isWin: winner == 'A',
          isDraw: winner == 'draw',
          isMvp: match.mvpPlayerId == player.id,
          ratingDelta: delta.delta,
          settledAt: settledAt,
        );
      }

      for (final player in teamBPlayers) {
        final delta = RatingEngine.calculateMatchDelta(
          player: player,
          match: match.copyWith(isAnomaly: false),
          isWinner: winner == 'B',
          isDraw: winner == 'draw',
          isMvp: match.mvpPlayerId == player.id,
          difficultyMultiplier: RatingEngine.computeDifficultyMultiplier(
            myTeamAvgRating: avgB,
            opponentAvgRating: avgA,
          ),
          recentEncounterCount: 0,
          isFanMvp: fanWinnerId == player.id,
        );
        if (delta.isBlocked) continue;
        _updatePlayerAggregate(
          transaction: transaction,
          player: player,
          isWin: winner == 'B',
          isDraw: winner == 'draw',
          isMvp: match.mvpPlayerId == player.id,
          ratingDelta: delta.delta,
          settledAt: settledAt,
        );
      }

      transaction.update(matchRef, {
        'status': MatchStatus.settled.name,
        'isAnomaly': false,
        'ratingsAppliedAt': settledAt.millisecondsSinceEpoch,
      });

      return const MatchSettlementResult(
        status: MatchStatus.settled,
        ratingsApplied: true,
      );
    });
  }

  Future<void> _ensureFanVotingSession({
    required Transaction transaction,
    required Match match,
    required DateTime openedAt,
  }) async {
    final sessionRef = _firestore
        .collection(FirebasePaths.fanVotingSessions)
        .doc(match.id);
    final sessionSnapshot = await transaction.get(sessionRef);

    if (sessionSnapshot.exists) {
      return;
    }

    transaction.set(sessionRef, {
      'matchId': match.id,
      'opensAt': openedAt.millisecondsSinceEpoch,
      'closesAt': openedAt
          .add(const Duration(minutes: 90))
          .millisecondsSinceEpoch,
      'totalVotes': 0,
      'playerVotes': <String, int>{},
      'winnerPlayerId': null,
    });
  }

  void _writeDetailedStats({
    required Transaction transaction,
    required String matchId,
    required List<PlayerMatchStats> detailedStats,
  }) {
    for (final stats in detailedStats) {
      final statRef = _firestore
          .collection(FirebasePaths.matches)
          .doc(matchId)
          .collection('player_stats')
          .doc(stats.playerId);
      transaction.set(statRef, {
        'playerId': stats.playerId,
        'matchId': stats.matchId,
        'teamId': stats.teamId,
        'played': stats.played,
        'goals': stats.goals,
        'assists': stats.assists,
        'saves': stats.saves,
        'yellowCard': stats.yellowCard,
        'redCard': stats.redCard,
        'cleanSheet': stats.cleanSheet,
        'position': stats.position.name,
      });
    }
  }

  Future<Map<String, Player>> _loadPlayers({
    required Transaction transaction,
    required List<String> playerIds,
  }) async {
    final players = <String, Player>{};
    for (final playerId in playerIds.toSet()) {
      final playerRef =
          _firestore.collection(FirebasePaths.players).doc(playerId);
      final playerSnapshot = await transaction.get(playerRef);
      if (!playerSnapshot.exists || playerSnapshot.data() == null) {
        continue;
      }
      players[playerId] = PlayerModel.fromJson(
        playerSnapshot.data()!,
        playerSnapshot.id,
      ).toEntity();
    }
    return players;
  }

  void _updatePlayerAggregate({
    required Transaction transaction,
    required Player player,
    required bool isWin,
    required bool isDraw,
    required bool isMvp,
    required int ratingDelta,
    required DateTime settledAt,
  }) {
    final playerRef =
        _firestore.collection(FirebasePaths.players).doc(player.id);
    final updates = <String, dynamic>{
      'rating': (player.rating + ratingDelta).clamp(0, 9999),
      'totalMatches': FieldValue.increment(1),
      'lastActiveAt': settledAt.millisecondsSinceEpoch,
    };
    if (isWin) updates['wins'] = FieldValue.increment(1);
    if (isDraw) updates['draws'] = FieldValue.increment(1);
    if (!isWin && !isDraw) updates['losses'] = FieldValue.increment(1);
    if (isMvp) updates['mvpCount'] = FieldValue.increment(1);
    transaction.update(playerRef, updates);
  }

  String? _resolveFanWinner({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> fanVotingRef,
    required DocumentSnapshot<Map<String, dynamic>> fanVotingSnapshot,
  }) {
    if (!fanVotingSnapshot.exists || fanVotingSnapshot.data() == null) {
      return null;
    }

    final data = fanVotingSnapshot.data()!;
    final existingWinner = data['winnerPlayerId'] as String?;
    if (existingWinner != null && existingWinner.isNotEmpty) {
      return existingWinner;
    }

    final playerVotes = Map<String, int>.from(
      (data['playerVotes'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
    );
    if (playerVotes.isEmpty) {
      return null;
    }

    final closesAtMs = (data['closesAt'] as num?)?.toInt();
    final isClosed = closesAtMs != null &&
        DateTime.now().isAfter(
          DateTime.fromMillisecondsSinceEpoch(closesAtMs),
        );
    if (!isClosed) {
      return null;
    }

    String? winnerId;
    var maxVotes = -1;
    playerVotes.forEach((playerId, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        winnerId = playerId;
      }
    });

    if (winnerId != null) {
      transaction.update(fanVotingRef, {
        'winnerPlayerId': winnerId,
      });
    }

    return winnerId;
  }

  double _avgRating(List<Player> players) {
    if (players.isEmpty) return 1000;
    final total = players
        .map((player) => player.rating)
        .fold<int>(0, (a, b) => a + b);
    return total / players.length;
  }

  bool _isSettled(DocumentSnapshot<Map<String, dynamic>> matchSnapshot) {
    final data = matchSnapshot.data();
    if (data == null) return false;
    return data['status'] == MatchStatus.settled.name ||
        data['ratingsAppliedAt'] != null;
  }
}
