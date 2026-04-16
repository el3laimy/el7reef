import 'package:get/get.dart';

import '../controllers/claim_entry_controller.dart';

class ClaimEntryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ClaimEntryController>()) {
      Get.lazyPut<ClaimEntryController>(() => ClaimEntryController());
    }
  }
}
