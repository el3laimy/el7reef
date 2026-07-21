import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/qr_code_widget.dart';
import '../../../domain/entities/match_side_player.dart';
import '../controllers/match_lobby_controller.dart';
import '../models/friendly_match_side_view.dart';
import '../widgets/invite_friends_sheet.dart';
import '../widgets/match_formation_section.dart';
import '../widgets/match_lobby_widgets.dart';

/// شاشة لوبي المباراة — مركز العمليات الشامل (Match Dashboard)
class MatchLobbyScreen extends GetView<MatchLobbyController> {
  const MatchLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final match = controller.match.value;
            if (match == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      'لم يتم العثور على المباراة',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              );
            }

            final isOpen = match.status == MatchStatus.open;
            final isStartableStatus =
                match.status == MatchStatus.open ||
                match.status == MatchStatus.full;
            final canCancelMatch = controller.canCancelMatch;
            final readiness = controller.startReadiness.value;
            final sideA = _sideViewFor(controller.sideViews, 'A');
            final sideB = _sideViewFor(controller.sideViews, 'B');

            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.pagePadding),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'لوبي المباراة',
                                  style: AppTextStyles.headlineMedium,
                                ),
                                Text(
                                  '${controller.effectiveTeamSize}v${controller.effectiveTeamSize}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                                if (match.location != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          match.location!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (controller.isOrganizer)
                            IconButton(
                              onPressed: () => _showMatchSettings(context),
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.textPrimary,
                              ),
                              tooltip: 'إعدادات المباراة',
                            ),
                          StatusChip(status: match.status),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                  // ── Readiness Stepper ──
                  if (isStartableStatus && controller.isOrganizer)
                    SliverToBoxAdapter(
                      child: ReadinessStepper(
                        readiness: readiness,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                    ),

                  // ── QR Code + رابط الدعوة ──
                  if (isOpen)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: El7reefGlassSurface(
                          variant: El7reefGlassVariant.base,
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Column(
                            children: [
                              Text(
                                'ادعُ اللاعبين 📲',
                                style: AppTextStyles.titleLarge,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              QrCodeWidget(
                                data: controller.inviteLink,
                                label: 'امسح للانضمام',
                                sublabel: match.location,
                                size: 160,
                                showBorder: false,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              // رابط الدعوة
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.md,
                                  vertical: AppDimensions.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        controller.inviteLink,
                                        style: AppTextStyles.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: controller.copyInviteLink,
                                      icon: const Icon(
                                        Icons.copy,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      tooltip: 'نسخ الرابط',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.lg),
                  ),

                  // ── فريق A (Collapsible) ──
                  SliverToBoxAdapter(
                    child: CollapsibleTeamSection(
                      sideView: sideA,
                      players: controller.teamAPlayers,
                      side: 'A',
                      isOrganizer: controller.isOrganizer,
                      isOpen:
                          controller.isFriendlyMatchHost && isStartableStatus,
                      matchId: controller.matchId,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'A'),
                      onRename: sideA == null
                          ? null
                          : () => _showRenameTemporarySide(context, sideA),
                      onAdd: () {
                        Get.bottomSheet(
                          RegisteredPlayerPickerSheet(
                            lobbyController: controller,
                            sideKey: 'A',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onAddTemporary: () =>
                          _showAddTemporaryPlayer(context, 'A'),
                      onInvite: () {
                        Get.bottomSheet(
                          InviteFriendsSheet(
                            lobbyController: controller,
                            side: 'A',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onEditTemporary: (player) =>
                          _showEditTemporaryPlayer(context, 'A', player),
                      onRemoveTemporary: (player) =>
                          _showRemoveTemporaryConfirm(context, 'A', player),
                      onInviteTemporary: (player) =>
                          controller.inviteTemporaryPlayer(player: player),
                    ).animate().fadeIn(delay: 300.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.md),
                  ),

                  // ── فريق B (Collapsible) ──
                  SliverToBoxAdapter(
                    child: CollapsibleTeamSection(
                      sideView: sideB,
                      players: controller.teamBPlayers,
                      side: 'B',
                      isOrganizer: controller.isOrganizer,
                      isOpen:
                          controller.isFriendlyMatchHost && isStartableStatus,
                      matchId: controller.matchId,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'B'),
                      onRename: sideB == null
                          ? null
                          : () => _showRenameTemporarySide(context, sideB),
                      onAdd: () {
                        Get.bottomSheet(
                          RegisteredPlayerPickerSheet(
                            lobbyController: controller,
                            sideKey: 'B',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onAddTemporary: () =>
                          _showAddTemporaryPlayer(context, 'B'),
                      onInvite: () {
                        Get.bottomSheet(
                          InviteFriendsSheet(
                            lobbyController: controller,
                            side: 'B',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onEditTemporary: (player) =>
                          _showEditTemporaryPlayer(context, 'B', player),
                      onRemoveTemporary: (player) =>
                          _showRemoveTemporaryConfirm(context, 'B', player),
                      onInviteTemporary: (player) =>
                          controller.inviteTemporaryPlayer(player: player),
                    ).animate().fadeIn(delay: 400.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),

                  // ── خطة اللعب (Pitch) ──
                  SliverToBoxAdapter(
                    child: MatchFormationSection(
                      controller: controller,
                    ).animate().fadeIn(delay: 500.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),

                  // ── Sticky Start Action ──
                  if (controller.isOrganizer)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: Column(
                          children: [
                            if (isStartableStatus)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: readiness.canStart
                                      ? () => _handleStartMatchPressed(
                                          sideA: sideA,
                                          sideB: sideB,
                                        )
                                      : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(
                                    readiness.canStart
                                        ? 'ابدأ المباراة ⚽'
                                        : 'غير جاهز للبدء',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: readiness.canStart
                                        ? AppColors.success
                                        : AppColors.surfaceBorder,
                                    foregroundColor: readiness.canStart
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.md,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (canCancelMatch) ...[
                              const SizedBox(height: AppDimensions.sm),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmCancel(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('إلغاء المباراة'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.md,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ).animate().fadeIn(delay: 500.ms),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('إلغاء المباراة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من إلغاء هذه المباراة؟ لن يتم حذف بيانات المباراة، لكنها لن تظهر كمباراة نشطة.',
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء اختياري',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              final reason = reasonController.text;
              Get.back();
              controller.cancelMatch(reason: reason);
            },
            child: const Text(
              'إلغاء المباراة',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchSettings(BuildContext context) {
    Get.bottomSheet(
      _MatchSettingsSheet(controller: controller),
      isScrollControlled: true,
    );
  }

  Future<void> _handleStartMatchPressed({
    required FriendlyMatchSideView? sideA,
    required FriendlyMatchSideView? sideB,
  }) async {
    final match = controller.match.value;
    final readiness = controller.startReadiness.value;
    final isFriendlyMatch =
        match != null &&
        (match.tournamentId == null || match.tournamentId!.isEmpty);
    if (match == null ||
        !isFriendlyMatch ||
        !readiness.canStart ||
        controller.hasLockedSnapshots.value) {
      await controller.startMatch();
      return;
    }

    Get.bottomSheet(
      StartWithoutLineupNudgeSheet(
        sideA: sideA,
        sideB: sideB,
        onStartWithoutLineup: () async {
          Get.back();
          await controller.startMatch();
        },
        onCreateLineup: (side) async {
          Get.back();
          await Get.toNamed(_lineupRouteForSide(side));
          await controller.refresh();
        },
      ),
      isScrollControlled: true,
    );
  }

  String _lineupRouteForSide(FriendlyMatchSideView side) {
    if (side.canOpenOfficialLineup && side.officialTeamId != null) {
      return AppRoutes.teamLineupEditorForMatch(
        matchId: controller.matchId,
        teamId: side.officialTeamId!,
      );
    }
    return AppRoutes.matchSideLineupEditorForMatch(
      matchId: controller.matchId,
      sideKey: side.sideKey,
    );
  }

  void _showRenameTemporarySide(
    BuildContext context,
    FriendlyMatchSideView side,
  ) {
    final nameController = TextEditingController(text: side.displayName);
    Get.dialog(
      AlertDialog(
        title: Text('تسمية فريق ${side.sideKey}'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'اسم الفريق المؤقت'),
          onSubmitted: (_) => _saveTemporarySideName(side, nameController),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => _saveTemporarySideName(side, nameController),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _saveTemporarySideName(
    FriendlyMatchSideView side,
    TextEditingController nameController,
  ) {
    final name = nameController.text.trim();
    Get.back();
    controller.renameTemporarySide(sideKey: side.sideKey, displayName: name);
  }

  void _showAddTemporaryPlayer(BuildContext context, String sideKey) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final positionController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('لاعب مؤقت لفريق $sideKey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم اللاعب'),
            ),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم القميص اختياري',
              ),
            ),
            TextField(
              controller: positionController,
              decoration: const InputDecoration(labelText: 'المركز اختياري'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final shirtNumber = int.tryParse(numberController.text.trim());
              Get.back();
              controller.addTemporaryPlayerToSide(
                sideKey: sideKey,
                displayName: nameController.text,
                shirtNumber: shirtNumber,
                position: positionController.text,
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditTemporaryPlayer(
    BuildContext context,
    String sideKey,
    MatchSidePlayer player,
  ) {
    final nameController = TextEditingController(text: player.displayName);
    final numberController = TextEditingController(
      text: player.shirtNumber?.toString() ?? '',
    );
    final positionController = TextEditingController(
      text: player.position ?? '',
    );
    Get.dialog(
      AlertDialog(
        title: Text('تعديل ${player.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم اللاعب'),
            ),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم القميص اختياري',
              ),
            ),
            TextField(
              controller: positionController,
              decoration: const InputDecoration(labelText: 'المركز اختياري'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final shirtNumber = int.tryParse(numberController.text.trim());
              Get.back();
              controller.editTemporaryPlayer(
                sideKey: sideKey,
                playerId: player.id,
                displayName: nameController.text,
                shirtNumber: shirtNumber,
                position: positionController.text,
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showRemoveTemporaryConfirm(
    BuildContext context,
    String sideKey,
    MatchSidePlayer player,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف لاعب مؤقت'),
        content: Text('هل أنت متأكد من حذف ${player.displayName} من المباراة؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeTemporaryPlayerFromSide(
                sideKey: sideKey,
                playerId: player.id,
              );
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

FriendlyMatchSideView? _sideViewFor(
  Iterable<FriendlyMatchSideView> sides,
  String sideKey,
) {
  for (final side in sides) {
    if (side.sideKey == sideKey) return side;
  }
  return null;
}

/// ── Settings Sheet ──
class _MatchSettingsSheet extends StatelessWidget {
  final MatchLobbyController controller;

  const _MatchSettingsSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Obx(() {
          final match = controller.match.value;
          final isTournament = match?.tournamentId != null;
          final currentSize = controller.effectiveTeamSize;
          final canChange = controller.canChangeTeamSize;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إعدادات المباراة', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isTournament
                    ? 'حجم مباراة البطولة يتم تحديده من إعدادات البطولة/الجدول.'
                    : canChange
                    ? 'تغيير عدد اللاعبين يؤثر على الفريقين والتشكيلات المفتوحة.'
                    : 'لا يمكن تغيير عدد اللاعبين بعد بدء المباراة أو بعد قفل أي تشكيلة.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('عدد اللاعبين لكل فريق', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: supportedPlayerCounts
                    .map((size) {
                      final selected = size == currentSize;
                      return ChoiceChip(
                        label: Text('${size}v$size'),
                        selected: selected,
                        onSelected: canChange && !selected
                            ? (_) => _confirmTeamSizeChange(size)
                            : null,
                        selectedColor: AppColors.primarySurface,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: AppDimensions.lg),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('إغلاق'),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _confirmTeamSizeChange(int size) {
    Get.dialog(
      AlertDialog(
        title: const Text('تغيير حجم المباراة'),
        content: Text(
          'سيتم تغيير المباراة إلى ${size}v$size. هذا يؤثر على الفريقين، '
          'وقد ينقل لاعبين زائدين إلى البدلاء في التشكيلات المفتوحة. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Get.back();
              final saved = await controller.updateTeamSize(size);
              if (saved) {
                Get.back();
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
