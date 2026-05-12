import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/team_roster_snapshot.dart';
import 'team_roster_helpers.dart';

class TeamRosterSnapshotCard extends StatelessWidget {
  final TeamRosterSnapshot snapshot;

  const TeamRosterSnapshotCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(snapshot.label, style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(snapshot.summaryLabel, style: AppTextStyles.bodySmall),
          const SizedBox(height: 2),
          Text(
            'تم الإنشاء: ${formatDate(snapshot.createdAt)}',
            style: AppTextStyles.labelSmall,
          ),
          if ((snapshot.sourceTemplateId ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'مشتقة من قالب محفوظ',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
