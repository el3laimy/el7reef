import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class LineupStatusPanel extends StatelessWidget {
  final String formationCode;
  final int filledSlots;
  final int totalSlots;
  final int benchCount;
  final bool isDirty;
  final bool canManageLineup;
  final String editableHint;
  final String readonlyHint;
  final String? selectedPlayerName;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  const LineupStatusPanel({
    super.key,
    required this.formationCode,
    required this.filledSlots,
    required this.totalSlots,
    required this.benchCount,
    required this.isDirty,
    required this.canManageLineup,
    this.editableHint =
        'اضغط لاعب من الملعب أو البدلاء، ثم اضغط خانة للنقل أو التبديل.',
    this.readonlyHint = 'عرض الخطة الحالية.',
    this.selectedPlayerName,
    this.onCancel,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSlots <= 0 ? 1 : totalSlots;
    final emptySlots = (safeTotal - filledSlots).clamp(0, safeTotal);
    final progress = (filledSlots / safeTotal).clamp(0.0, 1.0);
    final statusColor = isDirty
        ? AppColors.warning
        : emptySlots > 0
        ? AppColors.accentLight
        : AppColors.primaryLight;
    final statusLabel = isDirty
        ? 'جاهزة للحفظ'
        : emptySlots > 0
        ? 'تحتاج إكمال'
        : 'محفوظة';
    final showActions =
        canManageLineup && isDirty && (onCancel != null || onSave != null);
    final selectedName = selectedPlayerName?.trim();
    final hasSelectedPlayer =
        canManageLineup && selectedName != null && selectedName.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDirty ? 0.16 : 0.08),
            blurRadius: isDirty ? 18 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.7)),
                ),
                child: Icon(
                  isDirty ? Icons.edit_note_rounded : Icons.verified_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خطة $formationCode',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canManageLineup ? editableHint : readonlyHint,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _LineupMetricChip(
                icon: Icons.bolt_rounded,
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          if (hasSelectedPlayer) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.42),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'مختار: $selectedName',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Flexible(
                    child: Text(
                      'اضغط خانة للنقل أو التبديل',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              _LineupMetricChip(
                icon: Icons.sports_soccer_rounded,
                label: '$filledSlots/$safeTotal على الملعب',
                color: AppColors.primaryLight,
              ),
              _LineupMetricChip(
                icon: Icons.radio_button_unchecked_rounded,
                label: '$emptySlots خانة فاضية',
                color: emptySlots == 0
                    ? AppColors.primaryLight
                    : AppColors.accentLight,
              ),
              _LineupMetricChip(
                icon: Icons.event_seat_rounded,
                label: '$benchCount بدلاء',
                color: AppColors.infoLight,
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              alignment: WrapAlignment.end,
              children: [
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('إلغاء'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      textStyle: AppTextStyles.labelLarge,
                      minimumSize: const Size(92, 44),
                    ),
                  ),
                if (onSave != null)
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('حفظ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      textStyle: AppTextStyles.labelLarge,
                      minimumSize: const Size(128, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineupMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LineupMetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
