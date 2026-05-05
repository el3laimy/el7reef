import 'package:get/get.dart';

import '../models/public_player_profile_data.dart';
import '../services/public_player_profile_resolver.dart';

class PublicPlayerProfileController extends GetxController {
  final PublicPlayerProfileResolver _resolver;
  final String kind;
  final String id;

  PublicPlayerProfileController({
    required this.kind,
    required this.id,
    PublicPlayerProfileResolver? resolver,
  }) : _resolver = resolver ?? PublicPlayerProfileResolver();

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<PublicPlayerProfileData?> profile = Rx<PublicPlayerProfileData?>(
    null,
  );

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final resolved = await _resolver.resolve(kind: kind, id: id);
      if (resolved == null) {
        profile.value = null;
        errorMessage.value = 'تعذر العثور على هذا اللاعب.';
        return;
      }
      profile.value = resolved;
    } catch (_) {
      profile.value = null;
      errorMessage.value = 'تعذر تحميل بروفايل اللاعب الآن.';
    } finally {
      isLoading.value = false;
    }
  }
}
