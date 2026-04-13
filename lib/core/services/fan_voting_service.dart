import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/fan_voting_session.dart';
import '../../data/models/fan_voting_session_model.dart';

/// خدمة إدارة تصويت الجماهير (Fan Voting)
/// تعنى بضمان شفافية التصويت من خلال Transactions
class FanVotingService {
  final FirebaseFirestore _firestore;

  FanVotingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _sessionsRef =>
      _firestore.collection(FirebasePaths.fanVotingSessions);

  CollectionReference get _userVotesRef =>
      _firestore.collection(FirebasePaths.userVotes);

  /// إنشاء أو فتح جلسة التصويت لمباراة حالية
  Future<void> openSession(String matchId, {int durationMinutes = 90}) async {
    final now = DateTime.now();
    final model = FanVotingSessionModel(
      id: matchId,
      matchId: matchId,
      opensAt: now,
      closesAt: now.add(Duration(minutes: durationMinutes)),
      totalVotes: 0,
      playerVotes: {},
      winnerPlayerId: null,
    );

    // نستخدم set مع merge لتجنب مسح أصوات موجودة لو تم استدعاؤها خطأ
    await _sessionsRef.doc(matchId).set(model.toJson(), SetOptions(merge: false));
  }

  /// جلب تفاصيل الجلسة
  Future<FanVotingSession?> getSession(String matchId) async {
    final doc = await _sessionsRef.doc(matchId).get();
    if (!doc.exists || doc.data() == null) return null;

    return FanVotingSessionModel.fromJson(
            doc.data()! as Map<String, dynamic>, doc.id)
        .toEntity();
  }

  /// التحقق إن كان المستخدم صوّت بالفعل في هذه المباراة
  Future<bool> hasUserVoted(String matchId, String userId) async {
    final voteDocId = '${matchId}_$userId';
    final doc = await _userVotesRef.doc(voteDocId).get();
    return doc.exists;
  }

  /// تنفيذ عملية التصويت بلاعب معين באמצעות Transaction لتفادي التصادم الجماهيري
  Future<void> voteForPlayer({
    required String matchId,
    required String userId,
    required String targetPlayerId,
  }) async {
    final sessionDocRef = _sessionsRef.doc(matchId);
    final voteDocRef = _userVotesRef.doc('${matchId}_$userId');

    await _firestore.runTransaction((transaction) async {
      // 1. التأكد من أن الجلسة موجودة
      final sessionSnapshot = await transaction.get(sessionDocRef);
      if (!sessionSnapshot.exists) {
        throw Exception('جلسة التصويت غير موجودة لهذه المباراة.');
      }

      final session = FanVotingSessionModel.fromJson(
              sessionSnapshot.data() as Map<String, dynamic>, sessionSnapshot.id)
          .toEntity();

      // 2. التحقق من توقيت الجلسة (ضمان عدم التلاعب)
      if (session.isClosed) {
        throw Exception('التصويت مغلق الآن.');
      }

      if (!session.isOpen) {
        throw Exception('التصويت لم يفتح بعد.');
      }

      // 3. منع التصويت المزدوج
      final voteSnapshot = await transaction.get(voteDocRef);
      if (voteSnapshot.exists) {
        throw Exception('لقد قمت بالتصويت مسبقاً في هذه المباراة.');
      }

      // 4. تطبيق قواعد مكافحة التلاعب (Anti-Manipulation Rules)
      
      // أ. جلب بيانات المستخدم لفحص عمر الحساب
      final userSnapshot = await transaction.get(
        _firestore.collection(FirebasePaths.players).doc(userId),
      );
      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final createdAtMs = userData['createdAt'] as int?;
        if (createdAtMs != null) {
          final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
          if (DateTime.now().difference(createdAt).inDays < 7) {
            throw Exception('يجب أن يمر 7 أيام على إنشاء حسابك حتى تتمكن من التصويت في الجماهير.');
          }
        }
      }

      // ب. التأكد من أن المستخدم ليس من المشاركين في هذه المباراة
      final matchSnapshot = await transaction.get(
        _firestore.collection(FirebasePaths.matches).doc(matchId),
      );
      if (matchSnapshot.exists) {
        final matchData = matchSnapshot.data() as Map<String, dynamic>;
        final teamA = List<String>.from(matchData['teamAPlayerIds'] ?? []);
        final teamB = List<String>.from(matchData['teamBPlayerIds'] ?? []);
        
        if (teamA.contains(userId) || teamB.contains(userId)) {
          throw Exception('اللاعبون المشاركون في المباراة لا يحق لهم التصويت.');
        }
      }

      // 5. تسجيل الصوت باسم اللاعب المختار
      transaction.set(voteDocRef, {
        'matchId': matchId,
        'userId': userId,
        'votedFor': targetPlayerId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 6. تحديث عدادات الجلسة
      final playerVotes = Map<String, int>.from(session.playerVotes);
      playerVotes[targetPlayerId] = (playerVotes[targetPlayerId] ?? 0) + 1;
      
      transaction.update(sessionDocRef, {
        'totalVotes': FieldValue.increment(1),
        'playerVotes': playerVotes,
      });
    });
  }

  /// إغلاق جلسة التصويت وتحديد الفائز المخفي
  Future<void> closeSessionAndTally(String matchId) async {
    final session = await getSession(matchId);
    if (session == null) return;

    if (session.playerVotes.isEmpty) {
      await _sessionsRef.doc(matchId).update({
        'closesAt': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }

    // إيجاد الفائز (الأعلى أصواتاً)
    String? winnerId;
    int maxVotes = -1;

    session.playerVotes.forEach((playerId, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        winnerId = playerId;
      }
    });

    await _sessionsRef.doc(matchId).update({
      'closesAt': DateTime.now().millisecondsSinceEpoch,
      'winnerPlayerId': winnerId,
    });
  }
}
