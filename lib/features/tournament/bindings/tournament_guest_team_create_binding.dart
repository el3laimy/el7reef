import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../controllers/tournament_guest_team_create_controller.dart';

class TournamentGuestTeamCreateBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
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

    Get.lazyPut<TournamentGuestTeamCreateController>(
      () => TournamentGuestTeamCreateController(
        authSession: authSession,
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
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
