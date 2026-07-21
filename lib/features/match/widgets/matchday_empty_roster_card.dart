import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/matchday_controller.dart';

class MatchdayEmptyRosterCard extends StatelessWidget {
  final MatchdayController controller;

  const MatchdayEmptyRosterCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final side = controller.selectedSide;
    final route = _rosterRouteForSelectedSide();
    final isGuestSide = side?.isGuestTeam == true;

    return El7reefGlassSurface(
      variant: El7reefGlassVariant.raised,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isGuestSide
                ? Icons.person_add_alt_1_rounded
                : Icons.group_add_rounded,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.78),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'لا يوجد لاعبون في هذا الطرف',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isGuestSide
                ? 'أضف لاعبي الفريق الضيف أولاً، وبعدها ارجع ليوم المباراة لتسجيل الحضور وقفل التشكيلة.'
                : 'أضف لاعبي الفريق أولاً، وبعدها ارجع ليوم المباراة لتسجيل الحضور وقفل التشكيلة.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (route != null) ...[
            const SizedBox(height: AppDimensions.lg),
            El7reefButton(
              text: isGuestSide ? 'إضافة لاعبين ضيوف' : 'إدارة قائمة الفريق',
              icon: isGuestSide
                  ? Icons.person_add_alt_1_rounded
                  : Icons.groups_2_rounded,
              onPressed: () => Get.toNamed(route),
            ),
          ],
        ],
      ),
    );
  }

  String? _rosterRouteForSelectedSide() {
    final side = controller.selectedSide;
    if (side == null) return null;

    final teamId = side.teamId;
    if (side.isRegisteredTeam && teamId != null && teamId.isNotEmpty) {
      return AppRoutes.teamProfileById(teamId);
    }

    final guestTeamId = side.guestTeamId;
    final tournamentId =
        controller.tournament.value?.id ?? controller.match.value?.tournamentId;
    if (side.isGuestTeam &&
        guestTeamId != null &&
        guestTeamId.isNotEmpty &&
        tournamentId != null &&
        tournamentId.isNotEmpty) {
      return AppRoutes.tournamentGuestTeamRosterById(
        tournamentId: tournamentId,
        guestTeamId: guestTeamId,
      );
    }

    return null;
  }
}
