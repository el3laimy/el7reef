import 'package:get/get.dart';

import '../../../../core/auth/auth_service_session.dart';
import '../../../../core/services/fantasy_lifecycle_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/player_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../services/auth_service.dart';
import '../controllers/fantasy_leaderboard_controller.dart';

class FantasyLeaderboardBinding extends Bindings {
  @override
  void dependencies() {
    final leagueId = Get.parameters['leagueId'];
    if (leagueId == null || leagueId.isEmpty) {
      throw StateError('leagueId is required for fantasy leaderboard');
    }

    Get.lazyPut<FantasyLeaderboardController>(
      () => FantasyLeaderboardController(
        leagueId: leagueId,
        fantasyRepository: Get.isRegistered<FantasyRepositoryImpl>()
            ? Get.find<FantasyRepositoryImpl>()
            : null,
        playerRepository: Get.isRegistered<PlayerRepositoryImpl>()
            ? Get.find<PlayerRepositoryImpl>()
            : null,
        lifecycleService: Get.isRegistered<FantasyLifecycleService>()
            ? Get.find<FantasyLifecycleService>()
            : FantasyLifecycleService(
                lifecycleRepository:
                    Get.isRegistered<FantasyLifecycleRepositoryImpl>()
                        ? Get.find<FantasyLifecycleRepositoryImpl>()
                        : null,
                tournamentRepository:
                    Get.isRegistered<TournamentRepositoryImpl>()
                        ? Get.find<TournamentRepositoryImpl>()
                        : null,
              ),
        tournamentRepository: Get.isRegistered<TournamentRepositoryImpl>()
            ? Get.find<TournamentRepositoryImpl>()
            : null,
        authSession: Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : null,
      ),
    );
  }
}
