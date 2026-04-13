/// نوع / شكل الدورة
enum TournamentFormat {
  /// مجموعات فقط (Round Robin) — يفوز صاحب أعلى نقاط
  groupsOnly,

  /// تصفيات مباشرة (خروج المغلوب) من الجولة الأولى
  knockoutOnly,

  /// مجموعات ثم تصفيات — النظام الأكثر شيوعاً
  groupsThenKnockout,
}

/// حالة الدورة (State Machine)
enum TournamentStatus {
  /// قبل فتح التسجيل
  upcoming,

  /// التسجيل مفتوح — الفرق تنضم
  registration,

  /// مرحلة المجموعات جارية
  groupStage,

  /// نافذة التغيير الحرة (بين المجموعات والإقصاء)
  transferWindow,

  /// مرحلة الإقصاء جارية
  knockoutStage,

  /// الدورة انتهت — النتائج نهائية
  completed,

  /// ملغاة من المنظم
  cancelled,
}

/// مرحلة المباراة — تؤثر على حساب نقاط الفانتازي
enum MatchPhase {
  /// مباراة في مرحلة المجموعات (لا Survival Bonus)
  groupStage,

  /// مباراة في مرحلة الإقصاء (+8 Survival Bonus لكل دور يتخطاه الفريق)
  knockout,
}

/// حجم فريق الدورة — يحدد حجم التشكيلة الفانتازية ديناميكياً
enum TournamentTeamSize {
  fiveVsFive(5),
  sixVsSix(6),
  sevenVsSeven(7),
  eightVsEight(8),
  elevenVsEleven(11);

  final int value;
  const TournamentTeamSize(this.value);

  /// عدد الأساسيين في تشكيلة الفانتازي
  int get fantasyStartingCount => value;

  /// عدد الاحتياطيين: max(2, round(size × 0.4))
  int get fantasyBenchCount {
    final raw = (value * 0.4).round();
    return raw < 2 ? 2 : raw;
  }

  /// إجمالي التشكيلة = أساسيين + احتياطيين
  int get totalSquadSize => fantasyStartingCount + fantasyBenchCount;

  /// من رقم عددي
  static TournamentTeamSize fromInt(int n) {
    return TournamentTeamSize.values.firstWhere(
      (e) => e.value == n,
      orElse: () => TournamentTeamSize.fiveVsFive,
    );
  }
}

/// نتيجة الإقصاء — يُحدد الفائز في حالة التعادل
enum KnockoutResult {
  teamAWins,
  teamBWins,
  /// تعادل ذهب للركلات → الفائز يأخذ Win Bonus كالفوز العادي
  penaltyShootoutA,
  penaltyShootoutB,
}

/// دور مساعد الدورة (Admin Roles)
enum TournamentAssistantRole {
  /// مساعد كامل الصلاحيات
  full,
  
  /// إدخال نتائج المباريات فقط
  resultsOnly,
  
  /// مراقب فقط (قراءة وإشراف دون تعديل)
  observer,
  
  /// بديل طارئ — يتولى القيادة مؤقتاً لمدة 72 ساعة في حال غياب المنظم
  emergency,
}
