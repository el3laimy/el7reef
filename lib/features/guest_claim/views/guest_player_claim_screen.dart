import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/claim_merge_conflict_type.dart';
import '../../../core/enums/guest_claim_status.dart';
import '../../../core/navigation/pending_deep_link_service.dart';
import '../../../core/services/guest_claim_service.dart';
import '../controllers/guest_player_claim_controller.dart';
import '_claim_ui_shared.dart';

class GuestPlayerClaimScreen extends GetView<GuestPlayerClaimController> {
  const GuestPlayerClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استلام لاعب ضيف')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final errorMessage = controller.errorMessage.value;
          final guestPlayer = controller.guestPlayer.value;
          if (errorMessage.isNotEmpty && guestPlayer == null) {
            return ClaimCenteredMessage(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل رابط الاستلام',
              message: errorMessage,
            );
          }
          if (guestPlayer == null) {
            return const ClaimCenteredMessage(
              icon: Icons.person_off_rounded,
              title: 'اللاعب الضيف غير موجود',
              message: 'لم نتمكن من العثور على اللاعب المرتبط بهذا الرابط.',
            );
          }

          final claimResult = controller.claimResult.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClaimInfoCard(
                  title: guestPlayer.displayName,
                  subtitle:
                      controller.linkedTeam.value?.name ?? 'لا يوجد فريق مرتبط',
                  icon: Icons.person_pin_circle_outlined,
                  rows: [
                    ClaimInfoRow(
                      label: 'الحالة',
                      value: _claimStatusLabel(guestPlayer.claimStatus),
                    ),
                    if (guestPlayer.preferredPosition != null &&
                        guestPlayer.preferredPosition!.isNotEmpty)
                      ClaimInfoRow(
                        label: 'المركز',
                        value: guestPlayer.preferredPosition!,
                      ),
                    if (guestPlayer.phoneNumber != null &&
                        guestPlayer.phoneNumber!.isNotEmpty)
                      ClaimInfoRow(
                        label: 'الهاتف',
                        value: guestPlayer.phoneNumber!,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ClaimInfoCard(
                  title: controller.currentPlayer?.name ?? 'غير مسجل الدخول',
                  subtitle: controller.isAuthenticated
                      ? 'سيتم ربط هذا المكان بحسابك الحالي.'
                      : 'سجّل الدخول أولاً حتى تستلم مكانك.',
                  icon: Icons.verified_user_outlined,
                  rows: const [],
                ),
                if (claimResult != null) ...[
                  const SizedBox(height: 16),
                  ClaimResultCard(
                    title: _resultTitle(claimResult),
                    message: _resultMessage(claimResult),
                    color: _resultColor(claimResult),
                    icon: _resultIcon(claimResult),
                    footer: claimResult.conflict?.conflictingEntityLabel,
                  ),
                ],
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClaimResultCard(
                    title: 'تعذر إكمال العملية',
                    message: errorMessage,
                    color: Colors.redAccent,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
                const SizedBox(height: 24),
                if (!controller.isAuthenticated) ...[
                  FilledButton(
                    onPressed: _storePendingRouteAndOpenLogin,
                    child: const Text('تسجيل الدخول'),
                  ),
                ] else if (controller.hasSuccessfulClaim) ...[
                  FilledButton.icon(
                    onPressed: _openClaimedProfile,
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('افتح بروفايلك'),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed:
                        controller.isSubmitting.value ||
                            !controller.canSubmitClaim
                        ? null
                        : controller.submitClaim,
                    child: Text(
                      controller.isSubmitting.value
                          ? 'جارٍ تنفيذ الاستلام...'
                          : 'استلم مكاني',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Get.offAllNamed(AppRoutes.home),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _storePendingRouteAndOpenLogin() {
    final id = controller.guestPlayerId;
    if (id != null && id.isNotEmpty) {
      final query = Map<String, String?>.from(Get.parameters)
        ..remove('guestPlayerId');
      _pendingDeepLinkService().store(
        AppRoutes.guestPlayerClaimById(id, queryParameters: query),
      );
    }
    Get.toNamed(AppRoutes.login);
  }

  PendingDeepLinkService _pendingDeepLinkService() {
    return Get.isRegistered<PendingDeepLinkService>()
        ? Get.find<PendingDeepLinkService>()
        : Get.put(PendingDeepLinkService(), permanent: true);
  }

  void _openClaimedProfile() {
    final playerId = controller.claimedPlayerId;
    if (playerId == null || playerId.isEmpty) return;
    Get.offNamed(
      AppRoutes.playerProfileByKindAndId(kind: 'player', id: playerId),
    );
  }

  String _claimStatusLabel(GuestClaimStatus status) {
    return switch (status) {
      GuestClaimStatus.guest => 'ضيف',
      GuestClaimStatus.invited => 'بانتظار الاستلام',
      GuestClaimStatus.claimed => 'تم الاستلام',
      GuestClaimStatus.archived => 'مؤرشف',
    };
  }

  String _resultTitle(GuestPlayerClaimResult result) {
    switch (result.outcome) {
      case GuestPlayerClaimOutcome.claimed:
        return 'تم استلام مكانك بنجاح';
      case GuestPlayerClaimOutcome.alreadyClaimed:
        return 'هذا المكان مرتبط بحسابك بالفعل';
      case GuestPlayerClaimOutcome.conflict:
        return 'يوجد تعارض يحتاج مراجعة';
    }
  }

  String _resultMessage(GuestPlayerClaimResult result) {
    switch (result.outcome) {
      case GuestPlayerClaimOutcome.claimed:
        return 'تم ربط بيانات اللاعب الضيف بحسابك الحالي مع الحفاظ على سجلاته السابقة.';
      case GuestPlayerClaimOutcome.alreadyClaimed:
        return 'لا حاجة لتكرار العملية. هذا المكان تم ربطه بحسابك بالفعل.';
      case GuestPlayerClaimOutcome.conflict:
        return result.conflict?.message ??
            'حدث تعارض غير متوقع أثناء الاستلام.';
    }
  }

  Color _resultColor(GuestPlayerClaimResult result) {
    switch (result.outcome) {
      case GuestPlayerClaimOutcome.claimed:
      case GuestPlayerClaimOutcome.alreadyClaimed:
        return Colors.green;
      case GuestPlayerClaimOutcome.conflict:
        return switch (result.conflict?.type) {
          ClaimMergeConflictType.duplicatePhone ||
          ClaimMergeConflictType.duplicateName => Colors.orange,
          _ => Colors.redAccent,
        };
    }
  }

  IconData _resultIcon(GuestPlayerClaimResult result) {
    switch (result.outcome) {
      case GuestPlayerClaimOutcome.claimed:
        return Icons.check_circle_outline_rounded;
      case GuestPlayerClaimOutcome.alreadyClaimed:
        return Icons.verified_rounded;
      case GuestPlayerClaimOutcome.conflict:
        return Icons.warning_amber_rounded;
    }
  }
}
