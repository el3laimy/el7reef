import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/navigation/pending_deep_link_service.dart';

/// كونترولر المصادقة — Google Sign-In
class AuthController extends GetxController {
  static const communityPolicyRequiredMessage =
      'وافق على قواعد المجتمع وسياسة الخصوصية قبل المتابعة.';

  final AuthService _authService = Get.find<AuthService>();
  final PendingDeepLinkService _pendingDeepLinkService =
      Get.isRegistered<PendingDeepLinkService>()
      ? Get.find<PendingDeepLinkService>()
      : Get.put(PendingDeepLinkService(), permanent: true);

  /// حالة التحميل
  final RxBool isLoading = false.obs;

  /// رسالة الخطأ
  final RxString errorMessage = ''.obs;
  final RxBool hasAcceptedCommunityPolicy = false.obs;

  void setCommunityPolicyAccepted(bool accepted) {
    hasAcceptedCommunityPolicy.value = accepted;
    if (accepted && errorMessage.value == communityPolicyRequiredMessage) {
      errorMessage.value = '';
    }
  }

  /// تسجيل الدخول بـ Google
  Future<void> signInWithGoogle() async {
    if (!hasAcceptedCommunityPolicy.value) {
      errorMessage.value = communityPolicyRequiredMessage;
      return;
    }

    try {
      errorMessage.value = '';
      isLoading.value = true;

      final player = await _authService.signInWithGoogle();

      if (player != null) {
        final pendingRoute = _pendingDeepLinkService.take();
        Get.offAllNamed(pendingRoute ?? AppRoutes.home);
      } else if (_authService.isLoggedIn) {
        Get.offAllNamed(AppRoutes.profileRepair);
      }
    } catch (e) {
      final message = e.toString().trim();
      if (message.isNotEmpty) {
        errorMessage.value = message;
      }
    } finally {
      isLoading.value = false;
    }
  }
}
