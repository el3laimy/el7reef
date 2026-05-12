import 'package:flutter/material.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class TeamRosterCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const TeamRosterCountChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }
}
