import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_registration_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/tournament_registration_controller.dart';

class TournamentRegistrationBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentRegistrationRepositoryImpl>()) {
      Get.lazyPut<TournamentRegistrationRepositoryImpl>(
        () => TournamentRegistrationRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestTeamRepositoryImpl>()) {
      Get.lazyPut<GuestTeamRepositoryImpl>(() => GuestTeamRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentRegistrationService>()) {
      Get.lazyPut<TournamentRegistrationService>(
        () => TournamentRegistrationService(),
      );
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();

    Get.lazyPut<TournamentRegistrationController>(
      () => TournamentRegistrationController(
        authSession: authSession,
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        registrationRepository: Get.find<TournamentRegistrationRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        registrationService: Get.find<TournamentRegistrationService>(),
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
