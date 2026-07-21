import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/featured_tournaments.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import 'tournament_dashboard_helpers.dart';
import 'tournament_status_chip.dart';

enum _ParticipantAction { editSeed, replace, withdraw, reactivate }

class TournamentParticipantCard extends StatelessWidget {
  final TournamentParticipant participant;
  final TournamentOperationsController controller;

  const TournamentParticipantCard({
    super.key,
    required this.participant,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final canManage = controller.canManageTournament;
    final canReplace = controller.canReplaceParticipant(participant);
    final canWithdraw =
        canManage && participant.isActive && !controller.isActing.value;
    final canEditSeed = controller.canEditParticipantSeed(participant);
    final canReactivate = controller.canReactivateParticipant(participant);
    final canOpenRoster =
        participant.sourceType == TournamentParticipantSourceType.guestTeam &&
        (canManage ||
            participant.tournamentId == FeaturedTournaments.worldCup2026Id);
    final menuActions = <_ParticipantAction>[
      if (canEditSeed) _ParticipantAction.editSeed,
      if (canReplace) _ParticipantAction.replace,
      if (canWithdraw) _ParticipantAction.withdraw,
      if (canReactivate) _ParticipantAction.reactivate,
    ];

    return El7reefSurface(
      key: ValueKey('participant-${participant.id}'),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TeamMonogram(name: participant.displayName),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimaryTinted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      [
                        participant.groupId == null
                            ? 'لم يُسند إلى مجموعة'
                            : controller.groupLabelFor(participant.groupId),
                        participantSourceLabel(participant.sourceType),
                        if (participant.seed != null)
                          'تصنيف ${participant.seed}',
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              TournamentStatusChip(
                label: participantStatusLabel(participant.status),
                backgroundColor: participantStatusColor(participant.status),
              ),
            ],
          ),
          if (canOpenRoster || menuActions.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canOpenRoster)
                  OutlinedButton.icon(
                    key: ValueKey('participant-roster-${participant.id}'),
                    onPressed: () => _openGuestRoster(participant),
                    icon: const Icon(Icons.groups_2_outlined, size: 18),
                    label: const Text('اللاعبون'),
                  ),
                if (menuActions.isNotEmpty) ...[
                  const SizedBox(width: AppDimensions.xs),
                  PopupMenuButton<_ParticipantAction>(
                    key: ValueKey('participant-menu-${participant.id}'),
                    tooltip: 'خيارات ${participant.displayName}',
                    onSelected: (action) =>
                        _runAction(context, action, participant),
                    itemBuilder: (context) => menuActions
                        .map((action) => _menuItem(action))
                        .toList(growable: false),
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ],
            ),
          ],
          if (participant.replacedByParticipantId?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              'استُبدل بـ ${controller.participantLabelFor(participant.replacedByParticipantId)}',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (participant.replacementForParticipantId?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              'بديل عن ${controller.participantLabelFor(participant.replacementForParticipantId)}',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  void _openGuestRoster(TournamentParticipant team) {
    Get.toNamed(
      AppRoutes.tournamentGuestTeamRosterById(
        tournamentId: team.tournamentId,
        guestTeamId: team.sourceEntityId,
      ),
    );
  }

  PopupMenuItem<_ParticipantAction> _menuItem(_ParticipantAction action) {
    final (icon, label, color) = switch (action) {
      _ParticipantAction.editSeed => (
        Icons.tag_rounded,
        'تعديل التصنيف',
        AppColors.textPrimaryTinted,
      ),
      _ParticipantAction.replace => (
        Icons.swap_horiz_rounded,
        'استبدال الفريق',
        AppColors.textPrimaryTinted,
      ),
      _ParticipantAction.withdraw => (
        Icons.person_remove_alt_1_rounded,
        'سحب من البطولة',
        AppColors.error,
      ),
      _ParticipantAction.reactivate => (
        Icons.settings_backup_restore_rounded,
        'إعادة التفعيل',
        AppColors.primary,
      ),
    };
    return PopupMenuItem<_ParticipantAction>(
      value: action,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppDimensions.sm),
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    _ParticipantAction action,
    TournamentParticipant team,
  ) async {
    switch (action) {
      case _ParticipantAction.editSeed:
        showSeedEditorDialog(context, controller, team);
        return;
      case _ParticipantAction.replace:
        showReplaceParticipantDialog(context, controller, team);
        return;
      case _ParticipantAction.withdraw:
        await _confirmWithdrawal(context, team);
        return;
      case _ParticipantAction.reactivate:
        await controller.reactivateParticipant(team.id);
        return;
    }
  }

  Future<void> _confirmWithdrawal(
    BuildContext context,
    TournamentParticipant team,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سحب الفريق من البطولة؟'),
        content: Text(
          'سيظهر ${team.displayName} ضمن الفرق المنسحبة، ولن يُحذف تاريخه ونتائجه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد السحب'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.withdrawParticipant(team.id);
    }
  }
}

class _TeamMonogram extends StatelessWidget {
  final String name;

  const _TeamMonogram({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.34)),
      ),
      child: Text(
        name.trim().isEmpty ? '؟' : name.trim().characters.first,
        style: AppTextStyles.titleLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
