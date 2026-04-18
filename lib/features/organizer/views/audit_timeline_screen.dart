import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/audit_action.dart';
import '../../../domain/entities/audit_event.dart';
import '../controllers/audit_timeline_controller.dart';

/// شاشة عرض سجل التدقيق (Timeline) لكيان محدد
class AuditTimelineScreen extends GetView<AuditTimelineController> {
  const AuditTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'سجل التدقيق',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadTimeline,
          ),
        ],
      ),
      body: Obx(() {
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
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.loadTimeline,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        if (controller.events.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد أحداث مسجلة بعد',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.events.length,
          itemBuilder: (context, index) => _AuditEventTile(
            event: controller.events[index],
            label: controller.actionLabel(controller.events[index].action),
            isFirst: index == 0,
            isLast: index == controller.events.length - 1,
          ),
        );
      }),
    );
  }
}

class _AuditEventTile extends StatelessWidget {
  final AuditEvent event;
  final String label;
  final bool isFirst;
  final bool isLast;

  const _AuditEventTile({
    required this.event,
    required this.label,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline Indicator ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: AppColors.surfaceBorder),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dotColor(event.action),
                    border: Border.all(color: AppColors.surfaceBorder, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.surfaceBorder),
                  ),
              ],
            ),
          ),

          // ── Event Card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(event.createdAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (event.metadata != null && event.metadata!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...event.metadata!.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(AuditAction action) {
    if (action.name.contains('dispute') || action.name.contains('Frozen')) {
      return AppColors.warning;
    }
    if (action.name.contains('Rejected') || action.name.contains('Removed')) {
      return AppColors.error;
    }
    if (action.name.contains('Approved') ||
        action.name.contains('Settled') ||
        action.name.contains('Resolved')) {
      return AppColors.success;
    }
    return AppColors.accent;
  }

  String _formatTimestamp(DateTime dateTime) {
    final formatter = intl.DateFormat('yyyy/MM/dd – HH:mm', 'ar');
    return formatter.format(dateTime);
  }
}
