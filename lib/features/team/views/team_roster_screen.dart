import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/enums/team_membership_status.dart';
import '../controllers/team_roster_controller.dart';
import '../widgets/team_roster_widgets.dart';

class TeamRosterScreen extends GetView<TeamRosterController> {
  const TeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الفريق')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.team.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final team = controller.team.value;
          if (team == null) {
            return TeamRosterErrorState(
              message: controller.errorMessage.value.isEmpty
                  ? null
                  : controller.errorMessage.value,
              onRetry: controller.loadTeamRoster,
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadTeamRoster,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                TeamRosterHeader(team: team, controller: controller),
                const SizedBox(height: AppDimensions.md),
                TeamRosterActions(controller: controller),
                const SizedBox(height: AppDimensions.lg),
                TeamRosterFormationWorkspace(controller: controller),
                const SizedBox(height: AppDimensions.lg),
                TeamRosterSection(
                  title: 'الأساسيون',
                  status: TeamMembershipStatus.starter,
                  icon: Icons.sports_soccer,
                  accentColor: AppColors.primary,
                  controller: controller,
                ),
                const SizedBox(height: AppDimensions.md),
                TeamRosterSection(
                  title: 'الاحتياط',
                  status: TeamMembershipStatus.bench,
                  icon: Icons.airline_seat_recline_extra,
                  accentColor: AppColors.secondary,
                  controller: controller,
                ),
                const SizedBox(height: AppDimensions.md),
                TeamRosterSection(
                  title: 'غير النشطين',
                  status: TeamMembershipStatus.inactive,
                  icon: Icons.pause_circle_outline,
                  accentColor: AppColors.textMuted,
                  controller: controller,
                ),
                const SizedBox(height: AppDimensions.xxl),
              ],
            ),
          );
        }),
      ),
    );
  }
}
