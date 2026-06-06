import 'package:flutter/material.dart';

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
    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نبض البطولة', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              TournamentMetricChip(
                label: 'المباريات',
                value: controller.fixtures.length.toString(),
              ),
              TournamentMetricChip(
                label: 'مسودة',
                value: controller.draftFixturesCount.toString(),
              ),
              TournamentMetricChip(
                label: 'منشورة',
                value: controller.publishedFixturesCount.toString(),
              ),
              TournamentMetricChip(
                label: 'مجدولة',
                value: controller.scheduledFixturesCount.toString(),
              ),
              TournamentMetricChip(
                label: 'نتائج رسمية',
                value: controller.officialResultsCount.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
