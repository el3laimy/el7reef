import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/team_membership_role.dart';
import '../../../core/enums/team_membership_status.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_enums.dart';
import 'team_roster_helpers.dart';
import 'team_roster_tag.dart';

class TeamRosterMemberCard extends StatelessWidget {
  final TeamRosterMemberViewData entry;
  final TeamRosterController controller;

  const TeamRosterMemberCard({
    super.key,
    required this.entry,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final membership = entry.membership;
    final accentColor = entry.isGuest ? AppColors.accent : AppColors.primary;
    final canShowActions = controller.canManageRoster;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.18),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName.characters.first
                  : '?',
              style: AppTextStyles.titleLarge.copyWith(color: accentColor),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: AppTextStyles.titleLarge),
                if ((entry.secondaryText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.secondaryText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: entry.isGuest
                          ? AppColors.accentLight
                          : AppColors.primaryLight,
                    ),
                  ),
                ],
                if ((entry.position ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'المركز: ${entry.position}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  children: [
                    TeamRosterTag(
                      label: entry.isGuest ? 'ضيف' : 'مسجل',
                      color: entry.isGuest ? AppColors.accent : AppColors.primary,
                    ),
                    TeamRosterTag(
                      label: roleLabel(membership.role),
                      color: membership.role == TeamMembershipRole.viceCaptain
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                    TeamRosterTag(
                      label: availabilityLabel(membership.availability),
                      color: availabilityColor(membership.availability),
                    ),
                  ],
                ),
                if (entry.isGuestClaimedOrLinked) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'تم ربط هذا الضيف بالفعل ببروفايل لاعب مسجل.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canShowActions)
            PopupMenuButton<RosterAction>(
              key: ValueKey(
                'team-roster-member-actions-'
                '${membership.guestPlayerId ?? membership.playerId ?? membership.id}',
              ),
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              color: AppColors.surfaceLight,
              onSelected: (action) => _handleAction(action, entry),
              itemBuilder: (_) => buildActionItems(entry),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    RosterAction action,
    TeamRosterMemberViewData entry,
  ) async {
    final membership = entry.membership;
    switch (action) {
      case RosterAction.moveToStarter:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.starter,
        );
      case RosterAction.moveToBench:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.bench,
        );
      case RosterAction.makeInactive:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.inactive,
        );
      case RosterAction.promoteViceCaptain:
        await controller.changeRole(membership, TeamMembershipRole.viceCaptain);
      case RosterAction.demoteToPlayer:
        await controller.changeRole(membership, TeamMembershipRole.player);
      case RosterAction.markAvailable:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.available,
        );
      case RosterAction.markUnavailable:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.unavailable,
        );
      case RosterAction.markInjured:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.injured,
        );
      case RosterAction.remove:
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('إزالة من القائمة'),
            content: Text(
              'هل تريد إزالة ${entry.displayName} من القائمة النشطة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('إزالة'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.removeMembership(membership);
        }
      case RosterAction.shareGuestClaim:
        if (membership.guestPlayerId != null) {
          await controller.shareGuestPlayerClaimLink(membership.guestPlayerId!);
        }
    }
  }
}
