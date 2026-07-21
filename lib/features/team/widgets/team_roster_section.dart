import 'package:flutter/material.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_member_card.dart';

class TeamRosterSection extends StatelessWidget {
  final String title;
  final TeamMembershipStatus status;
  final IconData icon;
  final Color accentColor;
  final TeamRosterController controller;

  const TeamRosterSection({
    super.key,
    required this.title,
    required this.status,
    required this.icon,
    required this.accentColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final members = controller.membersByStatus(status);
    return El7reefGlassSurface(
      variant: El7reefGlassVariant.base,
      radius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: AppDimensions.sm),
              Text(title, style: AppTextStyles.headlineSmall),
              const Spacer(),
              Text(
                '${members.length}',
                style: AppTextStyles.titleMedium.copyWith(color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          if (members.isEmpty)
            Text(
              'لا يوجد عناصر في هذا القسم حالياً.',
              style: AppTextStyles.bodySmall,
            )
          else
            ...members.map(
              (entry) =>
                  TeamRosterMemberCard(entry: entry, controller: controller),
            ),
        ],
      ),
    );
  }
}
