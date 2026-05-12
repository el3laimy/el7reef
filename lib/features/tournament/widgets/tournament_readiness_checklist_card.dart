import 'package:flutter/material.dart';

import '../controllers/tournament_operations_controller.dart';

class TournamentReadinessChecklistCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentReadinessChecklistCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جاهزية التشغيل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...controller.readinessChecklist.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isReady ? Icons.check_circle : Icons.hourglass_top,
                      color: item.isReady ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label),
                          const SizedBox(height: 2),
                          Text(
                            item.detail,
                            style: Theme.of(context).textTheme.bodySmall,
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
      ),
    );
  }
}
