class TournamentGroup {
  final String id;
  final String tournamentId;
  final String groupStageId;
  final String name;
  final int order;
  final List<String> participantIds;
  final List<String> qualifierParticipantIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TournamentGroup({
    required this.id,
    required this.tournamentId,
    required this.groupStageId,
    required this.name,
    required this.order,
    this.participantIds = const [],
    this.qualifierParticipantIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  TournamentGroup copyWith({
    String? id,
    String? tournamentId,
    String? groupStageId,
    String? name,
    int? order,
    List<String>? participantIds,
    List<String>? qualifierParticipantIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TournamentGroup(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      groupStageId: groupStageId ?? this.groupStageId,
      name: name ?? this.name,
      order: order ?? this.order,
      participantIds: participantIds ?? this.participantIds,
      qualifierParticipantIds:
          qualifierParticipantIds ?? this.qualifierParticipantIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
