import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import 'matchday_status_badge.dart';

class MatchdaySnapshotReadonlyView extends StatelessWidget {
  final MatchLineupSnapshot snapshot;

  const MatchdaySnapshotReadonlyView({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchdayStatusBadge(label: snapshot.summaryLabel, color: AppColors.success),
        const SizedBox(height: AppDimensions.sm),
        Text('الأساسيون', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.xs),
        ...snapshot.starters.map(
          (entry) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: Text(entry.displayName),
            subtitle: Text(entry.position ?? 'بدون مركز'),
            trailing: entry.isGuest
                ? const MatchdayStatusBadge(label: 'ضيف', color: AppColors.warning)
                : null,
          ),
        ),
        if (snapshot.bench.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.sm),
          Text('الاحتياط', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          ...snapshot.bench.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(entry.displayName),
              subtitle: Text(entry.position ?? 'بدون مركز'),
              trailing: entry.isGuest
                  ? const MatchdayStatusBadge(label: 'ضيف', color: AppColors.warning)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
