import '../../domain/entities/fantasy_slot.dart';

class FantasySlotModel extends FantasySlot {
  const FantasySlotModel({
    required super.id,
    required super.fantasyTeamId,
    required super.playerId,
    required super.isStartingXI,
    super.benchPriority = 0,
    super.isEliminated = false,
    super.role = FantasyPlayerRole.none,
    super.pointsEarned = 0,
  });

  factory FantasySlotModel.fromJson(Map<String, dynamic> json, String documentId) {
    return FantasySlotModel(
      id: documentId,
      fantasyTeamId: json['fantasyTeamId'] as String? ?? '',
      playerId: json['playerId'] as String? ?? '',
      isStartingXI: json['isStartingXI'] as bool? ?? false,
      benchPriority: json['benchPriority'] as int? ?? 0,
      isEliminated: json['isEliminated'] as bool? ?? false,
      role: _parseRole(json['role'] as String?),
      pointsEarned: json['pointsEarned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fantasyTeamId': fantasyTeamId,
      'playerId': playerId,
      'isStartingXI': isStartingXI,
      'benchPriority': benchPriority,
      'isEliminated': isEliminated,
      'role': role.name,
      'pointsEarned': pointsEarned,
    };
  }

  factory FantasySlotModel.fromEntity(FantasySlot entity) {
    return FantasySlotModel(
      id: entity.id,
      fantasyTeamId: entity.fantasyTeamId,
      playerId: entity.playerId,
      isStartingXI: entity.isStartingXI,
      benchPriority: entity.benchPriority,
      isEliminated: entity.isEliminated,
      role: entity.role,
      pointsEarned: entity.pointsEarned,
    );
  }

  FantasySlot toEntity() {
    return FantasySlot(
      id: id,
      fantasyTeamId: fantasyTeamId,
      playerId: playerId,
      isStartingXI: isStartingXI,
      benchPriority: benchPriority,
      isEliminated: isEliminated,
      role: role,
      pointsEarned: pointsEarned,
    );
  }

  static FantasyPlayerRole _parseRole(String? val) {
    if (val == null) return FantasyPlayerRole.none;
    return FantasyPlayerRole.values.firstWhere(
      (e) => e.name == val,
      orElse: () => FantasyPlayerRole.none,
    );
  }
}
