import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_error_mapper.dart';
import '../../../core/services/cloud_sensitive_ops_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/repositories/player_repository.dart';
import '../../../data/repositories/player_repository_impl.dart';

/// كونترولر البروفايل — يدير عرض وتعديل بيانات اللاعب
class ProfileController extends GetxController {
  final AuthService _authService;
  final PlayerRepository _playerRepo;
  final CloudSensitiveOpsService _cloudSensitiveOps;

  ProfileController({
    AuthService? authService,
    PlayerRepository? playerRepository,
    CloudSensitiveOpsService? cloudSensitiveOps,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _playerRepo = playerRepository ?? PlayerRepositoryImpl(),
       _cloudSensitiveOps = cloudSensitiveOps ?? CloudSensitiveOpsService();

  /// اللاعب الحالي (reactive)
  Rx<Player?> get player => _authService.currentPlayer;

  /// اللاعب الحالي (snapshot)
  Player? get currentPlayer => _authService.currentPlayer.value;

  /// حالة التحميل
  final RxBool isLoading = false.obs;
  final RxBool isDeletingAccount = false.obs;

  /// المركز المختار (للتعديل)
  final RxString selectedPosition = ''.obs;

  /// المراكز المتاحة
  final positions = ['GK', 'DEF', 'MID', 'FWD'];
  final positionLabels = {
    'GK': 'حارس مرمى 🧤',
    'DEF': 'مدافع 🛡️',
    'MID': 'وسط ⚙️',
    'FWD': 'مهاجم ⚡',
  };
  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever(player, (value) {
      if (value == null) {
        resetSessionState();
      } else {
        selectedPosition.value = value.position ?? '';
      }
    });
    selectedPosition.value = player.value?.position ?? '';
  }

  void resetSessionState() {
    isLoading.value = false;
    isDeletingAccount.value = false;
    selectedPosition.value = '';
  }

  /// تحديث المركز
  Future<void> updatePosition(String position) async {
    if (player.value == null) return;
    try {
      isLoading.value = true;
      selectedPosition.value = position;

      final updated = player.value!.copyWith(position: position);
      await _playerRepo.updatePlayer(updated);
      await _authService.refreshProfile();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث المركز');
    } finally {
      isLoading.value = false;
    }
  }

  /// تحديث بيانات البروفايل
  Future<void> refreshProfile() async {
    await _authService.refreshProfile();
  }

  Future<void> updateProfilePhoto({
    required String photoUrl,
    required String photoThumbUrl,
  }) async {
    final current = player.value;
    if (current == null) return;
    await _playerRepo.updatePlayer(
      current.copyWith(photoUrl: photoUrl, photoThumbUrl: photoThumbUrl),
    );
    await refreshProfile();
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _authService.signOut();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<bool> deleteAccount() async {
    if (_authService.currentUserId == null) return false;
    try {
      isDeletingAccount.value = true;
      await _authService.reauthenticateWithGoogle();
      final deleted = await _cloudSensitiveOps.deleteAccountData();
      if (!deleted) {
        throw StateError('account-deletion-service-unavailable');
      }
      await _authService.signOut();
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar(
        'تم قبول طلب الحذف',
        'سيستكمل الحريف حذف البيانات بأمان حتى إذا انقطع الاتصال.',
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('ProfileController.deleteAccount', error, stackTrace);
      Get.snackbar('تعذر حذف الحساب', _deletionErrorMessage(error));
      return false;
    } finally {
      isDeletingAccount.value = false;
    }
  }

  String _deletionErrorMessage(Object error) {
    if (error is AuthDisplayException) return error.message;
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('network') || normalized.contains('unavailable')) {
      return 'الاتصال غير مستقر ولم نتأكد من قبول الطلب. حاول مرة أخرى.';
    }
    return 'تعذر قبول طلب الحذف. حاول مرة أخرى أو استخدم صفحة طلب الحذف على الويب.';
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }
}
