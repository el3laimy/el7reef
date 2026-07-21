import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_group.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../models/qualification_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class QualificationShareController {
  const QualificationShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  QualificationShareData? buildIfOfficial({
    required Tournament tournament,
    required TournamentGroup group,
    required GroupStandingSnapshot snapshot,
    required GroupStandingEntry entry,
    required TournamentParticipant participant,
    required bool qualificationIsOfficial,
  }) {
    final tournamentName = _requiredLabel(tournament.name);
    final groupName = _requiredLabel(group.name);
    final teamName = _requiredLabel(participant.displayName);
    final participantReferences = <String>{
      participant.id,
      participant.sourceEntityId,
    }..removeWhere((value) => value.trim().isEmpty);
    final matchingEntries = snapshot.entries
        .where((candidate) => candidate.participantId == entry.participantId)
        .toList(growable: false);
    final snapshotEntry = matchingEntries.length == 1
        ? matchingEntries.single
        : null;
    final assignedGroupId = participant.groupId?.trim();
    if (!qualificationIsOfficial ||
        !_supportsOfficialQualification(tournament.status) ||
        tournamentName == null ||
        groupName == null ||
        teamName == null ||
        _requiredLabel(tournament.id) == null ||
        _requiredLabel(group.id) == null ||
        _requiredLabel(group.groupStageId) == null ||
        _requiredLabel(snapshot.id) == null ||
        _requiredLabel(participant.sourceEntityId) == null ||
        group.tournamentId != tournament.id ||
        snapshot.tournamentId != tournament.id ||
        snapshot.groupId != group.id ||
        snapshot.groupStageId != group.groupStageId ||
        participant.tournamentId != tournament.id ||
        !participant.isActive ||
        !group.participantIds.any(participantReferences.contains) ||
        (assignedGroupId != null &&
            assignedGroupId.isNotEmpty &&
            assignedGroupId != group.id) ||
        !participantReferences.contains(entry.participantId) ||
        !snapshot.qualifierParticipantIds.contains(entry.participantId) ||
        snapshotEntry == null ||
        !_sameStandingEntry(snapshotEntry, entry) ||
        entry.rank <= 0) {
      return null;
    }

    return QualificationShareData(
      tournamentName: tournamentName,
      groupName: groupName,
      teamName: teamName,
      teamKindLabel:
          participant.sourceType == TournamentParticipantSourceType.guestTeam
          ? 'فريق ضيف'
          : 'فريق مسجل',
      initials: _initials(teamName),
      rank: entry.rank,
      points: entry.points,
      goalDifference: entry.goalDifference,
      sharePayload: _payloadBuilder.qualification(
        tournamentId: tournament.id,
        teamId: participant.sourceEntityId,
        teamKind: participant.sourceType.name,
      ),
    );
  }

  String? _requiredLabel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool _supportsOfficialQualification(TournamentStatus status) {
    return switch (status) {
      TournamentStatus.groupStage ||
      TournamentStatus.transferWindow ||
      TournamentStatus.knockoutStage ||
      TournamentStatus.completed => true,
      TournamentStatus.upcoming ||
      TournamentStatus.registration ||
      TournamentStatus.cancelled => false,
    };
  }

  bool _sameStandingEntry(
    GroupStandingEntry trusted,
    GroupStandingEntry candidate,
  ) {
    return trusted.participantId == candidate.participantId &&
        trusted.displayName == candidate.displayName &&
        trusted.played == candidate.played &&
        trusted.wins == candidate.wins &&
        trusted.draws == candidate.draws &&
        trusted.losses == candidate.losses &&
        trusted.goalsFor == candidate.goalsFor &&
        trusted.goalsAgainst == candidate.goalsAgainst &&
        trusted.rank == candidate.rank &&
        trusted.randomDrawOrder == candidate.randomDrawOrder;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return _take(words.first, 2);
    return '${_take(words.first, 1)}${_take(words[1], 1)}';
  }

  String _take(String value, int count) =>
      value.length <= count ? value : value.substring(0, count);
}
