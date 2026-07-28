import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/identity/identity_preset.dart';
import '../../../core/identity/identity_preset_picker_screen.dart';
import '../../../core/identity/identity_visual.dart';
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
      role: El7reefGlassRole.hero,
      tone: El7reefGlassTone.action,
      radius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: controller.canManageRoster,
                label: controller.canManageRoster
                    ? 'شعار فريق ${team.name}، اضغط لتغييره'
                    : 'شعار فريق ${team.name}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  onTap: controller.canManageRoster
                      ? () => _pickIdentity(context)
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IdentityVisual(
                        source: team.logoUrl,
                        size: 64,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        semanticLabel: 'شعار فريق ${team.name}',
                        fallbackBuilder: (_) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.actionContainer,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              team.name.isNotEmpty ? team.name[0] : '?',
                              style: AppTextStyles.headlineLarge.copyWith(
                                color: AppColors.actionLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (controller.canManageRoster)
                        const PositionedDirectional(
                          end: -4,
                          bottom: -4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.actionPrimary,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.surface, width: 2),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                color: AppColors.info,
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

  Future<void> _pickIdentity(BuildContext context) async {
    final selection = await IdentityPresetPickerScreen.show(
      context,
      scope: IdentityPresetScope.team,
      initialReference: team.logoUrl,
      previewTitle: team.name,
    );
    if (selection == null || !context.mounted) return;
    await controller.updateTeamLogo(
      selection.isCleared ? null : selection.reference,
    );
  }
}
