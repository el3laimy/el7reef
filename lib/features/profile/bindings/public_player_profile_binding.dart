import 'package:get/get.dart';

import '../../../core/services/match_event_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../controllers/public_player_profile_controller.dart';
import '../services/public_player_profile_resolver.dart';

class PublicPlayerProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
      Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
    }
    if (!Get.isRegistered<MatchEventService>()) {
      Get.lazyPut<MatchEventService>(() => MatchEventService());
    }
    if (!Get.isRegistered<PublicPlayerProfileResolver>()) {
      Get.lazyPut<PublicPlayerProfileResolver>(
        () => PublicPlayerProfileResolver(
          playerRepository: Get.find<PlayerRepositoryImpl>(),
          guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
          matchEventService: Get.find<MatchEventService>(),
        ),
      );
    }

    Get.lazyPut<PublicPlayerProfileController>(
      () => PublicPlayerProfileController(
        kind: Get.parameters['kind'] ?? '',
        id: Get.parameters['id'] ?? '',
        resolver: Get.find<PublicPlayerProfileResolver>(),
      ),
    );
  }
}
