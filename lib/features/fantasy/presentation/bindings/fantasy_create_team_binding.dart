import 'package:get/get.dart';

import '../../../../core/auth/auth_service_session.dart';
import '../../services/fantasy_lifecycle_service.dart';
import '../../services/fantasy_market_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../core/auth/auth_service.dart';
import '../controllers/fantasy_create_team_controller.dart';

class FantasyCreateTeamBinding extends Bindings {
  @override
  void dependencies() {
    final leagueId = Get.parameters['leagueId'];
    if (leagueId == null || leagueId.isEmpty) {
      throw StateError('leagueId is required for fantasy team creation');
    }

    Get.lazyPut<FantasyCreateTeamController>(
      () => FantasyCreateTeamController(
        leagueId: leagueId,
        fantasyRepository: Get.isRegistered<FantasyRepositoryImpl>()
            ? Get.find<FantasyRepositoryImpl>()
            : null,
        tournamentRepository: Get.isRegistered<TournamentRepositoryImpl>()
            ? Get.find<TournamentRepositoryImpl>()
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
        marketService: Get.isRegistered<FantasyMarketService>()
            ? Get.find<FantasyMarketService>()
            : null,
        authSession: Get.isRegistered<AuthService>()
            ? AuthServiceSession(Get.find<AuthService>())
            : null,
      ),
    );
  }
}
