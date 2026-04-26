import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/services/match_cancellation_service.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/services/match_start_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../services/auth_service.dart';

/// كونترولر المباراة — يدير دورة حياة المباراة الكاملة
class MatchController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final MatchCancellationService _cancellationService =
      MatchCancellationService();
  final MatchSettlementService _settlementService = MatchSettlementService();
  late final MatchStartService _matchStartService = MatchStartService(
    matchRepo: _matchRepo,
    snapshotRepo: MatchLineupSnapshotRepositoryImpl(),
    sidePlayerRepo: MatchSidePlayerRepositoryImpl(),
  );

  /// المستخدم الحالي — للتحقق من صلاحيات المنظم في الـ Views
  AuthService get authService => _authService;

  // ── State ──
  final RxList<Match> liveMatches = <Match>[].obs;
  final RxList<Match> myMatches = <Match>[].obs;
  final Rx<Match?> currentMatch = Rx<Match?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

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
    } catch (e) {
      AppLogger.error('MatchController.loadMyMatches', e);
    }
  }

  /// إنشاء مباراة جديدة
  Future<String?> createMatch({
    required List<String> teamAIds,
    required List<String> teamBIds,
    String? teamAId,
    String? teamBId,
    String? location,
    double? lat,
    double? lng,
    bool isOrganized = false,
    String? tournamentId,
    int? teamSize,
  }) async {
    final uid = _authService.currentUserId;
    if (uid == null) return null;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final now = DateTime.now();
      final match = Match(
        id: const Uuid().v4(),
        organizerId: uid,
        teamAPlayerIds: teamAIds,
        teamBPlayerIds: teamBIds,
        teamAId: teamAId,
        teamBId: teamBId,
        status: MatchStatus.open,
        location: location,
        latitude: lat,
        longitude: lng,
        teamSize: normalizeMatchTeamSize(teamSize),
        isOrganized: isOrganized,
        tournamentId: tournamentId,
        createdAt: now,
      );

      await _matchRepo.createMatch(match);
      currentMatch.value = match;
      liveMatches.insert(0, match);

      Get.snackbar(
        'تم ✅',
        'تم إنشاء المباراة!',
        snackPosition: SnackPosition.BOTTOM,
      );
      return match.id;
    } catch (e) {
      errorMessage.value = 'فشل إنشاء المباراة: $e';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// ── صلاحيات المنظم ──

  /// تجميد مباراة
  Future<void> freezeMatch(String matchId) async {
    try {
      await _matchRepo.freezeMatch(matchId);
      Get.snackbar(
        'تم التجميد 🔒',
        'تم تجميد المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );
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
      Get.snackbar(
        'تم الرفع 🔓',
        'تم رفع تجميد المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchController.unfreezeMatch', e);
      Get.snackbar('خطأ', 'فشل رفع التجميد');
    }
  }

  /// تفعيل التقييم الذهبي
  Future<void> activateGoldenRating(String matchId) async {
    try {
      await _matchRepo.activateGoldenRating(matchId);
      Get.snackbar(
        'تقييم ذهبي ⭐',
        'تم تفعيل التقييم المضاعف',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchController.activateGoldenRating', e);
      Get.snackbar('خطأ', 'فشل تفعيل التقييم الذهبي');
    }
  }

  /// اعتماد النتيجة من المنظم
  Future<void> approveScore(String matchId) async {
    final actorId = _authService.currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    try {
      isLoading.value = true;
      final result = await _settlementService.approveScore(
        matchId: matchId,
        actorId: actorId,
      );
      await loadLiveMatches();
      await loadMyMatches();

      if (result.alreadySettled) {
        Get.snackbar(
          'مُعتمدة بالفعل',
          'تم اعتماد هذه المباراة مسبقاً.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'تم الاعتماد ✅',
          'تمت تسوية النتيجة والتقييمات بنجاح.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      AppLogger.error('MatchController.approveScore', e);
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// إلغاء مباراة (soft-delete)
  Future<void> cancelMatch(String matchId, {String? reason}) async {
    final actorId = _authService.currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    try {
      await _cancellationService.cancelFriendlyMatch(
        matchId: matchId,
        actorId: actorId,
        reason: reason,
      );
      liveMatches.removeWhere((m) => m.id == matchId);
      myMatches.removeWhere((m) => m.id == matchId);
      Get.snackbar(
        'تم الإلغاء ❌',
        'تم إلغاء المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchController.cancelMatch', e);
      Get.snackbar('خطأ', _readableError(e));
    }
  }

  /// بدء المباراة (open → live)
  Future<void> startMatch(String matchId) async {
    final actorId = _authService.currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    try {
      await _matchStartService.startMatch(matchId: matchId, actorId: actorId);
      await loadLiveMatches();
      Get.snackbar(
        'بدأت المباراة ⚽',
        'تم بدء المباراة!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchController.startMatch', e);
      Get.snackbar('خطأ', _readableError(e));
    }
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

  /// إضافة لاعب لمباراة
  Future<void> addPlayer(String matchId, String playerId, String side) async {
    try {
      await _matchRepo.addPlayerToMatch(
        matchId: matchId,
        playerId: playerId,
        side: side,
      );
    } catch (e) {
      AppLogger.error('MatchController.addPlayer', e);
      Get.snackbar('خطأ', 'فشل إضافة اللاعب');
    }
  }

  /// إزالة لاعب من مباراة
  Future<void> removePlayer(
    String matchId,
    String playerId,
    String side,
  ) async {
    try {
      await _matchRepo.removePlayerFromMatch(
        matchId: matchId,
        playerId: playerId,
        side: side,
      );
    } catch (e) {
      AppLogger.error('MatchController.removePlayer', e);
      Get.snackbar('خطأ', 'فشل إزالة اللاعب');
    }
  }
}
