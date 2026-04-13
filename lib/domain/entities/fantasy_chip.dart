/// أنواع الخواص والدعم (Chips) التي يمكن لمدرب الفانتازي استغلالها خلال البطولة
enum ChipType {
  /// الكابتن الثلاثي: تُضرب نقاط الكابتن في هذه الجولة ×3 بدلاً من الشائع ×2
  tripleCaptain,

  /// تغيير شامل ومجاني للتشكيلة خلال مرحلة دور المجموعات
  wildcardGroups,

  /// تغيير شامل ومجاني للتشكيلة بعد التأهل للأدوار الإقصائية
  wildcardKnockout,

  /// تفعيل الدكة: يتم احتساب نقاط اللاعبين الأساسيين والاحتياط معاً في هذه الجولة
  benchBoost,

  /// التبديل الاضطراري: كارت يُدار تلقائياً أو يدوياً لتغطية غيابات قهرية
  emergencySub;

  /// اسم الخاصية كما يظهر للمستخدم في الواجهة
  String get displayName {
    switch (this) {
      case ChipType.tripleCaptain:
        return 'Triple Captain';
      case ChipType.wildcardGroups:
        return 'Wildcard (Groups)';
      case ChipType.wildcardKnockout:
        return 'Wildcard (Knockout)';
      case ChipType.benchBoost:
        return 'Bench Boost';
      case ChipType.emergencySub:
        return 'Emergency Sub';
    }
  }
}

/// سجل استخدام الخاصية لضمان عدم استعمالها أكثر من مرة للفريق الواحد
class ChipUsage {
  /// المعرف الفريد للفريق الذي استهلك هذه الخاصية
  final String fantasyTeamId;

  /// نوع الخاصية التي تم استهلاكها
  final ChipType chipType;

  /// رقم الجولة (Gameweek) التي تم تفعيل الخاصية خلالها
  final int usedInGameweek;

  /// تاريخ ووقت تفعيل الخاصية للتدقيق والمزامنة
  final DateTime usedAt;

  const ChipUsage({
    required this.fantasyTeamId,
    required this.chipType,
    required this.usedInGameweek,
    required this.usedAt,
  });

  ChipUsage copyWith({
    String? fantasyTeamId,
    ChipType? chipType,
    int? usedInGameweek,
    DateTime? usedAt,
  }) {
    return ChipUsage(
      fantasyTeamId: fantasyTeamId ?? this.fantasyTeamId,
      chipType: chipType ?? this.chipType,
      usedInGameweek: usedInGameweek ?? this.usedInGameweek,
      usedAt: usedAt ?? this.usedAt,
    );
  }
}
