import '../../../domain/entities/player_fantasy_value.dart';
import '../../../domain/repositories/fantasy_repository.dart';
import 'tier_system_engine.dart';

/// خدمة إدارة وتحديث القيمة السوقية للاعبين والتصنيف في نظام الفانتازي
class PlayerValueService {
  final FantasyRepository _fantasyRepository;

  PlayerValueService(this._fantasyRepository);

  /// تحديث قيمة اللاعب ومستواه بناءً على النقاط التي حصدها في مباراة معينة أو أسبوعياً
  /// 
  /// [playerId]: معرف اللاعب المستهدف.
  /// [pointsDelta]: النقاط التي أضيفت للاعب في الجولة الحالية لمعرفة أدائه.
  Future<void> updatePlayerValueAfterMatch(String playerId, int pointsDelta) async {
    final currentValue = await _fantasyRepository.getPlayerFantasyValue(playerId);
    
    // إذا لم يكن اللاعب موجوداً مسبقاً، لا يتم القيام بشيء (يفرضه منظم البطولة أولاً)
    if (currentValue == null) return;

    final int newTotalPoints = currentValue.totalFantasyPoints + pointsDelta;
    
    // 1. تحديد مستوى اللاعب الجديد بناءً على أرباحه التراكمية
    final PlayerTier updatedTier = TierSystemEngine.calculateTier(newTotalPoints);
    
    // 2. تحديث السعر الحالي بناءً على الأداء الشديد أو المنخفض
    double calculatedNetChange = 0.0;
    
    if (pointsDelta >= 15) {
      calculatedNetChange = 0.3; // أداء خارق = ارتفاع ملحوظ
    } else if (pointsDelta >= 8) {
      calculatedNetChange = 0.1; // أداء ممتاز = ارتفاع نسبي
    } else if (pointsDelta <= 2) {
      calculatedNetChange = -0.1; // أداء ضعيف جداً أو غياب = هبوط في السعر
    }

    double newPrice = currentValue.currentPrice + calculatedNetChange;
    // يجب التقييد بألا ينزل السعر عن 4.0 مليون كحد أدنى (قياسي في الفانتازي)
    if (newPrice < 4.0) {
      newPrice = 4.0;
    }
    
    // تقريب الكسور العشرية لمنع تلوث القيمة
    newPrice = double.parse(newPrice.toStringAsFixed(1));
    
    // 3. بناء الكيان المُحدث
    final updatedValue = currentValue.copyWith(
      currentPrice: newPrice,
      netPriceChangeWeek: calculatedNetChange,
      tier: updatedTier,
      totalFantasyPoints: newTotalPoints,
    );
    
    // 4. حفظ الكيان في مستودع البيانات
    await _fantasyRepository.updatePlayerFantasyValue(updatedValue);
  }
}
