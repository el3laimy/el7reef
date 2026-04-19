import 'package:get/get.dart';

import '../../../core/services/tournament_participant_service.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
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
    Get.lazyPut<TournamentDetailController>(
      () => TournamentDetailController(
        repository: Get.find<TournamentRepositoryImpl>(),
        participantService: Get.find<TournamentParticipantService>(),
      ),
    );
  }
}
