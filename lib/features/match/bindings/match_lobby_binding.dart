import 'package:get/get.dart';
import '../controllers/match_lobby_controller.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../domain/repositories/match_invitation_repository.dart';
import '../../../data/repositories/match_invitation_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/friend_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../social/controllers/friend_controller.dart';

class MatchLobbyBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['id'] ?? '';

    if (!Get.isRegistered<MatchRepository>()) {
      Get.lazyPut<MatchRepository>(() => MatchRepositoryImpl());
    }
    if (!Get.isRegistered<MatchInvitationRepository>()) {
      Get.lazyPut<MatchInvitationRepository>(
        () => MatchInvitationRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<MatchLineupSnapshotRepositoryImpl>()) {
      Get.lazyPut(() => MatchLineupSnapshotRepositoryImpl());
    }
    if (!Get.isRegistered<FriendRepositoryImpl>()) {
      Get.put(FriendRepositoryImpl());
    }
    if (!Get.isRegistered<FriendController>()) {
      Get.put(FriendController(Get.find<FriendRepositoryImpl>()));
    }

    Get.lazyPut<MatchLobbyController>(
      () => MatchLobbyController(matchId: matchId),
    );
  }
}
