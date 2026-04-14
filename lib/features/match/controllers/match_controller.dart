import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/services/rating_engine.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';
import '../../../services/auth_service.dart';

/// كونترولر المباراة — يدير دورة حياة المباراة الكاملة
class MatchController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final PlayerRepositoryImpl _playerRepo = PlayerRepositoryImpl();

  /// المستخدم الحالي — للتحقق من صلاحيات المنظم في الـ Views
  AuthService get authService => _authService;

  // ── State ──
  final RxList<Match> liveMatches = <Match>[].obs;
  final RxList<Match> myMatches = <Match>[].obs;
  final Rx<Match?> currentMatch = Rx<Match?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // ── Score Form ──
  final scoreAController = TextEditingController();
  final scoreBController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final RxString selectedMvpId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadLiveMatches();
    loadMyMatches();
  }

  /// تحميل المباريات المتاحة
  Future<void> loadLiveMatches() async {
    try {
      isLoading.value = true;
      liveMatches.value = await _matchRepo.getLiveMatches();
    } catch (e) {
      AppLogger.error('MatchController.loadLiveMatches', e);
      errorMessage.value = 'فشل تحميل المباريات';
    } finally {
      isLoading.value = false;
    }
  }

  /// تحميل مباراياتي
  Future<void> loadMyMatches() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    try {
      myMatches.value = await _matchRepo.getPlayerMatches(uid);
    } catch (e) { AppLogger.error('MatchController.loadMyMatches', e); }
  }

  /// إنشاء مباراة جديدة
  Future<void> createMatch({
    required List<String> teamAIds,
    required List<String> teamBIds,
    String? location,
    double? lat,
    double? lng,
    bool isOrganized = false,
    String? tournamentId,
  }) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final now = DateTime.now();
      final match = Match(
        id: const Uuid().v4(),
        organizerId: uid,
        teamAPlayerIds: teamAIds,
        teamBPlayerIds: teamBIds,
        status: MatchStatus.live,
        location: location,
        latitude: lat,
        longitude: lng,
        isOrganized: isOrganized,
        tournamentId: tournamentId,
        createdAt: now,
        startedAt: now,
      );

      await _matchRepo.createMatch(match);
      currentMatch.value = match;
      liveMatches.insert(0, match);

      Get.snackbar('تم ✅', 'تم إنشاء المباراة!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      errorMessage.value = 'فشل إنشاء المباراة: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// تسجيل النتيجة
  Future<void> submitScore(String matchId) async {
    if (!formKey.currentState!.validate()) return;

    final scoreA = int.tryParse(scoreAController.text) ?? 0;
    final scoreB = int.tryParse(scoreBController.text) ?? 0;

    // فحص الشذوذ
    final isAnomaly = RatingEngine.isAnomalousResult(
      scoreA: scoreA, scoreB: scoreB,
    );

    try {
      isLoading.value = true;
      await _matchRepo.submitScore(
        matchId: matchId,
        scoreA: scoreA,
        scoreB: scoreB,
        mvpPlayerId: selectedMvpId.value.isNotEmpty ? selectedMvpId.value : null,
      );

      if (isAnomaly) {
        await _matchRepo.updateMatch(
          (await _matchRepo.getMatch(matchId))!
              .copyWith(isAnomaly: true, status: MatchStatus.pendingReview),
        );
        Get.snackbar('⚠️ تحت المراجعة',
            'النتيجة شاذة وتحتاج مراجعة من المنظم',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        // تطبيق التقييمات تلقائياً
        await _applyRatings(matchId, scoreA, scoreB);
        Get.snackbar('تم ✅', 'تم تسجيل النتيجة وتحديث التقييمات!',
            snackPosition: SnackPosition.BOTTOM);
      }

      scoreAController.clear();
      scoreBController.clear();
      selectedMvpId.value = '';
      await loadMyMatches();
    } catch (e) {
      errorMessage.value = 'فشل تسجيل النتيجة: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// ── صلاحيات المنظم ──

  /// تجميد مباراة
  Future<void> freezeMatch(String matchId) async {
    try {
      await _matchRepo.freezeMatch(matchId);
      Get.snackbar('تم التجميد 🔒', 'تم تجميد المباراة',
          snackPosition: SnackPosition.BOTTOM);
      await loadLiveMatches();
    } catch (e) {
      AppLogger.error('MatchController.freezeMatch', e);
      Get.snackbar('خطأ', 'فشل التجميد');
    }
  }

  /// رفع التجميد
  Future<void> unfreezeMatch(String matchId) async {
    try {
      await _matchRepo.unfreezeMatch(matchId);
      Get.snackbar('تم الرفع 🔓', 'تم رفع تجميد المباراة',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchController.unfreezeMatch', e);
      Get.snackbar('خطأ', 'فشل رفع التجميد');
    }
  }

  /// تفعيل التقييم الذهبي
  Future<void> activateGoldenRating(String matchId) async {
    try {
      await _matchRepo.activateGoldenRating(matchId);
      Get.snackbar('تقييم ذهبي ⭐', 'تم تفعيل التقييم المضاعف',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchController.activateGoldenRating', e);
      Get.snackbar('خطأ', 'فشل تفعيل التقييم الذهبي');
    }
  }

  /// اعتماد النتيجة من المنظم
  Future<void> approveScore(String matchId) async {
    try {
      await _matchRepo.approveScore(matchId);
      await _applyRatings(matchId, 0, 0);
      Get.snackbar('تم الاعتماد ✅', 'تمت تسوية النتيجة والتقييمات',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchController.approveScore', e);
      Get.snackbar('خطأ', 'فشل اعتماد النتيجة');
    }
  }

  /// ── تطبيق التقييمات ──
  Future<void> _applyRatings(String matchId, int scoreA, int scoreB) async {
    final match = await _matchRepo.getMatch(matchId);
    if (match == null) return;

    // جلب نتيجة تصويت الجماهير لمعرفة الزميل الفائز جماهيرياً
    String? fanMvpId;
    try {
      final fanSessionData = await FirebaseFirestore.instance.collection(FirebasePaths.fanVotingSessions).doc(matchId).get();
      if (fanSessionData.exists) {
        fanMvpId = fanSessionData.data()?['winnerPlayerId'] as String?;
      }
    } catch (e) { AppLogger.error('MatchController._applyRatings.fanMvp', e); }

    final actualScoreA = match.scoreTeamA ?? scoreA;
    final actualScoreB = match.scoreTeamB ?? scoreB;
    final winner = actualScoreA > actualScoreB ? 'A' : actualScoreB > actualScoreA ? 'B' : 'draw';

    // احسب متوسط تقييم الفريقين
    final teamAPlayers = await _fetchPlayers(match.teamAPlayerIds);
    final teamBPlayers = await _fetchPlayers(match.teamBPlayerIds);

    final avgA = _avgRating(teamAPlayers);
    final avgB = _avgRating(teamBPlayers);

    // طبّق التقييم لكل لاعب
    for (final player in teamAPlayers) {
      final isWin = winner == 'A';
      final isDraw = winner == 'draw';
      final isMvp = match.mvpPlayerId == player.id;

      final difficulty = RatingEngine.computeDifficultyMultiplier(
        myTeamAvgRating: avgA,
        opponentAvgRating: avgB,
      );

      final delta = RatingEngine.calculateMatchDelta(
        player: player,
        match: match,
        isWinner: isWin,
        isDraw: isDraw,
        isMvp: isMvp,
        difficultyMultiplier: difficulty,
        recentEncounterCount: 0,
        isFanMvp: fanMvpId == player.id,
      );

      if (!delta.isBlocked) {
        final newRating = (player.rating + delta.delta).clamp(0, 9999);
        await _playerRepo.updateRating(player.id, newRating);
        await _playerRepo.updateMatchStats(
          playerId: player.id,
          isWin: isWin,
          isDraw: isDraw,
          isMvp: isMvp,
        );
      }
    }

    for (final player in teamBPlayers) {
      final isWin = winner == 'B';
      final isDraw = winner == 'draw';
      final isMvp = match.mvpPlayerId == player.id;

      final difficulty = RatingEngine.computeDifficultyMultiplier(
        myTeamAvgRating: avgB,
        opponentAvgRating: avgA,
      );

      final delta = RatingEngine.calculateMatchDelta(
        player: player,
        match: match,
        isWinner: isWin,
        isDraw: isDraw,
        isMvp: isMvp,
        difficultyMultiplier: difficulty,
        recentEncounterCount: 0,
        isFanMvp: fanMvpId == player.id,
      );

      if (!delta.isBlocked) {
        final newRating = (player.rating + delta.delta).clamp(0, 9999);
        await _playerRepo.updateRating(player.id, newRating);
        await _playerRepo.updateMatchStats(
          playerId: player.id,
          isWin: isWin,
          isDraw: isDraw,
          isMvp: isMvp,
        );
      }
    }
  }

  Future<List<Player>> _fetchPlayers(List<String> ids) async {
    final players = <Player>[];
    for (final id in ids) {
      final p = await _playerRepo.getPlayer(id);
      if (p != null) players.add(p);
    }
    return players;
  }

  double _avgRating(List<Player> players) {
    if (players.isEmpty) return 1000;
    return players.map((p) => p.rating).reduce((a, b) => a + b) /
        players.length;
  }

  /// Validators
  String? validateScore(String? value) {
    if (value == null || value.isEmpty) return 'أدخل النتيجة';
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'رقم غير صحيح';
    if (n > 30) return 'النتيجة عالية جداً';
    return null;
  }

  @override
  void onClose() {
    scoreAController.dispose();
    scoreBController.dispose();
    super.onClose();
  }
}
