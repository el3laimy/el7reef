import 'package:get/get.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/guest_team_roster_service.dart';
import '../../../core/services/tournament_audit_emitter.dart';
import '../../../core/services/tournament_permission_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/tournament_assistant_permission_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../controllers/tournament_guest_team_roster_controller.dart';

class TournamentGuestTeamRosterBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
    }
    if (!Get.isRegistered<GuestTeamRepositoryImpl>()) {
      Get.lazyPut<GuestTeamRepositoryImpl>(() => GuestTeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
      Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentAssistantPermissionRepositoryImpl>()) {
      Get.lazyPut<TournamentAssistantPermissionRepositoryImpl>(
        () => TournamentAssistantPermissionRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TournamentAuditEmitter>()) {
      Get.lazyPut<TournamentAuditEmitter>(() => TournamentAuditEmitter());
    }
    if (!Get.isRegistered<TournamentPermissionService>()) {
      Get.lazyPut<TournamentPermissionService>(
        () => TournamentPermissionService(),
      );
    }
    if (!Get.isRegistered<GuestTeamRosterService>()) {
      Get.lazyPut<GuestTeamRosterService>(
        () => GuestTeamRosterService(
          guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
          guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
          tournamentRepository: Get.find<TournamentRepositoryImpl>(),
          assistantPermissionRepository:
              Get.find<TournamentAssistantPermissionRepositoryImpl>(),
          tournamentPermissionService: Get.find<TournamentPermissionService>(),
          auditEmitter: Get.find<TournamentAuditEmitter>(),
        ),
      );
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
        ? AuthServiceSession(Get.find<AuthService>())
        : const _AnonymousAuthSession();

    Get.lazyPut<TournamentGuestTeamRosterController>(
      () => TournamentGuestTeamRosterController(
        authSession: authSession,
        guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        rosterService: Get.find<GuestTeamRosterService>(),
      ),
    );
  }
}

class _AnonymousAuthSession implements AuthSession {
  const _AnonymousAuthSession();

  @override
  String? get currentUserId => null;

  @override
  get currentPlayer => null;
}
