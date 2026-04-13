import '../../domain/entities/player_match_stats.dart';
import '../../domain/entities/fantasy_slot.dart';

/// محرك احتساب نقاط الفانتازي
/// يتم حسابه بناءً على إحصائيات اللاعب الفردية في المباراة المحددة
class FantasyPointsEngine {
  /// حساب النقاط المحصلة للاعب بناءً على مركزه وأدائه
  static int calculateFantasyPoints(PlayerMatchStats stats, {bool isMvp = false, bool isDoubleAward = false}) {
    if (!stats.played) return 0;

    int points = 0;

    // 1. نقاط المشاركة الأساسية
    points += 2; // نقطتان للمشاركة الفعلية

    // 2. نقاط الأهداف، تختلف بحسب المركز
    points += _calculateGoalPoints(stats.goals, stats.position);

    // 3. نقاط التمريرات الحاسمة (الأسيست)، تختلف بحسب المركز
    points += _calculateAssistPoints(stats.assists, stats.position);

    // 4. نقاط التصديات (لإعطاء قيمة أكبر لحراس المرمى)
    // مثلاً: 1 نقطة لكل تصديين اثنين أو 2 نقطة لكل 3 تصديات بناءً على المتعارف عليه
    if (stats.saves > 0) {
      points += (stats.saves / 3).floor() * 2; // +2 نقطة لكل 3 تصديات
    }

    // 5. الشباك النظيفة
    if (stats.cleanSheet) {
      points += _calculateCleanSheetPoints(stats.position);
    }

    // 6. الخصومات للبطاقات
    if (stats.yellowCard) {
      points -= 1; // خصم نقطة للبطاقة الصفراء
    }
    if (stats.redCard) {
      points -= 3; // خصم 3 نقاط للبطاقة الحمراء
    }
    // 7. جوائز رجل المباراة
    if (isDoubleAward) {
      points += 45; // الـ Double Award الخارقة
    } else if (isMvp) {
      points += 25; // رجل المباراة المعتاد
    }

    return points;
  }

  /// تطبيق مضاعف الكابتن (وضم خاصية الكابتن الثلاثي)
  static int applyRoleMultiplier(int basePoints, FantasyPlayerRole role, {bool isTripleCaptain = false}) {
    if (role == FantasyPlayerRole.captain) {
      return basePoints * (isTripleCaptain ? 3 : 2);
    }
    // Vice Captain multiplier doesn't apply directly here. It applies only if the Captain didn't play.
    return basePoints;
  }

  static int _calculateGoalPoints(int goals, MatchPosition position) {
    if (goals <= 0) return 0;
    switch (position) {
      case MatchPosition.goalkeeper:
        return goals * 12; // هدف الحارس نادر وقيمته عالية جداً
      case MatchPosition.defender:
        return goals * 6; // هدف المدافع بقيمة كبيرة
      case MatchPosition.midfielder:
        return goals * 5;
      case MatchPosition.forward:
      case MatchPosition.mixed:
        return goals * 4; // القيمة الافتراضية
    }
  }

  static int _calculateAssistPoints(int assists, MatchPosition position) {
    if (assists <= 0) return 0;
    switch (position) {
      case MatchPosition.goalkeeper:
        return assists * 7;
      case MatchPosition.defender:
        return assists * 5;
      case MatchPosition.midfielder:
      case MatchPosition.forward:
      case MatchPosition.mixed:
        return assists * 3;
    }
  }

  static int _calculateCleanSheetPoints(MatchPosition position) {
    switch (position) {
      case MatchPosition.goalkeeper:
      case MatchPosition.defender:
        return 4; // المدافع والحارس يحصلون على المكافأة الكبرى من الشباك النظيفة
      case MatchPosition.midfielder:
        return 1; // مكافأة بسيطة لخط الوسط
      case MatchPosition.forward:
      case MatchPosition.mixed:
        return 0; // المهاجمون لا يحصلون على نقاط شباك نظيفة
    }
  }

  /// تجميع النقاط النهائية لتشكيلة الفانتازي في نهاية الجولة
  /// وتطبيق خواص الدكة (Bench Boost) والكابتنة (Triple Captain) إن وجدت.
  static int calculateRoundPoints({
    required List<FantasySlot> slots,
    required Map<String, PlayerMatchStats> roundStats,
    List<String> activeChips = const [],
    Set<String> mvpPlayers = const {},
    Set<String> doubleAwardPlayers = const {},
  }) {
    int totalPoints = 0;
    final bool benchBoost = activeChips.contains('Bench Boost');
    final bool tripleCaptain = activeChips.contains('Triple Captain');

    for (var slot in slots) {
      // إهمال اللاعب إذا كان احتياطياً ولم تستخدم خاصية الـ Bench Boost
      if (!slot.isStartingXI && !benchBoost) continue;

      final stats = roundStats[slot.playerId];
      if (stats == null || !stats.played) continue;

      // التأكد ما إذا كان اللاعب قد حصل على جوائز فخرية لتعزيز نقاطه
      final bool isMvp = mvpPlayers.contains(slot.playerId);
      final bool isDoubleAward = doubleAwardPlayers.contains(slot.playerId);

      // حساب النقاط الأساسية بناءً على الأداء الشامل في المباراة
      int basePoints = calculateFantasyPoints(
        stats, 
        isMvp: isMvp, 
        isDoubleAward: isDoubleAward, 
      );
      
      // تطبيق مضاعف الكابتن أو الكابتن الثلاثي
      int finalPoints = applyRoleMultiplier(basePoints, slot.role, isTripleCaptain: tripleCaptain);

      totalPoints += finalPoints;
    }

    return totalPoints;
  }
}
