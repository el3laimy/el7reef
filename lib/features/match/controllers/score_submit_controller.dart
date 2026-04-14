import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_match_stats.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/models/player_match_stats_model.dart';
import 'match_controller.dart';

class ScoreSubmitController extends GetxController {
  final Match match;
  final MatchController parentController;
  final PlayerRepositoryImpl _playerRepo;

  ScoreSubmitController({
    required this.match,
    required this.parentController,
  }) : _playerRepo = PlayerRepositoryImpl();

  final RxBool isLoading = true.obs;
  
  // Players data
  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;

  // Stats Maps: playerId -> PlayerMatchStats modifier map
  final Map<String, RxMap<String, dynamic>> playerStats = {};

  final RxString selectedMvpId = ''.obs;
  
  // Global clean sheet by team
  final RxBool teamACleanSheet = false.obs;
  final RxBool teamBCleanSheet = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      isLoading.value = true;
      final futuresA = match.teamAPlayerIds.map((id) => _playerRepo.getPlayer(id));
      final futuresB = match.teamBPlayerIds.map((id) => _playerRepo.getPlayer(id));
      
      final resultsA = await Future.wait(futuresA);
      final resultsB = await Future.wait(futuresB);
      
      teamAPlayers.value = resultsA.whereType<Player>().toList();
      teamBPlayers.value = resultsB.whereType<Player>().toList();

      // Initialize stats map
      for (final p in [...teamAPlayers, ...teamBPlayers]) {
        playerStats[p.id] = <String, dynamic>{
          'goals': 0,
          'assists': 0,
          'saves': 0,
          'yellowCard': false,
          'redCard': false,
          'played': true,
        }.obs;
      }
    } finally {
      isLoading.value = false;
    }
  }

  void incrementStat(String playerId, String key) {
    if (playerStats.containsKey(playerId)) {
      playerStats[playerId]![key] = (playerStats[playerId]![key] as int) + 1;
    }
  }

  void decrementStat(String playerId, String key) {
    if (playerStats.containsKey(playerId)) {
      final current = playerStats[playerId]![key] as int;
      if (current > 0) {
        playerStats[playerId]![key] = current - 1;
      }
    }
  }

  void toggleCard(String playerId, String cardType) {
    if (playerStats.containsKey(playerId)) {
      playerStats[playerId]![cardType] = !(playerStats[playerId]![cardType] as bool);
    }
  }

  int get totalTeamAGoals {
    int sum = 0;
    for (final p in teamAPlayers) {
      sum += (playerStats[p.id]?['goals'] ?? 0) as int;
    }
    return sum;
  }

  int get totalTeamBGoals {
    int sum = 0;
    for (final p in teamBPlayers) {
      sum += (playerStats[p.id]?['goals'] ?? 0) as int;
    }
    return sum;
  }

  Future<void> submit() async {
    final scoreA = totalTeamAGoals;
    final scoreB = totalTeamBGoals;

    // Apply auto clean sheet detection based on score
    if (scoreB == 0) teamACleanSheet.value = true;
    if (scoreA == 0) teamBCleanSheet.value = true;

    // Sync scores to parent controller
    parentController.scoreAController.text = scoreA.toString();
    parentController.scoreBController.text = scoreB.toString();
    parentController.selectedMvpId.value = selectedMvpId.value;

    // Parent submitScore() handles: save score + _applyRatings() (rating + aggregate stats)
    // We must NOT call updateMatchStats() again — only save detailed per-player stats
    await parentController.submitScore(match.id);
    
    // Save detailed stats to subcollection (matches/{matchId}/player_stats/{playerId})
    // WITHOUT incrementing totalMatches/wins/losses again
    isLoading.value = true;
    try {
      for (var p in teamAPlayers) {
        final st = playerStats[p.id]!;
        final detailed = PlayerMatchStats(
          playerId: p.id,
          matchId: match.id,
          teamId: 'A',
          played: st['played'],
          goals: st['goals'],
          assists: st['assists'],
          saves: st['saves'],
          yellowCard: st['yellowCard'],
          redCard: st['redCard'],
          cleanSheet: teamACleanSheet.value,
        );
        // فقط حفظ الإحصائيات التفصيلية — بدون تكرار الـ aggregate stats
        await _saveDetailedStats(detailed);
      }

      for (var p in teamBPlayers) {
        final st = playerStats[p.id]!;
        final detailed = PlayerMatchStats(
          playerId: p.id,
          matchId: match.id,
          teamId: 'B',
          played: st['played'],
          goals: st['goals'],
          assists: st['assists'],
          saves: st['saves'],
          yellowCard: st['yellowCard'],
          redCard: st['redCard'],
          cleanSheet: teamBCleanSheet.value,
        );
        await _saveDetailedStats(detailed);
      }

    } finally {
      isLoading.value = false;
      Get.back();
    }
  }

  /// حفظ الإحصائيات التفصيلية فقط في subcollection بدون تكرار aggregate stats
  Future<void> _saveDetailedStats(PlayerMatchStats stats) async {
    try {
      final statModel = PlayerMatchStatsModel.fromEntity(stats);
      await FirebaseFirestore.instance
          .collection(FirebasePaths.matches)
          .doc(stats.matchId)
          .collection('player_stats')
          .doc(stats.playerId)
          .set(statModel.toJson());
    } catch (e) { AppLogger.error('ScoreSubmitController._saveDetailedStats', e); }
  }
}
