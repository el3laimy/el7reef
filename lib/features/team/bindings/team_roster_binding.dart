import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/team_formation_service.dart';
import '../../../core/services/team_roster_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_formation_template_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/team_roster_snapshot_repository_impl.dart';
import '../../../features/team/controllers/team_roster_controller.dart';
import '../../../services/auth_service.dart';

class TeamRosterBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
      Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
    }
    if (!Get.isRegistered<TeamMembershipRepositoryImpl>()) {
      Get.lazyPut<TeamMembershipRepositoryImpl>(
        () => TeamMembershipRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TeamFormationTemplateRepositoryImpl>()) {
      Get.lazyPut<TeamFormationTemplateRepositoryImpl>(
        () => TeamFormationTemplateRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TeamRosterSnapshotRepositoryImpl>()) {
      Get.lazyPut<TeamRosterSnapshotRepositoryImpl>(
        () => TeamRosterSnapshotRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TeamRosterService>()) {
      Get.lazyPut<TeamRosterService>(
        () => TeamRosterService(
          teamRepository: Get.find<TeamRepositoryImpl>(),
          membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
          guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
        ),
      );
    }
    if (!Get.isRegistered<TeamFormationService>()) {
      Get.lazyPut<TeamFormationService>(
        () => TeamFormationService(
          teamRepository: Get.find<TeamRepositoryImpl>(),
          membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
          playerRepository: Get.find<PlayerRepositoryImpl>(),
          guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
          templateRepository: Get.find<TeamFormationTemplateRepositoryImpl>(),
          snapshotRepository: Get.find<TeamRosterSnapshotRepositoryImpl>(),
        ),
      );
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();

    Get.lazyPut<TeamRosterController>(
      () => TeamRosterController(
        authSession: authSession,
        teamRepository: Get.find<TeamRepositoryImpl>(),
        teamRosterService: Get.find<TeamRosterService>(),
        teamFormationService: Get.find<TeamFormationService>(),
        playerRepository: Get.find<PlayerRepositoryImpl>(),
        guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
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
