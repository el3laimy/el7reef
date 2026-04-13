import '../../core/enums/friendship_status.dart';
import 'friendship.dart';

/// كيان طلب الصداقة (يُستخدم غالباً كـ DTO أو للواجهة)
class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final FriendshipStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  /// إنشاء من Friendship entity
  factory FriendRequest.fromFriendship(Friendship friendship, String myId) {
    // لمعرفة من المرسل ومن المستقبل
    final isSender = friendship.lastActionBy == myId;
    final otherId = friendship.userId1 == myId ? friendship.userId2 : friendship.userId1;
    
    return FriendRequest(
      id: friendship.id,
      senderId: isSender ? myId : otherId,
      receiverId: isSender ? otherId : myId,
      status: friendship.status,
      createdAt: friendship.createdAt,
    );
  }
}
