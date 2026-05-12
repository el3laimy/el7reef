import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/match_start_service.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../models/friendly_match_side_view.dart';

class StartWithoutLineupNudgeSheet extends StatelessWidget {
  final FriendlyMatchSideView? sideA;
  final FriendlyMatchSideView? sideB;
  final Future<void> Function() onStartWithoutLineup;
  final Future<void> Function(FriendlyMatchSideView side) onCreateLineup;

  const StartWithoutLineupNudgeSheet({
    super.key,
    required this.sideA,
    required this.sideB,
    required this.onStartWithoutLineup,
    required this.onCreateLineup,
  });

  @override
  Widget build(BuildContext context) {
    final lineupSides = [sideA, sideB]
        .whereType<FriendlyMatchSideView>()
        .where((side) => side.playerCount > 0)
        .toList(growable: false);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تبدأ من غير تشكيلة؟', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'التشكيلة اختيارية، لكنها تخلي الماتش شكله احترافي وتقدر تشاركها مع اللاعبين.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (lineupSides.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.lg),
              ...lineupSides.map(
                (side) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: FilledButton.icon(
                    onPressed: () => onCreateLineup(side),
                    icon: const Icon(Icons.sports_soccer_rounded),
                    label: Text('اعمل تشكيلة ${side.displayName}'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.sm),
            OutlinedButton.icon(
              onPressed: onStartWithoutLineup,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ بدون تشكيلة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReadinessStepper extends StatelessWidget {
  final MatchStartReadiness readiness;

  const ReadinessStepper({super.key, required this.readiness});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  readiness.canStart
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: readiness.canStart
                      ? AppColors.success
                      : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  readiness.canStart ? 'جاهز للبدء ✅' : 'متطلبات البدء',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: readiness.canStart
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
            if (!readiness.canStart) ...[
              const SizedBox(height: AppDimensions.sm),
              ...readiness.blockedReasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Expanded(
                        child: Text(
                          reason,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
