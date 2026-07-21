import 'package:get/get.dart';

import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../controllers/public_team_profile_controller.dart';
import '../services/public_team_profile_resolver.dart';

class PublicTeamProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestTeamRepositoryImpl>()) {
      Get.lazyPut<GuestTeamRepositoryImpl>(() => GuestTeamRepositoryImpl());
    }
    if (!Get.isRegistered<PublicTeamProfileResolver>()) {
      Get.lazyPut<PublicTeamProfileResolver>(
        () => PublicTeamProfileResolver(
          teamRepository: Get.find<TeamRepositoryImpl>(),
          guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        ),
      );
    }
    Get.lazyPut<PublicTeamProfileController>(
      () => PublicTeamProfileController(
        kind: Get.parameters['kind'] ?? '',
        id: Get.parameters['id'] ?? '',
        resolver: Get.find<PublicTeamProfileResolver>(),
      ),
    );
  }
}
