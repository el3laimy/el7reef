import 'package:flutter/material.dart';

import '../controllers/tournament_operations_controller.dart';

class TournamentPendingActionsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const TournamentPendingActionsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEDF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الخطوات التالية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...controller.pendingActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.playlist_add_check_circle_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.title),
                          const SizedBox(height: 2),
                          Text(
                            action.detail,
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
