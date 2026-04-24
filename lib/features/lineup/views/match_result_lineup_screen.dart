import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../controllers/match_result_lineup_controller.dart';
import '../widgets/bench_bar.dart';
import '../widgets/professional_match_header.dart';
import '../widgets/professional_pitch_card.dart';

class MatchResultLineupScreen extends GetView<MatchResultLineupController> {
  const MatchResultLineupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تشكيلة المباراة'),
          actions: [
            IconButton(
              onPressed: _shareResult,
              icon: const Icon(Icons.share_rounded),
              tooltip: 'مشاركة',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (controller.errorMessage.value.isNotEmpty) {
              return _ResultErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.loadResultLineup,
              );
            }
            final match = controller.match.value;
            final home = controller.homeSide;
            final away = controller.awaySide;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.loadResultLineup,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                children: [
                  ProfessionalMatchHeader(
                    homeName: home.label,
                    awayName: away.label,
                    homeLogoUrl: home.logoUrl,
                    awayLogoUrl: away.logoUrl,
                    homeScore: match?.scoreTeamA,
                    awayScore: match?.scoreTeamB,
                    status: match?.status,
                    startedAt: match?.startedAt,
                    tournamentName: match?.isOrganized == true
                        ? 'مباراة بطولة'
                        : 'مباراة الحريف',
                    location: match?.location,
                    onShare: _shareResult,
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  _SnapshotWarning(
                    hasHome: home.snapshot != null,
                    hasAway: away.snapshot != null,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 720;
                      final homeCard = _ResultTeamLineupCard(
                        controller: controller,
                        title: home.label,
                        side: home,
                      );
                      final awayCard = _ResultTeamLineupCard(
                        controller: controller,
                        title: away.label,
                        side: away,
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            homeCard,
                            const SizedBox(height: AppDimensions.lg),
                            awayCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: homeCard),
                          const SizedBox(width: AppDimensions.lg),
                          Expanded(child: awayCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.xl),
                  Center(
                    child: Text(
                      'EL7REEF • الحريف',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _shareResult() {
    // TODO(lineup-share): capture this screen as a branded image/card and
    // share the generated image instead of text-only sharing.
    final match = controller.match.value;
    final home = controller.homeSide.label;
    final away = controller.awaySide.label;
    final score = match == null
        ? ''
        : ' ${match.scoreTeamA ?? 0}-${match.scoreTeamB ?? 0} ';
    Share.share('تشكيلة مباراة $home$score$away على الحريف');
  }
}

class _ResultTeamLineupCard extends StatelessWidget {
  final MatchResultLineupController controller;
  final String title;
  final ResultLineupSide side;

  const _ResultTeamLineupCard({
    required this.controller,
    required this.title,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = side.snapshot;
    final playerCount = controller.playerCountForSnapshot(snapshot);
    final formation = controller.formationForSnapshot(snapshot);
    final playersByKey = controller.playersByKeyForSnapshot(snapshot);
    final slots = controller.slotsForSnapshot(snapshot);
    final bench = controller.benchForSnapshot(snapshot);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      snapshot == null
                          ? 'لم يتم حفظ snapshot للتشكيلة'
                          : '$formation • ${snapshot.starters.length}/$playerCount أساسي',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              _FormationPill(label: formation),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ProfessionalPitchCard(
            slots: slots,
            playersByKey: playersByKey,
            formationCode: formation,
            playerCount: playerCount,
            teamName: title,
            presentationMode: true,
          ),
          if (bench.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            BenchBar(players: bench, compact: true),
          ],
        ],
      ),
    );
  }
}

class _FormationPill extends StatelessWidget {
  final String label;

  const _FormationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SnapshotWarning extends StatelessWidget {
  final bool hasHome;
  final bool hasAway;

  const _SnapshotWarning({required this.hasHome, required this.hasAway});

  @override
  Widget build(BuildContext context) {
    if (hasHome && hasAway) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'هذه الشاشة تعرض snapshots المباراة المحفوظة فقط، ولا تستخدم التشكيلة الحالية للفريق.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ResultErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
