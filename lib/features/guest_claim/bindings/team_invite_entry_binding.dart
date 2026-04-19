import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/team_invite_service.dart';
import '../../../data/repositories/claim_code_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../controllers/team_invite_entry_controller.dart';

class TeamInviteEntryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<TeamMembershipRepositoryImpl>()) {
      Get.lazyPut<TeamMembershipRepositoryImpl>(
        () => TeamMembershipRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<ClaimCodeRepositoryImpl>()) {
      Get.lazyPut<ClaimCodeRepositoryImpl>(() => ClaimCodeRepositoryImpl());
    }
    if (!Get.isRegistered<TeamInviteService>()) {
      Get.lazyPut<TeamInviteService>(
        () => TeamInviteService(
          claimCodeRepository: Get.find<ClaimCodeRepositoryImpl>(),
          teamRepository: Get.find<TeamRepositoryImpl>(),
          membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
          playerRepository: Get.find<PlayerRepositoryImpl>(),
        ),
      );
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();

    Get.lazyPut<TeamInviteEntryController>(
      () => TeamInviteEntryController(
        authSession: authSession,
        teamInviteService: Get.find<TeamInviteService>(),
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
