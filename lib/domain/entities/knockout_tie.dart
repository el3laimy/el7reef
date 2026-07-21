import '../../core/enums/tournament_ops_enums.dart';

class KnockoutTie {
  final String id;
  final String tournamentId;
  final String bracketId;
  final int roundIndex;
  final int slotNumber;
  final String? participantAId;
  final String? participantBId;
  final String? winnerParticipantId;
  final String? matchId;
  final String? nextTieId;
  final KnockoutTieResolution resolutionType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnockoutTie({
    required this.id,
    required this.tournamentId,
    required this.bracketId,
    required this.roundIndex,
    required this.slotNumber,
    this.participantAId,
    this.participantBId,
    this.winnerParticipantId,
    this.matchId,
    this.nextTieId,
    this.resolutionType = KnockoutTieResolution.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isReady =>
      participantAId != null &&
      participantAId!.isNotEmpty &&
      participantBId != null &&
      participantBId!.isNotEmpty;

  KnockoutTie copyWith({
    String? id,
    String? tournamentId,
    String? bracketId,
    int? roundIndex,
    int? slotNumber,
    Object? participantAId = _unsetTieValue,
    Object? participantBId = _unsetTieValue,
    Object? winnerParticipantId = _unsetTieValue,
    Object? matchId = _unsetTieValue,
    Object? nextTieId = _unsetTieValue,
    KnockoutTieResolution? resolutionType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnockoutTie(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      bracketId: bracketId ?? this.bracketId,
      roundIndex: roundIndex ?? this.roundIndex,
      slotNumber: slotNumber ?? this.slotNumber,
      participantAId: identical(participantAId, _unsetTieValue)
          ? this.participantAId
          : participantAId as String?,
      participantBId: identical(participantBId, _unsetTieValue)
          ? this.participantBId
          : participantBId as String?,
      winnerParticipantId: identical(winnerParticipantId, _unsetTieValue)
          ? this.winnerParticipantId
          : winnerParticipantId as String?,
      matchId: identical(matchId, _unsetTieValue)
          ? this.matchId
          : matchId as String?,
      nextTieId: identical(nextTieId, _unsetTieValue)
          ? this.nextTieId
          : nextTieId as String?,
      resolutionType: resolutionType ?? this.resolutionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unsetTieValue = Object();
