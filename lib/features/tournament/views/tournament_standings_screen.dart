import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentStandingsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentStandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Standings',
      child: Obx(() {
        if (controller.standings.isEmpty) {
          return const _StateMessage(
            title: 'لا توجد standings بعد',
            message: 'لن تظهر standings إلا بعد إنشاء المجموعات.',
          );
        }
        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترتيب المجموعات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tie-breakers: ${controller.standings.first.tiebreakerOrder.map(_standingsMetricLabel).join(' → ')}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...controller.standings.map(
              (snapshot) =>
                  _StandingCard(snapshot: snapshot, controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

class _StandingCard extends StatelessWidget {
  final GroupStandingSnapshot snapshot;
  final TournamentOperationsController controller;

  const _StandingCard({required this.snapshot, required this.controller});

  @override
  Widget build(BuildContext context) {
    final qualifiers = snapshot.qualifierParticipantIds.toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.groupLabelFor(snapshot.groupId),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'آخر تحديث: ${intl.DateFormat('yyyy/MM/dd – HH:mm').format(snapshot.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${snapshot.qualifierParticipantIds.length} Qualified',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'هذا هو الـ canonical standings snapshot المعتمد للتأهل والترتيب.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Team')),
                  DataColumn(label: Text('P')),
                  DataColumn(label: Text('W')),
                  DataColumn(label: Text('D')),
                  DataColumn(label: Text('L')),
                  DataColumn(label: Text('GF')),
                  DataColumn(label: Text('GA')),
                  DataColumn(label: Text('GD')),
                  DataColumn(label: Text('Pts')),
                  DataColumn(label: Text('Status')),
                ],
                rows: snapshot.entries
                    .map((entry) {
                      final isQualified = qualifiers.contains(
                        entry.participantId,
                      );
                      return DataRow(
                        color: WidgetStatePropertyAll<Color?>(
                          isQualified ? const Color(0xFFF0FAF0) : null,
                        ),
                        cells: [
                          DataCell(Text(entry.rank.toString())),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.displayName),
                                if (isQualified) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9F2D9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text('Qualified'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(Text(entry.played.toString())),
                          DataCell(Text(entry.wins.toString())),
                          DataCell(Text(entry.draws.toString())),
                          DataCell(Text(entry.losses.toString())),
                          DataCell(Text(entry.goalsFor.toString())),
                          DataCell(Text(entry.goalsAgainst.toString())),
                          DataCell(Text(entry.goalDifference.toString())),
                          DataCell(Text(entry.points.toString())),
                          DataCell(
                            Text(isQualified ? 'Advancing' : 'In Group'),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _ScaffoldListScreen({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String message;

  const _StateMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _standingsMetricLabel(GroupStandingsMetric metric) => switch (metric) {
  GroupStandingsMetric.points => 'Points',
  GroupStandingsMetric.goalDifference => 'Goal Difference',
  GroupStandingsMetric.goalsFor => 'Goals For',
  GroupStandingsMetric.randomDraw => 'Random Draw',
};
