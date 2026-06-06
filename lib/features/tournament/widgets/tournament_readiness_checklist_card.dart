import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentReadinessChecklistCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentReadinessChecklistCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جاهزية التشغيل', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.md),
          ...controller.readinessChecklist.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isReady
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    color: item.isReady ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppTextStyles.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          item.detail,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryTinted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
