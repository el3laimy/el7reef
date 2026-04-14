import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/enums/friendship_status.dart';
import '../../domain/entities/friendship.dart';

/// نموذج بيانات الصداقة (يتعامل مع Firestore)
class FriendshipModel extends Friendship {
  const FriendshipModel({
    required super.id,
    required super.userId1,
    required super.userId2,
    required super.status,
    required super.lastActionBy,
    required super.createdAt,
    required super.updatedAt,
  });

  /// إنشاء من خريطة بيانات (Firestore Mappings)
  factory FriendshipModel.fromJson(Map<String, dynamic> json, String id) {
    return FriendshipModel(
      id: id,
      userId1: json['userId1'] as String,
      userId2: json['userId2'] as String,
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => FriendshipStatus.pending,
      ),
      lastActionBy: json['lastActionBy'] as String,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// تحويل لبيانات Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'status': status.name,
      'lastActionBy': lastActionBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      // حقل إضافي لتسهيل الاستعلامات المعقدة لو احتجنا
      'participants': [userId1, userId2], 
    };
  }

  /// تحويل Entity إلى Model
  factory FriendshipModel.fromEntity(Friendship entity) {
    return FriendshipModel(
      id: entity.id,
      userId1: entity.userId1,
      userId2: entity.userId2,
      status: entity.status,
      lastActionBy: entity.lastActionBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// توليد ID فريد يعتمد على الترتيب الأبجدي للمستخدمين
  static String generateId(String idA, String idB) {
    final ids = [idA, idB]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
