import '../../domain/entities/player_fantasy_value.dart';

/// محرك الاختيار التلقائي (Auto-Pick) المخصص لاختيار التشكيلة آلياً
/// لمن يتأخر في بناء فريقه أو يفضل الاعتماد على استراتيجية الذكاء الاصطناعي الأساسية.
class AutoPickEngine {
  /// يقوم باختيار قائمة من اللاعبين العشوائيين بأفضل جودة ممكنة في حدود الميزانية والقوانين
  ///
  /// [availablePlayers]: كل اللاعبين المتاحين وغير المقصيين.
  /// [squadSize]: حجم التشكيلة المراد تعبئتها (مثلاً 5 للخماسي أو 11).
  /// [budgetLimit]: الميزانية القصوى المتاحة (مثلاً 100 مليون).
  /// 
  /// يعود بقائمة [PlayerFantasyValue] جاهزة لوضعها كخانات للفريق.
  static List<PlayerFantasyValue> generateBestTeam({
    required List<PlayerFantasyValue> availablePlayers,
    required int squadSize,
    required double budgetLimit,
  }) {
    // 1. ترتيب اللاعبين تنازلياً حسب النقاط الكلية لضمان الحصول على الأفضل أولاً
    final sortedPlayers = List<PlayerFantasyValue>.from(availablePlayers)
      ..sort((a, b) => b.totalFantasyPoints.compareTo(a.totalFantasyPoints));

    List<PlayerFantasyValue> selectedRoster = [];
    double currentSpent = 0.0;
    int goldCount = 0;
    int silverCount = 0;

    for (var player in sortedPlayers) {
      if (selectedRoster.length == squadSize) break;

      // تحقق من قوانين الندرة
      if (player.tier == PlayerTier.gold && goldCount >= 1) continue;
      if (player.tier == PlayerTier.silver && silverCount >= 2) continue;

      // حساب كم يتبقى من الميزانية إذا تم شراء هذا اللاعب
      double remainingBudgetAfterPurchase = budgetLimit - (currentSpent + player.currentPrice);
      
      // حساب الحد الأدنى المطلوب لشراء باقي التشكيلة (بافتراض أن أقل لاعب سعره 4.0)
      int playersNeeded = squadSize - (selectedRoster.length + 1);
      double minimumRequiredForOthers = playersNeeded * 4.0;

      // هل يمكننا شراءه دون كسر الميزانية وتدمير فرص شراء باقي التشكيلة؟
      if (remainingBudgetAfterPurchase >= minimumRequiredForOthers) {
        selectedRoster.add(player);
        currentSpent += player.currentPrice;

        if (player.tier == PlayerTier.gold) goldCount++;
        if (player.tier == PlayerTier.silver) silverCount++;
      }
    }

    // إذا فشلت الخوارزمية في إكمال العدد (لأسباب نقص في اللاعبين الرخيصين جداً أو غيرها) 
    // سيتم إرجاع ما تم اختياره ليقوم النظام بإبلاغ المستخدم بضرورة التدخل اليدوي، 
    // أو يمكن تطوير الخوارزمية مستقبلاً لدعم Backtracking معقد.
    return selectedRoster;
  }
}
