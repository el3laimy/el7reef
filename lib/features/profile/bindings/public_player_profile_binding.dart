import 'package:get/get.dart';

import '../../../core/services/match_event_service.dart';
import '../../../core/services/share_link_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/cloud_sensitive_ops_service.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';
import '../controllers/public_player_profile_controller.dart';
import '../services/public_player_profile_resolver.dart';
import '../services/user_safety_service.dart';

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
    if (!Get.isRegistered<MatchRepositoryImpl>()) {
      Get.lazyPut<MatchRepositoryImpl>(() => MatchRepositoryImpl());
    }
    if (!Get.isRegistered<ShareLinkService>()) {
      Get.lazyPut<ShareLinkService>(() => ShareLinkService());
    }
    if (!Get.isRegistered<GuestMvpClaimLinkService>()) {
      Get.lazyPut<GuestMvpClaimLinkService>(
        () => GuestMvpClaimLinkService(
          claimLinkIssuer: Get.find<ShareLinkService>(),
        ),
      );
    }
    if (!Get.isRegistered<PublicPlayerProfileResolver>()) {
      Get.lazyPut<PublicPlayerProfileResolver>(
        () => PublicPlayerProfileResolver(
          playerRepository: Get.find<PlayerRepositoryImpl>(),
          guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
          matchEventService: Get.find<MatchEventService>(),
          matchRepository: Get.find<MatchRepositoryImpl>(),
          currentUserId: () => Get.find<AuthService>().currentUserId,
        ),
      );
    }
    if (!Get.isRegistered<UserSafetyService>()) {
      Get.lazyPut<UserSafetyService>(
        () => UserSafetyService(
          authService: Get.find<AuthService>(),
          cloudService: CloudSensitiveOpsService(),
        ),
      );
    }

    Get.lazyPut<PublicPlayerProfileController>(
      () => PublicPlayerProfileController(
        kind: Get.parameters['kind'] ?? '',
        id: Get.parameters['id'] ?? '',
        resolver: Get.find<PublicPlayerProfileResolver>(),
        userSafetyService: Get.find<UserSafetyService>(),
      ),
    );
  }
}
