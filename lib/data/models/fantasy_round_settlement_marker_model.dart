import '../../domain/entities/fantasy_round_settlement_marker.dart';

class FantasyRoundSettlementMarkerModel extends FantasyRoundSettlementMarker {
  const FantasyRoundSettlementMarkerModel({
    required super.id,
    required super.leagueId,
    required super.gameweek,
    required super.settlementType,
    required super.roundStartedAt,
    required super.roundEndedAt,
    required super.settledAt,
    super.processedMatchIds = const [],
    super.processedTeamIds = const [],
    super.processedMatchCount = 0,
    super.processedTeamCount = 0,
    super.processedSlotCount = 0,
    super.totalPointsApplied = 0,
  });

  factory FantasyRoundSettlementMarkerModel.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    return FantasyRoundSettlementMarkerModel(
      id: documentId,
      leagueId: json['leagueId'] as String? ?? '',
      gameweek: (json['gameweek'] as num?)?.toInt() ?? 0,
      settlementType: json['settlementType'] as String? ?? 'round_points',
      roundStartedAt: json['roundStartedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['roundStartedAt'] as int)
          : DateTime.now(),
      roundEndedAt: json['roundEndedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['roundEndedAt'] as int)
          : DateTime.now(),
      settledAt: json['settledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['settledAt'] as int)
          : DateTime.now(),
      processedMatchIds: List<String>.from(json['processedMatchIds'] ?? const []),
      processedTeamIds: List<String>.from(json['processedTeamIds'] ?? const []),
      processedMatchCount: (json['processedMatchCount'] as num?)?.toInt() ?? 0,
      processedTeamCount: (json['processedTeamCount'] as num?)?.toInt() ?? 0,
      processedSlotCount: (json['processedSlotCount'] as num?)?.toInt() ?? 0,
      totalPointsApplied: (json['totalPointsApplied'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leagueId': leagueId,
      'gameweek': gameweek,
      'settlementType': settlementType,
      'roundStartedAt': roundStartedAt.millisecondsSinceEpoch,
      'roundEndedAt': roundEndedAt.millisecondsSinceEpoch,
      'settledAt': settledAt.millisecondsSinceEpoch,
      'processedMatchIds': processedMatchIds,
      'processedTeamIds': processedTeamIds,
      'processedMatchCount': processedMatchCount,
      'processedTeamCount': processedTeamCount,
      'processedSlotCount': processedSlotCount,
      'totalPointsApplied': totalPointsApplied,
    };
  }

  factory FantasyRoundSettlementMarkerModel.fromEntity(
    FantasyRoundSettlementMarker entity,
  ) {
    return FantasyRoundSettlementMarkerModel(
      id: entity.id,
      leagueId: entity.leagueId,
      gameweek: entity.gameweek,
      settlementType: entity.settlementType,
      roundStartedAt: entity.roundStartedAt,
      roundEndedAt: entity.roundEndedAt,
      settledAt: entity.settledAt,
      processedMatchIds: entity.processedMatchIds,
      processedTeamIds: entity.processedTeamIds,
      processedMatchCount: entity.processedMatchCount,
      processedTeamCount: entity.processedTeamCount,
      processedSlotCount: entity.processedSlotCount,
      totalPointsApplied: entity.totalPointsApplied,
    );
  }

  FantasyRoundSettlementMarker toEntity() {
    return FantasyRoundSettlementMarker(
      id: id,
      leagueId: leagueId,
      gameweek: gameweek,
      settlementType: settlementType,
      roundStartedAt: roundStartedAt,
      roundEndedAt: roundEndedAt,
      settledAt: settledAt,
      processedMatchIds: processedMatchIds,
      processedTeamIds: processedTeamIds,
      processedMatchCount: processedMatchCount,
      processedTeamCount: processedTeamCount,
      processedSlotCount: processedSlotCount,
      totalPointsApplied: totalPointsApplied,
    );
  }
}
