import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/claim_target_type.dart';

class ClaimEntryController extends GetxController {
  final isLoading = true.obs;
  final errorMessage = ''.obs;

  String? get code => Get.parameters['code'];
  String? get targetTypeValue => Get.parameters['type'];
  String? get targetId => Get.parameters['targetId'];

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveEntry();
    });
  }

  void _resolveEntry() {
    if (!FeatureFlags.guestIdentityEnabled) {
      errorMessage.value = 'خاصية الـ claim غير مفعلة في هذا البناء حالياً.';
      isLoading.value = false;
      return;
    }

    final resolvedTargetType = _parseTargetType(targetTypeValue);
    final resolvedTargetId = targetId;
    if (code == null || code!.isEmpty) {
      errorMessage.value = 'رابط الـ claim لا يحتوي على code صالح.';
      isLoading.value = false;
      return;
    }
    if (resolvedTargetType == null || resolvedTargetId == null || resolvedTargetId.isEmpty) {
      errorMessage.value = 'رابط الـ claim غير مكتمل أو غير مدعوم.';
      isLoading.value = false;
      return;
    }

    final forwardedQuery = Map<String, String?>.from(Get.parameters)
      ..remove('guestPlayerId')
      ..remove('guestTeamId');

    switch (resolvedTargetType) {
      case ClaimTargetType.guestPlayer:
        Get.offNamed(
          AppRoutes.guestPlayerClaimById(
            resolvedTargetId,
            queryParameters: forwardedQuery,
          ),
        );
        return;
      case ClaimTargetType.guestTeam:
        Get.offNamed(
          AppRoutes.guestTeamClaimById(
            resolvedTargetId,
            queryParameters: forwardedQuery,
          ),
        );
        return;
      case ClaimTargetType.teamInvite:
        errorMessage.value =
            'رابط الدعوة هذا غير مدعوم بعد داخل شاشات الـ claim الحالية.';
        isLoading.value = false;
        return;
    }
  }

  ClaimTargetType? _parseTargetType(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final targetType in ClaimTargetType.values) {
      if (targetType.name == value) {
        return targetType;
      }
    }
    return null;
  }
}
