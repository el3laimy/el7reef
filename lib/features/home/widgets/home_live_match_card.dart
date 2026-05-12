import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../domain/entities/match.dart';
import '../../match/controllers/match_controller.dart';

class HomeLiveMatchCard extends StatelessWidget {
  final Match match;
  final int index;

  const HomeLiveMatchCard({super.key, required this.match, required this.index});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = match.status == MatchStatus.live
        ? AppColors.primary
        : match.status == MatchStatus.open
        ? AppColors.success
        : AppColors.textMuted;
    final matchController = Get.find<MatchController>();

    return Container(
          width: 200,
          margin: const EdgeInsetsDirectional.only(end: AppDimensions.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      match.status == MatchStatus.live
                          ? 'جارية الآن'
                          : match.status == MatchStatus.open
                          ? 'مفتوحة'
                          : 'منتهية',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: statusColor,
                      ),
                    ),
                    const Spacer(),
                    if (match.isGoldenRating)
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.secondary,
                        size: 16,
                      ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🔵', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    match.isCompleted && match.scoreTeamA != null
                        ? Text(
                            '${match.scoreTeamA} - ${match.scoreTeamB}',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          )
                        : Text('vs', style: AppTextStyles.titleMedium),
                    const SizedBox(width: 6),
                    Text('🔴', style: const TextStyle(fontSize: 22)),
                  ],
                ),

                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Obx(
                      () => Text(
                        matchController.totalParticipantCountLabel(match),
                        style: AppTextStyles.labelSmall,
                      ),
                    ),
                    const Spacer(),
                    if (match.isFrozen)
                      const Icon(Icons.lock, size: 14, color: AppColors.error),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate(delay: (100 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.2);
  }
}
