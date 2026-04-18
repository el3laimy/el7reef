/// حالة النزاع
enum DisputeStatus {
  /// مفتوح — في انتظار المراجعة
  open,

  /// قيد المراجعة — المنظم يراجع الأدلة
  underReview,

  /// تم الحل — النزاع حُل لصالح أحد الأطراف
  resolved,

  /// مرفوض — النزاع غير مقبول
  rejected,

  /// منتهي الصلاحية — تجاوز المهلة بدون حل
  expired,
}

/// نوع النزاع
enum DisputeType {
  /// نزاع على نتيجة المباراة
  scoreDispute,

  /// نزاع على تشكيلة المباراة
  lineupDispute,

  /// نزاع على اختيار MVP
  mvpDispute,

  /// نزاع على تقييم لاعب
  ratingDispute,

  /// نزاع عام
  general,
}
