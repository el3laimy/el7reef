import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/guest_claim_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/guest_player_claim_controller.dart';

class GuestPlayerClaimBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
      Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
    }
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestClaimService>()) {
      Get.lazyPut<GuestClaimService>(() => GuestClaimService());
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();

    Get.lazyPut<GuestPlayerClaimController>(
      () => GuestPlayerClaimController(
        authSession: authSession,
        guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        guestClaimService: Get.find<GuestClaimService>(),
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
