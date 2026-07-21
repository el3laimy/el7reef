import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_surface.dart';

class PostMatchPrideHubSheet extends StatelessWidget {
  final String? scoreLine;
  final bool hasMvp;
  final String? mvpName;
  final bool canOpenTopScorers;
  final VoidCallback onOpenResult;
  final VoidCallback? onOpenMvp;
  final VoidCallback? onOpenTopScorers;
  final VoidCallback onReturnToMatch;

  const PostMatchPrideHubSheet({
    super.key,
    required this.scoreLine,
    required this.hasMvp,
    this.mvpName,
    required this.canOpenTopScorers,
    required this.onOpenResult,
    this.onOpenMvp,
    this.onOpenTopScorers,
    required this.onReturnToMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.md,
            AppDimensions.lg,
            AppDimensions.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.center,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                const El7reefBadge(
                  label: 'لحظة الفخر جاهزة',
                  color: AppColors.secondary,
                  icon: Icons.emoji_events_rounded,
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'اختار الكارت اللي هتشاركه',
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'النتيجة والـMVP والهدافون يفتحون من مكان واحد، بدون تغيير النتيجة المسجلة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
                if (scoreLine != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  _ScoreLine(scoreLine: scoreLine!),
                ],
                const SizedBox(height: AppDimensions.lg),
                _HubAction(
                  icon: Icons.sports_score_rounded,
                  title: 'شارك كارت النتيجة',
                  subtitle: 'المشاركة تفتح الآن من غير تنقل إضافي.',
                  color: AppColors.primary,
                  onPressed: onOpenResult,
                ),
                if (hasMvp) ...[
                  const SizedBox(height: AppDimensions.sm),
                  _HubAction(
                    icon: Icons.workspace_premium_rounded,
                    title: 'شارك كارت نجم المباراة',
                    subtitle: mvpName == null
                        ? 'شارك لحظة MVP من نفس المكان.'
                        : 'نجم المباراة: $mvpName',
                    color: AppColors.secondary,
                    onPressed: onOpenMvp,
                  ),
                ],
                if (canOpenTopScorers) ...[
                  const SizedBox(height: AppDimensions.sm),
                  _HubAction(
                    icon: Icons.leaderboard_rounded,
                    title: 'هدافو البطولة',
                    subtitle: 'افتح ترتيب الهدافين وشارك الكارت الحالي.',
                    color: AppColors.accent,
                    onPressed: onOpenTopScorers,
                  ),
                ],
                const SizedBox(height: AppDimensions.md),
                TextButton(
                  onPressed: onReturnToMatch,
                  child: const Text('العودة للمباراة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String scoreLine;

  const _ScoreLine({required this.scoreLine});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Text(
        scoreLine,
        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w900),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HubAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onPressed;

  const _HubAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Ink(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryTinted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
