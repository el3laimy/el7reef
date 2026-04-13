import 'package:get/get.dart';
import '../controllers/friend_controller.dart';
import '../controllers/search_players_controller.dart';
import '../../../data/repositories/friend_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';

class FriendBinding extends Bindings {
  @override
  void dependencies() {
    // تأكد من تهيئة PlayerRepositoryImpl أولاً لأن FriendController سيحتاجه
    Get.lazyPut(() => PlayerRepositoryImpl());
    
    Get.lazyPut(() => FriendRepositoryImpl());
    Get.lazyPut(() => FriendController(Get.find<FriendRepositoryImpl>()));
    Get.lazyPut(() => SearchPlayersController(Get.find<PlayerRepositoryImpl>()));
  }
}
