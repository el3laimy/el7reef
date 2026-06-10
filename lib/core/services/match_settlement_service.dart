import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../data/models/match_model.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_match_stats.dart';
import '../../domain/entities/tournament.dart';
import '../../data/models/tournament_model.dart';
import 'official_match_roster_service.dart';
import 'rating_engine.dart';
import 'tournament_lifecycle_service.dart';

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
  final TournamentLifecycleService _tournamentLifecycleService;
  final OfficialMatchRosterService _officialRosterService;

  MatchSettlementService({
    FirebaseFirestore? firestore,
    TournamentLifecycleService? tournamentLifecycleService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _tournamentLifecycleService =
           tournamentLifecycleService ??
           TournamentLifecycleService(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _officialRosterService = OfficialMatchRosterService(
         firestore: firestore ?? FirebaseFirestore.instance,
       );

  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
  }) async {
    _assertActor(actorId);
    final officialRoster = await _officialRosterService.loadRegisteredRoster(
      matchId: matchId,
    );
    final eligiblePlayerIds = officialRoster.allPlayerIds.toSet();
    final normalizedMvpId = _normalizeOptionalId(mvpPlayerId);
    if (normalizedMvpId != null) {
      final participantRoster = await _officialRosterService
          .loadParticipantRoster(matchId: matchId);
      final participantIds = participantRoster.allParticipants
          .map((participant) => participant.id)
          .toSet();
      if (!participantIds.contains(normalizedMvpId)) {
        throw StateError('لا يمكن اختيار MVP خارج roster المباراة.');
      }
    }
    final effectiveMvpId = normalizedMvpId;
    final officialDetailedStats = detailedStats
        .where((stats) => eligiblePlayerIds.contains(stats.playerId))
        .toList(growable: false);

    return _firestore.runTransaction((transaction) async {
      final matchRef = _firestore
          .collection(FirebasePaths.matches)
          .doc(matchId);
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw StateError('المباراة غير موجودة');
      }

      final rawMatch = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();

      _assertCanSubmitScore(rawMatch);
      await _assertCanManageScore(
        transaction: transaction,
        match: rawMatch,
        actorId: actorId,
        assistantPermissions: const ['canSubmitScore', 'canRecordGoalsAndMvp'],
      );

      final isAnomaly = RatingEngine.isAnomalousResult(
        scoreA: scoreA,
        scoreB: scoreB,
      );
      final submittedAt = DateTime.now();
      final fanVotingRef = _firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc(matchId);
      final fanVotingSnapshot = await transaction.get(fanVotingRef);
      final updatedMatch = rawMatch.copyWith(
        scoreTeamA: scoreA,
        scoreTeamB: scoreB,
        mvpPlayerId: effectiveMvpId,
        prideEventsPending: true,
        completedAt: submittedAt,
        isAnomaly: isAnomaly,
        status: isAnomaly ? MatchStatus.pendingReview : MatchStatus.completed,
      );

      transaction.update(matchRef, {
        'scoreTeamA': scoreA,
        'scoreTeamB': scoreB,
        'mvpPlayerId': effectiveMvpId,
        'prideEventsPending': true,
        'completedAt': submittedAt.millisecondsSinceEpoch,
        'isAnomaly': isAnomaly,
        'status': updatedMatch.status.name,
      });

      _writeDetailedStats(
        transaction: transaction,
        matchId: matchId,
        detailedStats: officialDetailedStats,
      );
      await _ensureFanVotingSession(
        transaction: transaction,
        match: updatedMatch,
        openedAt: submittedAt,
        sessionRef: fanVotingRef,
        sessionExists: fanVotingSnapshot.exists,
        eligiblePlayerIds: officialRoster.allPlayerIds,
      );

      return MatchSettlementResult(
        status: updatedMatch.status,
        ratingsApplied: false,
      );
    });
  }

  Future<MatchSettlementResult> approveScore({
    required String matchId,
    required String actorId,
  }) async {
    _assertActor(actorId);
    final officialRoster = await _officialRosterService.loadRegisteredRoster(
      matchId: matchId,
    );
    Match? tournamentMatch;
    final result = await _firestore.runTransaction((transaction) async {
      final matchRef = _firestore
          .collection(FirebasePaths.matches)
          .doc(matchId);
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw StateError('المباراة غير موجودة');
      }

      final match = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();
      tournamentMatch = match;

      await _assertCanManageScore(
        transaction: transaction,
        match: match,
        actorId: actorId,
        assistantPermissions: const ['canApproveScore'],
      );

      if (_isSettled(matchSnapshot)) {
        return const MatchSettlementResult(
          status: MatchStatus.settled,
          ratingsApplied: true,
          alreadySettled: true,
        );
      }

      _assertCanApproveScore(match);

      if (match.scoreTeamA == null || match.scoreTeamB == null) {
        throw StateError('لا يمكن اعتماد مباراة بدون نتيجة');
      }

      final fanVotingRef = _firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc(matchId);
      final fanVotingSnapshot = await transaction.get(fanVotingRef);

      final fanWinnerId = _resolveFanWinner(
        transaction: transaction,
        fanVotingRef: fanVotingRef,
        fanVotingSnapshot: fanVotingSnapshot,
        eligiblePlayerIds: officialRoster.allPlayerIds.toSet(),
      );
      final teamAPlayers = officialRoster.teamAPlayers;
      final teamBPlayers = officialRoster.teamBPlayers;
      final canApplyRatingDeltas =
          teamAPlayers.isNotEmpty && teamBPlayers.isNotEmpty;

      final avgA = _avgRating(teamAPlayers);
      final avgB = _avgRating(teamBPlayers);
      final winner = match.winner;
      final settledAt = DateTime.now();

      // V1 rates registered players only. If either side has no registered
      // eligible players, skip rating deltas rather than treating guests as
      // Player documents or calculating a one-sided official rating result.
      // mvpPlayerId may now store a Player.id, GuestPlayer.id, or
      // MatchSidePlayer.id. Guest/MSP MVPs are preserved on the match, but only
      // registered Player.id matches grant rating bonuses; the future MatchEvent
      // MVP dual-write will carry the full ParticipantRef.
      if (canApplyRatingDeltas) {
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
      }

      transaction.update(matchRef, {
        'status': MatchStatus.settled.name,
        'isAnomaly': false,
        'ratingsAppliedAt': settledAt.millisecondsSinceEpoch,
      });
      tournamentMatch = match.copyWith(status: MatchStatus.settled);

      return MatchSettlementResult(
        status: MatchStatus.settled,
        ratingsApplied: canApplyRatingDeltas,
      );
    });
    await _refreshTournamentProgress(match: tournamentMatch);
    return result;
  }

  Future<void> _ensureFanVotingSession({
    required Transaction transaction,
    required Match match,
    required DateTime openedAt,
    required DocumentReference<Map<String, dynamic>> sessionRef,
    required bool sessionExists,
    required List<String> eligiblePlayerIds,
  }) async {
    if (sessionExists) {
      return;
    }
    if (eligiblePlayerIds.isEmpty) {
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
      'eligiblePlayerIds': eligiblePlayerIds,
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
          .collection(FirebasePaths.playerStats)
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

  void _updatePlayerAggregate({
    required Transaction transaction,
    required Player player,
    required bool isWin,
    required bool isDraw,
    required bool isMvp,
    required int ratingDelta,
    required DateTime settledAt,
  }) {
    final playerRef = _firestore
        .collection(FirebasePaths.players)
        .doc(player.id);
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
    required Set<String> eligiblePlayerIds,
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
      (data['playerVotes'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    )..removeWhere((playerId, _) => !eligiblePlayerIds.contains(playerId));
    if (playerVotes.isEmpty) {
      transaction.update(fanVotingRef, {
        'closesAt': DateTime.now().millisecondsSinceEpoch,
      });
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
        'closesAt': DateTime.now().millisecondsSinceEpoch,
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

  String? _normalizeOptionalId(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _assertActor(String actorId) {
    if (actorId.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
  }

  void _assertCanSubmitScore(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw StateError('لا يمكن تسجيل نتيجة مباراة مجمّدة.');
    }
    if (match.status != MatchStatus.live) {
      throw StateError('يمكن تسجيل النتيجة فقط أثناء المباراة الجارية.');
    }
  }

  void _assertCanApproveScore(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw StateError('لا يمكن اعتماد نتيجة مباراة مجمّدة.');
    }
    if (match.status != MatchStatus.completed &&
        match.status != MatchStatus.pendingReview) {
      throw StateError('لا يمكن اعتماد نتيجة قبل تسجيلها.');
    }
  }

  Future<void> _assertCanManageScore({
    required Transaction transaction,
    required Match match,
    required String actorId,
    required List<String> assistantPermissions,
  }) async {
    final tournamentId = match.tournamentId;
    if (tournamentId == null || tournamentId.isEmpty) {
      if (match.organizerId != actorId) {
        throw StateError('فقط منظم المباراة يمكنه إدارة النتيجة.');
      }
      return;
    }

    final tournament = await _loadTournamentForTransaction(
      transaction: transaction,
      tournamentId: tournamentId,
    );
    if (tournament.organizerId == actorId) {
      return;
    }
    final hasAssistantPermission = await _hasAssistantPermissions(
      transaction: transaction,
      tournamentId: tournamentId,
      actorId: actorId,
      permissionNames: assistantPermissions,
    );
    if (!hasAssistantPermission) {
      throw StateError('لا تملك صلاحية إدارة نتائج هذه البطولة.');
    }
  }

  Future<bool> _hasAssistantPermissions({
    required Transaction transaction,
    required String tournamentId,
    required String actorId,
    required List<String> permissionNames,
  }) async {
    final assistantRef = _firestore
        .collection(FirebasePaths.tournaments)
        .doc(tournamentId)
        .collection('assistants')
        .doc(actorId);
    final assistantSnapshot = await transaction.get(assistantRef);
    final data = assistantSnapshot.data();
    if (!assistantSnapshot.exists || data == null) {
      return false;
    }
    final permissions = data['permissions'];
    return data['status'] == 'active' &&
        permissions is Map &&
        permissionNames.every((permissionName) {
          return permissions[permissionName] == true;
        });
  }

  Future<Tournament> _loadTournamentForTransaction({
    required Transaction transaction,
    required String tournamentId,
  }) async {
    final snapshot = await transaction.get(
      _firestore.collection(FirebasePaths.tournaments).doc(tournamentId),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('البطولة المرتبطة بالمباراة غير موجودة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  bool _isSettled(DocumentSnapshot<Map<String, dynamic>> matchSnapshot) {
    final data = matchSnapshot.data();
    if (data == null) return false;
    return data['status'] == MatchStatus.settled.name ||
        data['ratingsAppliedAt'] != null;
  }

  Future<void> _refreshTournamentProgress({required Match? match}) async {
    if (match == null ||
        match.tournamentId == null ||
        match.tournamentId!.isEmpty ||
        !match.isOfficialTournamentResult) {
      return;
    }

    switch (match.stageType) {
      case TournamentStageType.groupStage:
        await _tournamentLifecycleService.refreshGroupStandings(
          tournamentId: match.tournamentId!,
        );
        return;
      case TournamentStageType.knockoutStage:
        await _tournamentLifecycleService.refreshKnockoutProgress(
          tournamentId: match.tournamentId!,
        );
        return;
      case null:
        return;
    }
  }
}
