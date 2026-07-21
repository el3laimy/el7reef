import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../data/models/match_model.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_participant_roster.dart';
import '../../domain/entities/penalty_shootout_result.dart';
import '../../domain/entities/participant_ref.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_match_stats.dart';
import '../../domain/entities/tournament.dart';
import '../../data/models/tournament_model.dart';
import 'cloud_sensitive_ops_service.dart';
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

class MatchSettlementGoalDraft {
  final String sideKey;
  final ParticipantRef actor;
  final int goals;
  final int? minute;

  const MatchSettlementGoalDraft({
    required this.sideKey,
    required this.actor,
    required this.goals,
    this.minute,
  });
}

class MatchSettlementMvpDraft {
  final String sideKey;
  final ParticipantRef actor;

  const MatchSettlementMvpDraft({required this.sideKey, required this.actor});
}

/// Handles score submission, fan-voting session bootstrap, and rating
/// settlement in one place so the match lifecycle stays atomic and idempotent.
class MatchSettlementService {
  final FirebaseFirestore _firestore;
  final TournamentLifecycleService _tournamentLifecycleService;
  final OfficialMatchRosterService _officialRosterService;
  final CloudSensitiveOpsService _cloudSensitiveOps;
  final bool _allowLocalFallback;

  MatchSettlementService({
    FirebaseFirestore? firestore,
    TournamentLifecycleService? tournamentLifecycleService,
    CloudSensitiveOpsService? cloudSensitiveOps,
    bool allowLocalFallback = false,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _tournamentLifecycleService =
           tournamentLifecycleService ??
           TournamentLifecycleService(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _officialRosterService = OfficialMatchRosterService(
         firestore: firestore ?? FirebaseFirestore.instance,
       ),
       _cloudSensitiveOps = cloudSensitiveOps ?? CloudSensitiveOpsService(),
       _allowLocalFallback = allowLocalFallback;

  Future<MatchSettlementResult> submitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    List<PlayerMatchStats> detailedStats = const [],
    List<MatchSettlementGoalDraft> goalDrafts = const [],
    MatchSettlementMvpDraft? mvpDraft,
    PenaltyShootoutResult? penaltyShootout,
  }) async {
    _assertActor(actorId);
    _assertScoreRange(scoreA: scoreA, scoreB: scoreB);
    _assertAttributedGoalsWithinScore(
      scoreA: scoreA,
      scoreB: scoreB,
      goalDrafts: goalDrafts,
    );
    final remoteResult = await _tryRemoteSubmitScore(
      matchId: matchId,
      actorId: actorId,
      scoreA: scoreA,
      scoreB: scoreB,
      mvpPlayerId: mvpPlayerId,
      detailedStats: detailedStats,
      goalDrafts: goalDrafts,
      mvpDraft: mvpDraft,
      penaltyShootout: penaltyShootout,
    );
    if (remoteResult != null) {
      return remoteResult;
    }
    _assertLocalFallbackAllowed();

    final officialRoster = await _officialRosterService.loadRegisteredRoster(
      matchId: matchId,
    );
    final eligiblePlayerIds = officialRoster.allPlayerIds.toSet();
    final normalizedMvpId = _normalizeOptionalId(mvpPlayerId);
    final participantRoster =
        goalDrafts.isNotEmpty || mvpDraft != null || normalizedMvpId != null
        ? await _officialRosterService.loadParticipantRoster(matchId: matchId)
        : null;
    _assertPrideActorsInRoster(
      roster: participantRoster,
      goalDrafts: goalDrafts,
      mvpDraft: mvpDraft,
      legacyMvpId: normalizedMvpId,
    );
    final effectiveMvpId = normalizedMvpId;
    final officialDetailedStats = detailedStats
        .where((stats) => eligiblePlayerIds.contains(stats.playerId))
        .toList(growable: false);
    final activeEvents = await _loadActiveMatchEvents(matchId);

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
      final knockoutDecision = _resolveKnockoutSubmission(
        match: rawMatch,
        scoreA: scoreA,
        scoreB: scoreB,
        penaltyShootout: penaltyShootout,
      );
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
        penaltyScoreTeamA: penaltyShootout?.scoreTeamA,
        penaltyScoreTeamB: penaltyShootout?.scoreTeamB,
        knockoutDecision: knockoutDecision,
        mvpPlayerId: effectiveMvpId,
        prideEventsPending: false,
        completedAt: submittedAt,
        isAnomaly: isAnomaly,
        status: isAnomaly ? MatchStatus.pendingReview : MatchStatus.completed,
      );

      transaction.update(matchRef, {
        'scoreTeamA': scoreA,
        'scoreTeamB': scoreB,
        'penaltyScoreTeamA': penaltyShootout?.scoreTeamA,
        'penaltyScoreTeamB': penaltyShootout?.scoreTeamB,
        'knockoutDecision': knockoutDecision?.name,
        'mvpPlayerId': effectiveMvpId,
        'prideEventsPending': false,
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
      _writePrideEvents(
        transaction: transaction,
        match: updatedMatch,
        activeEvents: activeEvents,
        goalDrafts: goalDrafts,
        mvpDraft: mvpDraft,
        actorId: actorId,
        createdAt: submittedAt,
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
    final remoteResult = await _tryRemoteApproveScore(
      matchId: matchId,
      actorId: actorId,
    );
    if (remoteResult != null) {
      return remoteResult;
    }
    _assertLocalFallbackAllowed();

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
      final knockoutDecision = _resolveKnockoutApproval(match);

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

      final matchUpdates = <String, dynamic>{
        'status': MatchStatus.settled.name,
        'isAnomaly': false,
        'ratingsAppliedAt': settledAt.millisecondsSinceEpoch,
      };
      if (knockoutDecision != null) {
        matchUpdates['knockoutDecision'] = knockoutDecision.name;
      }
      transaction.update(matchRef, matchUpdates);
      transaction.set(
        _firestore
            .collection(FirebasePaths.auditEvents)
            .doc(
              'match-score-approved::$matchId::${settledAt.millisecondsSinceEpoch}',
            ),
        {
          'entityType': 'match',
          'entityId': matchId,
          'action': 'matchScoreApproved',
          'actorId': actorId,
          'beforePayload': null,
          'afterPayload': {
            'status': MatchStatus.settled.name,
            'scoreTeamA': match.scoreTeamA,
            'scoreTeamB': match.scoreTeamB,
            'penaltyScoreTeamA': match.penaltyScoreTeamA,
            'penaltyScoreTeamB': match.penaltyScoreTeamB,
            'knockoutDecision': knockoutDecision?.name,
          },
          'metadata': {
            'tournamentId': match.tournamentId,
            'knockoutTieId': match.knockoutTieId,
            'knockoutResolution': match.knockoutResolution?.name,
          },
          'createdAt': settledAt.millisecondsSinceEpoch,
        },
      );
      tournamentMatch = match.copyWith(
        status: MatchStatus.settled,
        knockoutDecision: knockoutDecision,
      );

      return MatchSettlementResult(
        status: MatchStatus.settled,
        ratingsApplied: canApplyRatingDeltas,
      );
    });
    await _refreshTournamentProgress(match: tournamentMatch);
    return result;
  }

  Future<MatchSettlementResult?> _tryRemoteSubmitScore({
    required String matchId,
    required String actorId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
    required List<PlayerMatchStats> detailedStats,
    required List<MatchSettlementGoalDraft> goalDrafts,
    required MatchSettlementMvpDraft? mvpDraft,
    required PenaltyShootoutResult? penaltyShootout,
  }) async {
    final response = await _cloudSensitiveOps.submitMatchSettlement({
      'matchId': matchId,
      'actorId': actorId,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'penaltyScoreTeamA': penaltyShootout?.scoreTeamA,
      'penaltyScoreTeamB': penaltyShootout?.scoreTeamB,
      'mvpPlayerId': mvpPlayerId,
      'detailedStats': detailedStats.map(_playerMatchStatsToMap).toList(),
      'goals': goalDrafts.map(_goalDraftToMap).toList(),
      'mvp': mvpDraft == null ? null : _mvpDraftToMap(mvpDraft),
    });
    return _parseRemoteSettlementResult(response);
  }

  Future<MatchSettlementResult?> _tryRemoteApproveScore({
    required String matchId,
    required String actorId,
  }) async {
    final response = await _cloudSensitiveOps.approveMatchScore({
      'matchId': matchId,
      'actorId': actorId,
    });
    return _parseRemoteSettlementResult(response);
  }

  MatchSettlementResult? _parseRemoteSettlementResult(
    Map<String, dynamic>? response,
  ) {
    if (response == null || response.isEmpty) {
      return null;
    }

    final rawStatus = response['status'];
    if (rawStatus is! String || rawStatus.trim().isEmpty) {
      throw StateError('استجابة خادم نتائج المباراة لا تحتوي على حالة صالحة.');
    }
    final normalizedStatus = rawStatus.trim();
    final matchingStatuses = MatchStatus.values.where(
      (candidate) => candidate.name == normalizedStatus,
    );
    if (matchingStatuses.isEmpty) {
      throw StateError(
        'استجابة خادم نتائج المباراة تحتوي على حالة غير معروفة: '
        '$normalizedStatus.',
      );
    }
    final status = matchingStatuses.single;

    return MatchSettlementResult(
      status: status,
      ratingsApplied: response['ratingsApplied'] as bool? ?? false,
      alreadySettled: response['alreadySettled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _playerMatchStatsToMap(PlayerMatchStats stats) {
    return {
      'playerId': stats.playerId,
      'matchId': stats.matchId,
      'teamId': stats.teamId,
      'played': stats.played,
      'position': stats.position.name,
      'goals': stats.goals,
      'assists': stats.assists,
      'saves': stats.saves,
      'tackles': stats.tackles,
      'cleanSheet': stats.cleanSheet,
      'yellowCard': stats.yellowCard,
      'redCard': stats.redCard,
      'rating': stats.rating,
    };
  }

  Map<String, dynamic> _goalDraftToMap(MatchSettlementGoalDraft draft) {
    return {
      'sideKey': draft.sideKey,
      'actor': _participantRefToMap(draft.actor),
      'goals': draft.goals,
      'minute': draft.minute,
    };
  }

  Map<String, dynamic> _mvpDraftToMap(MatchSettlementMvpDraft draft) {
    return {
      'sideKey': draft.sideKey,
      'actor': _participantRefToMap(draft.actor),
    };
  }

  Map<String, dynamic> _participantRefToMap(ParticipantRef participant) {
    return {
      'kind': participant.kind.name,
      'id': participant.id,
      'displayName': participant.displayName,
      'linkedPlayerId': participant.linkedPlayerId,
    };
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadActiveMatchEvents(String matchId) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.matchEvents)
        .where('matchId', isEqualTo: matchId)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs;
  }

  void _writePrideEvents({
    required Transaction transaction,
    required Match match,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeEvents,
    required List<MatchSettlementGoalDraft> goalDrafts,
    required MatchSettlementMvpDraft? mvpDraft,
    required String actorId,
    required DateTime createdAt,
  }) {
    for (final event in activeEvents) {
      final eventType = event.data()['eventType'];
      if (eventType == 'goal' ||
          (eventType == 'mvp' &&
              (mvpDraft == null || event.id != _mvpEventId(match.id)))) {
        transaction.update(event.reference, {'status': 'voided'});
      }
    }

    for (final draft in goalDrafts.where((draft) => draft.goals > 0)) {
      for (var index = 1; index <= draft.goals; index += 1) {
        transaction.set(
          _firestore
              .collection(FirebasePaths.matchEvents)
              .doc(_goalEventId(matchId: match.id, draft: draft, index: index)),
          {
            'matchId': match.id,
            'tournamentId': match.tournamentId,
            'eventType': 'goal',
            'sideKey': _sideKey(draft.sideKey),
            'actor': _participantRefToMap(draft.actor),
            'minute': draft.minute,
            'createdBy': actorId,
            'createdAt': createdAt.millisecondsSinceEpoch,
            'status': 'active',
          },
        );
      }
    }

    if (mvpDraft != null) {
      transaction.set(
        _firestore
            .collection(FirebasePaths.matchEvents)
            .doc(_mvpEventId(match.id)),
        {
          'matchId': match.id,
          'tournamentId': match.tournamentId,
          'eventType': 'mvp',
          'sideKey': _sideKey(mvpDraft.sideKey),
          'actor': _participantRefToMap(mvpDraft.actor),
          'minute': null,
          'createdBy': actorId,
          'createdAt': createdAt.millisecondsSinceEpoch,
          'status': 'active',
        },
      );
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

  void _assertLocalFallbackAllowed() {
    if (_allowLocalFallback) {
      return;
    }
    throw StateError(
      'تعذر الوصول لخادم نتائج المباراة. أعد المحاولة بعد التأكد من الاتصال.',
    );
  }

  void _assertPrideActorsInRoster({
    required MatchParticipantRoster? roster,
    required List<MatchSettlementGoalDraft> goalDrafts,
    required MatchSettlementMvpDraft? mvpDraft,
    required String? legacyMvpId,
  }) {
    if (roster == null) {
      return;
    }
    final rosterKeys = roster.allParticipants.map(_participantKey).toSet();
    for (final draft in goalDrafts) {
      if (draft.goals <= 0) {
        continue;
      }
      if (!rosterKeys.contains(_participantKey(draft.actor))) {
        throw StateError('لا يمكن تسجيل هدف للاعب خارج roster المباراة.');
      }
    }
    if (mvpDraft != null) {
      if (!rosterKeys.contains(_participantKey(mvpDraft.actor))) {
        throw StateError('لا يمكن اختيار MVP خارج roster المباراة.');
      }
      return;
    }
    if (legacyMvpId != null &&
        !roster.allParticipants.any(
          (participant) => participant.id == legacyMvpId,
        )) {
      throw StateError('لا يمكن اختيار MVP خارج roster المباراة.');
    }
  }

  String _participantKey(ParticipantRef participant) {
    return '${participant.kind.name}:${participant.id.trim()}';
  }

  String _sideKey(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized != 'A' && normalized != 'B') {
      throw StateError('sideKey must be A or B.');
    }
    return normalized;
  }

  String _mvpEventId(String matchId) => 'mvp-$matchId';

  String _goalEventId({
    required String matchId,
    required MatchSettlementGoalDraft draft,
    required int index,
  }) {
    return [
      'goal',
      _safeEventIdSegment(matchId),
      _sideKey(draft.sideKey),
      draft.actor.kind.name,
      _safeEventIdSegment(draft.actor.id),
      index.toString(),
    ].join('-');
  }

  String _safeEventIdSegment(String value) {
    final encoded = Uri.encodeComponent(value.trim());
    return encoded.isEmpty ? 'unknown' : encoded;
  }

  void _assertActor(String actorId) {
    if (actorId.trim().isEmpty) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }
  }

  void _assertScoreRange({required int scoreA, required int scoreB}) {
    if (scoreA < 0 ||
        scoreA > PenaltyShootoutResult.maxScore ||
        scoreB < 0 ||
        scoreB > PenaltyShootoutResult.maxScore) {
      throw StateError('يجب أن تكون النتيجة بين 0 و99.');
    }
  }

  void _assertAttributedGoalsWithinScore({
    required int scoreA,
    required int scoreB,
    required List<MatchSettlementGoalDraft> goalDrafts,
  }) {
    final totals = <String, int>{'A': 0, 'B': 0};
    for (final draft in goalDrafts) {
      if (draft.goals <= 0) {
        throw StateError('يجب أن يكون عدد الأهداف المنسوبة أكبر من صفر.');
      }
      final sideKey = _sideKey(draft.sideKey);
      totals[sideKey] = totals[sideKey]! + draft.goals;
    }
    if (totals['A']! > scoreA || totals['B']! > scoreB) {
      throw StateError('لا يمكن أن تتجاوز الأهداف المنسوبة النتيجة المسجلة.');
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

  KnockoutDecision? _resolveKnockoutSubmission({
    required Match match,
    required int scoreA,
    required int scoreB,
    required PenaltyShootoutResult? penaltyShootout,
  }) {
    if (match.stageType != TournamentStageType.knockoutStage) {
      if (penaltyShootout != null) {
        throw StateError('ركلات الترجيح متاحة فقط في مباريات الإقصاء.');
      }
      return null;
    }

    if (scoreA != scoreB) {
      if (penaltyShootout != null) {
        throw StateError(
          'لا تُسجل ركلات ترجيح عندما تحسم النتيجة في الوقت الأصلي.',
        );
      }
      return scoreA > scoreB ? KnockoutDecision.teamA : KnockoutDecision.teamB;
    }
    if (penaltyShootout == null || !penaltyShootout.isValid) {
      throw StateError('يجب إدخال نتيجة ركلات ترجيح صحيحة وغير متعادلة.');
    }
    return penaltyShootout.decision;
  }

  KnockoutDecision? _resolveKnockoutApproval(Match match) {
    if (match.scoreTeamA == null || match.scoreTeamB == null) {
      throw StateError('لا يمكن اعتماد مباراة بدون نتيجة');
    }
    _assertScoreRange(scoreA: match.scoreTeamA!, scoreB: match.scoreTeamB!);
    if (match.stageType != TournamentStageType.knockoutStage) {
      if (match.penaltyScoreTeamA != null ||
          match.penaltyScoreTeamB != null ||
          match.knockoutDecision != null) {
        throw StateError('بيانات الحسم الإقصائي غير صالحة لهذه المباراة.');
      }
      return null;
    }

    final decision = match.resolvedKnockoutDecision;
    if (decision == null) {
      throw StateError('لا يمكن اعتماد تعادل إقصائي دون ركلات ترجيح حاسمة.');
    }
    if (match.scoreTeamA != match.scoreTeamB &&
        (match.penaltyScoreTeamA != null || match.penaltyScoreTeamB != null)) {
      throw StateError(
        'لا تُقبل ركلات ترجيح بعد نتيجة محسومة في الوقت الأصلي.',
      );
    }
    return decision;
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
