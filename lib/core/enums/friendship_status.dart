/// حالة الصداقة (Friendship Status)
enum FriendshipStatus {
  /// بانتظار الموافقة (يُستخدم كطلب صداقة)
  pending,
  
  /// تم القبول (صديقان)
  accepted,
  
  /// تم الرفض
  declined,
  
  /// محظور (محجوب)
  blocked,
  
  /// متابعة فقط (أحادي)
  following,
}
