import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../match/widgets/send_challenge_sheet.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_dialogs.dart';

class TeamRosterActions extends StatelessWidget {
  final TeamRosterController controller;

  const TeamRosterActions({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.canManageRoster) {
      return El7reefSolidSurface(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'يمكنك مشاهدة القائمة حالياً، لكن إدارة التشكيلة متاحة فقط لمالك الفريق أو نوابه.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.md),
            El7reefButton(
              text: 'تحدي هذا الفريق ⚔️',
              icon: Icons.flash_on,
              onPressed: () {
                final team = controller.team.value;
                if (team != null) {
                  Get.bottomSheet(
                    SendChallengeSheet(
                      challengedId: team.ownerId,
                      challengedName: team.name,
                      challengedTeamId: team.id,
                    ),
                    isScrollControlled: true,
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إدارة القائمة', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: El7reefButton(
                text: 'إضافة لاعب',
                icon: Icons.person_add_alt_1,
                onPressed: () => showRegisteredPlayerSheet(context, controller),
              ),
            ),
            if (FeatureFlags.guestIdentityEnabled) ...[
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: El7reefButton(
                  text: 'إضافة ضيف',
                  icon: Icons.group_add_rounded,
                  isOutlined: true,
                  onPressed: () => showGuestPlayerSheet(context, controller),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          width: double.infinity,
          child: El7reefButton(
            text: 'مشاركة رابط الانضمام للفريق',
            icon: Icons.share_rounded,
            isOutlined: true,
            onPressed: controller.shareTeamInviteLink,
          ),
        ),
      ],
    );
  }
}
