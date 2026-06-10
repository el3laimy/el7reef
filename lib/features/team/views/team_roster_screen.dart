import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../domain/entities/team.dart';
import '../../lineup/widgets/bench_bar.dart';
import '../../lineup/widgets/formation_control_bar.dart';
import '../../lineup/widgets/professional_pitch_card.dart';
import '../../lineup/widgets/player_picker_sheet.dart';
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
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: Stack(
            children: [
              Obx(() {
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

                return TabBarView(
                  children: [
                    // التبويب الأول: قائمة اللاعبين
                    _buildRosterListTab(team),
                    
                    // التبويب الثاني: خطة الفريق البصرية
                    _buildFormationTab(context, team),
                  ],
                );
              }),
              
              // الشريط العائم السفلي لحفظ التعديلات
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Obx(() {
                  if (!controller.isLineupDirty.value || controller.isSubmitting.value) {
                    return const SizedBox.shrink();
                  }
                  return _buildFloatingActionBar();
                }),
              ),
              
              // واجهة تحميل شفافة أثناء الحفظ
              Obx(() {
                if (controller.isSubmitting.value) {
                  return Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
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
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Obx(() => FormationControlBar(
                playerCount: controller.visualPlayerCount.value,
                formationCode: controller.visualFormationCode.value,
                onFormationChanged: controller.changeVisualFormation,
                onReset: controller.resetVisualLayout,
              )),
          const SizedBox(height: AppDimensions.md),
          Obx(() => ProfessionalPitchCard(
                slots: controller.visualSlots,
                playersByKey: {for (final p in controller.allVisualPlayers) p.key: p},
                formationCode: controller.visualFormationCode.value,
                playerCount: controller.visualPlayerCount.value,
                teamName: team.name,
                editorMode: controller.canManageRoster,
                onEmptySlotTap: (slot) => _showVisualPlayerPicker(context, slot),
                onPlayerTap: (slot, player) =>
                    _showVisualPlayerActions(context, player),
                onPlayerLongPress: (slot, player) =>
                    _showVisualPlayerActions(context, player),
                onPlayerDrop: controller.canManageRoster
                    ? (slot, player) =>
                          controller.dropPlayerOnVisualSlot(slot, player)
                    : null,
              )),
          const SizedBox(height: AppDimensions.md),
          Obx(() => BenchBar(
                players: controller.visualBench,
                draggable: controller.canManageRoster,
                onPlayerTap: controller.canManageRoster
                    ? (player) => _assignVisualBenchPlayer(context, player)
                    : null,
                onAddGuest: null,
                onPlayerDroppedOnBench: controller.canManageRoster
                    ? (player) => controller.movePlayerToVisualBench(player)
                    : null,
              )),
          const SizedBox(height: AppDimensions.xxl * 2), // حشوة إضافية لضمان عدم تغطية الشريط العائم للعناصر
        ],
      ),
    );
  }

  void _showVisualPlayerPicker(BuildContext context, FormationSlot slot) {
    if (!controller.canManageRoster) return;
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

  void _assignVisualBenchPlayer(BuildContext context, LineupPlayer player) {
    final emptySlots = controller.visualSlots.where((slot) => slot.isEmpty).toList();
    if (emptySlots.isEmpty) {
      Get.snackbar('الملعب ممتلئ', 'قم بإزالة لاعب أولاً أو نقله لقائمة البدلاء.');
      return;
    }
    if (emptySlots.length == 1) {
      controller.assignPlayerToVisualSlot(player, emptySlots.first);
      return;
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اختر مركز ${player.name}',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppDimensions.md),
              ...controller.visualSlots.map(
                (slot) => ListTile(
                  onTap: () {
                    controller.assignPlayerToVisualSlot(player, slot);
                    Get.back();
                  },
                  leading: Icon(
                    slot.isEmpty
                        ? Icons.add_circle_outline_rounded
                        : Icons.swap_horiz_rounded,
                    color: AppColors.primaryLight,
                  ),
                  title: Text('${slot.role.arabicLabel} • ${slot.id}'),
                  subtitle: Text(
                    slot.isEmpty ? 'خانة فارغة' : 'استبدال اللاعب الحالي',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
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
                leading: const Icon(Icons.event_seat_rounded, color: AppColors.secondary),
                title: const Text(
                  'نقل إلى البدلاء',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  controller.movePlayerToVisualBench(player);
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

  Widget _buildFloatingActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعديلات غير محفوظة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'تغيير تشكيلة ومواقع اللاعبين',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: controller.cancelVisualLineup,
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 40), // Constrain button width to prevent infinite-width Row crash
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
                ),
                onPressed: controller.saveVisualLineup,
                child: const Text(
                  'حفظ التشكيلة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
