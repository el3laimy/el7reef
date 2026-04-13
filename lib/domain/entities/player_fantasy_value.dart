/// مستوى ندرة/فئة اللاعب في بورصة الفانتازي
enum PlayerTier {
  /// المستوى البرونزي (اللاعب العادي / أقل من المتوسط)
  bronze,
  /// المستوى الفضي (اللاعب ذو الأداء المتوسط العالي)
  silver,
  /// المستوى الذهبي (نجوم الصف الأول)
  gold,
}

/// تقييم وقيمة اللاعب الحالية في سوق الفانتازي
class PlayerFantasyValue {
  /// معرف اللاعب (نفس معرف اللاعب في نظام الـ Auth)
  final String playerId;
  
  /// سعر اللاعب الحالي في سوق الفانتازي (مثلاً: 5.0 مليون أو 10.5 مليون)
  /// مبدئياً يتم وضع قيمة افتراضية مثل 5.0 أو 8.0 للمستخدمين الجدد
  final double currentPrice;
  
  /// نسبة ملكية اللاعب بين مدربي الفانتازي (ملك لـ X بالمئة من المستخدمين)
  final double ownershipPct;
  
  /// التغير المطلق في السعر خلال الأسبوع الأخير (مثلاً: +0.2 أو -0.1)
  final double netPriceChangeWeek;
  
  /// المستوى الحالي للاعب بناءً على أدائه التراكمي
  final PlayerTier tier;
  
  /// إجمالي النقاط التي حصدها اللاعب طوال تاريخه حتى الآن في الفانتازي
  final int totalFantasyPoints;

  const PlayerFantasyValue({
    required this.playerId,
    this.currentPrice = 5.0,
    this.ownershipPct = 0.0,
    this.netPriceChangeWeek = 0.0,
    this.tier = PlayerTier.bronze,
    this.totalFantasyPoints = 0,
  });

  PlayerFantasyValue copyWith({
    String? playerId,
    double? currentPrice,
    double? ownershipPct,
    double? netPriceChangeWeek,
    PlayerTier? tier,
    int? totalFantasyPoints,
  }) {
    return PlayerFantasyValue(
      playerId: playerId ?? this.playerId,
      currentPrice: currentPrice ?? this.currentPrice,
      ownershipPct: ownershipPct ?? this.ownershipPct,
      netPriceChangeWeek: netPriceChangeWeek ?? this.netPriceChangeWeek,
      tier: tier ?? this.tier,
      totalFantasyPoints: totalFantasyPoints ?? this.totalFantasyPoints,
    );
  }
}
