import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../models/public_team_profile_data.dart';
import '../services/public_team_profile_resolver.dart';

class PublicTeamProfileController extends GetxController {
  final PublicTeamProfileResolver _resolver;
  final String kind;
  final String id;

  PublicTeamProfileController({
    required this.kind,
    required this.id,
    PublicTeamProfileResolver? resolver,
  }) : _resolver = resolver ?? PublicTeamProfileResolver();

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<PublicTeamProfileData?> profile = Rx<PublicTeamProfileData?>(null);

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      profile.value = await _resolver.resolve(kind: kind, id: id);
      if (profile.value == null) {
        errorMessage.value = 'تعذر العثور على هذا الفريق.';
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'PublicTeamProfileController.loadProfile',
        error,
        stackTrace,
      );
      profile.value = null;
      errorMessage.value = 'تعذر تحميل بطاقة الفريق الآن.';
    } finally {
      isLoading.value = false;
    }
  }
}
