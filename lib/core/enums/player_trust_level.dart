/// مستوى ثقة اللاعب
enum PlayerTrustLevel {
  /// لاعب جديد (أقل من 5 مباريات) — Trust Weight = 0.5
  newPlayer,

  /// لاعب نشط (عادي) — Trust Weight = 1.0
  active,

  /// مخضرم (50+ مباراة، شهرين+، سجل نظيف) — Trust Weight = 1.2
  veteran,

  /// موقوف (غش) — Trust Weight = 0.0
  suspended,
}
