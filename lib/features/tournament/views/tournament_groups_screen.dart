import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament_group.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentGroupsScreen extends GetView<TournamentOperationsController> {
  const TournamentGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Groups',
      child: Obx(() {
        if (controller.groups.isEmpty) {
          return const _StateMessage(
            title: 'لم يتم إنشاء المجموعات بعد',
            message: 'ابدأ مرحلة المجموعات من dashboard أولاً.',
          );
        }
        return ListView.builder(
          itemCount: controller.groups.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        label: 'Groups',
                        value: controller.groups.length.toString(),
                      ),
                      _MetricChip(
                        label: 'Fixtures',
                        value: controller.groupStageFixtures
                            .where(
                              (fixture) =>
                                  controller.canManageTournament ||
                                  fixture.fixtureStatus != FixtureStatus.draft,
                            )
                            .length
                            .toString(),
                      ),
                      _MetricChip(
                        label: 'Official',
                        value: controller.groupStageFixtures
                            .where(
                              (fixture) => fixture.isOfficialTournamentResult,
                            )
                            .length
                            .toString(),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (index == 1) {
              return const SizedBox(height: 12);
            }
            return _GroupCard(
              group: controller.groups[index - 2],
              controller: controller,
            );
          },
        );
      }),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final TournamentGroup group;
  final TournamentOperationsController controller;

  const _GroupCard({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    final participants = controller.participantsForGroup(group.id);
    final snapshot = controller.standings
        .where((item) => item.groupId == group.id)
        .firstOrNull;
    final qualifiers = snapshot?.qualifierParticipantIds.toSet() ?? <String>{};
    final groupFixtures =
        controller.groupStageFixtures
            .where((fixture) => fixture.groupId == group.id)
            .where(
              (fixture) =>
                  controller.canManageTournament ||
                  fixture.fixtureStatus != FixtureStatus.draft,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final leftDate = left.scheduledAt ?? left.createdAt;
            final rightDate = right.scheduledAt ?? right.createdAt;
            return leftDate.compareTo(rightDate);
          });
    final officialFixtures = groupFixtures
        .where((fixture) => fixture.isOfficialTournamentResult)
        .length;
    final scheduledFixtures = groupFixtures
        .where((fixture) => fixture.scheduledAt != null)
        .length;

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
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (qualifiers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${qualifiers.length} متأهل',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'فرق',
                  value: participants.length.toString(),
                ),
                _MetricChip(
                  label: 'مباريات',
                  value: groupFixtures.length.toString(),
                ),
                _MetricChip(
                  label: 'مجدولة',
                  value: scheduledFixtures.toString(),
                ),
                _MetricChip(label: 'رسمية', value: officialFixtures.toString()),
              ],
            ),
            const SizedBox(height: 12),
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${participant.seed ?? '-'} • ${participant.displayName}',
                      ),
                    ),
                    if (qualifiers.contains(participant.id))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'متأهل',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (groupFixtures.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'مباريات المجموعة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...groupFixtures.map(
                (fixture) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${controller.fixtureTeamLabel(fixture, isHome: true)} ضد ${controller.fixtureTeamLabel(fixture, isHome: false)}',
                  ),
                  subtitle: Text(
                    '${_formatDateTime(fixture.scheduledAt)} • ${_matchScoreLabel(fixture)}',
                  ),
                  trailing: fixture.isOfficialTournamentResult
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : const Icon(Icons.chevron_right),
                  onTap: () =>
                      Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _ScaffoldListScreen({required this.title, required this.child});

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

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd – HH:mm').format(value);
}

String _matchScoreLabel(Match? match) {
  if (match == null || match.scoreTeamA == null || match.scoreTeamB == null) {
    return '-';
  }
  return '${match.scoreTeamA} - ${match.scoreTeamB}';
}
