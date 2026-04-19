import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/tournament_participant.dart';

class TournamentParticipantModel {
  final String id;
  final String tournamentId;
  final String sourceType;
  final String sourceEntityId;
  final String displayName;
  final String status;
  final int? seed;
  final String? groupId;
  final String? sourceRegistrationId;
  final String? replacementForParticipantId;
  final String? replacedByParticipantId;
  final int createdAt;
  final int updatedAt;
  final int? approvedAt;
  final int? finalizedAt;
  final int? withdrawnAt;
  final int? replacedAt;

  const TournamentParticipantModel({
    required this.id,
    required this.tournamentId,
    required this.sourceType,
    required this.sourceEntityId,
    required this.displayName,
    required this.status,
    this.seed,
    this.groupId,
    this.sourceRegistrationId,
    this.replacementForParticipantId,
    this.replacedByParticipantId,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.finalizedAt,
    this.withdrawnAt,
    this.replacedAt,
  });

  factory TournamentParticipantModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TournamentParticipantModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      sourceEntityId: json['sourceEntityId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      status:
          json['status'] as String? ??
          TournamentParticipantStatus.approved.name,
      seed: (json['seed'] as num?)?.toInt(),
      groupId: json['groupId'] as String?,
      sourceRegistrationId: json['sourceRegistrationId'] as String?,
      replacementForParticipantId:
          json['replacementForParticipantId'] as String?,
      replacedByParticipantId: json['replacedByParticipantId'] as String?,
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      approvedAt: (json['approvedAt'] as num?)?.toInt(),
      finalizedAt: (json['finalizedAt'] as num?)?.toInt(),
      withdrawnAt: (json['withdrawnAt'] as num?)?.toInt(),
      replacedAt: (json['replacedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'sourceType': sourceType,
      'sourceEntityId': sourceEntityId,
      'displayName': displayName,
      'status': status,
      'seed': seed,
      'groupId': groupId,
      'sourceRegistrationId': sourceRegistrationId,
      'replacementForParticipantId': replacementForParticipantId,
      'replacedByParticipantId': replacedByParticipantId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'approvedAt': approvedAt,
      'finalizedAt': finalizedAt,
      'withdrawnAt': withdrawnAt,
      'replacedAt': replacedAt,
    };
  }

  TournamentParticipant toEntity() {
    return TournamentParticipant(
      id: id,
      tournamentId: tournamentId,
      sourceType: TournamentParticipantSourceType.values.firstWhere(
        (value) => value.name == sourceType,
        orElse: () => TournamentParticipantSourceType.registeredTeam,
      ),
      sourceEntityId: sourceEntityId,
      displayName: displayName,
      status: TournamentParticipantStatus.values.firstWhere(
        (value) => value.name == status,
        orElse: () => TournamentParticipantStatus.approved,
      ),
      seed: seed,
      groupId: groupId,
      sourceRegistrationId: sourceRegistrationId,
      replacementForParticipantId: replacementForParticipantId,
      replacedByParticipantId: replacedByParticipantId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      approvedAt: approvedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(approvedAt!),
      finalizedAt: finalizedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(finalizedAt!),
      withdrawnAt: withdrawnAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(withdrawnAt!),
      replacedAt: replacedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(replacedAt!),
    );
  }

  factory TournamentParticipantModel.fromEntity(TournamentParticipant entity) {
    return TournamentParticipantModel(
      id: entity.id,
      tournamentId: entity.tournamentId,
      sourceType: entity.sourceType.name,
      sourceEntityId: entity.sourceEntityId,
      displayName: entity.displayName,
      status: entity.status.name,
      seed: entity.seed,
      groupId: entity.groupId,
      sourceRegistrationId: entity.sourceRegistrationId,
      replacementForParticipantId: entity.replacementForParticipantId,
      replacedByParticipantId: entity.replacedByParticipantId,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
      approvedAt: entity.approvedAt?.millisecondsSinceEpoch,
      finalizedAt: entity.finalizedAt?.millisecondsSinceEpoch,
      withdrawnAt: entity.withdrawnAt?.millisecondsSinceEpoch,
      replacedAt: entity.replacedAt?.millisecondsSinceEpoch,
    );
  }
}
