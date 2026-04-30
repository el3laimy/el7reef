import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class LineupSaveSuccessShareSheet extends StatelessWidget {
  final bool isIncomplete;
  final VoidCallback onShare;
  final VoidCallback onContinueEditing;

  const LineupSaveSuccessShareSheet({
    super.key,
    required this.isIncomplete,
    required this.onShare,
    required this.onContinueEditing,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تم حفظ التشكيلة ✅', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.sm),
            Text(
              isIncomplete
                  ? 'تم حفظ التشكيلة، لكنها لسه فيها خانات فاضية. تقدر تشاركها أو تكمل تعديلها.'
                  : 'شارك التشكيلة مع اللاعبين وخلي شكل الماتش احترافي.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('شارك التشكيلة'),
            ),
            const SizedBox(height: AppDimensions.sm),
            TextButton(
              onPressed: onContinueEditing,
              child: const Text('متابعة التعديل'),
            ),
          ],
        ),
      ),
    );
  }
}
