/// حالة المباراة
enum MatchStatus {
  open,           // مفتوحة للانضمام
  full,           // اكتملت الأماكن
  live,           // جارية
  completed,      // انتهت — بانتظار اعتماد النتيجة
  ratingWindow,   // نافذة التقييم مفتوحة (10 دقائق)
  settled,        // تمت التسوية
  pendingReview,  // قيد المراجعة (شذوذ)
  frozen,         // مجمدة من المنظم
}
