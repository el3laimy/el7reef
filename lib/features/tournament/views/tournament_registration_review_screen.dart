import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/tournament_registration_status.dart';
import '../controllers/tournament_registration_review_controller.dart';

class TournamentRegistrationReviewScreen
    extends GetView<TournamentRegistrationReviewController> {
  const TournamentRegistrationReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة تسجيل البطولة')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final tournament = controller.tournament.value;
          final registration = controller.registration.value;
          if (tournament == null || registration == null) {
            return _ReviewState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل التسجيل',
              message: controller.errorMessage.value.isEmpty
                  ? 'لم نتمكن من العثور على بيانات التسجيل المطلوبة.'
                  : controller.errorMessage.value,
            );
          }

          if (!controller.isOrganizer) {
            return const _ReviewState(
              icon: Icons.lock_outline_rounded,
              title: 'هذه الصفحة للمنظّم فقط',
              message:
                  'اعتماد التسجيلات أو رفضها يحتاج صلاحية المنظّم داخل البطولة.',
            );
          }

          final participantName =
              controller.team.value?.name ?? controller.guestTeam.value?.name ?? 'غير معروف';
          final participantType =
              registration.isGuestRegistration ? 'فريق ضيف' : 'فريق مسجل';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _StatusChip(status: registration.status),
                      const SizedBox(height: 12),
                      Text('المشارك: $participantName'),
                      Text('النوع: $participantType'),
                      if (registration.verifiedBy != null &&
                          registration.verifiedBy!.isNotEmpty)
                        Text('تم الاعتماد بواسطة: ${registration.verifiedBy}'),
                      if (registration.isGuestRegistration) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: controller.shareGuestTeamClaimLink,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('إرسال رابط تسليم الفريق'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات المنظّم',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller.rejectionNotesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'أضف سبب الرفض أو أي ملاحظات تنظيمية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.errorMessage.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    controller.isSubmitting.value || !controller.canApprove
                        ? null
                        : controller.approve,
                icon: controller.isSubmitting.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(
                  controller.isSubmitting.value
                      ? 'جارٍ تنفيذ الطلب...'
                      : registration.status == TournamentRegistrationStatus.rejected
                          ? 'اعتماد بعد الرفض'
                          : 'اعتماد التسجيل',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    controller.isSubmitting.value || !controller.canReject
                        ? null
                        : controller.reject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('رفض التسجيل'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TournamentRegistrationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TournamentRegistrationStatus.approved => Colors.green,
      TournamentRegistrationStatus.pending => Colors.orange,
      TournamentRegistrationStatus.rejected => Colors.redAccent,
      TournamentRegistrationStatus.cancelled => Colors.blueGrey,
    };
    final label = switch (status) {
      TournamentRegistrationStatus.approved => 'معتمد',
      TournamentRegistrationStatus.pending => 'بانتظار الاعتماد',
      TournamentRegistrationStatus.rejected => 'مرفوض',
      TournamentRegistrationStatus.cancelled => 'ملغي',
    };

    return Chip(
      avatar: Icon(Icons.info_outline_rounded, color: color, size: 18),
      label: Text(label),
    );
  }
}

class _ReviewState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ReviewState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
