import 'package:flutter/material.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class MatchdayStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const MatchdayStatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
