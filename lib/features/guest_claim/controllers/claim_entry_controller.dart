import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/claim_target_type.dart';
import '../../../core/navigation/app_link_route_parser.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/pride_share_attribution.dart';
import '../../../core/auth/auth_service.dart';
import '../../../domain/entities/share_payload.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';

class ClaimEntryController extends GetxController {
  final AnalyticsService _analyticsService;

  ClaimEntryController({AnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? AnalyticsService();
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
    final pridePayload = PrideShareAttribution.fromQueryParameters(
      Get.parameters,
      targetUrl: Uri(
        scheme: 'https',
        host: AppLinkRouteParser.pilotWebHost,
        path: AppRoutes.claimEntry,
      ),
    );

    if (pridePayload != null &&
        _isGuestPrideAttributionForTarget(
          pridePayload: pridePayload,
          targetType: resolvedTargetType,
          targetId: resolvedTargetId,
        )) {
      _analyticsService.trackShareLinkOpened(pridePayload);
    }

    if (resolvedTargetType != null && resolvedTargetId != null) {
      if (Get.isRegistered<AuthService>() &&
          Get.find<AuthService>().currentUserId != null) {
        _analyticsService.trackClaimOpen(
          type: resolvedTargetType.name,
          targetId: resolvedTargetId,
        );
      }
    }
    if (code == null || code!.isEmpty) {
      errorMessage.value = 'رابط الـ claim لا يحتوي على code صالح.';
      isLoading.value = false;
      return;
    }
    if (resolvedTargetType == null ||
        resolvedTargetId == null ||
        resolvedTargetId.isEmpty) {
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
        Get.offNamed(AppRoutes.inviteEntryWithQuery(forwardedQuery));
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

  bool _isGuestPrideAttributionForTarget({
    required SharePayload? pridePayload,
    required ClaimTargetType? targetType,
    required String? targetId,
  }) {
    return GuestMvpClaimLinkService.claimableCardTypes.contains(
          pridePayload?.cardType,
        ) &&
        pridePayload?.entityType == ShareEntityType.guestPlayer &&
        pridePayload?.entityId == targetId &&
        targetType == ClaimTargetType.guestPlayer;
  }
}
