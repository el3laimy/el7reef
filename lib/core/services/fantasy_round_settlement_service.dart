import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/fantasy_league_phase.dart';
import '../../core/enums/match_status.dart';
import '../../data/models/fantasy_league_lifecycle_model.dart';
import '../../data/models/fantasy_round_settlement_marker_model.dart';
import '../../data/models/fantasy_slot_model.dart';
import '../../data/models/fantasy_team_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_match_stats_model.dart';
import '../../data/repositories/fantasy_round_settlement_repository_impl.dart';
import '../../domain/entities/fantasy_chip.dart';
import '../../domain/entities/fantasy_league_lifecycle.dart';
import '../../domain/entities/fantasy_round_settlement_marker.dart';
import '../../domain/entities/fantasy_slot.dart';
import '../../domain/entities/fantasy_team.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/player_match_stats.dart';
import '../../domain/repositories/fantasy_round_settlement_repository.dart';
import 'auto_substitution_engine.dart';
import 'fantasy_lifecycle_service.dart';
import 'fantasy_points_engine.dart';

class FantasyRoundSettlementResult {
  final FantasyRoundSettlementMarker marker;
  final bool alreadySettled;
  final int processedTeamCount;
  final int processedSlotCount;
  final int processedMatchCount;
  final int totalPointsApplied;

  const FantasyRoundSettlementResult({
    required this.marker,
    this.alreadySettled = false,
    required this.processedTeamCount,
    required this.processedSlotCount,
    required this.processedMatchCount,
    required this.totalPointsApplied,
  });
}

class FantasyRoundSettlementService {
  final FirebaseFirestore _firestore;
  final FantasyLifecycleService _lifecycleService;
  final FantasyRoundSettlementRepository _markerRepository;

  FantasyRoundSettlementService({
    FirebaseFirestore? firestore,
    FantasyLifecycleService? lifecycleService,
    FantasyRoundSettlementRepository? markerRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _lifecycleService =
            lifecycleService ?? FantasyLifecycleService(),
        _markerRepository = markerRepository ??
            FantasyRoundSettlementRepositoryImpl(db: firestore);

  Future<FantasyRoundSettlementResult> settleRound({
    required String leagueId,
    String settlementType = 'round_points',
    DateTime? settledAt,
  }) async {
    final effectiveSettledAt = settledAt ?? DateTime.now();
    final lifecycle = await _lifecycleService.resolveLifecycle(
      leagueId,
      now: effectiveSettledAt,
    );

    if (lifecycle.phase == FantasyLeaguePhase.completed ||
        lifecycle.phase == FantasyLeaguePhase.cancelled) {
      throw StateError('لا يمكن تسوية دوري مكتمل أو ملغى.');
    }

    final existingMarker = await _markerRepository.getSettlementMarker(
      leagueId: leagueId,
      gameweek: lifecycle.currentGameweek,
      settlementType: settlementType,
    );
    if (existingMarker != null) {
      return FantasyRoundSettlementResult(
        marker: existingMarker,
        alreadySettled: true,
        processedTeamCount: existingMarker.processedTeamCount,
        processedSlotCount: existingMarker.processedSlotCount,
        processedMatchCount: existingMarker.processedMatchCount,
        totalPointsApplied: existingMarker.totalPointsApplied,
      );
    }

    final roundStartedAt = _resolveRoundStartAt(
      lifecycle: lifecycle,
      settledAt: effectiveSettledAt,
    );
    final relevantMatches = await _loadRelevantMatches(
      leagueId: leagueId,
      roundStartedAt: roundStartedAt,
      roundEndedAt: effectiveSettledAt,
    );
    final roundData = await _loadRoundData(relevantMatches);
    final teams = await _loadLeagueTeams(leagueId);
    final teamSlots = await _loadTeamSlots(teams);
    final settlement = _buildSettlement(
      teams: teams,
      teamSlots: teamSlots,
      lifecycle: lifecycle,
      settledAt: effectiveSettledAt,
      roundStartedAt: roundStartedAt,
      relevantMatches: relevantMatches,
      roundData: roundData,
      settlementType: settlementType,
    );

    await _persistSettlement(
      lifecycle: lifecycle,
      updatedLifecycle: lifecycle.copyWith(
        phase: FantasyLeaguePhase.settled,
        settledAt: effectiveSettledAt,
        isLocked: true,
        updatedAt: effectiveSettledAt,
      ),
      updatedTeams: settlement.updatedTeams,
      updatedSlots: settlement.updatedSlots,
      marker: settlement.marker,
    );

    return FantasyRoundSettlementResult(
      marker: settlement.marker,
      processedTeamCount: settlement.marker.processedTeamCount,
      processedSlotCount: settlement.marker.processedSlotCount,
      processedMatchCount: settlement.marker.processedMatchCount,
      totalPointsApplied: settlement.marker.totalPointsApplied,
    );
  }

  DateTime _resolveRoundStartAt({
    required FantasyLeagueLifecycle lifecycle,
    required DateTime settledAt,
  }) {
    final candidate = lifecycle.openedAt ?? lifecycle.updatedAt;
    if (candidate.isAfter(settledAt)) {
      return settledAt;
    }
    return candidate;
  }

  Future<List<FantasyTeam>> _loadLeagueTeams(String leagueId) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.fantasyTeams)
        .where('leagueIds', arrayContains: leagueId)
        .get();

    return snapshot.docs
        .map(
          (doc) => FantasyTeamModel.fromJson(
            doc.data(),
            doc.id,
          ).toEntity(),
        )
        .toList(growable: false);
  }

  Future<Map<String, List<FantasySlot>>> _loadTeamSlots(
    List<FantasyTeam> teams,
  ) async {
    final result = <String, List<FantasySlot>>{};
    for (final team in teams) {
      final snapshot = await _firestore
          .collection(FirebasePaths.fantasySlots)
          .where('fantasyTeamId', isEqualTo: team.id)
          .get();
      result[team.id] = snapshot.docs
          .map(
            (doc) => FantasySlotModel.fromJson(
              doc.data(),
              doc.id,
            ).toEntity(),
          )
          .toList(growable: false);
    }
    return result;
  }

  Future<List<Match>> _loadRelevantMatches({
    required String leagueId,
    required DateTime roundStartedAt,
    required DateTime roundEndedAt,
  }) async {
    final snapshot = await _firestore
        .collection(FirebasePaths.matches)
        .where('status', isEqualTo: MatchStatus.settled.name)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromJson(doc.data(), doc.id).toEntity())
        .where((match) {
          final completedAt = match.completedAt;
          if (completedAt == null) {
            return false;
          }
          if (completedAt.isBefore(roundStartedAt) ||
              completedAt.isAfter(roundEndedAt)) {
            return false;
          }
          if (leagueId == 'global') {
            return true;
          }
          return match.tournamentId == leagueId;
        })
        .toList(growable: false);
  }

  Future<_RoundData> _loadRoundData(List<Match> matches) async {
    final statsByPlayerId = <String, List<PlayerMatchStats>>{};
    final mvpAwards = <String, Set<String>>{};
    final doubleAwards = <String, Set<String>>{};

    for (final match in matches) {
      final statsSnapshot = await _firestore
          .collection(FirebasePaths.matches)
          .doc(match.id)
          .collection('player_stats')
          .get();
      for (final doc in statsSnapshot.docs) {
        final stats = PlayerMatchStatsModel.fromJson(doc.data(), doc.id).toEntity();
        statsByPlayerId.putIfAbsent(stats.playerId, () => <PlayerMatchStats>[])
            .add(stats);
      }

      final mvpPlayerId = match.mvpPlayerId;
      if (mvpPlayerId != null && mvpPlayerId.isNotEmpty) {
        mvpAwards.putIfAbsent(mvpPlayerId, () => <String>{}).add(match.id);
      }

      final fanVotingSnapshot = await _firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc(match.id)
          .get();
      final fanWinnerId = fanVotingSnapshot.data()?['winnerPlayerId'] as String?;
      if (mvpPlayerId != null &&
          fanWinnerId != null &&
          fanWinnerId.isNotEmpty &&
          fanWinnerId == mvpPlayerId) {
        doubleAwards.putIfAbsent(mvpPlayerId, () => <String>{}).add(match.id);
      }
    }

    return _RoundData(
      statsByPlayerId: statsByPlayerId,
      mvpAwards: mvpAwards,
      doubleAwards: doubleAwards,
    );
  }

  _SettlementBuild _buildSettlement({
    required List<FantasyTeam> teams,
    required Map<String, List<FantasySlot>> teamSlots,
    required FantasyLeagueLifecycle lifecycle,
    required DateTime settledAt,
    required DateTime roundStartedAt,
    required List<Match> relevantMatches,
    required _RoundData roundData,
    required String settlementType,
  }) {
    final updatedTeams = <FantasyTeam>[];
    final updatedSlots = <FantasySlot>[];
    var totalPointsApplied = 0;

    for (final team in teams) {
      final slots = teamSlots[team.id] ?? const <FantasySlot>[];
      final benchBoostActive = team.hasActiveChip(
        ChipType.benchBoost,
        gameweek: lifecycle.currentGameweek,
      );
      final tripleCaptainActive = team.hasActiveChip(
        ChipType.tripleCaptain,
        gameweek: lifecycle.currentGameweek,
      );
      final aggregateStatsByPlayerId = _buildAggregateStatsByPlayerId(
        slots: slots,
        roundData: roundData,
      );
      final effectiveSlots = benchBoostActive
          ? List<FantasySlot>.from(slots)
          : AutoSubstitutionEngine.processAutoSubstitutions(
              currentSlots: slots,
              roundStats: aggregateStatsByPlayerId,
            );
      final captainTargetPlayerId = _resolveCaptainTargetPlayerId(
        slots: effectiveSlots,
        aggregateStatsByPlayerId: aggregateStatsByPlayerId,
      );

      final roundPointsBySlotId = <String, int>{};
      var teamRoundPoints = 0;

      for (final slot in effectiveSlots) {
        if (!slot.isStartingXI && !benchBoostActive) {
          roundPointsBySlotId[slot.id] = 0;
          continue;
        }

        final basePoints = _calculateBasePointsForSlot(
          slot: slot,
          roundData: roundData,
        );
        final finalPoints = _applyEffectiveMultiplier(
          slot: slot,
          basePoints: basePoints,
          captainTargetPlayerId: captainTargetPlayerId,
          tripleCaptainActive: tripleCaptainActive,
        );
        roundPointsBySlotId[slot.id] = finalPoints;
        teamRoundPoints += finalPoints;
      }

      totalPointsApplied += teamRoundPoints;
      updatedTeams.add(
        team.copyWith(
          currentGameweekPoints: teamRoundPoints,
          totalPoints: team.totalPoints + teamRoundPoints,
          updatedAt: settledAt,
        ),
      );
      updatedSlots.addAll(
        effectiveSlots.map(
          (slot) => slot.copyWith(
            pointsEarned: slot.pointsEarned + (roundPointsBySlotId[slot.id] ?? 0),
          ),
        ),
      );
    }

    final marker = FantasyRoundSettlementMarker(
      id: FantasyRoundSettlementMarker.buildId(
        leagueId: lifecycle.leagueId,
        gameweek: lifecycle.currentGameweek,
        settlementType: settlementType,
      ),
      leagueId: lifecycle.leagueId,
      gameweek: lifecycle.currentGameweek,
      settlementType: settlementType,
      roundStartedAt: roundStartedAt,
      roundEndedAt: settledAt,
      settledAt: settledAt,
      processedMatchIds: relevantMatches.map((match) => match.id).toList(),
      processedTeamIds: updatedTeams.map((team) => team.id).toList(),
      processedMatchCount: relevantMatches.length,
      processedTeamCount: updatedTeams.length,
      processedSlotCount: updatedSlots.length,
      totalPointsApplied: totalPointsApplied,
    );

    return _SettlementBuild(
      updatedTeams: updatedTeams,
      updatedSlots: updatedSlots,
      marker: marker,
    );
  }

  Map<String, PlayerMatchStats> _buildAggregateStatsByPlayerId({
    required List<FantasySlot> slots,
    required _RoundData roundData,
  }) {
    final result = <String, PlayerMatchStats>{};
    for (final slot in slots) {
      final playerStats = roundData.statsByPlayerId[slot.playerId] ?? const [];
      if (playerStats.isEmpty) {
        continue;
      }

      final first = playerStats.first;
      result[slot.playerId] = PlayerMatchStats(
        playerId: slot.playerId,
        matchId: first.matchId,
        teamId: first.teamId,
        played: playerStats.any((stats) => stats.played),
        position: first.position,
        goals: playerStats.fold(0, (total, stats) => total + stats.goals),
        assists: playerStats.fold(0, (total, stats) => total + stats.assists),
        saves: playerStats.fold(0, (total, stats) => total + stats.saves),
        tackles: playerStats.fold(0, (total, stats) => total + stats.tackles),
        cleanSheet: playerStats.any((stats) => stats.cleanSheet),
        yellowCard: playerStats.any((stats) => stats.yellowCard),
        redCard: playerStats.any((stats) => stats.redCard),
        rating: playerStats.isEmpty
            ? 0
            : playerStats
                    .map((stats) => stats.rating)
                    .reduce((a, b) => a + b) /
                playerStats.length,
      );
    }
    return result;
  }

  String? _resolveCaptainTargetPlayerId({
    required List<FantasySlot> slots,
    required Map<String, PlayerMatchStats> aggregateStatsByPlayerId,
  }) {
    FantasySlot? captainSlot;
    FantasySlot? viceCaptainSlot;

    for (final slot in slots) {
      if (slot.role == FantasyPlayerRole.captain) {
        captainSlot = slot;
      } else if (slot.role == FantasyPlayerRole.viceCaptain) {
        viceCaptainSlot = slot;
      }
    }

    if (captainSlot != null &&
        (aggregateStatsByPlayerId[captainSlot.playerId]?.played ?? false)) {
      return captainSlot.playerId;
    }

    if (viceCaptainSlot != null &&
        viceCaptainSlot.isStartingXI &&
        (aggregateStatsByPlayerId[viceCaptainSlot.playerId]?.played ?? false)) {
      return viceCaptainSlot.playerId;
    }

    return null;
  }

  int _calculateBasePointsForSlot({
    required FantasySlot slot,
    required _RoundData roundData,
  }) {
    final playerStats = roundData.statsByPlayerId[slot.playerId] ?? const [];
    var basePoints = 0;
    for (final stats in playerStats) {
      final isDoubleAward =
          roundData.doubleAwards[slot.playerId]?.contains(stats.matchId) ??
              false;
      final isMvp =
          roundData.mvpAwards[slot.playerId]?.contains(stats.matchId) ?? false;
      basePoints += FantasyPointsEngine.calculateFantasyPoints(
        stats,
        isMvp: isMvp,
        isDoubleAward: isDoubleAward,
      );
    }
    return basePoints;
  }

  int _applyEffectiveMultiplier({
    required FantasySlot slot,
    required int basePoints,
    required String? captainTargetPlayerId,
    required bool tripleCaptainActive,
  }) {
    if (captainTargetPlayerId == null || slot.playerId != captainTargetPlayerId) {
      return basePoints;
    }

    return FantasyPointsEngine.applyRoleMultiplier(
      basePoints,
      FantasyPlayerRole.captain,
      isTripleCaptain: tripleCaptainActive,
    );
  }

  Future<void> _persistSettlement({
    required FantasyLeagueLifecycle lifecycle,
    required FantasyLeagueLifecycle updatedLifecycle,
    required List<FantasyTeam> updatedTeams,
    required List<FantasySlot> updatedSlots,
    required FantasyRoundSettlementMarker marker,
  }) async {
    final markerRef = _firestore
        .collection(FirebasePaths.fantasyRoundSettlements)
        .doc(marker.id);
    final lifecycleRef = _firestore
        .collection(FirebasePaths.fantasyLeagues)
        .doc(lifecycle.leagueId);

    await _firestore.runTransaction((transaction) async {
      final existingMarker = await transaction.get(markerRef);
      if (existingMarker.exists) {
        return;
      }

      transaction.set(
        markerRef,
        FantasyRoundSettlementMarkerModel.fromEntity(marker).toJson(),
      );
      transaction.set(
        lifecycleRef,
        FantasyLeagueLifecycleModel.fromEntity(updatedLifecycle).toJson(),
      );

      for (final team in updatedTeams) {
        final teamRef = _firestore
            .collection(FirebasePaths.fantasyTeams)
            .doc(team.id);
        transaction.update(
          teamRef,
          FantasyTeamModel.fromEntity(team).toJson(),
        );
      }

      for (final slot in updatedSlots) {
        final slotRef = _firestore
            .collection(FirebasePaths.fantasySlots)
            .doc(slot.id);
        transaction.update(
          slotRef,
          FantasySlotModel.fromEntity(slot).toJson(),
        );
      }
    });
  }
}

class _RoundData {
  final Map<String, List<PlayerMatchStats>> statsByPlayerId;
  final Map<String, Set<String>> mvpAwards;
  final Map<String, Set<String>> doubleAwards;

  const _RoundData({
    required this.statsByPlayerId,
    required this.mvpAwards,
    required this.doubleAwards,
  });
}

class _SettlementBuild {
  final List<FantasyTeam> updatedTeams;
  final List<FantasySlot> updatedSlots;
  final FantasyRoundSettlementMarker marker;

  const _SettlementBuild({
    required this.updatedTeams,
    required this.updatedSlots,
    required this.marker,
  });
}
