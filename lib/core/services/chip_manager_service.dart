import '../../domain/entities/fantasy_team.dart';
import '../../domain/entities/fantasy_chip.dart';

/// خدمة إدارة الخواص (Chips Manager) لفرض قوانين قياسية وصارمة على نظام الدعم الفني
class ChipManagerService {
  
  /// محاولة تفعيل خاصية (Chip) جديدة وإرجاع نسخة محدثة من الفريق
  ///
  /// يرمي `Exception` في حال:
  /// - وجود خاصية أخرى مفعلة في نفس الجولة.
  /// - إذا تم استخدام هذه الخاصية مسبقاً طوال عمر البطولة (عدا الاضطراري).
  static FantasyTeam activateChip({
    required FantasyTeam currentTeam,
    required ChipType targetChip,
    required List<ChipUsage> historicalUsages,
    required int currentGameweek,
  }) {
    // 1. يمنع تفعيل أكثر من خاصية واحدة في ذات الجولة
    if (currentTeam.activeChips.isNotEmpty) {
      throw Exception('عذراً، نظام الفانتازي يمنع تفعيل أكثر من خاصية داعمة واحدة في الجولة نفسها.');
    }

    // 2. التحقق التاريخي (تُستخدم مرة واحدة فقط عدا الاستثناءات المبرمجة كطوارئ)
    if (targetChip != ChipType.emergencySub) {
      final bool hasBeenConsumed = historicalUsages.any((usage) => usage.chipType == targetChip);
      
      if (hasBeenConsumed) {
        throw Exception('لقد قمت باستهلاك خاصية (${targetChip.displayName}) مسبقاً! الخاصية تُفعل مرة واحدة فقط.');
      }
    }

    // 3. تفعيل الخاصية بدمجها ضمن الخواص النشطة الحالية (والتي كانت فارغة مؤكداً)
    // نعتمد displayName ليقرأه محرك النقاط والميركاتو كـ String
    final List<String> newActiveChips = List.from(currentTeam.activeChips)
      ..add(targetChip.displayName);

    return currentTeam.copyWith(
      activeChips: newActiveChips,
    );
  }

  /// أداة للتحقق السريع في واجهة المستخدم إذا كانت الخاصية استُهلكت ليتم تعطيل الزر (Greyed Out)
  static bool isChipExhausted(ChipType chip, List<ChipUsage> historicalUsages) {
    if (chip == ChipType.emergencySub) return false; // التبديل الاضطراري لا يشيخ
    return historicalUsages.any((u) => u.chipType == chip);
  }
}
