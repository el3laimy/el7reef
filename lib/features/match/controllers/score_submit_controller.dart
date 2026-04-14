import 'package:get/get.dart';

import '../../../core/enums/match_status.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import 'match_controller.dart';

class ScoreSubmitController extends GetxController {
  final String matchId;
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final PlayerRepositoryImpl _playerRepo = PlayerRepositoryImpl();
  final MatchSettlementService _settlementService = MatchSettlementService();

  ScoreSubmitController({required this.matchId});

  final Rx<Match?> match = Rx<Match?>(null);
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final Map<String, RxMap<String, dynamic>> playerStats = {};
  final RxString selectedMvpId = ''.obs;
  final RxBool teamACleanSheet = false.obs;
  final RxBool teamBCleanSheet = false.obs;

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

      match.value = loadedMatch;
      selectedMvpId.value = loadedMatch.mvpPlayerId ?? '';

      final futuresA =
          loadedMatch.teamAPlayerIds.map((id) => _playerRepo.getPlayer(id));
      final futuresB =
          loadedMatch.teamBPlayerIds.map((id) => _playerRepo.getPlayer(id));

      final resultsA = await Future.wait(futuresA);
      final resultsB = await Future.wait(futuresB);

      teamAPlayers.value = resultsA.whereType<Player>().toList();
      teamBPlayers.value = resultsB.whereType<Player>().toList();

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

  int get totalTeamAGoals => _sumGoals(teamAPlayers);

  int get totalTeamBGoals => _sumGoals(teamBPlayers);

  Future<void> submit() async {
    final currentMatch = match.value;
    if (currentMatch == null) return;

    final scoreA = totalTeamAGoals;
    final scoreB = totalTeamBGoals;

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
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId:
            selectedMvpId.value.isEmpty ? null : selectedMvpId.value,
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
      errorMessage.value = 'فشل حفظ النتيجة: $error';
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
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
