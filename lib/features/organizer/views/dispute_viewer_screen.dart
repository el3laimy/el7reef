import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/dispute_enums.dart';
import '../../../domain/entities/dispute.dart';
import '../controllers/dispute_viewer_controller.dart';

/// شاشة عرض وإدارة النزاعات لمباراة محددة
class DisputeViewerScreen extends GetView<DisputeViewerController> {
  const DisputeViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'النزاعات',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Obx(() {
            final open = controller.openCount;
            if (open == 0) return const SizedBox.shrink();
            return Center(
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$open مفتوح',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadDisputes,
          ),
        ],
      ),
      body: Obx(() {
        // Success/error snackbar
        if (controller.successMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.snackbar(
              'تم',
              controller.successMessage.value,
              backgroundColor: AppColors.success.withValues(alpha: 0.9),
              colorText: Colors.white,
            );
            controller.successMessage.value = '';
          });
        }

        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        if (controller.disputes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                SizedBox(height: 12),
                Text(
                  'لا توجد نزاعات على هذه المباراة',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.disputes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _DisputeCard(
            dispute: controller.disputes[index],
            controller: controller,
          ),
        );
      }),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Dispute dispute;
  final DisputeViewerController controller;

  const _DisputeCard({
    required this.dispute,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dispute.isOpen ? AppColors.warning.withValues(alpha: 0.5) : AppColors.surfaceBorder,
          width: dispute.isOpen ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              _StatusChip(status: dispute.status, label: controller.statusLabel(dispute.status)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.typeLabel(dispute.type),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Description ──
          Text(
            dispute.description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // ── Meta ──
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                _formatDate(dispute.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 16),
              Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'المهلة: ${_formatDate(dispute.deadline)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),

          // ── Resolution Note ──
          if (dispute.resolutionNote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dispute.resolutionNote!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Action Buttons (for open disputes) ──
          if (dispute.isOpen) ...[
            const SizedBox(height: 16),
            Obx(() {
              final processing = controller.isProcessing.value;
              return Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: processing
                          ? null
                          : () => _showResolveDialog(context),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('حل'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processing
                          ? null
                          : () => _showRejectDialog(context),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext context) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حل النزاع', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'ملاحظات الحل...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.resolveDispute(
                disputeId: dispute.id,
                resolvedBy: controller.currentUserId ?? '',
                resolutionNote: noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : 'تم الحل',
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('تأكيد الحل'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('رفض النزاع', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'سبب الرفض...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.rejectDispute(
                disputeId: dispute.id,
                rejectedBy: controller.currentUserId ?? '',
                rejectionNote: noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : 'النزاع مرفوض',
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final formatter = intl.DateFormat('MM/dd – HH:mm', 'ar');
    return formatter.format(dt);
  }
}

class _StatusChip extends StatelessWidget {
  final DisputeStatus status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _chipColor {
    switch (status) {
      case DisputeStatus.open:
      case DisputeStatus.underReview:
        return AppColors.warning;
      case DisputeStatus.resolved:
        return AppColors.success;
      case DisputeStatus.rejected:
        return AppColors.error;
      case DisputeStatus.expired:
        return AppColors.textMuted;
    }
  }
}
