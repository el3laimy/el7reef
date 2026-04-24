import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import '../controllers/team_lineup_editor_controller.dart';
import '../widgets/bench_bar.dart';
import '../widgets/formation_control_bar.dart';
import '../widgets/lineup_bottom_action_bar.dart';
import '../widgets/player_picker_sheet.dart';
import '../widgets/professional_pitch_card.dart';

class TeamLineupEditorScreen extends GetView<TeamLineupEditorController> {
  const TeamLineupEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تشكيلة الفريق'),
          actions: [
            IconButton(
              onPressed: controller.loadLineup,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (controller.errorMessage.value.isNotEmpty) {
              return _EditorErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.loadLineup,
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.loadLineup,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                children: [
                  _TeamLineupHeader(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  if (controller.isConfirmed)
                    _ConfirmedNotice(controller: controller)
                  else
                    FormationControlBar(
                      playerCount: controller.playerCount.value,
                      formationCode: controller.formationCode.value,
                      onFormationChanged: controller.changeFormation,
                      onReset: controller.resetLayout,
                    ),
                  const SizedBox(height: AppDimensions.md),
                  ProfessionalPitchCard(
                    slots: controller.slots,
                    playersByKey: controller.playersByKey,
                    formationCode: controller.formationCode.value,
                    playerCount: controller.playerCount.value,
                    teamName: controller.teamName,
                    editorMode: controller.canEdit,
                    onEmptySlotTap: (slot) => _showPlayerPicker(context, slot),
                    onPlayerTap: (slot, player) =>
                        _showPlayerActions(context, player),
                    onPlayerLongPress: (slot, player) =>
                        _showPlayerActions(context, player),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  BenchBar(
                    players: controller.benchPlayers,
                    onPlayerTap: controller.canEdit
                        ? (player) => _assignBenchPlayer(context, player)
                        : null,
                    onAddGuest: controller.canEdit
                        ? () => _showGuestDialog(context)
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  if (!controller.isConfirmed)
                    LineupBottomActionBar(
                      isSaving: controller.isSaving.value,
                      canStart: false,
                      onSave: controller.saveConfirmedLineup,
                      onStartMatch: null,
                    ),
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _showPlayerPicker(BuildContext context, FormationSlot slot) {
    if (!controller.canEdit) return;
    Get.bottomSheet(
      PlayerPickerSheet(
        title: 'اختيار لاعب ${slot.role.arabicLabel}',
        players: controller.benchPlayers,
        onPlayerSelected: (player) {
          controller.assignPlayerToSlot(player, slot);
          Get.back();
        },
        onAddGuest: () => _showGuestDialog(context),
      ),
      isScrollControlled: true,
    );
  }

  void _assignBenchPlayer(BuildContext context, LineupPlayer player) {
    final emptySlots = controller.slots.where((slot) => slot.isEmpty).toList();
    if (emptySlots.length == 1) {
      controller.assignPlayerToSlot(player, emptySlots.first);
      return;
    }
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: Color(0xFF07111F),
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
              ...controller.slots.map(
                (slot) => ListTile(
                  onTap: () {
                    controller.assignPlayerToSlot(player, slot);
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

  void _showPlayerActions(BuildContext context, LineupPlayer player) {
    if (!controller.canEdit) return;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: Color(0xFF07111F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_seat_rounded),
                title: const Text('نقل إلى البدلاء'),
                onTap: () {
                  controller.movePlayerToBench(player);
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestDialog(BuildContext context) {
    Get.dialog(_TeamLineupGuestDialog(controller: controller));
  }
}

class _TeamLineupGuestDialog extends StatefulWidget {
  final TeamLineupEditorController controller;

  const _TeamLineupGuestDialog({required this.controller});

  @override
  State<_TeamLineupGuestDialog> createState() => _TeamLineupGuestDialogState();
}

class _TeamLineupGuestDialogState extends State<_TeamLineupGuestDialog> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final saved = await widget.controller.addGuestPlayer(
      _nameController.text,
      number: int.tryParse(_numberController.text.trim()),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (saved) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة لاعب ضيف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'اسم اللاعب'),
            textInputAction: TextInputAction.next,
            autofocus: true,
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(labelText: 'رقم القميص اختياري'),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Get.back(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إضافة'),
        ),
      ],
    );
  }
}

class _TeamLineupHeader extends StatelessWidget {
  final TeamLineupEditorController controller;

  const _TeamLineupHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            backgroundImage: (controller.teamLogoUrl ?? '').isEmpty
                ? null
                : NetworkImage(controller.teamLogoUrl!),
            child: (controller.teamLogoUrl ?? '').isEmpty
                ? Text(
                    controller.teamName.characters.first,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.teamName, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  '${controller.playerCount.value}v${controller.playerCount.value} • ${controller.formationCode.value}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedNotice extends StatelessWidget {
  final TeamLineupEditorController controller;

  const _ConfirmedNotice({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.primaryLight),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'تم حفظ نسخة المباراة. أي تغيير لاحق في الفريق لن يغير هذه المباراة.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EditorErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
