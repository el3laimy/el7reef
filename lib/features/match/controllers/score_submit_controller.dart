import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/services/official_match_roster_service.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import '../../../domain/entities/team.dart';
import '../../../services/auth_service.dart';
import '../models/friendly_match_side_view.dart';
import 'match_controller.dart';

class ScoreSubmitController extends GetxController {
  final String matchId;
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final MatchSettlementService _settlementService = MatchSettlementService();
  final OfficialMatchRosterService _officialRosterService =
      OfficialMatchRosterService();
  final MatchSideRepositoryImpl _sideRepository = MatchSideRepositoryImpl();
  final MatchSidePlayerRepositoryImpl _sidePlayerRepository =
      MatchSidePlayerRepositoryImpl();
  final TeamRepositoryImpl _teamRepository = TeamRepositoryImpl();
  final AuthService _authService = Get.find<AuthService>();

  ScoreSubmitController({required this.matchId});

  final Rx<Match?> match = Rx<Match?>(null);
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final RxString teamASideName = 'فريق A'.obs;
  final RxString teamBSideName = 'فريق B'.obs;
  final Map<String, RxMap<String, dynamic>> playerStats = {};
  final RxString selectedMvpId = ''.obs;
  final RxBool teamACleanSheet = false.obs;
  final RxBool teamBCleanSheet = false.obs;
  final TextEditingController teamAScoreController = TextEditingController();
  final TextEditingController teamBScoreController = TextEditingController();

  bool get isFriendlyMatch => match.value?.tournamentId == null;

  @override
  void onInit() {
    super.onInit();
    _loadMatchAndPlayers();
  }

  Future<void> _loadMatchAndPlayers() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedMatch = await _matchRepo.getMatch(matchId);
      if (loadedMatch == null) {
        errorMessage.value = 'تعذر العثور على المباراة';
        return;
      }
      if (loadedMatch.status == MatchStatus.cancelled) {
        errorMessage.value = 'هذه المباراة ملغاة ولا يمكن تسجيل نتيجة لها.';
        return;
      }

      match.value = loadedMatch;
      selectedMvpId.value = loadedMatch.mvpPlayerId ?? '';
      teamAScoreController.text = loadedMatch.scoreTeamA?.toString() ?? '';
      teamBScoreController.text = loadedMatch.scoreTeamB?.toString() ?? '';
      await _loadFriendlySideNames(loadedMatch);

      final roster = await _officialRosterService.loadRegisteredRoster(
        matchId: loadedMatch.id,
        match: loadedMatch,
      );
      teamAPlayers.value = roster.teamAPlayers;
      teamBPlayers.value = roster.teamBPlayers;

      for (final player in [...teamAPlayers, ...teamBPlayers]) {
        playerStats[player.id] = <String, dynamic>{
          'goals': 0,
          'assists': 0,
          'saves': 0,
          'yellowCard': false,
          'redCard': false,
          'played': true,
        }.obs;
      }
    } catch (error) {
      errorMessage.value = 'حدث خطأ أثناء تحميل المباراة: $error';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    teamAScoreController.dispose();
    teamBScoreController.dispose();
    super.onClose();
  }

  void incrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![key] = (playerStats[playerId]![key] as int) + 1;
  }

  void decrementStat(String playerId, String key) {
    if (!playerStats.containsKey(playerId)) return;
    final current = playerStats[playerId]![key] as int;
    if (current > 0) {
      playerStats[playerId]![key] = current - 1;
    }
  }

  void toggleCard(String playerId, String cardType) {
    if (!playerStats.containsKey(playerId)) return;
    playerStats[playerId]![cardType] =
        !(playerStats[playerId]![cardType] as bool);
  }

  int get totalTeamAGoals => isFriendlyMatch
      ? _parsedTeamScore(teamAScoreController.text) ?? 0
      : _sumGoals(teamAPlayers);

  int get totalTeamBGoals => isFriendlyMatch
      ? _parsedTeamScore(teamBScoreController.text) ?? 0
      : _sumGoals(teamBPlayers);

  Future<void> submit() async {
    final currentMatch = match.value;
    if (currentMatch == null) return;
    final actorId = _authService.currentUserId;
    if (actorId == null || actorId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً لتسجيل النتيجة.';
      Get.snackbar(
        'غير مسموح',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final scoreA = isFriendlyMatch
        ? _validatedFriendlyScore(
            teamAScoreController.text,
            teamASideName.value,
          )
        : totalTeamAGoals;
    if (scoreA == null) return;
    final scoreB = isFriendlyMatch
        ? _validatedFriendlyScore(
            teamBScoreController.text,
            teamBSideName.value,
          )
        : totalTeamBGoals;
    if (scoreB == null) return;

    teamACleanSheet.value = scoreB == 0;
    teamBCleanSheet.value = scoreA == 0;

    final detailedStats = <PlayerMatchStats>[
      ...teamAPlayers.map(
        (player) => _buildDetailedStats(
          player: player,
          teamId: currentMatch.teamAId ?? 'A',
          cleanSheet: teamACleanSheet.value,
        ),
      ),
      ...teamBPlayers.map(
        (player) => _buildDetailedStats(
          player: player,
          teamId: currentMatch.teamBId ?? 'B',
          cleanSheet: teamBCleanSheet.value,
        ),
      ),
    ];

    try {
      isLoading.value = true;
      final result = await _settlementService.submitScore(
        matchId: currentMatch.id,
        actorId: actorId,
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId: selectedMvpId.value.isEmpty ? null : selectedMvpId.value,
        detailedStats: detailedStats,
      );

      if (Get.isRegistered<MatchController>()) {
        await Get.find<MatchController>().loadLiveMatches();
        await Get.find<MatchController>().loadMyMatches();
      }

      if (result.status == MatchStatus.pendingReview) {
        Get.snackbar(
          'تحت المراجعة',
          'تم حفظ النتيجة، لكنها تحتاج مراجعة بسبب الشذوذ الظاهر.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'تم الحفظ',
          'تم تسجيل النتيجة وفتح تصويت الجماهير قبل الاعتماد النهائي.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      Get.back();
    } catch (error) {
      errorMessage.value = 'فشل حفظ النتيجة: ${_readableError(error)}';
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFriendlySideNames(Match loadedMatch) async {
    if (loadedMatch.tournamentId != null) {
      teamASideName.value = 'فريق A';
      teamBSideName.value = 'فريق B';
      return;
    }
    final teamIds = <String>[
      if (loadedMatch.teamAId != null && loadedMatch.teamAId!.isNotEmpty)
        loadedMatch.teamAId!,
      if (loadedMatch.teamBId != null && loadedMatch.teamBId!.isNotEmpty)
        loadedMatch.teamBId!,
    ];
    final results = await Future.wait<dynamic>([
      _teamRepository.getTeamsByIds(teamIds),
      _sideRepository.getMatchSides(loadedMatch.id),
      _sidePlayerRepository.getMatchPlayers(loadedMatch.id),
    ]);
    final teams = results[0] as List<Team>;
    final sides = results[1] as List<MatchSide>;
    final sidePlayers = results[2] as List<MatchSidePlayer>;
    final sideViews = FriendlyMatchSideView.fromMatch(
      match: loadedMatch,
      teamsById: {for (final team in teams) team.id: team},
      sides: sides,
      sidePlayers: sidePlayers,
    );
    for (final side in sideViews) {
      if (side.sideKey == 'A') {
        teamASideName.value = side.displayName;
      } else if (side.sideKey == 'B') {
        teamBSideName.value = side.displayName;
      }
    }
  }

  int? _validatedFriendlyScore(String rawValue, String sideName) {
    final trimmed = rawValue.trim();
    final parsed = int.tryParse(trimmed);
    if (trimmed.isEmpty || parsed == null || parsed < 0) {
      final message = 'أدخل نتيجة صحيحة وغير سالبة لـ $sideName.';
      errorMessage.value = message;
      Get.snackbar(
        'نتيجة غير صحيحة',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
    return parsed;
  }

  int? _parsedTeamScore(String rawValue) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  String _readableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    return raw;
  }

  PlayerMatchStats _buildDetailedStats({
    required Player player,
    required String teamId,
    required bool cleanSheet,
  }) {
    final stats = playerStats[player.id]!;
    return PlayerMatchStats(
      playerId: player.id,
      matchId: matchId,
      teamId: teamId,
      played: stats['played'] as bool,
      position: _mapPosition(player.position),
      goals: stats['goals'] as int,
      assists: stats['assists'] as int,
      saves: stats['saves'] as int,
      yellowCard: stats['yellowCard'] as bool,
      redCard: stats['redCard'] as bool,
      cleanSheet: cleanSheet,
    );
  }

  MatchPosition _mapPosition(String? position) {
    switch (position) {
      case 'GK':
        return MatchPosition.goalkeeper;
      case 'DEF':
        return MatchPosition.defender;
      case 'MID':
        return MatchPosition.midfielder;
      case 'FWD':
        return MatchPosition.forward;
      default:
        return MatchPosition.mixed;
    }
  }

  int _sumGoals(List<Player> players) {
    var total = 0;
    for (final player in players) {
      total += (playerStats[player.id]?['goals'] ?? 0) as int;
    }
    return total;
  }
}
