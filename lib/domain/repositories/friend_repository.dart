import '../entities/friendship.dart';

/// واجهة مستودع الأصدقاء
abstract class FriendRepository {
  /// جلب حالة الصداقة بين مستخدمين (لو وجدت)
  Future<Friendship?> getFriendship(String userId1, String userId2);

  /// إرسال طلب صداقة
  Future<void> sendFriendRequest(String senderId, String receiverId);

  /// قبول طلب صداقة
  Future<void> acceptFriendRequest(String idA, String idB, String actionUserId);

  /// رفض أو إلغاء أو حذف طلب صداقة
  Future<void> removeFriendship(String idA, String idB);

  /// حظر مستخدم عبر العملية الخادمية الموثوقة
  Future<void> blockUser(String blockedId);

  /// فك الحظر
  Future<void> unblockUser(String blockedId);

  /// متابعة مستخدم (لا يحتاج موافقة - يحفظ في قائمة المُتَابَعين)
  /// المتابعة أحادية الاتجاه ولا تحفظ في نفس الموديل كصداقة معتمدة لتجنب التعقيد،
  /// ولكن يمكن تخزينها في مصفوفة sub-collection أو مصفوفة في Profile
  Future<void> followUser(String followerId, String followedId);
  Future<void> unfollowUser(String followerId, String followedId);

  /// جلب قائمة أصدقاء المستخدم
  Future<List<Friendship>> getFriends(String userId);

  /// جلب طلبات الصداقة الواردة
  Future<List<Friendship>> getPendingRequests(String userId);
}
