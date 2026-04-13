import '../../domain/entities/fantasy_team.dart';

class FantasyTeamModel extends FantasyTeam {
  const FantasyTeamModel({
    required super.id,
    required super.ownerPlayerId,
    required super.teamName,
    super.budget = 100.0,
    super.totalPoints = 0,
    super.currentGameweekPoints = 0,
    super.freeTransfers = 1,
    super.totalTransfers = 0,
    super.formation = '2-1-1',
    super.activeChips = const [],
    required super.createdAt,
    required super.updatedAt,
  });

  factory FantasyTeamModel.fromJson(Map<String, dynamic> json, String documentId) {
    return FantasyTeamModel(
      id: documentId,
      ownerPlayerId: json['ownerPlayerId'] as String? ?? '',
      teamName: json['teamName'] as String? ?? 'فريق بدون اسم',
      budget: (json['budget'] as num?)?.toDouble() ?? 100.0,
      totalPoints: json['totalPoints'] as int? ?? 0,
      currentGameweekPoints: json['currentGameweekPoints'] as int? ?? 0,
      freeTransfers: json['freeTransfers'] as int? ?? 1,
      totalTransfers: json['totalTransfers'] as int? ?? 0,
      formation: json['formation'] as String? ?? '2-1-1',
      activeChips: List<String>.from(json['activeChips'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerPlayerId': ownerPlayerId,
      'teamName': teamName,
      'budget': budget,
      'totalPoints': totalPoints,
      'currentGameweekPoints': currentGameweekPoints,
      'freeTransfers': freeTransfers,
      'totalTransfers': totalTransfers,
      'formation': formation,
      'activeChips': activeChips,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FantasyTeamModel.fromEntity(FantasyTeam entity) {
    return FantasyTeamModel(
      id: entity.id,
      ownerPlayerId: entity.ownerPlayerId,
      teamName: entity.teamName,
      budget: entity.budget,
      totalPoints: entity.totalPoints,
      currentGameweekPoints: entity.currentGameweekPoints,
      freeTransfers: entity.freeTransfers,
      totalTransfers: entity.totalTransfers,
      formation: entity.formation,
      activeChips: entity.activeChips,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  FantasyTeam toEntity() {
    return FantasyTeam(
      id: id,
      ownerPlayerId: ownerPlayerId,
      teamName: teamName,
      budget: budget,
      totalPoints: totalPoints,
      currentGameweekPoints: currentGameweekPoints,
      freeTransfers: freeTransfers,
      totalTransfers: totalTransfers,
      formation: formation,
      activeChips: activeChips,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
