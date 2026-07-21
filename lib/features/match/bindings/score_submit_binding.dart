import 'package:get/get.dart';

import '../../../core/services/share_link_service.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';
import '../../shareables/services/pride_identity_image_resolver.dart';
import '../controllers/score_submit_controller.dart';

class ScoreSubmitBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['matchId'];
    if (matchId == null || matchId.isEmpty) {
      throw StateError('matchId is required for score submission');
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
    if (!Get.isRegistered<PrideIdentityImageResolver>()) {
      Get.lazyPut<PrideIdentityImageResolver>(PrideIdentityImageResolver.new);
    }

    Get.lazyPut<ScoreSubmitController>(
      () => ScoreSubmitController(matchId: matchId),
    );
  }
}
