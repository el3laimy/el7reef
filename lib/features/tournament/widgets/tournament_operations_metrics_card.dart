import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../controllers/tournament_operations_controller.dart';
import 'tournament_metric_chip.dart';

class TournamentOperationsMetricsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentOperationsMetricsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      TournamentMetricChip(
        label: 'المباريات',
        value: controller.fixtures.length.toString(),
      ),
      TournamentMetricChip(
        label: 'مسودة',
        value: controller.draftFixturesCount.toString(),
      ),
      TournamentMetricChip(
        label: 'متاحة',
        value: controller.releasedFixturesCount.toString(),
      ),
      TournamentMetricChip(
        label: 'لها موعد',
        value: controller.scheduledFixturesCount.toString(),
      ),
      TournamentMetricChip(
        label: 'نتائج رسمية',
        value: controller.officialResultsCount.toString(),
      ),
    ];
    return El7reefSurface(
      color: AppColors.surfaceSunken,
      borderColor: AppColors.surfaceBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                'نبض البطولة',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 5 : 3;
              final width =
                  (constraints.maxWidth - AppDimensions.md * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppDimensions.md,
                runSpacing: AppDimensions.md,
                children: metrics
                    .map((metric) => SizedBox(width: width, child: metric))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
