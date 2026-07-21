import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/knockout_bracket.dart';

class KnockoutBracketModel {
  final String id;
  final String tournamentId;
  final String format;
  final List<String> qualifierParticipantIds;
  final String seedingMethod;
  final List<String> byeParticipantIds;
  final String? championParticipantId;
  final int createdAt;
  final int updatedAt;

  const KnockoutBracketModel({
    required this.id,
    required this.tournamentId,
    required this.format,
    this.qualifierParticipantIds = const [],
    this.seedingMethod = 'ranked',
    this.byeParticipantIds = const [],
    this.championParticipantId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnockoutBracketModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return KnockoutBracketModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      format:
          json['format'] as String? ?? KnockoutFormat.singleElimination.name,
      qualifierParticipantIds:
          (json['qualifierParticipantIds'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList(growable: false) ??
          const [],
      seedingMethod:
          json['seedingMethod'] as String? ?? KnockoutSeedingMethod.ranked.name,
      byeParticipantIds:
          (json['byeParticipantIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      championParticipantId: json['championParticipantId'] as String?,
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
      'format': format,
      'qualifierParticipantIds': qualifierParticipantIds,
      'seedingMethod': seedingMethod,
      'byeParticipantIds': byeParticipantIds,
      'championParticipantId': championParticipantId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  KnockoutBracket toEntity() {
    return KnockoutBracket(
      id: id,
      tournamentId: tournamentId,
      format: KnockoutFormat.values.firstWhere(
        (value) => value.name == format,
        orElse: () => KnockoutFormat.singleElimination,
      ),
      qualifierParticipantIds: qualifierParticipantIds,
      seedingMethod: KnockoutSeedingMethod.values.firstWhere(
        (value) => value.name == seedingMethod,
        orElse: () => KnockoutSeedingMethod.ranked,
      ),
      byeParticipantIds: byeParticipantIds,
      championParticipantId: championParticipantId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  factory KnockoutBracketModel.fromEntity(KnockoutBracket entity) {
    return KnockoutBracketModel(
      id: entity.id,
      tournamentId: entity.tournamentId,
      format: entity.format.name,
      qualifierParticipantIds: entity.qualifierParticipantIds,
      seedingMethod: entity.seedingMethod.name,
      byeParticipantIds: entity.byeParticipantIds,
      championParticipantId: entity.championParticipantId,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}
