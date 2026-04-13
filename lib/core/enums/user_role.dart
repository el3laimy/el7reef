/// نوع إجراء المنظم
enum OrganizerActionType {
  /// اعتماد نتيجة المباراة
  approveScore,

  /// تقييم ذهبي (ضعف التأثير)
  goldenRating,

  /// تجميد نقاط مباراة
  freezeMatch,

  /// رفض نتيجة المباراة
  rejectScore,
}

/// دور المستخدم في النظام
enum UserRole {
  /// لاعب عادي
  player,

  /// منظم (قاضي الملعب)
  organizer,

  /// مشرف النظام
  admin,
}
