import '../../core/constants/app_constants.dart';
import '../../core/enums/player_trust_level.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/player.dart';

/// محرك التقييم — يطبق الفورمولا الكاملة
///
/// Formula: ΔRating = BaseScore × DifficultyMultiplier × TrustWeight
/// مع تطبيق Anti-Cheat Pipeline كاملاً
class RatingEngine {
  /// حساب تغيير التقييم لمباراة
  static RatingDelta calculateMatchDelta({
    required Player player,
    required Match match,
    required bool isWinner,
    required bool isDraw,
    required bool isMvp,
    required double difficultyMultiplier,
    required int recentEncounterCount, // عدد المباريات مع نفس الخصوم (48 ساعة)
    bool isFanMvp = false, // الجائزة المضاعفة (اختيار الجماهير)
  }) {
    // ── Step 1: النتيجة الأساسية ──
    final int baseScore = isDraw
        ? AppConstants.drawScore
        : isWinner
            ? AppConstants.winScore
            : AppConstants.loseScore;

    // ── Step 2: مضاعف MVP & الجائزة المضاعفة ──
    int mvpBonus = isMvp ? AppConstants.mvpBonus : 0;
    
    // تطبيق Double Award (Official MOM + Fan MOM)
    bool isDoubleAward = isMvp && isFanMvp;
    if (isDoubleAward) {
      mvpBonus += 45; // الجائزة الكبرى
    } else if (isFanMvp) {
      mvpBonus += 15; // جائزة الجماهير وحدها لو لم يختره المنظم
    }

    // ── Step 3: Anti-Cheat — Diminishing Returns ──
    final double diminishingFactor =
        _getDiminishingFactor(recentEncounterCount);

    // ── Step 4: مضاعف الصعوبة ──
    final double clampedDifficulty = difficultyMultiplier.clamp(
      AppConstants.difficultyMultiplierMin,
      AppConstants.difficultyMultiplierMax,
    );

    // ── Step 5: وزن الثقة ──
    final double trustWeight = _getTrustWeight(player.trustLevel);

    // ── Step 6: مضاعف Golden Rating (منظم) ──
    final double goldenMultiplier = match.isGoldenRating ? 2.0 : 1.0;

    // ── Step 7: الحساب النهائي ──
    if (match.isAnomaly) {
      return RatingDelta(
        delta: 0,
        reason: 'مجمّد — نتيجة شاذة تحت المراجعة',
        isBlocked: true,
      );
    }

    final double raw =
        (baseScore + mvpBonus) *
        clampedDifficulty *
        trustWeight *
        diminishingFactor *
        goldenMultiplier;

    return RatingDelta(
      delta: raw.round(),
      reason: _buildReason(
        baseScore: baseScore,
        mvpBonus: mvpBonus,
        difficulty: clampedDifficulty,
        trust: trustWeight,
        diminishing: diminishingFactor,
        golden: goldenMultiplier,
        isDoubleAward: isDoubleAward,
      ),
      isBlocked: false,
    );
  }

  /// مضاعف الصعوبة بناءً على فرق التقييم بين الفريقين
  static double computeDifficultyMultiplier({
    required double myTeamAvgRating,
    required double opponentAvgRating,
  }) {
    if (myTeamAvgRating <= 0) return 1.0;
    final ratio = opponentAvgRating / myTeamAvgRating;
    // كلما كان الخصم أقوى، كلما زاد المضاعف عند الفوز
    return ratio.clamp(
      AppConstants.difficultyMultiplierMin,
      AppConstants.difficultyMultiplierMax,
    );
  }

  /// اكتشاف الشذوذ
  static bool isAnomalousResult({
    required int scoreA,
    required int scoreB,
  }) {
    final total = scoreA + scoreB;
    final diff = (scoreA - scoreB).abs();
    return total >= AppConstants.anomalyScoreThreshold || diff >= 10;
  }

  /// ── Private Helpers ──

  static double _getDiminishingFactor(int recentCount) {
    if (recentCount >= AppConstants.diminishingMatch7) {
      return AppConstants.diminishingFactor7;
    } else if (recentCount >= AppConstants.diminishingMatch5) {
      return AppConstants.diminishingFactor5;
    } else if (recentCount >= AppConstants.diminishingMatch3) {
      return AppConstants.diminishingFactor3;
    }
    return 1.0;
  }

  static double _getTrustWeight(PlayerTrustLevel level) {
    switch (level) {
      case PlayerTrustLevel.veteran:
        return AppConstants.trustWeightVeteran;
      case PlayerTrustLevel.active:
        return AppConstants.trustWeightActive;
      case PlayerTrustLevel.newPlayer:
        return AppConstants.trustWeightNew;
      case PlayerTrustLevel.suspended:
        return 0.0;
    }
  }

  static String _buildReason({
    required int baseScore,
    required int mvpBonus,
    required double difficulty,
    required double trust,
    required double diminishing,
    required double golden,
    required bool isDoubleAward,
  }) {
    final parts = <String>[];
    parts.add('أساس: $baseScore');
    if (isDoubleAward) {
      parts.add('🏆 Double Award (+45)'); 
    } else if (mvpBonus > 0) {
      parts.add('MVP: +$mvpBonus');
    }
    if (difficulty != 1.0) parts.add('صعوبة: ×${difficulty.toStringAsFixed(1)}');
    if (trust != 1.0) parts.add('ثقة: ×${trust.toStringAsFixed(1)}');
    if (diminishing < 1.0) parts.add('تراجع: ×${diminishing.toStringAsFixed(1)}');
    if (golden > 1.0) parts.add('تقييم ذهبي: ×2');
    return parts.join(' • ');
  }
}

/// نتيجة حساب التقييم
class RatingDelta {
  final int delta;
  final String reason;
  final bool isBlocked;

  const RatingDelta({
    required this.delta,
    required this.reason,
    required this.isBlocked,
  });

  @override
  String toString() => 'RatingDelta($delta, blocked: $isBlocked)';
}
