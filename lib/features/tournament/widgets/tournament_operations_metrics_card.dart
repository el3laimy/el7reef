import 'package:flutter/material.dart';

import '../controllers/tournament_operations_controller.dart';
import 'tournament_metric_chip.dart';

class TournamentOperationsMetricsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentOperationsMetricsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مؤشرات التشغيل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TournamentMetricChip(
                  label: 'Fixtures',
                  value: controller.fixtures.length.toString(),
                ),
                TournamentMetricChip(
                  label: 'Draft',
                  value: controller.draftFixturesCount.toString(),
                ),
                TournamentMetricChip(
                  label: 'Published',
                  value: controller.publishedFixturesCount.toString(),
                ),
                TournamentMetricChip(
                  label: 'Scheduled',
                  value: controller.scheduledFixturesCount.toString(),
                ),
                TournamentMetricChip(
                  label: 'Official Results',
                  value: controller.officialResultsCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
