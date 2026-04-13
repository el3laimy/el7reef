import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';

/// كائن يمثل نشاطاً في الـ Feed
class ActivityItem {
  final String id;
  final String playerName;
  final String actionText;
  final String highlightText;
  final String timeText;
  final String iconEmoji;

  const ActivityItem({
    required this.id,
    required this.playerName,
    required this.actionText,
    required this.highlightText,
    required this.timeText,
    required this.iconEmoji,
  });
}

/// ودجت النشاطات - يُعرض في الصفحة الرئيسية
class ActivityFeedWidget extends StatelessWidget {
  const ActivityFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // قائمة تجريبية للأحداث (سيتم ربطها بـ Firestore لاحقاً)
    final mockActivities = [
      const ActivityItem(
        id: '1',
        playerName: 'محمد',
        actionText: 'فاز ببطولة',
        highlightText: 'كأس الزيتون',
        timeText: 'منذ ساعتين',
        iconEmoji: '🏆',
      ),
      const ActivityItem(
        id: '2',
        playerName: 'أحمد',
        actionText: 'تم اختياره',
        highlightText: 'رجل المباراة MVP',
        timeText: 'منذ 5 ساعات',
        iconEmoji: '⭐',
      ),
      const ActivityItem(
        id: '3',
        playerName: 'كريم',
        actionText: 'سجّل هدفه رقم',
        highlightText: '50',
        timeText: 'منذ يوم',
        iconEmoji: '🎯',
      ),
      const ActivityItem(
        id: '4',
        playerName: 'فريق النسور',
        actionText: 'انضم لبطولة',
        highlightText: 'كأس الشباب 2025',
        timeText: 'منذ يومين',
        iconEmoji: '🔥',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر الأنشطة',
                style: AppTextStyles.titleLarge,
              ),
              Text(
                'عرض الكل',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
            itemCount: mockActivities.length,
            itemBuilder: (context, index) {
              final item = mockActivities[index];
              return _buildActivityCard(item)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * index))
                  .slideX(begin: 0.2);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityItem item) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(left: AppDimensions.md, bottom: 8), // Shadow space
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
                          text: '${item.playerName} ',
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
                    item.timeText,
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
