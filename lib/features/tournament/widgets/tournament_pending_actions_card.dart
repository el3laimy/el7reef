import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentPendingActionsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentPendingActionsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      color: AppColors.infoSurface,
      borderColor: AppColors.info.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الخطوة الجاية', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.md),
          ...controller.pendingActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.playlist_add_check_circle_rounded,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.title, style: AppTextStyles.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          action.detail,
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
