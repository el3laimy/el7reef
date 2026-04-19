import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../services/auth_service.dart';
import '../controllers/dispute_viewer_controller.dart';

class DisputeViewerBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['matchId'] ?? '';
    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();
    Get.lazyPut<DisputeViewerController>(
      () => DisputeViewerController(
        matchId: matchId,
        authSession: authSession,
      ),
    );
  }
}

class _AnonymousAuthSession implements AuthSession {
  const _AnonymousAuthSession();

  @override
  get currentPlayer => null;

  @override
  String? get currentUserId => null;
}
