import 'package:get/get.dart';

import '../../../../core/services/fantasy_lifecycle_service.dart';
import '../../../../core/services/fantasy_market_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../services/auth_service.dart';
import '../controllers/transfer_market_controller.dart';

class TransferMarketBinding extends Bindings {
  @override
  void dependencies() {
    final leagueId = Get.parameters['leagueId'];
    if (leagueId == null || leagueId.isEmpty) {
      throw StateError('leagueId is required for fantasy transfers');
    }

    Get.lazyPut<TransferMarketController>(
      () => TransferMarketController(
        leagueId: leagueId,
        fantasyRepository: Get.isRegistered<FantasyRepositoryImpl>()
            ? Get.find<FantasyRepositoryImpl>()
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
        tournamentRepository: Get.isRegistered<TournamentRepositoryImpl>()
            ? Get.find<TournamentRepositoryImpl>()
            : null,
        authService:
            Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null,
      ),
    );
  }
}
