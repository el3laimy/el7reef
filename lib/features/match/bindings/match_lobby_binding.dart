import 'package:get/get.dart';
import '../controllers/match_lobby_controller.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../domain/repositories/match_invitation_repository.dart';
import '../../../data/repositories/match_invitation_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/friend_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../core/services/match_cancellation_service.dart';
import '../../../core/services/match_start_service.dart';
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
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<MatchSideRepositoryImpl>()) {
      Get.lazyPut(() => MatchSideRepositoryImpl());
    }
    if (!Get.isRegistered<MatchSidePlayerRepositoryImpl>()) {
      Get.lazyPut(() => MatchSidePlayerRepositoryImpl());
    }
    if (!Get.isRegistered<MatchLineupSnapshotRepositoryImpl>()) {
      Get.lazyPut(() => MatchLineupSnapshotRepositoryImpl());
    }
    if (!Get.isRegistered<MatchStartService>()) {
      Get.lazyPut(
        () => MatchStartService(
          matchRepo: Get.find<MatchRepository>(),
          snapshotRepo: Get.find<MatchLineupSnapshotRepositoryImpl>(),
          sidePlayerRepo: Get.find<MatchSidePlayerRepositoryImpl>(),
        ),
      );
    }
    if (!Get.isRegistered<MatchCancellationService>()) {
      Get.lazyPut(() => MatchCancellationService());
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
