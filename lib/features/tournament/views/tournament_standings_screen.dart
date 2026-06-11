import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_state_card.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentStandingsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentStandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'ترتيب البطولة',
      child: Obx(() {
        if (controller.standings.isEmpty) {
          return const Center(
            child: El7reefStateCard(
              title: 'لا يوجد ترتيب بعد',
              message: 'ابدأ المجموعات وسجّل النتائج حتى يظهر ترتيب الفرق.',
              icon: Icons.leaderboard_rounded,
              color: AppColors.primary,
            ),
          );
        }
        return ListView.builder(
          itemCount: controller.standings.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _StandingsHeader(snapshot: controller.standings.first);
            }
            if (index == 1) {
              return const SizedBox(height: AppDimensions.md);
            }
            return _GroupStandingPanel(
              snapshot: controller.standings[index - 2],
              controller: controller,
            );
          },
        );
      }),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  final GroupStandingSnapshot snapshot;

  const _StandingsHeader({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.secondary.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          El7reefBadge(
            label: 'لوحة شرف البطولة',
            color: AppColors.secondary,
            icon: Icons.emoji_events_rounded,
          ),
          const SizedBox(height: AppDimensions.md),
          Text('ترتيب المجموعات', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'حسم التعادل: ${snapshot.tiebreakerOrder.map(_standingsMetricLabel).join('، ')}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupStandingPanel extends StatelessWidget {
  final GroupStandingSnapshot snapshot;
  final TournamentOperationsController controller;

  const _GroupStandingPanel({required this.snapshot, required this.controller});

  @override
  Widget build(BuildContext context) {
    final qualifiers = snapshot.qualifierParticipantIds.toSet();
    final podiumEntries = snapshot.entries.take(3).toList(growable: false);
    final remainingEntries = snapshot.entries.skip(3).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: El7reefSurface(
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
                        style: AppTextStyles.titleLarge,
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'آخر تحديث: ${intl.DateFormat('yyyy/MM/dd - HH:mm').format(snapshot.updatedAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryTinted,
                        ),
                      ),
                    ],
                  ),
                ),
                El7reefBadge(
                  label: '${snapshot.qualifierParticipantIds.length} متأهل',
                  color: AppColors.success,
                  icon: Icons.trending_up_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'الترتيب المعتمد للتأهل وحساب المراحل التالية.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            if (podiumEntries.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              _PodiumSection(entries: podiumEntries, qualifiers: qualifiers),
            ],
            if (remainingEntries.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              ...remainingEntries.map(
                (entry) => _StandingTeamRow(
                  entry: entry,
                  isQualified: qualifiers.contains(entry.participantId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  final List<GroupStandingEntry> entries;
  final Set<String> qualifiers;

  const _PodiumSection({required this.entries, required this.qualifiers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries
          .map(
            (entry) => _PodiumTeamCard(
              entry: entry,
              isQualified: qualifiers.contains(entry.participantId),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PodiumTeamCard extends StatelessWidget {
  final GroupStandingEntry entry;
  final bool isQualified;

  const _PodiumTeamCard({required this.entry, required this.isQualified});

  @override
  Widget build(BuildContext context) {
    final accent = _rankAccent(entry.rank);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: entry.rank == 1 ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RankToken(rank: entry.rank, color: accent),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  entry.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimaryTinted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isQualified)
                const El7reefBadge(
                  label: 'متأهل',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Text(
                '${entry.points}',
                style: AppTextStyles.displaySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AppDimensions.xs),
              Text(
                'نقطة',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _StandingStatsLine(entry: entry),
        ],
      ),
    );
  }
}

class _StandingTeamRow extends StatelessWidget {
  final GroupStandingEntry entry;
  final bool isQualified;

  const _StandingTeamRow({required this.entry, required this.isQualified});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RankToken(rank: entry.rank, color: AppColors.textMuted),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  entry.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryTinted,
                  ),
                ),
              ),
              if (isQualified)
                const El7reefBadge(label: 'متأهل', color: AppColors.success),
              const SizedBox(width: AppDimensions.sm),
              Text(
                '${entry.points} نقطة',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _StandingStatsLine(entry: entry),
        ],
      ),
    );
  }
}

class _RankToken extends StatelessWidget {
  final int rank;
  final Color color;

  const _RankToken({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '#$rank',
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StandingStatsLine extends StatelessWidget {
  final GroupStandingEntry entry;

  const _StandingStatsLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final gd = entry.goalDifference;
    final gdLabel = gd > 0 ? '+$gd' : gd.toString();
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.xs,
      children: [
        _CompactStat(label: 'لعب', value: entry.played.toString()),
        _CompactStat(label: 'فاز', value: entry.wins.toString()),
        _CompactStat(label: 'تعادل', value: entry.draws.toString()),
        _CompactStat(label: 'خسر', value: entry.losses.toString()),
        _CompactStat(label: 'له', value: entry.goalsFor.toString()),
        _CompactStat(label: 'عليه', value: entry.goalsAgainst.toString()),
        _CompactStat(label: 'فرق', value: gdLabel),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;

  const _CompactStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondaryTinted,
        fontWeight: FontWeight.w700,
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

String _standingsMetricLabel(GroupStandingsMetric metric) => switch (metric) {
  GroupStandingsMetric.points => 'النقاط',
  GroupStandingsMetric.goalDifference => 'فرق الأهداف',
  GroupStandingsMetric.goalsFor => 'الأهداف المسجلة',
  GroupStandingsMetric.randomDraw => 'قرعة',
};

Color _rankAccent(int rank) => switch (rank) {
  1 => AppColors.secondary,
  2 => AppColors.rankSilver,
  3 => AppColors.rankBronze,
  _ => AppColors.primary,
};
