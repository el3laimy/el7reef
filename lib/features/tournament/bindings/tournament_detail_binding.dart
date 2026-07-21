import 'package:get/get.dart';

import '../../../core/services/tournament_participant_service.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../shareables/services/pride_identity_image_resolver.dart';
import '../controllers/tournament_detail_controller.dart';

class TournamentDetailBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentParticipantService>()) {
      Get.lazyPut<TournamentParticipantService>(
        () => TournamentParticipantService(),
      );
    }
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<PrideIdentityImageResolver>()) {
      Get.lazyPut<PrideIdentityImageResolver>(
        () => PrideIdentityImageResolver(
          playerRepository: Get.find<PlayerRepositoryImpl>(),
        ),
      );
    }
    Get.lazyPut<TournamentDetailController>(
      () => TournamentDetailController(
        repository: Get.find<TournamentRepositoryImpl>(),
        participantService: Get.find<TournamentParticipantService>(),
        identityImageResolver: Get.find<PrideIdentityImageResolver>(),
      ),
    );
  }
}
