import 'package:get/get.dart';
import '../../../domain/entities/friendship.dart';
import '../../../domain/repositories/friend_repository.dart';
import '../../../domain/entities/player.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../core/auth/auth_service.dart';

class FriendController extends GetxController {
  final FriendRepository _repository;
  final AuthService _authService = Get.find<AuthService>();
  // To resolve player data
  final _playerRepo = Get.find<PlayerRepositoryImpl>();

  FriendController(this._repository);

  // States
  final RxList<Friendship> friends = <Friendship>[].obs;
  final RxList<Friendship> pendingRequests = <Friendship>[].obs;
  final RxMap<String, Player> friendProfiles = <String, Player>{}.obs;
  final RxBool isLoading = false.obs;

  String? get currentUserId => _authService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    if (currentUserId != null) {
      loadAllData();
    }
    
    // إعادة التحميل إذا تغير المستخدم
    ever(_authService.currentPlayer, (player) {
      if (player != null) {
        loadAllData();
      } else {
        friends.clear();
        pendingRequests.clear();
        friendProfiles.clear();
      }
    });
  }

  /// تحميل الأصدقاء والطلبات
  Future<void> loadAllData() async {
    if (currentUserId == null) return;
    try {
      isLoading.value = true;
      
      final friendsFuture = _repository.getFriends(currentUserId!);
      final requestsFuture = _repository.getPendingRequests(currentUserId!);

      final results = await Future.wait([friendsFuture, requestsFuture]);
      
      final friendsList = results[0];
      final requestsList = results[1];
      
      friends.value = friendsList;
      pendingRequests.value = requestsList;

      // تحميل بيانات اللاعبين
      final Set<String> playerIdsToFetch = {};
      for (var f in friendsList) {
        playerIdsToFetch.add(f.getOtherUserId(currentUserId!));
      }
      for (var r in requestsList) {
        playerIdsToFetch.add(r.getOtherUserId(currentUserId!));
      }

      for (String id in playerIdsToFetch) {
        if (!friendProfiles.containsKey(id)) {
          final player = await _playerRepo.getPlayer(id);
          if (player != null) {
            friendProfiles[id] = player;
          }
        }
      }

    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات الأصدقاء: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// إرسال طلب صداقة
  Future<bool> sendFriendRequest(String receiverId) async {
    if (currentUserId == null || currentUserId == receiverId) return false;
    
    try {
      await _repository.sendFriendRequest(currentUserId!, receiverId);
      Get.snackbar('تم', 'تم إرسال طلب الصداقة بنجاح');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'لم نتمكن من إرسال الطلب: $e');
      return false;
    }
  }

  /// قبول طلب صداقة
  Future<bool> acceptRequest(String senderId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.acceptFriendRequest(currentUserId!, senderId, currentUserId!);
      Get.snackbar('تم', 'أصبحتم أصدقاء الآن 🎉');
      await loadAllData();
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء قبول الطلب');
      return false;
    }
  }

  /// رفض طلب صداقة أو إنهاء صداقة
  Future<bool> removeFriendship(String otherUserId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.removeFriendship(currentUserId!, otherUserId);
      await loadAllData();
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تنفيذ الطلب');
      return false;
    }
  }

  /// حظر مستخدم
  Future<bool> blockUser(String blockedId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.blockUser(currentUserId!, blockedId);
      Get.snackbar('تم الحظر', 'تم حظر المستخدم ولن يتمكن من التفاعل معك');
      await loadAllData();
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء حظر المستخدم');
      return false;
    }
  }

  /// فك حظر مستخدم
  Future<bool> unblockUser(String blockedId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.unblockUser(currentUserId!, blockedId);
      Get.snackbar('تم التحديث', 'تم فك الحظر عن المستخدم');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء فك الحظر');
      return false;
    }
  }

  /// متابعة لاعب
  Future<bool> followUser(String followedId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.followUser(currentUserId!, followedId);
      Get.snackbar('تم', 'أنت تتابع هذا اللاعب الآن');
      // يمكن تحديث ملف اللاعب الحالي هنا
      await _authService.refreshProfile();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إلغاء متابعة
  Future<bool> unfollowUser(String followedId) async {
    if (currentUserId == null) return false;
    
    try {
      await _repository.unfollowUser(currentUserId!, followedId);
      // يمكن تحديث ملف اللاعب الحالي هنا
      await _authService.refreshProfile();
      return true;
    } catch (e) {
      return false;
    }
  }
}
