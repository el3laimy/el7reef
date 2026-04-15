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

  /// مفتاح تخزين ثابت وآمن داخل Firestore والاختبارات.
  String get storageKey {
    switch (this) {
      case ChipType.tripleCaptain:
        return 'triple_captain';
      case ChipType.wildcardGroups:
        return 'wildcard_groups';
      case ChipType.wildcardKnockout:
        return 'wildcard_knockout';
      case ChipType.benchBoost:
        return 'bench_boost';
      case ChipType.emergencySub:
        return 'emergency_sub';
    }
  }

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

  bool get removesTransferHits =>
      this == ChipType.wildcardGroups || this == ChipType.wildcardKnockout;

  static ChipType? fromValue(String value) {
    final normalized = value.trim().toLowerCase();

    for (final chip in ChipType.values) {
      if (chip.storageKey == normalized ||
          chip.displayName.toLowerCase() == normalized) {
        return chip;
      }
    }

    switch (normalized) {
      case 'wildcard':
        return ChipType.wildcardGroups;
      default:
        return null;
    }
  }
}

/// سجل استخدام الخاصية لضمان عدم استعمالها أكثر من مرة للفريق الواحد
class ChipUsage {
  /// نوع الخاصية التي تم استهلاكها
  final ChipType chipType;

  /// رقم الجولة (Gameweek) التي تم تفعيل الخاصية خلالها
  final int gameweek;

  /// تاريخ ووقت تفعيل الخاصية للتدقيق والمزامنة
  final DateTime activatedAt;

  /// متى انتهى أثر الخاصية أو تم استهلاكها نهائياً.
  final DateTime? consumedAt;

  const ChipUsage({
    required this.chipType,
    required this.gameweek,
    required this.activatedAt,
    this.consumedAt,
  });

  bool get isConsumed => consumedAt != null;

  bool isActiveInGameweek(int currentGameweek) =>
      !isConsumed && gameweek == currentGameweek;

  String get displayName => chipType.displayName;

  Map<String, dynamic> toJson() {
    return {
      'chipType': chipType.storageKey,
      'gameweek': gameweek,
      'activatedAt': activatedAt.millisecondsSinceEpoch,
      if (consumedAt != null)
        'consumedAt': consumedAt!.millisecondsSinceEpoch,
    };
  }

  factory ChipUsage.fromJson(Map<String, dynamic> json) {
    final rawChipType = json['chipType'] as String? ?? '';
    final chipType = ChipType.fromValue(rawChipType) ?? ChipType.tripleCaptain;
    final activatedAtMs =
        (json['activatedAt'] ?? json['usedAt']) as int?;
    final consumedAtMs = json['consumedAt'] as int?;

    return ChipUsage(
      chipType: chipType,
      gameweek: (json['gameweek'] ?? json['usedInGameweek']) as int? ?? 0,
      activatedAt: activatedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(activatedAtMs)
          : DateTime.now(),
      consumedAt: consumedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(consumedAtMs)
          : null,
    );
  }

  factory ChipUsage.fromLegacyLabel(
    String label, {
    required DateTime activatedAt,
  }) {
    final chipType = ChipType.fromValue(label);
    if (chipType == null) {
      throw FormatException('Unsupported chip label: $label');
    }

    return ChipUsage(
      chipType: chipType,
      gameweek: 0,
      activatedAt: activatedAt,
    );
  }

  ChipUsage copyWith({
    ChipType? chipType,
    int? gameweek,
    DateTime? activatedAt,
    DateTime? consumedAt,
    bool clearConsumedAt = false,
  }) {
    return ChipUsage(
      chipType: chipType ?? this.chipType,
      gameweek: gameweek ?? this.gameweek,
      activatedAt: activatedAt ?? this.activatedAt,
      consumedAt: clearConsumedAt ? null : consumedAt ?? this.consumedAt,
    );
  }
}
