import '../../domain/entities/knockout_tie.dart';

class KnockoutTieModel {
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
  final int createdAt;
  final int updatedAt;

  const KnockoutTieModel({
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnockoutTieModel.fromJson(Map<String, dynamic> json, String docId) {
    return KnockoutTieModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      bracketId: json['bracketId'] as String? ?? '',
      roundIndex: (json['roundIndex'] as num?)?.toInt() ?? 0,
      slotNumber: (json['slotNumber'] as num?)?.toInt() ?? 0,
      participantAId: json['participantAId'] as String?,
      participantBId: json['participantBId'] as String?,
      winnerParticipantId: json['winnerParticipantId'] as String?,
      matchId: json['matchId'] as String?,
      nextTieId: json['nextTieId'] as String?,
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'bracketId': bracketId,
      'roundIndex': roundIndex,
      'slotNumber': slotNumber,
      'participantAId': participantAId,
      'participantBId': participantBId,
      'winnerParticipantId': winnerParticipantId,
      'matchId': matchId,
      'nextTieId': nextTieId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  KnockoutTie toEntity() {
    return KnockoutTie(
      id: id,
      tournamentId: tournamentId,
      bracketId: bracketId,
      roundIndex: roundIndex,
      slotNumber: slotNumber,
      participantAId: participantAId,
      participantBId: participantBId,
      winnerParticipantId: winnerParticipantId,
      matchId: matchId,
      nextTieId: nextTieId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  factory KnockoutTieModel.fromEntity(KnockoutTie entity) {
    return KnockoutTieModel(
      id: entity.id,
      tournamentId: entity.tournamentId,
      bracketId: entity.bracketId,
      roundIndex: entity.roundIndex,
      slotNumber: entity.slotNumber,
      participantAId: entity.participantAId,
      participantBId: entity.participantBId,
      winnerParticipantId: entity.winnerParticipantId,
      matchId: entity.matchId,
      nextTieId: entity.nextTieId,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
