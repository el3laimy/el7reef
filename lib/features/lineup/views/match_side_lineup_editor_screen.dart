import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../shareables/controllers/lineup_share_controller.dart';
import '../../shareables/models/lineup_share_data.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/lineup_share_card.dart';
import '../controllers/match_side_lineup_editor_controller.dart';
import '../widgets/bench_bar.dart';
import '../widgets/formation_control_bar.dart';
import '../widgets/lineup_bottom_action_bar.dart';
import '../widgets/lineup_player_display.dart';
import '../widgets/lineup_save_success_share_sheet.dart';
import '../widgets/player_picker_sheet.dart';
import '../widgets/professional_pitch_card.dart';

class MatchSideLineupEditorScreen
    extends GetView<MatchSideLineupEditorController> {
  const MatchSideLineupEditorScreen({super.key});

  static final GlobalKey _lineupShareBoundaryKey = GlobalKey();
  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تشكيلة الطرف المؤقت'),
          actions: [
            IconButton(
              onPressed: () => _shareLineup(context),
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'مشاركة التشكيلة',
            ),
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
                  _MatchSideLineupHeader(controller: controller),
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
                    teamName: controller.sideName,
                    editorMode: controller.canEdit,
                    onEmptySlotTap: (slot) => _showPlayerPicker(context, slot),
                    onPlayerTap: (slot, player) =>
                        _showPlayerActions(context, player),
                    onPlayerLongPress: (slot, player) =>
                        _showPlayerActions(context, player),
                    onPlayerDrop: controller.canEdit
                        ? (slot, player) =>
                              controller.dropPlayerOnSlot(player, slot)
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  BenchBar(
                    players: controller.benchPlayers,
                    title: 'لاعبو الطرف',
                    draggable: controller.canEdit,
                    onPlayerTap: controller.canEdit
                        ? (player) => _assignBenchPlayer(context, player)
                        : null,
                    onPlayerDroppedOnBench: controller.canEdit
                        ? (player) => controller.movePlayerToBench(player)
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  if (!controller.isConfirmed)
                    LineupBottomActionBar(
                      isSaving: controller.isSaving.value,
                      canStart: false,
                      onSave: () {
                        _handleSaveLineup(context);
                      },
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
                'اختر مركز ${lineupDisplayName(player)}',
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

  Future<void> _handleSaveLineup(BuildContext context) async {
    final saved = await controller.saveConfirmedLineup();
    if (!saved || !context.mounted) return;

    Get.bottomSheet(
      LineupSaveSuccessShareSheet(
        isIncomplete: _savedLineupIsIncomplete(),
        onShare: () {
          Get.back();
          _shareLineup(context);
        },
        onContinueEditing: () => Get.back(),
      ),
      isScrollControlled: true,
    );
  }

  bool _savedLineupIsIncomplete() {
    final snapshot = controller.confirmedSnapshot.value;
    return snapshot != null &&
        snapshot.starters.length < controller.playerCount.value;
  }

  Future<void> _shareLineup(BuildContext context) async {
    final snapshot = controller.confirmedSnapshot.value;
    if (snapshot == null) {
      Get.snackbar('تعذر المشاركة', 'احفظ التشكيلة أولًا قبل مشاركتها.');
      return;
    }

    final shareData = Get.find<LineupShareController>().buildFromSnapshot(
      snapshot: snapshot,
      teamName: controller.sideName,
      lineupOwnerType: LineupShareOwnerType.temporarySide,
      lineupTypeLabel: 'فريق مؤقت',
      matchLabel: 'مباراة ودية',
      accentColor: AppColors.success,
    );

    await _captureAndShareLineup(context, shareData);
  }

  Future<void> _captureAndShareLineup(
    BuildContext context,
    LineupShareData shareData,
  ) async {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(
              key: _lineupShareBoundaryKey,
              child: LineupShareCard(data: shareData, exportMode: true),
            ),
          ),
        ),
      ),
    );

    var inserted = false;
    try {
      overlay.insert(entry);
      inserted = true;
      await WidgetsBinding.instance.endOfFrame;
      await _captureService.captureAndShare(
        boundaryKey: _lineupShareBoundaryKey,
        fileName: 'el7reef_lineup_${shareData.matchId}_${shareData.ownerId}',
        text: 'تشكيلة ${shareData.teamName} على الحريف',
        pixelRatio: matchResultShareExportPixelRatio,
      );
    } catch (error) {
      Get.snackbar('تعذر المشاركة', _readableShareError(error));
    } finally {
      if (inserted) entry.remove();
    }
  }

  String _readableShareError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}

class _MatchSideLineupHeader extends StatelessWidget {
  final MatchSideLineupEditorController controller;

  const _MatchSideLineupHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.primaryLight),
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.sideName,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'مباراة ودية • فريق مؤقت',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryLight,
                  ),
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
  final MatchSideLineupEditorController controller;

  const _ConfirmedNotice({required this.controller});

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.confirmedSnapshot.value;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.success),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              snapshot == null
                  ? 'تم تثبيت التشكيلة.'
                  : 'تم تثبيت التشكيلة: ${snapshot.summaryLabel}',
              style: AppTextStyles.bodyMedium.copyWith(
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
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
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
