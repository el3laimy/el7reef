import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import 'tournament_dashboard_helpers.dart';
import 'tournament_status_chip.dart';

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
    final canReplace = controller.canReplaceParticipant(participant);
    final canWithdraw = participant.isActive && !controller.isActing.value;
    final canEditSeed = controller.canEditParticipantSeed(participant);
    final canReactivate = controller.canReactivateParticipant(participant);

    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      participant.groupId == null
                          ? 'لم يُسند إلى مجموعة بعد'
                          : 'المجموعة: ${controller.groupLabelFor(participant.groupId)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (participant.replacedByParticipantId != null &&
                        participant.replacedByParticipantId!.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: AppDimensions.xs),
                        child: Text(
                          'تم استبداله بواسطة: ${controller.participantLabelFor(participant.replacedByParticipantId)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    if (participant.replacementForParticipantId != null &&
                        participant.replacementForParticipantId!.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: AppDimensions.xs),
                        child: Text(
                          'بديل عن: ${controller.participantLabelFor(participant.replacementForParticipantId)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              TournamentStatusChip(
                label: participantStatusLabel(participant.status),
                backgroundColor:
                    participantStatusColor(participant.status),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              TournamentStatusChip(
                label: participantSourceLabel(participant.sourceType),
                backgroundColor: AppColors.surface,
              ),
              if (participant.seed != null)
                TournamentStatusChip(
                  label: 'تصنيف ${participant.seed}',
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                ),
            ],
          ),
          if (participant.isActive) ...[
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                if (canEditSeed)
                  OutlinedButton.icon(
                    onPressed: () => showSeedEditorDialog(
                        context, controller, participant),
                    icon: const Icon(Icons.tag, size: 16),
                    label: const Text('تعديل التصنيف'),
                  ),
                if (canReplace)
                  OutlinedButton.icon(
                    onPressed: () => showReplaceParticipantDialog(
                        context, controller, participant),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('استبدال'),
                  ),
                OutlinedButton.icon(
                  onPressed: canWithdraw
                      ? () =>
                          controller.withdrawParticipant(participant.id)
                      : null,
                  icon: const Icon(Icons.person_remove_alt_1, size: 16),
                  label: const Text('سحب'),
                ),
              ],
            ),
          ] else if (canReactivate) ...[
            const SizedBox(height: AppDimensions.md),
            OutlinedButton.icon(
              onPressed: () =>
                  controller.reactivateParticipant(participant.id),
              icon: const Icon(Icons.settings_backup_restore, size: 16),
              label: const Text('إعادة تفعيل'),
            ),
          ],
        ],
      ),
    );
  }
}
