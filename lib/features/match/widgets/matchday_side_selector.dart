import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_no_managed_side_card.dart';

class MatchdaySideSelector extends StatelessWidget {
  final MatchdayController controller;

  const MatchdaySideSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.managedSides.isEmpty) {
      return MatchdayNoManagedSideCard(controller: controller);
    }

    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأطراف القابلة للإدارة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.managedSides
                .map(
                  (side) => ChoiceChip(
                    label: Text(side.label),
                    selected: controller.selectedSideKey.value == side.key,
                    onSelected: (_) => controller.selectSide(side.key),
                    selectedColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                      color: controller.selectedSideKey.value == side.key
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
