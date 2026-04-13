/// ثوابت النظام الأساسية — القيم الرياضية والحدود
abstract class AppConstants {
  // ── App Info ──
  static const String appName = 'الحريف';
  static const String appTagline = 'الشبكة الاجتماعية لكرة القدم الشعبية';

  // ── Rating System ──
  static const int baseRating = 1000;
  static const int winScore = 25;
  static const int drawScore = 10;
  static const int loseScore = -10;
  static const int mvpBonus = 15;
  static const int peerRatingPositive = 10;
  static const int peerRatingNegative = -10;

  // ── Organizer Golden Rating ──
  static const int goldenRatingMultiplier = 2; // ×2 impact
  static const int goldenRatingPositive = peerRatingPositive * goldenRatingMultiplier;
  static const int goldenRatingNegative = peerRatingNegative * goldenRatingMultiplier;

  // ── Difficulty Multiplier Bounds ──
  static const double difficultyMultiplierMin = 0.8;
  static const double difficultyMultiplierMax = 1.5;

  // ── Trust Weights ──
  static const double trustWeightNew = 0.5;
  static const double trustWeightActive = 1.0;
  static const double trustWeightVeteran = 1.2;

  // ── Veteran Criteria ──
  static const int veteranMatchThreshold = 50;
  static const int veteranDaysThreshold = 60; // شهرين
  static const int newPlayerMatchThreshold = 5;

  // ── Anti-Cheat: Diminishing Returns ──
  static const int diminishingWindowHours = 48;
  static const int diminishingMatch3 = 3;
  static const int diminishingMatch5 = 5;
  static const int diminishingMatch7 = 7;
  static const double diminishingFactor3 = 0.8;  // 20% reduction
  static const double diminishingFactor5 = 0.5;  // 50% reduction
  static const double diminishingFactor7 = 0.0;  // 100% reduction

  // ── Anti-Cheat: Mutual Abuse ──
  static const int mutualAbuseCheckWindow = 10; // آخر 10 تقييمات
  static const double mutualAbuseThreshold = 0.9; // 90% positive
  static const int mutualAbuseMinRatings = 5;

  // ── Anti-Cheat: Anomaly ──
  static const int anomalyScoreThreshold = 15; // e.g. 15-0

  // ── Rating Window ──
  static const int ratingWindowMinutes = 10;

  // ── Match ──
  static const int defaultTeamSize = 5; // 5v5
  static const int defaultTotalSlots = 10;

  // ── Fantasy Points ──
  static const double fantasyRatingMultiplier = 1.0;
  static const int fantasyMvpBonus = 20;
  static const int fantasyCleanSheetBonus = 10;
  static const int fantasyWinBonus = 5;
  static const int fantasyDrawBonus = 2;

  // ── Geolocation ──
  static const double defaultSearchRadiusKm = 5.0;
  static const double maxSearchRadiusKm = 25.0;

  // ── Rank Tier Thresholds ──
  static const int rankBronzeMax = 799;
  static const int rankSilverMax = 1099;
  static const int rankGoldMax = 1399;
  static const int rankPlatinumMax = 1699;
  static const int rankDiamondMax = 1999;
  // 2000+ = Legendary
}
