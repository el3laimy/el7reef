import 'package:flutter/material.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/matchday_controller.dart';

class MatchdayNoManagedSideCard extends StatelessWidget {
  final MatchdayController controller;

  const MatchdayNoManagedSideCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isFriendlyHostWithoutFormalSides =
        controller.isFriendlyMatchHost && !controller.hasFormalMatchdaySides;
    final title = isFriendlyHostWithoutFormalSides
        ? 'هذه المباراة لا تحتوي على فرق رسمية'
        : 'لا يوجد طرف متاح حاليًا';
    final message = isFriendlyHostWithoutFormalSides
        ? 'يمكنك إدارة الدعوات وبدء هذه المباراة من اللوبي كمنظم للمباراة.'
        : controller.isLoggedIn
            ? 'لا توجد أطراف تملك صلاحية إدارتها في هذه المباراة من حسابك الحالي.'
            : 'سجّل الدخول أولًا حتى تظهر لك أطراف المباراة التي يمكنك إدارتها.';
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.lg),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        children: [
          const Icon(Icons.sports_soccer_outlined, size: 42),
          const SizedBox(height: AppDimensions.sm),
          Text(
            title,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
