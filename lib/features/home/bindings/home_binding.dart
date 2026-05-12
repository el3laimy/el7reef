import 'package:get/get.dart';
import '../../../features/profile/controllers/profile_controller.dart';
import '../../../features/team/controllers/team_controller.dart';
import '../../../features/match/controllers/match_controller.dart';
import '../../../features/tournament/controllers/tournament_controller.dart';
import '../../../features/social/controllers/activity_feed_controller.dart';
import '../../../features/match/controllers/challenge_controller.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../data/repositories/challenge_repository_impl.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/session_reset_coordinator.dart';

/// HomeBinding — يسجل جميع Controllers المطلوبة لشاشة Home
/// بدلاً من تسجيلها يدوياً في HomeScreen.initState()
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final sessionResetCoordinator = Get.isRegistered<SessionResetCoordinator>()
        ? Get.find<SessionResetCoordinator>()
        : Get.put(SessionResetCoordinator(), permanent: true);

    final profileController = _putPermanentIfAbsent<ProfileController>(
      () => ProfileController(),
    );
    final teamController = _putPermanentIfAbsent<TeamController>(
      () => TeamController(),
    );
    final matchController = _putPermanentIfAbsent<MatchController>(
      () => MatchController(),
    );
    final tournamentController = _putPermanentIfAbsent<TournamentController>(
      () => TournamentController(),
    );
    final activityFeedController =
        _putPermanentIfAbsent<ActivityFeedController>(
          () => ActivityFeedController(),
        );

    sessionResetCoordinator
      ..register(
        key: 'ProfileController',
        onReset: profileController.resetSessionState,
      )
      ..register(
        key: 'TeamController',
        onReset: teamController.resetSessionState,
      )
      ..register(
        key: 'MatchController',
        onReset: matchController.resetSessionState,
      )
      ..register(
        key: 'TournamentController',
        onReset: tournamentController.resetSessionState,
      )
      ..register(
        key: 'ActivityFeedController',
        onReset: activityFeedController.resetSessionState,
      );

    if (!Get.isRegistered<ChallengeRepository>()) {
      Get.put<ChallengeRepository>(ChallengeRepositoryImpl(), permanent: true);
    }
    if (!Get.isRegistered<MatchRepository>()) {
      Get.put<MatchRepository>(MatchRepositoryImpl(), permanent: true);
    }
    final challengeController = _putPermanentIfAbsent<ChallengeController>(
      () => ChallengeController(
        challengeRepo: Get.find<ChallengeRepository>(),
        authService: Get.find<AuthService>(),
      ),
    );
    sessionResetCoordinator.register(
      key: 'ChallengeController',
      onReset: challengeController.resetSessionState,
    );
  }

  T _putPermanentIfAbsent<T extends Object>(T Function() builder) {
    if (Get.isRegistered<T>()) {
      return Get.find<T>();
    }
    return Get.put<T>(builder(), permanent: true);
  }
}
