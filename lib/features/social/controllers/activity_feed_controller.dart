import 'package:get/get.dart';

import '../../../core/services/activity_feed_service.dart';
import '../../../services/auth_service.dart';

class ActivityFeedController extends GetxController {
  final ActivityFeedService _activityFeedService;
  final AuthService _authService;

  ActivityFeedController({
    ActivityFeedService? activityFeedService,
    AuthService? authService,
  }) : _activityFeedService = activityFeedService ?? ActivityFeedService(),
       _authService = authService ?? Get.find<AuthService>();

  final RxList<ActivityFeedEntry> items = <ActivityFeedEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever(_authService.currentPlayer, (_) => loadFeed());
    loadFeed();
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }

  Future<void> loadFeed() async {
    final currentPlayer = _authService.currentPlayer.value;
    if (currentPlayer == null) {
      resetSessionState();
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loadedItems = await _activityFeedService.buildFeedForPlayer(
        currentPlayer,
      );
      items.assignAll(loadedItems);
    } catch (error) {
      errorMessage.value = 'تعذر تحميل آخر الأنشطة حالياً.';
    } finally {
      isLoading.value = false;
    }
  }

  void resetSessionState() {
    items.clear();
    isLoading.value = false;
    errorMessage.value = '';
  }
}
