import '../../domain/entities/player_fantasy_value.dart';

/// نموذج بيانات سوق الفانتازي الخاص باللاعب للتعامل مع Firestore
class PlayerFantasyValueModel extends PlayerFantasyValue {
  const PlayerFantasyValueModel({
    required super.playerId,
    required super.currentPrice,
    required super.ownershipPct,
    required super.netPriceChangeWeek,
    required super.tier,
    required super.totalFantasyPoints,
  });

  factory PlayerFantasyValueModel.fromJson(Map<String, dynamic> json, String documentId) {
    return PlayerFantasyValueModel(
      playerId: documentId,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 5.0,
      ownershipPct: (json['ownershipPct'] as num?)?.toDouble() ?? 0.0,
      netPriceChangeWeek: (json['netPriceChangeWeek'] as num?)?.toDouble() ?? 0.0,
      tier: _parseTier(json['tier'] as String?),
      totalFantasyPoints: json['totalFantasyPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPrice': currentPrice,
      'ownershipPct': ownershipPct,
      'netPriceChangeWeek': netPriceChangeWeek,
      'tier': tier.name,
      'totalFantasyPoints': totalFantasyPoints,
    };
  }

  factory PlayerFantasyValueModel.fromEntity(PlayerFantasyValue entity) {
    return PlayerFantasyValueModel(
      playerId: entity.playerId,
      currentPrice: entity.currentPrice,
      ownershipPct: entity.ownershipPct,
      netPriceChangeWeek: entity.netPriceChangeWeek,
      tier: entity.tier,
      totalFantasyPoints: entity.totalFantasyPoints,
    );
  }

  PlayerFantasyValue toEntity() {
    return PlayerFantasyValue(
      playerId: playerId,
      currentPrice: currentPrice,
      ownershipPct: ownershipPct,
      netPriceChangeWeek: netPriceChangeWeek,
      tier: tier,
      totalFantasyPoints: totalFantasyPoints,
    );
  }

  static PlayerTier _parseTier(String? val) {
    if (val == null) return PlayerTier.bronze;
    return PlayerTier.values.firstWhere(
      (e) => e.name == val,
      orElse: () => PlayerTier.bronze,
    );
  }
}
