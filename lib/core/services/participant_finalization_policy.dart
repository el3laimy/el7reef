import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_participant.dart';

class ParticipantFinalizationPolicy {
  const ParticipantFinalizationPolicy();

  List<TournamentParticipant> finalize({
    required Tournament tournament,
    required List<TournamentParticipant> participants,
    required DateTime now,
  }) {
    final activeParticipants = participants
        .where(
          (participant) =>
              participant.status == TournamentParticipantStatus.approved ||
              participant.status == TournamentParticipantStatus.finalized,
        )
        .toList(growable: true);
    if (activeParticipants.length < 2) {
      throw Exception('لا يمكن قفل قائمة المشاركين قبل وجود فريقين على الأقل.');
    }

    activeParticipants.sort((left, right) {
      final leftSeed = left.seed ?? 1 << 20;
      final rightSeed = right.seed ?? 1 << 20;
      if (leftSeed != rightSeed) {
        return leftSeed.compareTo(rightSeed);
      }
      final leftApproved = left.approvedAt ?? left.createdAt;
      final rightApproved = right.approvedAt ?? right.createdAt;
      if (leftApproved != rightApproved) {
        return leftApproved.compareTo(rightApproved);
      }
      return left.displayName.compareTo(right.displayName);
    });

    return activeParticipants
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWith(
            seed: entry.value.seed ?? entry.key + 1,
            status: TournamentParticipantStatus.finalized,
            finalizedAt: entry.value.finalizedAt ?? now,
            updatedAt: now,
          ),
        )
        .toList(growable: false);
  }
}
