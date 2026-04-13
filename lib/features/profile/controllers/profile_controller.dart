import 'package:get/get.dart';
import '../../../services/auth_service.dart';
import '../../../domain/entities/player.dart';
import '../../../data/repositories/player_repository_impl.dart';

/// كونترولر البروفايل — يدير عرض وتعديل بيانات اللاعب
class ProfileController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final PlayerRepositoryImpl _playerRepo = PlayerRepositoryImpl();

  /// اللاعب الحالي (reactive)
  Rx<Player?> get player => _authService.currentPlayer;

  /// اللاعب الحالي (snapshot)
  Player? get currentPlayer => _authService.currentPlayer.value;

  /// حالة التحميل
  final RxBool isLoading = false.obs;

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

  @override
  void onInit() {
    super.onInit();
    selectedPosition.value = player.value?.position ?? '';
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

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _authService.signOut();
    Get.offAllNamed('/login');
  }
}
