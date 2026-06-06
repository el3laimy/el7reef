import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/match.dart';
import '../controllers/match_controller.dart';
import 'match_status_badge.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final int index;
  final MatchController controller;

  const MatchCard({
    super.key,
    required this.match,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOrganizer =
        match.organizerId == controller.authService.currentUserId;
    final currentUserId = controller.authService.currentUserId;
    final isParticipant =
        currentUserId != null &&
        (match.teamAPlayerIds.contains(currentUserId) ||
            match.teamBPlayerIds.contains(currentUserId));
    final canOpenMatchday = isOrganizer || isParticipant;
    final hasResult = match.scoreTeamA != null && match.scoreTeamB != null;

    return GlassmorphicContainer(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusLg,
          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MatchStatusBadge(status: match.status),
                  const Spacer(),
                  if (FeatureFlags.goldenRatingUiEnabled &&
                      match.isGoldenRating)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        '⭐ ذهبي',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  if (match.isFrozen) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.lock,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppDimensions.md),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('🔵', style: TextStyle(fontSize: 28)),
                        Obx(
                          () => Text(
                            controller.participantCountLabel(match, 'A'),
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (match.scoreTeamA != null && match.scoreTeamB != null)
                        Text(
                          '${match.scoreTeamA} - ${match.scoreTeamB}',
                          style: AppTextStyles.ratingMedium.copyWith(
                            fontSize: 24,
                          ),
                        )
                      else
                        Text('vs', style: AppTextStyles.headlineMedium),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('🔴', style: TextStyle(fontSize: 28)),
                        Obx(
                          () => Text(
                            controller.participantCountLabel(match, 'B'),
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.md),

              if (hasResult)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchResultLineupById(match.id)),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('عرض ومشاركة النتيجة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),

              if (canOpenMatchday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match.id)),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(
                      isOrganizer ? 'إدارة المباراة' : 'تفاصيل مباراتي',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),

              if (match.status == MatchStatus.completed ||
                  match.status == MatchStatus.pendingReview ||
                  match.status == MatchStatus.settled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.mvpVoteForMatch(match.id)),
                    icon: const Icon(Icons.star_border_purple500, size: 18),
                    label: const Text('تصويت رجل المباراة (الجماهير)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                    ),
                  ),
                ),

              if (isOrganizer &&
                  !match.isFrozen &&
                  match.status == MatchStatus.live)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.toNamed(
                          AppRoutes.scoreApprovalForMatch(match.id),
                        ),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('سجّل النتيجة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => controller.freezeMatch(match.id),
                      icon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'تجميد',
                    ),
                    if (FeatureFlags.goldenRatingUiEnabled)
                      IconButton(
                        onPressed: () =>
                            controller.activateGoldenRating(match.id),
                        icon: const Icon(
                          Icons.star_outline,
                          color: AppColors.secondary,
                        ),
                        tooltip: 'تقييم ذهبي',
                      ),
                  ],
                ),

              if (isOrganizer &&
                  match.tournamentId == null &&
                  !match.isFrozen &&
                  (match.status == MatchStatus.open ||
                      match.status == MatchStatus.full))
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancel(context),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('إلغاء المباراة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),

              if (isOrganizer &&
                  (match.status == MatchStatus.completed ||
                      match.status == MatchStatus.pendingReview))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => controller.approveScore(match.id),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      match.status == MatchStatus.pendingReview
                          ? 'اعتماد بعد المراجعة'
                          : 'اعتماد النتيجة',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        )
        .animate(delay: (80 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1);
  }

  void _confirmCancel(BuildContext context) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('إلغاء المباراة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من إلغاء هذه المباراة؟ لن يتم حذف بيانات المباراة، لكنها لن تظهر كمباراة نشطة.',
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء اختياري',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              final reason = reasonController.text;
              Get.back();
              controller.cancelMatch(match.id, reason: reason);
            },
            child: const Text(
              'إلغاء المباراة',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
