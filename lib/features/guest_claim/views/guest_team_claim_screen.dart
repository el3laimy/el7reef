import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/claim_merge_conflict_type.dart';
import '../../../core/services/guest_claim_service.dart';
import '../controllers/guest_team_claim_controller.dart';
import '_claim_ui_shared.dart';

class GuestTeamClaimScreen extends GetView<GuestTeamClaimController> {
  const GuestTeamClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استلام فريق ضيف')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final errorMessage = controller.errorMessage.value;
          final guestTeam = controller.guestTeam.value;
          if (errorMessage.isNotEmpty && guestTeam == null) {
            return ClaimCenteredMessage(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل رابط استلام الفريق',
              message: errorMessage,
            );
          }
          if (guestTeam == null) {
            return const ClaimCenteredMessage(
              icon: Icons.groups_2_outlined,
              title: 'الفريق الضيف غير موجود',
              message: 'لم نتمكن من العثور على الفريق المرتبط بهذا الرابط.',
            );
          }

          final claimResult = controller.claimResult.value;
          final selectedTeamId = controller.selectedTeamId.value;
          final canCompletePendingApproval = controller.canCompletePendingApproval;
          final pendingRequestedTeam = controller.pendingRequestedTeam.value;
          final hasTerminalResult = claimResult != null &&
              (claimResult.outcome == GuestTeamClaimOutcome.claimed ||
                  claimResult.outcome == GuestTeamClaimOutcome.alreadyClaimed);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClaimInfoCard(
                  title: guestTeam.name,
                  subtitle: guestTeam.contactName ?? 'فريق ضيف',
                  icon: Icons.shield_outlined,
                  rows: [
                    ClaimInfoRow(
                      label: 'الحالة',
                      value: guestTeam.claimStatus.name,
                    ),
                    if (guestTeam.tournamentIds.isNotEmpty)
                      ClaimInfoRow(
                        label: 'البطولات',
                        value: guestTeam.tournamentIds.join('، '),
                      ),
                    if (guestTeam.contactPhone != null &&
                        guestTeam.contactPhone!.isNotEmpty)
                      ClaimInfoRow(
                        label: 'رقم التواصل',
                        value: guestTeam.contactPhone!,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ClaimInfoCard(
                  title: controller.currentPlayer?.name ?? 'غير مسجل الدخول',
                  subtitle: controller.isAuthenticated
                      ? 'اختر فريقك المسجل الذي تريد ربطه بهذا الفريق الضيف.'
                      : 'سجّل الدخول أولاً حتى تتمكن من تقديم طلب الاستلام.',
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
                if (canCompletePendingApproval) ...[
                  const SizedBox(height: 16),
                  ClaimResultCard(
                    title: 'يوجد طلب claim معلق',
                    message: pendingRequestedTeam != null
                        ? 'تم إرسال طلب ربط هذا الفريق الضيف بالفريق "${pendingRequestedTeam.name}". يمكنك الآن إتمام الموافقة النهائية من حساب منشئ الفريق الضيف.'
                        : 'تم إرسال طلب claim لهذا الفريق، ويمكنك الآن إتمام الموافقة النهائية.',
                    color: Colors.blueGrey,
                    icon: Icons.assignment_turned_in_outlined,
                    footer: pendingRequestedTeam?.name,
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
                const SizedBox(height: 16),
                if (hasTerminalResult) ...[
                  FilledButton(
                    onPressed: () => Get.toNamed(AppRoutes.myTeams),
                    child: const Text('افتح فرقّي'),
                  ),
                ] else if (!controller.isAuthenticated) ...[
                  FilledButton(
                    onPressed: () => Get.toNamed(AppRoutes.login),
                    child: const Text('تسجيل الدخول'),
                  ),
                ] else if (canCompletePendingApproval) ...[
                  FilledButton(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : controller.submitClaim,
                    child: Text(
                      controller.isSubmitting.value
                          ? 'جارٍ اعتماد الطلب...'
                          : 'موافقة المنظم وإتمام الربط',
                    ),
                  ),
                ] else if (controller.ownedTeams.isEmpty) ...[
                  const ClaimResultCard(
                    title: 'لا يوجد فريق صالح للربط',
                    message:
                        'هذا الحساب لا يملك أي فريق مسجل حاليًا. أنشئ فريقًا أو ادخل بحساب القائد أولًا.',
                    color: Colors.orange,
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Get.toNamed(AppRoutes.myTeams),
                    child: const Text('اذهب إلى فرقّي'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeamId,
                    decoration: const InputDecoration(
                      labelText: 'الفريق الذي سيتم ربطه',
                      border: OutlineInputBorder(),
                    ),
                    items: controller.ownedTeams
                        .map(
                          (team) => DropdownMenuItem<String>(
                            value: team.id,
                            child: Text(team.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controller.isSubmitting.value
                        ? null
                        : controller.selectTeam,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : controller.submitClaim,
                    child: Text(
                      controller.isSubmitting.value
                          ? 'جارٍ معالجة الطلب...'
                          : controller.requiresApprovalHint
                              ? 'إرسال طلب الاستلام'
                              : 'استلام الفريق',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Get.toNamed(AppRoutes.myTeams),
                  child: const Text('العودة إلى فرقّي'),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _resultTitle(GuestTeamClaimResult result) {
    switch (result.outcome) {
      case GuestTeamClaimOutcome.claimed:
        return 'تم ربط الفريق بنجاح';
      case GuestTeamClaimOutcome.alreadyClaimed:
        return 'الفريق مرتبط مسبقًا';
      case GuestTeamClaimOutcome.approvalRequired:
        return 'تم إرسال طلب الاستلام';
      case GuestTeamClaimOutcome.conflict:
        return 'يوجد تعارض يحتاج مراجعة';
    }
  }

  String _resultMessage(GuestTeamClaimResult result) {
    switch (result.outcome) {
      case GuestTeamClaimOutcome.claimed:
        return 'تم ربط الفريق الضيف بالفريق المسجل مع الحفاظ على تاريخ البطولات الحالي.';
      case GuestTeamClaimOutcome.alreadyClaimed:
        return 'هذا الفريق الضيف مرتبط بالفعل بالفريق المحدد.';
      case GuestTeamClaimOutcome.approvalRequired:
        return 'تم حفظ طلب الـ claim. سيحتاج الرابط الآن إلى موافقة منشئ الفريق الضيف لإكمال الربط.';
      case GuestTeamClaimOutcome.conflict:
        return result.conflict?.message ?? 'حدث تعارض غير متوقع أثناء الاستلام.';
    }
  }

  Color _resultColor(GuestTeamClaimResult result) {
    switch (result.outcome) {
      case GuestTeamClaimOutcome.claimed:
      case GuestTeamClaimOutcome.alreadyClaimed:
        return Colors.green;
      case GuestTeamClaimOutcome.approvalRequired:
        return Colors.blue;
      case GuestTeamClaimOutcome.conflict:
        return switch (result.conflict?.type) {
          ClaimMergeConflictType.duplicateName => Colors.orange,
          _ => Colors.redAccent,
        };
    }
  }

  IconData _resultIcon(GuestTeamClaimResult result) {
    switch (result.outcome) {
      case GuestTeamClaimOutcome.claimed:
        return Icons.check_circle_outline_rounded;
      case GuestTeamClaimOutcome.alreadyClaimed:
        return Icons.verified_rounded;
      case GuestTeamClaimOutcome.approvalRequired:
        return Icons.hourglass_top_rounded;
      case GuestTeamClaimOutcome.conflict:
        return Icons.warning_amber_rounded;
    }
  }
}
