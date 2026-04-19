import '../../core/enums/tournament_ops_enums.dart';

class KnockoutBracket {
  final String id;
  final String tournamentId;
  final KnockoutFormat format;
  final List<String> qualifierParticipantIds;
  final String? championParticipantId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnockoutBracket({
    required this.id,
    required this.tournamentId,
    this.format = KnockoutFormat.singleElimination,
    this.qualifierParticipantIds = const [],
    this.championParticipantId,
    required this.createdAt,
    required this.updatedAt,
  });

  KnockoutBracket copyWith({
    String? id,
    String? tournamentId,
    KnockoutFormat? format,
    List<String>? qualifierParticipantIds,
    Object? championParticipantId = _unsetChampion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnockoutBracket(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      format: format ?? this.format,
      qualifierParticipantIds:
          qualifierParticipantIds ?? this.qualifierParticipantIds,
      championParticipantId: identical(championParticipantId, _unsetChampion)
          ? this.championParticipantId
          : championParticipantId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unsetChampion = Object();
