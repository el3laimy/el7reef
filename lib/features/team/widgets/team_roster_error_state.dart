import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';

class TeamRosterErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const TeamRosterErrorState({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_off_rounded,
              size: 72,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              message ?? 'تعذر تحميل قائمة الفريق.',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.md),
            El7reefButton(
              text: 'إعادة المحاولة',
              icon: Icons.refresh,
              width: 200,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
