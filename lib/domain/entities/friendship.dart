import '../../core/enums/friendship_status.dart';

/// كيان تفاعل الصداقة بين لاعبين
class Friendship {
  final String id;
  final String userId1; // 항상 أقل ترتيباً أبجدياً لضمان عدم التكرار
  final String userId2;
  final FriendshipStatus status;
  final String lastActionBy; // من قام بآخر إجراء (إرسال، حجب، قبول)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Friendship({
    required this.id,
    required this.userId1,
    required this.userId2,
    required this.status,
    required this.lastActionBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// جلب معرّف الطرف الآخر
  String getOtherUserId(String myId) {
    return userId1 == myId ? userId2 : userId1;
  }

  Friendship copyWith({
    String? id,
    String? userId1,
    String? userId2,
    FriendshipStatus? status,
    String? lastActionBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      status: status ?? this.status,
      lastActionBy: lastActionBy ?? this.lastActionBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
