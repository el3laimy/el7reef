import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/match.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_stage_components.dart';
import '../widgets/tournament_standings_table.dart';

class TournamentStandingsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentStandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TournamentStageScaffold(
      title: 'ترتيب البطولة',
      onRefresh: controller.refreshAll,
      child: Obx(() {
        final hasData = controller.standings.isNotEmpty;
        if (controller.isLoading.value && !hasData) {
          return const TournamentStageSkeleton(rows: 6);
        }
        if (controller.errorMessage.value.isNotEmpty && !hasData) {
          return TournamentStageStateView(
            title: 'تعذر تحميل الترتيب',
            message: controller.errorMessage.value,
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            actionLabel: 'إعادة المحاولة',
            actionIcon: Icons.refresh_rounded,
            onAction: controller.refreshAll,
          );
        }
        if (!hasData) {
          return _EmptyStandingsState(controller: controller);
        }

        final groupLabels = {
          for (final group in controller.groups) group.id: group.name,
        };
        final qualificationIsOfficialByGroup = <String, bool>{
          for (final snapshot in controller.standings)
            snapshot.groupId: _qualificationIsOfficial(
              snapshot.groupId,
              controller.groupStageFixtures,
            ),
        };

        return Column(
          children: [
            if (controller.errorMessage.value.isNotEmpty) ...[
              TournamentStageDataNotice.cachedError(
                onRetry: controller.refreshAll,
              ),
              const SizedBox(height: AppDimensions.md),
            ] else if (controller.isLoading.value) ...[
              const TournamentStageDataNotice.refreshing(),
              const SizedBox(height: AppDimensions.md),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    TournamentStandingsContent(
                      snapshots: controller.standings.toList(growable: false),
                      groupLabel: (groupId) => groupLabels[groupId] ?? groupId,
                      qualificationIsOfficialByGroup:
                          qualificationIsOfficialByGroup,
                    ),
                    const SizedBox(height: AppDimensions.xl),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class TournamentStandingsContent extends StatefulWidget {
  final List<GroupStandingSnapshot> snapshots;
  final String Function(String groupId) groupLabel;
  final Map<String, bool> qualificationIsOfficialByGroup;

  const TournamentStandingsContent({
    super.key,
    required this.snapshots,
    required this.groupLabel,
    required this.qualificationIsOfficialByGroup,
  });

  @override
  State<TournamentStandingsContent> createState() =>
      _TournamentStandingsContentState();
}

class _TournamentStandingsContentState
    extends State<TournamentStandingsContent> {
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.snapshots.firstOrNull?.groupId;
  }

  @override
  void didUpdateWidget(covariant TournamentStandingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.snapshots.any(
      (snapshot) => snapshot.groupId == _selectedGroupId,
    )) {
      _selectedGroupId = widget.snapshots.firstOrNull?.groupId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshots
        .where((standing) => standing.groupId == _selectedGroupId)
        .firstOrNull;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    final qualificationIsOfficial =
        widget.qualificationIsOfficialByGroup[snapshot.groupId] ?? false;
    final sortedEntries = snapshot.entries.toList(growable: false)
      ..sort((left, right) => left.rank.compareTo(right.rank));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ترتيب المجموعات', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppDimensions.sm),
        TournamentGroupSelector(
          items: widget.snapshots
              .map(
                (standing) => TournamentGroupSelectorItem(
                  id: standing.groupId,
                  label: widget.groupLabel(standing.groupId),
                  trailingCount: standing.entries.length,
                ),
              )
              .toList(growable: false),
          selectedId: snapshot.groupId,
          onSelected: (groupId) => setState(() => _selectedGroupId = groupId),
        ),
        const SizedBox(height: AppDimensions.md),
        El7reefSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TournamentStageSectionHeading(
                title: widget.groupLabel(snapshot.groupId),
                subtitle:
                    'آخر تحديث: ${intl.DateFormat('yyyy/MM/dd، HH:mm').format(snapshot.updatedAt)}',
                trailing: El7reefBadge(
                  label: qualificationIsOfficial
                      ? 'مراكز رسمية'
                      : 'مراكز مؤقتة',
                  color: qualificationIsOfficial
                      ? AppColors.success
                      : AppColors.primary,
                  icon: qualificationIsOfficial
                      ? Icons.verified_rounded
                      : Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Text(
                  'حسم التعادل: ${snapshot.tiebreakerOrder.map(_standingsMetricLabel).join('، ')}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
              ),
              if (sortedEntries.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Text(
                      'المتصدر',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    const Spacer(),
                    Text(
                      '${sortedEntries.first.points}',
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      'نقطة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimensions.md),
              TournamentStandingsTable(
                entries: sortedEntries,
                qualifierParticipantIds: snapshot.qualifierParticipantIds
                    .toSet(),
                qualificationIsOfficial: qualificationIsOfficial,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyStandingsState extends StatelessWidget {
  final TournamentOperationsController controller;

  const _EmptyStandingsState({required this.controller});

  @override
  Widget build(BuildContext context) {
    final canManage = controller.canManageTournament;
    final canStartGroups = controller.canStartGroupStageAction;
    return TournamentStageStateView(
      title: 'لا يوجد ترتيب بعد',
      message: canManage
          ? canStartGroups
                ? 'ابدأ دور المجموعات ليظهر جدول الفرق من أول نتيجة.'
                : 'سجّل واعتمد نتائج مباريات المجموعات ليُحدّث الترتيب.'
          : 'سيظهر ترتيب الفرق هنا بعد بدء المجموعات واعتماد النتائج.',
      icon: Icons.leaderboard_rounded,
      actionLabel: !canManage
          ? null
          : canStartGroups
          ? 'ابدأ دور المجموعات'
          : 'افتح لوحة التشغيل',
      actionIcon: canStartGroups
          ? Icons.groups_2_rounded
          : Icons.dashboard_customize_rounded,
      onAction: !canManage
          ? null
          : canStartGroups
          ? controller.startGroupStage
          : () {
              final tournamentId = controller.tournamentId;
              if (tournamentId != null && tournamentId.isNotEmpty) {
                Get.offNamed(
                  AppRoutes.organizerDashboardForTournament(tournamentId),
                );
              }
            },
      actionLoading: controller.isActing.value,
    );
  }
}

bool _qualificationIsOfficial(String groupId, List<Match> fixtures) {
  final groupFixtures = fixtures
      .where((fixture) => fixture.groupId == groupId)
      .toList(growable: false);
  return groupFixtures.isNotEmpty &&
      groupFixtures.every((fixture) => fixture.isOfficialTournamentResult);
}

String _standingsMetricLabel(GroupStandingsMetric metric) => switch (metric) {
  GroupStandingsMetric.points => 'النقاط',
  GroupStandingsMetric.goalDifference => 'فرق الأهداف',
  GroupStandingsMetric.goalsFor => 'الأهداف المسجلة',
  GroupStandingsMetric.randomDraw => 'القرعة',
};
