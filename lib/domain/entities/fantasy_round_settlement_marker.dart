class FantasyRoundSettlementMarker {
  final String id;
  final String leagueId;
  final int gameweek;
  final String settlementType;
  final DateTime roundStartedAt;
  final DateTime roundEndedAt;
  final DateTime settledAt;
  final List<String> processedMatchIds;
  final List<String> processedTeamIds;
  final int processedMatchCount;
  final int processedTeamCount;
  final int processedSlotCount;
  final int totalPointsApplied;

  const FantasyRoundSettlementMarker({
    required this.id,
    required this.leagueId,
    required this.gameweek,
    required this.settlementType,
    required this.roundStartedAt,
    required this.roundEndedAt,
    required this.settledAt,
    this.processedMatchIds = const [],
    this.processedTeamIds = const [],
    this.processedMatchCount = 0,
    this.processedTeamCount = 0,
    this.processedSlotCount = 0,
    this.totalPointsApplied = 0,
  });

  static String buildId({
    required String leagueId,
    required int gameweek,
    required String settlementType,
  }) {
    return '${leagueId}_gw${gameweek}_$settlementType';
  }

  FantasyRoundSettlementMarker copyWith({
    String? id,
    String? leagueId,
    int? gameweek,
    String? settlementType,
    DateTime? roundStartedAt,
    DateTime? roundEndedAt,
    DateTime? settledAt,
    List<String>? processedMatchIds,
    List<String>? processedTeamIds,
    int? processedMatchCount,
    int? processedTeamCount,
    int? processedSlotCount,
    int? totalPointsApplied,
  }) {
    return FantasyRoundSettlementMarker(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      gameweek: gameweek ?? this.gameweek,
      settlementType: settlementType ?? this.settlementType,
      roundStartedAt: roundStartedAt ?? this.roundStartedAt,
      roundEndedAt: roundEndedAt ?? this.roundEndedAt,
      settledAt: settledAt ?? this.settledAt,
      processedMatchIds: processedMatchIds ?? this.processedMatchIds,
      processedTeamIds: processedTeamIds ?? this.processedTeamIds,
      processedMatchCount: processedMatchCount ?? this.processedMatchCount,
      processedTeamCount: processedTeamCount ?? this.processedTeamCount,
      processedSlotCount: processedSlotCount ?? this.processedSlotCount,
      totalPointsApplied: totalPointsApplied ?? this.totalPointsApplied,
    );
  }
}
