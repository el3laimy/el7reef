import '../../../domain/entities/fantasy_team.dart';
import '../../../domain/entities/fantasy_slot.dart';

/// خدمة التبديلات الاضطرارية للمدربين
/// يتم المناداة عليها عادة عندما يتم إقصاء (Elimination) فريق في مراحل خروج المغلوب.
class EmergencyTransferService {
  
  /// يقوم هذا المحرك بتحديث الخانات للفرق المتضررة ومنحهم تبديلات مجانية لتعويضهم
  ///
  /// [eliminatedPlayerIds]: معرفات جميع اللاعبين الذين ينتمون للفريق المُقصى.
  /// [allFantasyTeams]: جميع فرق الفانتازي النشطة في السيرفر.
  /// [allSlots]: الخانات المربوطة بتلك الفرق.
  ///
  /// يعود بخريطة تحتوي على الفرق المحدثة والخانات المحدثة تمهيداً لحفظها مجمعاً.
  static Map<String, dynamic> processEliminationGrants({
    required Set<String> eliminatedPlayerIds,
    required List<FantasyTeam> allFantasyTeams,
    required List<FantasySlot> allSlots,
  }) {
    List<FantasyTeam> updatedTeams = [];
    List<FantasySlot> updatedSlots = [];

    // تحويل الفرق لخريطة لتسهيل الوصول والتحديث
    Map<String, FantasyTeam> teamMap = {for (var t in allFantasyTeams) t.id: t};
    // تتبع كم لاعب مُقصى يمتلكه كل فريق بناءً على المعرف
    Map<String, int> teamGrantCounts = {};

    for (var slot in allSlots) {
      if (eliminatedPlayerIds.contains(slot.playerId)) {
        // 1. تحديث حالة اللاعب ليكون مقصى (ليظهر كبطاقة حمراء/رمادية في واجهة المستخدم)
        updatedSlots.add(slot.copyWith(isEliminated: true));

        // 2. تتبع حجم الضرر الذي لحق بصاحب هذا الفريق من الإقصاء
        teamGrantCounts[slot.fantasyTeamId] = (teamGrantCounts[slot.fantasyTeamId] ?? 0) + 1;
      }
    }

    // 3. تحديث أرصدة الكروم (التبديلات المجانية) للمدربين المتضررين فقط
    teamGrantCounts.forEach((teamId, eliminationsCount) {
      final team = teamMap[teamId];
      if (team != null) {
        // يتم منح تبديل مجاني لكل لاعب يتم إقصاؤه من التشكيلة (كأسلوب عادل كلياً لدوري الكؤوس)
        updatedTeams.add(
          team.copyWith(freeTransfers: team.freeTransfers + eliminationsCount)
        );
      }
    });

    return {
      'teams': updatedTeams,
      'slots': updatedSlots,
    };
  }
}
