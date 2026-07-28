import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';

class MatchStatusBadge extends StatelessWidget {
  final MatchStatus status;
  const MatchStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      MatchStatus.open => (AppColors.actionPrimary, 'مفتوحة'),
      MatchStatus.live => (AppColors.tactical, 'مباشر'),
      MatchStatus.completed => (AppColors.warning, 'بانتظار الاعتماد'),
      MatchStatus.settled => (AppColors.success, 'معتمدة'),
      MatchStatus.pendingReview => (AppColors.warning, '🟠 قيد المراجعة'),
      MatchStatus.frozen => (AppColors.error, '🔒 مجمدة'),
      MatchStatus.full => (AppColors.textSecondary, 'مكتملة العدد'),
      MatchStatus.cancelled => (AppColors.error, '❌ ملغاة'),
      _ => (AppColors.textMuted, '⏸ معلقة'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
