import '../../domain/entities/tournament_group.dart';

class TournamentGroupModel {
  final String id;
  final String tournamentId;
  final String groupStageId;
  final String name;
  final int order;
  final List<String> participantIds;
  final List<String> qualifierParticipantIds;
  final int createdAt;
  final int updatedAt;

  const TournamentGroupModel({
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

  factory TournamentGroupModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TournamentGroupModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      groupStageId: json['groupStageId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      participantIds:
          (json['participantIds'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList(growable: false) ??
          const [],
      qualifierParticipantIds:
          (json['qualifierParticipantIds'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList(growable: false) ??
          const [],
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
      'groupStageId': groupStageId,
      'name': name,
      'order': order,
      'participantIds': participantIds,
      'qualifierParticipantIds': qualifierParticipantIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  TournamentGroup toEntity() {
    return TournamentGroup(
      id: id,
      tournamentId: tournamentId,
      groupStageId: groupStageId,
      name: name,
      order: order,
      participantIds: participantIds,
      qualifierParticipantIds: qualifierParticipantIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  factory TournamentGroupModel.fromEntity(TournamentGroup entity) {
    return TournamentGroupModel(
      id: entity.id,
      tournamentId: entity.tournamentId,
      groupStageId: entity.groupStageId,
      name: entity.name,
      order: entity.order,
      participantIds: entity.participantIds,
      qualifierParticipantIds: entity.qualifierParticipantIds,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
