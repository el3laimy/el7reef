import 'package:get/get.dart';

import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../services/auth_service.dart';
import '../controllers/fantasy_home_controller.dart';

class FantasyHomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FantasyHomeController>(
      () => FantasyHomeController(
        fantasyRepository: Get.isRegistered<FantasyRepositoryImpl>()
            ? Get.find<FantasyRepositoryImpl>()
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
