import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/activity_feed_controller.dart';
import '../../../core/services/activity_feed_service.dart';

/// ودجت النشاطات - يُعرض في الصفحة الرئيسية
class ActivityFeedWidget extends StatelessWidget {
  const ActivityFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.activityFeedEnabled) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<ActivityFeedController>();

    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pagePadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'آخر الأنشطة',
                  style: AppTextStyles.titleLarge,
                ),
                GestureDetector(
                  onTap: controller.loadFeed,
                  child: Text(
                    'تحديث',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          if (controller.isLoading.value && controller.items.isEmpty)
            _buildLoadingState()
          else if (controller.errorMessage.isNotEmpty &&
              controller.items.isEmpty)
            _buildInfoState(
              title: controller.errorMessage.value,
              subtitle: 'حاول مرة أخرى بعد لحظات.',
            )
          else if (controller.items.isEmpty)
            _buildInfoState(
              title: 'لا توجد أنشطة بعد',
              subtitle: 'ابدأ بإضافة أصدقاء أو متابعة منظمين لتظهر تحركاتهم هنا.',
            )
          else
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePadding,
                ),
                itemCount: controller.items.length,
                itemBuilder: (context, index) {
                  final item = controller.items[index];
                  return _buildActivityCard(item)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 100 * index))
                      .slideX(begin: 0.2);
                },
              ),
            ),
        ],
      );
    });
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 260,
            margin: const EdgeInsetsDirectional.only(start: AppDimensions.md, bottom: 8),
            child: const GlassmorphicContainer(
              padding: EdgeInsets.all(AppDimensions.md),
              borderRadius: AppDimensions.radiusLg,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoState({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.lg),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimensions.xs),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityFeedEntry item) {
    return Container(
      width: 260,
      margin: const EdgeInsetsDirectional.only(start: AppDimensions.md, bottom: 8), // Shadow space
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Icon Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Text(item.iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: AppDimensions.sm),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium,
                      children: [
                        TextSpan(
                          text: '${item.actorName} ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        TextSpan(text: '${item.actionText} '),
                        TextSpan(
                          text: item.highlightText,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.timeAgo(),
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
