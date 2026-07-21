import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../domain/entities/team.dart';
import '../../lineup/utils/lineup_haptics.dart';
import '../../lineup/widgets/bench_bar.dart';
import '../../lineup/widgets/formation_control_bar.dart';
import '../../lineup/widgets/professional_pitch_card.dart';
import '../../lineup/widgets/player_picker_sheet.dart';
import '../../lineup/widgets/starter_swap_sheet.dart';
import '../controllers/team_roster_controller.dart';
import '../widgets/team_roster_widgets.dart';

class TeamRosterScreen extends GetView<TeamRosterController> {
  const TeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قائمة وتشكيلة الفريق'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'قائمة اللاعبين'),
              Tab(text: 'خطة الفريق'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Stack(
            children: [
              Obx(() {
                if (controller.isLoading.value &&
                    controller.team.value == null) {
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

                return TabBarView(
                  children: [
                    // التبويب الأول: قائمة اللاعبين
                    _buildRosterListTab(team),

                    // التبويب الثاني: خطة الفريق البصرية
                    _buildFormationTab(context, team),
                  ],
                );
              }),

              // واجهة تحميل شفافة أثناء الحفظ
              Obx(() {
                if (controller.isSubmitting.value) {
                  return Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosterListTab(Team team) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.loadTeamRoster,
      child: ListView(
        key: const ValueKey('team-roster-list-view'),
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
  }

  Widget _buildFormationTab(BuildContext context, Team team) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.loadTeamRoster,
      child: ListView(
        key: const ValueKey('team-roster-formation-list-view'),
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Obx(
            () => FormationControlBar(
              playerCount: controller.visualPlayerCount.value,
              formationCode: controller.visualFormationCode.value,
              onPlayerCountChanged: controller.changeVisualPlayerCount,
              onFormationChanged: controller.changeVisualFormation,
              onReset: controller.resetVisualLayout,
              enabled:
                  controller.canManageRoster && !controller.isSubmitting.value,
              isDirty: controller.isLineupDirty.value,
              onSave: controller.canManageRoster
                  ? controller.saveVisualLineup
                  : null,
              onCancel: controller.canManageRoster
                  ? controller.cancelVisualLineup
                  : null,
              selectedPlayerName: controller.selectedVisualPlayerName,
              helperText: controller.canManageRoster
                  ? 'اضغط لاعبًا ثم اختر خانة للنقل أو التبديل.'
                  : 'عرض الخطة الحالية للفريق.',
              allowPlayerCountChange: controller.canManageRoster,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Obx(
            () => ProfessionalPitchCard(
              slots: controller.visualSlots,
              playersByKey: {
                for (final p in controller.allVisualPlayers) p.key: p,
              },
              formationCode: controller.visualFormationCode.value,
              playerCount: controller.visualPlayerCount.value,
              teamName: team.name,
              selectedPlayerKey: controller.selectedVisualPlayerKey,
              editorMode: controller.canManageRoster,
              onEmptySlotTap: (slot) => _showVisualPlayerPicker(context, slot),
              onPlayerTap: _handleVisualPlayerTap,
              onPlayerLongPress: (slot, player) =>
                  _showVisualPlayerActions(context, player),
              onPlayerDrop: controller.canManageRoster
                  ? (slot, payload) {
                      controller.dropPlayerOnVisualSlot(slot, payload);
                      LineupHaptics.commit();
                    }
                  : null,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Obx(
            () => BenchBar(
              players: controller.visualBench,
              draggable: controller.canManageRoster,
              selectedPlayerKey: controller.selectedVisualPlayerKey,
              onPlayerTap: controller.canManageRoster
                  ? (player) {
                      controller.selectVisualPlayer(player);
                      LineupHaptics.select();
                    }
                  : null,
              onAddGuest: null,
              onPlayerDroppedOnBench: controller.canManageRoster
                  ? (player) {
                      controller.movePlayerToVisualBench(player);
                      LineupHaptics.move();
                    }
                  : null,
              onSelectedPlayerMoveToBench:
                  controller.canManageRoster &&
                      controller.selectedVisualPlayerCanMoveToBench
                  ? () {
                      if (controller.moveSelectedVisualPlayerToBench()) {
                        LineupHaptics.move();
                      }
                    }
                  : null,
              onSelectedBenchSwapRequest: controller.canManageRoster
                  ? () => _showVisualStarterSwapSheet(context)
                  : null,
            ),
          ),
          const SizedBox(
            height: AppDimensions.xxl * 2,
          ), // حشوة إضافية لضمان عدم تغطية الشريط العائم للعناصر
        ],
      ),
    );
  }

  void _showVisualStarterSwapSheet(BuildContext context) {
    if (!controller.canManageRoster) return;
    Get.bottomSheet(
      StarterSwapSheet(
        title: 'بدّل مع لاعب أساسي',
        slots: controller.visualSlots,
        playersByKey: {
          for (final player in controller.allVisualPlayers) player.key: player,
        },
        onSlotSelected: (slot) {
          if (controller.moveSelectedVisualPlayerToSlot(slot)) {
            LineupHaptics.commit();
            Get.back();
          }
        },
      ),
      isScrollControlled: true,
    );
  }

  void _showVisualPlayerPicker(BuildContext context, FormationSlot slot) {
    if (!controller.canManageRoster) return;
    if (controller.moveSelectedVisualPlayerToSlot(slot)) {
      LineupHaptics.commit();
      return;
    }
    Get.bottomSheet(
      PlayerPickerSheet(
        title: 'اختيار لاعب ${slot.role.arabicLabel}',
        players: controller.visualBench,
        onPlayerSelected: (player) {
          controller.assignPlayerToVisualSlot(player, slot);
          Get.back();
        },
      ),
      isScrollControlled: true,
    );
  }

  void _handleVisualPlayerTap(FormationSlot slot, LineupPlayer player) {
    if (!controller.canManageRoster) return;
    if (controller.moveSelectedVisualPlayerToSlot(slot)) {
      LineupHaptics.commit();
      return;
    }
    controller.selectVisualPlayer(player, sourceSlotId: slot.id);
    LineupHaptics.select();
  }

  void _showVisualPlayerActions(BuildContext context, LineupPlayer player) {
    if (!controller.canManageRoster) return;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.event_seat_rounded,
                  color: AppColors.secondary,
                ),
                title: const Text(
                  'نقل إلى البدلاء',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  controller.movePlayerToVisualBench(player);
                  LineupHaptics.move();
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
