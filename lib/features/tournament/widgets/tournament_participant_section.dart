import 'package:flutter/material.dart';

import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import 'tournament_participant_card.dart';

class TournamentParticipantSection extends StatelessWidget {
  final String title;
  final List<TournamentParticipant> participants;
  final TournamentOperationsController controller;

  const TournamentParticipantSection({
    super.key,
    required this.title,
    required this.participants,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...participants.map(
          (participant) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TournamentParticipantCard(
              participant: participant,
              controller: controller,
            ),
          ),
        ),
      ],
    );
  }
}
