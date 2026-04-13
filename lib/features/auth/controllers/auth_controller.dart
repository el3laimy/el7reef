import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../services/auth_service.dart';

/// كونترولر المصادقة — Google Sign-In
class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  /// حالة التحميل
  final RxBool isLoading = false.obs;

  /// رسالة الخطأ
  final RxString errorMessage = ''.obs;

  /// تسجيل الدخول بـ Google
  Future<void> signInWithGoogle() async {
    try {
      errorMessage.value = '';
      isLoading.value = true;

      final player = await _authService.signInWithGoogle();

      if (player != null) {
        Get.offAllNamed(AppRoutes.home);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
