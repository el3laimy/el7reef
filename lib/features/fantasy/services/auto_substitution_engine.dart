import '../../../domain/entities/fantasy_slot.dart';
import '../../../domain/entities/player_match_stats.dart';

/// محرك التبديلات التلقائية
/// يعمل في نهاية الجولة أو المباراة لاستبدال اللاعبين الأساسيين الذين لم يشاركوا
/// باللاعبين المتواجدين على دكة البدلاء حسب أولوية الدكة (benchPriority).
class AutoSubstitutionEngine {
  /// يقوم بمعالجة الخانات (Slots) وبناء تشكيلة معدلة بناءً على التبديلات التلقائية.
  /// 
  /// [currentSlots]: قائمة الخانات الحالية لفريق الفانتازي.
  /// [roundStats]: إحصائيات اللاعبين في هذه الجولة لمعرفة من شارك ومن غاب.
  /// 
  /// تعيد هذه الدالة قائمة جديدة من [FantasySlot] بعد تطبيق التبديلات الممكنة.
  static List<FantasySlot> processAutoSubstitutions({
    required List<FantasySlot> currentSlots,
    required Map<String, PlayerMatchStats> roundStats,
  }) {
    // 1. فصل الأساسيين عن الاحتياط
    final List<FantasySlot> starters = currentSlots.where((s) => s.isStartingXI).toList();
    final List<FantasySlot> bench = currentSlots.where((s) => !s.isStartingXI).toList();

    // 2. ترتيب دكة البدلاء حسب الأولوية (1, 2, 3..)
    bench.sort((a, b) => a.benchPriority.compareTo(b.benchPriority));

    final List<FantasySlot> modifiedStarters = List.from(starters);
    final List<FantasySlot> modifiedBench = List.from(bench);

    // 3. البحث عن الأساسيين الذين لم يشاركوا
    for (int i = 0; i < modifiedStarters.length; i++) {
      final starter = modifiedStarters[i];
      final starterStats = roundStats[starter.playerId];

      // إذا لم يشارك الأساسي (إما ليس له إحصائيات أو played = false)
      final didNotPlay = starterStats == null || !starterStats.played;

      if (didNotPlay) {
        // 4. إيجاد أول لاعب احتياطي متاح وشارك بالفعل
        int subIndex = -1;
        for (int j = 0; j < modifiedBench.length; j++) {
          final b = modifiedBench[j];
          final bStats = roundStats[b.playerId];

          // يجب أن يكون الاحتياطي قد شارك بالفعل
          if (bStats != null && bStats.played) {
            subIndex = j;
            break; // وجدنا البديل المناسب
          }
        }

        // 5. في حال وجدنا بديل، نقوم بعملتي التبديل الـ Swap
        if (subIndex != -1) {
          final substitute = modifiedBench[subIndex];

          // ترقية الاحتياطي ليصبح أساسياً مع الاحتفاظ بدوره السابق لو لزم (مثل الكابتن)
          modifiedStarters[i] = substitute.copyWith(
            isStartingXI: true,
            // لو كان الأساسي هو الكابتن والبديل أصبح مكانه، يمكن تطبيق منطق نقل الكابتنة
            // لكن عادة الكابتن ينتقل لـ Vice Captain وليس لأول بديل مباشر
            benchPriority: 0, 
          );

          // تحويل الأساسي الغائب إلى مقاعد البدلاء في موضع الاحتياطي
          modifiedBench[subIndex] = starter.copyWith(
            isStartingXI: false,
            benchPriority: substitute.benchPriority,
          );
        }
      }
    }

    // 6. إرجاع القائمة النهائية المدمجة
    return [...modifiedStarters, ...modifiedBench];
  }
}
