import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/team.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_count_chip.dart';

class TeamRosterHeader extends StatelessWidget {
  final Team team;
  final TeamRosterController controller;

  const TeamRosterHeader({
    super.key,
    required this.team,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return El7reefGlassSurface(
      variant: El7reefGlassVariant.base,
      radius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  team.name.isNotEmpty ? team.name[0] : '?',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'إدارة حيّة للقائمة الأساسية والاحتياط والضيوف',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              TeamRosterCountChip(
                label: 'أساسي',
                count: controller.countByStatus(TeamMembershipStatus.starter),
                color: AppColors.primary,
              ),
              TeamRosterCountChip(
                label: 'احتياط',
                count: controller.countByStatus(TeamMembershipStatus.bench),
                color: AppColors.secondary,
              ),
              TeamRosterCountChip(
                label: 'غير نشط',
                count: controller.countByStatus(TeamMembershipStatus.inactive),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08);
  }
}
