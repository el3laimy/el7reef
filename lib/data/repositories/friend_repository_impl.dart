import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../core/enums/friendship_status.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/repositories/friend_repository.dart';
import '../models/friendship_model.dart';

class FriendRepositoryImpl implements FriendRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _friendshipsRef => _firestore.collection(FirebasePaths.friendships);
  CollectionReference get _playersRef => _firestore.collection(FirebasePaths.players);

  @override
  Future<Friendship?> getFriendship(String userId1, String userId2) async {
    final docId = FriendshipModel.generateId(userId1, userId2);
    final doc = await _friendshipsRef.doc(docId).get();

    if (doc.exists) {
      return FriendshipModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  @override
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    final docId = FriendshipModel.generateId(senderId, receiverId);
    
    final friendship = FriendshipModel(
      id: docId,
      userId1: senderId.compareTo(receiverId) < 0 ? senderId : receiverId,
      userId2: senderId.compareTo(receiverId) < 0 ? receiverId : senderId,
      status: FriendshipStatus.pending,
      lastActionBy: senderId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _friendshipsRef.doc(docId).set(friendship.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> acceptFriendRequest(String idA, String idB, String actionUserId) async {
    final docId = FriendshipModel.generateId(idA, idB);
    
    // Batch update لضمان تناسق البيانات
    final batch = _firestore.batch();
    
    // 1. تحديث الصداقة
    batch.update(_friendshipsRef.doc(docId), {
      'status': FriendshipStatus.accepted.name,
      'lastActionBy': actionUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. تحديث قائمة الأصدقاء للاعبين
    batch.update(_playersRef.doc(idA), {
      'friendIds': FieldValue.arrayUnion([idB])
    });
    batch.update(_playersRef.doc(idB), {
      'friendIds': FieldValue.arrayUnion([idA])
    });

    await batch.commit();
  }

  @override
  Future<void> removeFriendship(String idA, String idB) async {
    final docId = FriendshipModel.generateId(idA, idB);
    
    final batch = _firestore.batch();
    
    batch.delete(_friendshipsRef.doc(docId));
    
    batch.update(_playersRef.doc(idA), {
      'friendIds': FieldValue.arrayRemove([idB])
    });
    batch.update(_playersRef.doc(idB), {
      'friendIds': FieldValue.arrayRemove([idA])
    });

    await batch.commit();
  }

  @override
  Future<void> blockUser(String blockerId, String blockedId) async {
    final docId = FriendshipModel.generateId(blockerId, blockedId);
    
    final batch = _firestore.batch();

    // 1. تحديث أو إنشاء وثيقة Friendship كـ blocked
    final friendship = FriendshipModel(
      id: docId,
      userId1: blockerId.compareTo(blockedId) < 0 ? blockerId : blockedId,
      userId2: blockerId.compareTo(blockedId) < 0 ? blockedId : blockerId,
      status: FriendshipStatus.blocked,
      lastActionBy: blockerId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    batch.set(_friendshipsRef.doc(docId), friendship.toJson());

    // 2. إزالة من قوائم الأصدقاء إن كانوا أصدقاء
    batch.update(_playersRef.doc(blockerId), {
      'friendIds': FieldValue.arrayRemove([blockedId]),
      'blockedIds': FieldValue.arrayUnion([blockedId])
    });
    batch.update(_playersRef.doc(blockedId), {
      'friendIds': FieldValue.arrayRemove([blockerId])
    });

    await batch.commit();
  }

  @override
  Future<void> unblockUser(String blockerId, String blockedId) async {
    final docId = FriendshipModel.generateId(blockerId, blockedId);
    
    final batch = _firestore.batch();
    batch.delete(_friendshipsRef.doc(docId));
    
    batch.update(_playersRef.doc(blockerId), {
      'blockedIds': FieldValue.arrayRemove([blockedId])
    });

    await batch.commit();
  }

  @override
  Future<void> followUser(String followerId, String followedId) async {
    await _playersRef.doc(followerId).update({
      'followingIds': FieldValue.arrayUnion([followedId])
    });
  }

  @override
  Future<void> unfollowUser(String followerId, String followedId) async {
    await _playersRef.doc(followerId).update({
      'followingIds': FieldValue.arrayRemove([followedId])
    });
  }

  @override
  Future<List<Friendship>> getFriends(String userId) async {
    // نجلب كل الصداقات التي يشارك فيها المستخدم وحالتها accepted
    final snapshot = await _friendshipsRef
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .get();

    return snapshot.docs
        .map((doc) => FriendshipModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<List<Friendship>> getPendingRequests(String userId) async {
    // طلبات معلقة موجهة إليّ: أشارك فيها، وحالتها pending، لكن الـ lastActionBy ليس أنا
    // لا يمكننا عمل != في Firestore مع where أخرى غالباً ، لذلك سنفلتر في الدارت
    final snapshot = await _friendshipsRef
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .get();

    return snapshot.docs
        .map((doc) => FriendshipModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
        .where((friendship) => friendship.lastActionBy != userId) // من قام بالفعل (الإرسال) ليس أنا
        .toList();
  }
}
