import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/services/match_settlement_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../services/auth_service.dart';

/// كونترولر المباراة — يدير دورة حياة المباراة الكاملة
class MatchController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final MatchSettlementService _settlementService = MatchSettlementService();

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
      isLoading.value = true;
      final result = await _settlementService.approveScore(matchId: matchId);
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
      Get.snackbar('خطأ', 'فشل اعتماد النتيجة');
    } finally {
      isLoading.value = false;
    }
  }
}
