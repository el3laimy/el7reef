import '../../domain/entities/player_fantasy_value.dart';

/// محرك احتساب وتنظيم مستويات الندرة للاعبين في نظام الفانتازي
class TierSystemEngine {
  /// احتساب المستوى الجديد بناءً على إجمالي النقاط (أو النقاط التراكمية)
  /// 
  /// المعايير:
  /// - الذهبي (Gold): أكبر من أو يساوي 200 نقطة.
  /// - الفضي (Silver): من 150 إلى 199 نقطة.
  /// - البرونزي (Bronze): أقل من 150 نقطة.
  static PlayerTier calculateTier(int totalPoints) {
    if (totalPoints >= 200) {
      return PlayerTier.gold;
    } else if (totalPoints >= 150 && totalPoints < 200) {
      return PlayerTier.silver;
    } else {
      return PlayerTier.bronze;
    }
  }

  /// يتحقق من صحة تشكيلة المستخدم لتتطابق مع قوانين الندرة المعتمدة
  /// 
  /// القوانين المطبقة:
  /// - حد أقصى (1) لاعب ذهبي فقط كلاعب استثنائي (Franchise Player).
  /// - حد أقصى (2) لاعبين تصنيف فضي لدعم التشكيلة.
  /// - عدد لا نهائي (Unlimited) من اللاعبين ذوي التصنيف البرونزي الأساسي.
  /// 
  /// يفضل إرجاع قائمة بالنواقص أو رسالة خطأ، هنا نعيد (نص) يمثل الخطأ إن وجد.
  static String? validateTeamTiers(List<PlayerFantasyValue> teamPlayers) {
    int goldCount = 0;
    int silverCount = 0;

    for (var player in teamPlayers) {
      if (player.tier == PlayerTier.gold) {
        goldCount++;
      } else if (player.tier == PlayerTier.silver) {
        silverCount++;
      }
    }

    if (goldCount > 1) {
      return 'تجاوزت الحد المسموح به للاعبين الذهبيين (الحد الأقصى هو تقييم ذهبي واحد فقط).';
    }

    if (silverCount > 2) {
      return 'تجاوزت الحد المسموح به للاعبين الفضيين (الحد الأقصى هو لاعبان فضيان فقط).';
    }

    // التشكيلة صالحة ولا توجد أخطاء تخص مستويات الفانتازي
    return null;
  }
}
