import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/guest_claim_status.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/guest_player.dart';
import '../controllers/tournament_guest_team_roster_controller.dart';
import '../widgets/tournament_status_chip.dart';

class TournamentGuestTeamRosterScreen
    extends GetView<TournamentGuestTeamRosterController> {
  const TournamentGuestTeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لاعبو الفريق الضيف')),
      floatingActionButton: Obx(() {
        if (controller.isLoading.value || controller.errorMessage.isNotEmpty) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: controller.isSubmitting.value
              ? null
              : () => _showPlayerForm(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة لاعب'),
        );
      }),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value &&
                controller.guestTeam.value == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (controller.errorMessage.value.isNotEmpty &&
                controller.guestTeam.value == null) {
              return _GuestRosterErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.loadRoster,
              );
            }

            final guestTeam = controller.guestTeam.value;
            if (guestTeam == null) {
              return _GuestRosterErrorState(
                message: 'الفريق الضيف المطلوب غير موجود.',
                onRetry: controller.loadRoster,
              );
            }

            return Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.loadRoster,
                  child: ListView(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    children: [
                      _GuestTeamRosterHeader(controller: controller),
                      const SizedBox(height: AppDimensions.md),
                      if (controller.activePlayers.isEmpty)
                        _GuestRosterEmptyState(
                          onAddPressed: () => _showPlayerForm(context),
                        )
                      else
                        _GuestRosterSection(
                          title: 'القائمة النشطة',
                          players: controller.activePlayers,
                          controller: controller,
                          onEdit: (player) =>
                              _showPlayerForm(context, player: player),
                        ),
                      if (controller.archivedPlayers.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.lg),
                        _GuestRosterSection(
                          title: 'المؤرشفون',
                          players: controller.archivedPlayers,
                          controller: controller,
                          onEdit: (player) =>
                              _showPlayerForm(context, player: player),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.xxl * 2),
                    ],
                  ),
                ),
                if (controller.isSubmitting.value)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showPlayerForm(BuildContext context, {GuestPlayer? player}) {
    if (player == null) {
      controller.startCreate();
    } else {
      controller.startEdit(player);
    }

    Get.bottomSheet(
      _GuestPlayerFormSheet(controller: controller, isEditing: player != null),
      isScrollControlled: true,
    );
  }
}

class _GuestTeamRosterHeader extends StatelessWidget {
  final TournamentGuestTeamRosterController controller;

  const _GuestTeamRosterHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final guestTeam = controller.guestTeam.value!;
    final tournament = controller.tournament.value;
    final captain = controller.captain;

    return El7reefSurface(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guestTeam.name, style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(
            tournament == null ? 'بطولة غير محددة' : tournament.name,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              TournamentStatusChip(
                label: '${controller.activePlayers.length} لاعب نشط',
                backgroundColor: AppColors.primarySurface,
              ),
              TournamentStatusChip(
                label: captain == null
                    ? 'لا يوجد قائد'
                    : 'القائد: ${captain.displayName}',
                backgroundColor: captain == null
                    ? AppColors.surface
                    : AppColors.secondary.withValues(alpha: 0.18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestRosterSection extends StatelessWidget {
  final String title;
  final List<GuestPlayer> players;
  final TournamentGuestTeamRosterController controller;
  final ValueChanged<GuestPlayer> onEdit;

  const _GuestRosterSection({
    required this.title,
    required this.players,
    required this.controller,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.sm),
        ...players.map(
          (player) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: _GuestPlayerCard(
              player: player,
              controller: controller,
              onEdit: () => onEdit(player),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestPlayerCard extends StatelessWidget {
  final GuestPlayer player;
  final TournamentGuestTeamRosterController controller;
  final VoidCallback onEdit;

  const _GuestPlayerCard({
    required this.player,
    required this.controller,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isArchived = player.claimStatus == GuestClaimStatus.archived;
    final isCaptain = controller.isCaptain(player);

    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JerseyBadge(number: player.jerseyNumber),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.displayName, style: AppTextStyles.titleLarge),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      _playerSecondaryText(player),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isCaptain)
                TournamentStatusChip(
                  label: 'قائد',
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.18),
                ),
            ],
          ),
          if (player.notes != null && player.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(player.notes!, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              TournamentStatusChip(
                label: _claimStatusLabel(player.claimStatus),
                backgroundColor: isArchived
                    ? AppColors.errorSurface
                    : AppColors.primarySurface,
              ),
              if (player.hasLinkedPlayer)
                const TournamentStatusChip(
                  label: 'مرتبط بحساب',
                  backgroundColor: AppColors.infoSurface,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('تعديل'),
              ),
              if (!isArchived && !isCaptain)
                OutlinedButton.icon(
                  onPressed: () => controller.setCaptain(player),
                  icon: const Icon(Icons.military_tech, size: 16),
                  label: const Text('قائد'),
                ),
              if (!isArchived)
                OutlinedButton.icon(
                  onPressed: () => _confirmArchive(context),
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('أرشفة'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _playerSecondaryText(GuestPlayer player) {
    final details = <String>[
      if (player.preferredPosition != null &&
          player.preferredPosition!.trim().isNotEmpty)
        player.preferredPosition!.trim(),
      if (player.phoneNumber != null && player.phoneNumber!.trim().isNotEmpty)
        player.phoneNumber!.trim(),
    ];
    return details.isEmpty ? 'لا توجد بيانات إضافية' : details.join(' • ');
  }

  String _claimStatusLabel(GuestClaimStatus status) {
    return switch (status) {
      GuestClaimStatus.guest => 'ضيف',
      GuestClaimStatus.invited => 'رابط مطالبة',
      GuestClaimStatus.claimed => 'تمت المطالبة',
      GuestClaimStatus.archived => 'مؤرشف',
    };
  }

  void _confirmArchive(BuildContext context) {
    Get.defaultDialog(
      title: 'أرشفة اللاعب',
      middleText: 'سيخرج ${player.displayName} من القائمة النشطة للفريق الضيف.',
      textCancel: 'إلغاء',
      textConfirm: 'أرشفة',
      confirmTextColor: AppColors.textOnPrimary,
      buttonColor: AppColors.primary,
      onConfirm: () {
        Get.back();
        controller.archivePlayer(player);
      },
    );
  }
}

class _JerseyBadge extends StatelessWidget {
  final int? number;

  const _JerseyBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Text(
        number == null ? '--' : number.toString(),
        style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _GuestPlayerFormSheet extends StatelessWidget {
  final TournamentGuestTeamRosterController controller;
  final bool isEditing;

  const _GuestPlayerFormSheet({
    required this.controller,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppDimensions.lg,
          right: AppDimensions.lg,
          top: AppDimensions.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'تعديل لاعب ضيف' : 'إضافة لاعب ضيف',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: controller.nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم اللاعب'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'رقم الموبايل'),
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.jerseyController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'رقم القميص',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: TextField(
                      controller: controller.positionController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'المركز'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: controller.notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: AppDimensions.lg),
              Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.submitPlayerForm,
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'حفظ التعديل' : 'إضافة اللاعب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestRosterEmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _GuestRosterEmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('لاعبو الفريق لسه ما اتسجلوش', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'أضف اللاعبين الضيوف هنا عشان يظهروا في matchday وتسجيل النتيجة.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.md),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة أول لاعب'),
          ),
        ],
      ),
    );
  }
}

class _GuestRosterErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _GuestRosterErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: El7reefSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 36,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text('تعذر تحميل القائمة', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppDimensions.xs),
              Text(
                message,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
