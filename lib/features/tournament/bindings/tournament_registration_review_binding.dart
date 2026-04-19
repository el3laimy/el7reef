import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_registration_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../controllers/tournament_registration_review_controller.dart';
import '../../../core/services/share_link_service.dart';

class TournamentRegistrationReviewBinding extends Bindings {
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

    if (!Get.isRegistered<ShareLinkService>()) {
      Get.lazyPut<ShareLinkService>(() => ShareLinkService());
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : const _AnonymousAuthSession();

    Get.lazyPut<TournamentRegistrationReviewController>(
      () => TournamentRegistrationReviewController(
        authSession: authSession,
        registrationRepository: Get.find<TournamentRegistrationRepositoryImpl>(),
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        registrationService: Get.find<TournamentRegistrationService>(),
        shareLinkService: Get.find<ShareLinkService>(),
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
