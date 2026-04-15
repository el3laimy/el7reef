import '../../domain/entities/fantasy_chip.dart';
import '../../domain/entities/fantasy_team.dart';

class FantasyTeamModel extends FantasyTeam {
  const FantasyTeamModel({
    required super.id,
    required super.ownerPlayerId,
    required super.teamName,
    super.leagueIds = const ['global'],
    super.budget = 100.0,
    super.totalPoints = 0,
    super.currentGameweekPoints = 0,
    super.freeTransfers = 1,
    super.freeTransfersGameweek = 0,
    super.totalTransfers = 0,
    super.formation = '2-1-1',
    super.chipUsages = const [],
    required super.createdAt,
    required super.updatedAt,
  });

  factory FantasyTeamModel.fromJson(Map<String, dynamic> json, String documentId) {
    final createdAt = json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : DateTime.now();
    final updatedAt = json['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
        : DateTime.now();

    return FantasyTeamModel(
      id: documentId,
      ownerPlayerId: json['ownerPlayerId'] as String? ?? '',
      teamName: json['teamName'] as String? ?? 'فريق بدون اسم',
      leagueIds: List<String>.from(json['leagueIds'] ?? const ['global']),
      budget: (json['budget'] as num?)?.toDouble() ?? 100.0,
      totalPoints: json['totalPoints'] as int? ?? 0,
      currentGameweekPoints: json['currentGameweekPoints'] as int? ?? 0,
      freeTransfers: json['freeTransfers'] as int? ?? 1,
      freeTransfersGameweek: json['freeTransfersGameweek'] as int? ?? 0,
      totalTransfers: json['totalTransfers'] as int? ?? 0,
      formation: json['formation'] as String? ?? '2-1-1',
      chipUsages: _parseChipUsages(json, createdAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final activeChipLabels = chipUsages
        .where((usage) => !usage.isConsumed)
        .map((usage) => usage.displayName)
        .toList(growable: false);

    return {
      'ownerPlayerId': ownerPlayerId,
      'teamName': teamName,
      'leagueIds': leagueIds,
      'budget': budget,
      'totalPoints': totalPoints,
      'currentGameweekPoints': currentGameweekPoints,
      'freeTransfers': freeTransfers,
      'freeTransfersGameweek': freeTransfersGameweek,
      'totalTransfers': totalTransfers,
      'formation': formation,
      'chipUsages': chipUsages.map((usage) => usage.toJson()).toList(),
      'activeChips': activeChipLabels,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FantasyTeamModel.fromEntity(FantasyTeam entity) {
    return FantasyTeamModel(
      id: entity.id,
      ownerPlayerId: entity.ownerPlayerId,
      teamName: entity.teamName,
      leagueIds: entity.leagueIds,
      budget: entity.budget,
      totalPoints: entity.totalPoints,
      currentGameweekPoints: entity.currentGameweekPoints,
      freeTransfers: entity.freeTransfers,
      freeTransfersGameweek: entity.freeTransfersGameweek,
      totalTransfers: entity.totalTransfers,
      formation: entity.formation,
      chipUsages: entity.chipUsages,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  FantasyTeam toEntity() {
    return FantasyTeam(
      id: id,
      ownerPlayerId: ownerPlayerId,
      teamName: teamName,
      leagueIds: leagueIds,
      budget: budget,
      totalPoints: totalPoints,
      currentGameweekPoints: currentGameweekPoints,
      freeTransfers: freeTransfers,
      freeTransfersGameweek: freeTransfersGameweek,
      totalTransfers: totalTransfers,
      formation: formation,
      chipUsages: chipUsages,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static List<ChipUsage> _parseChipUsages(
    Map<String, dynamic> json,
    DateTime fallbackActivatedAt,
  ) {
    final rawUsages = json['chipUsages'];
    if (rawUsages is List) {
      return rawUsages
          .whereType<Map>()
          .map((usage) => ChipUsage.fromJson(Map<String, dynamic>.from(usage)))
          .toList(growable: false);
    }

    final legacyActiveChips = json['activeChips'];
    if (legacyActiveChips is List) {
      final usages = <ChipUsage>[];
      for (final value in legacyActiveChips) {
        if (value is! String) continue;
        final chipType = ChipType.fromValue(value);
        if (chipType == null) continue;
        usages.add(
          ChipUsage(
            chipType: chipType,
            gameweek: 0,
            activatedAt: fallbackActivatedAt,
          ),
        );
      }
      return usages;
    }

    return const [];
  }
}
