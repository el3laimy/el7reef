import 'package:flutter/material.dart';

import '../../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import 'tournament_dashboard_helpers.dart';
import 'tournament_status_chip.dart';

class TournamentParticipantCard extends StatelessWidget {
  final TournamentParticipant participant;
  final TournamentOperationsController controller;

  const TournamentParticipantCard({super.key, required this.participant, required this.controller});

  @override
  Widget build(BuildContext context) {
    final canReplace = controller.canReplaceParticipant(participant);
    final canWithdraw = participant.isActive && !controller.isActing.value;
    final canEditSeed = controller.canEditParticipantSeed(participant);
    final canReactivate = controller.canReactivateParticipant(participant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participant.groupId == null
                            ? 'لم يُسند إلى مجموعة بعد'
                            : 'المجموعة: ${controller.groupLabelFor(participant.groupId)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (participant.replacedByParticipantId != null &&
                          participant.replacedByParticipantId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'تم استبداله بواسطة: ${controller.participantLabelFor(participant.replacedByParticipantId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (participant.replacementForParticipantId != null &&
                          participant.replacementForParticipantId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'بديل عن: ${controller.participantLabelFor(participant.replacementForParticipantId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                TournamentStatusChip(
                  label: participantStatusLabel(participant.status),
                  backgroundColor: participantStatusColor(participant.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TournamentStatusChip(
                  label: participantSourceLabel(participant.sourceType),
                  backgroundColor: const Color(0xFFF1F3F5),
                ),
                if (participant.seed != null)
                  TournamentStatusChip(
                    label: 'Seed ${participant.seed}',
                    backgroundColor: const Color(0xFFEAF1FF),
                  ),
              ],
            ),
            if (participant.isActive) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEditSeed)
                    OutlinedButton.icon(
                      onPressed: () => showSeedEditorDialog(context, controller, participant),
                      icon: const Icon(Icons.tag),
                      label: const Text('Edit Seed'),
                    ),
                  if (canReplace)
                    OutlinedButton.icon(
                      onPressed: () => showReplaceParticipantDialog(context, controller, participant),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Replace'),
                    ),
                  OutlinedButton.icon(
                    onPressed: canWithdraw
                        ? () => controller.withdrawParticipant(participant.id)
                        : null,
                    icon: const Icon(Icons.person_remove_alt_1),
                    label: const Text('Withdraw'),
                  ),
                ],
              ),
            ] else if (canReactivate) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => controller.reactivateParticipant(participant.id),
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Reactivate'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
