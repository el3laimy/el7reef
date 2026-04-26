import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firebase_paths.dart';
import '../enums/match_status.dart';
import '../../data/models/match_model.dart';
import '../../domain/entities/match.dart';

class MatchCancellationService {
  final FirebaseFirestore _firestore;

  MatchCancellationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);

  Future<Match> cancelFriendlyMatch({
    required String matchId,
    required String actorId,
    String? reason,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final trimmedActorId = actorId.trim();
    final trimmedReason = reason?.trim();
    if (trimmedActorId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    return _firestore.runTransaction<Match>((transaction) async {
      final matchRef = _matchesRef.doc(matchId);
      final snapshot = await transaction.get(matchRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('المباراة المطلوبة غير موجودة.');
      }

      final match = MatchModel.fromJson(
        snapshot.data()!,
        snapshot.id,
      ).toEntity();
      _validateCancelable(match: match, actorId: trimmedActorId);

      final cancelled = match.copyWith(
        status: MatchStatus.cancelled,
        cancelledAt: effectiveNow,
        cancelledBy: trimmedActorId,
        cancelReason: trimmedReason == null || trimmedReason.isEmpty
            ? null
            : trimmedReason,
      );
      transaction.update(matchRef, {
        'status': MatchStatus.cancelled.name,
        'cancelledAt': effectiveNow.millisecondsSinceEpoch,
        'cancelledBy': trimmedActorId,
        'cancelReason': cancelled.cancelReason,
      });
      return cancelled;
    });
  }

  void _validateCancelable({required Match match, required String actorId}) {
    if (match.tournamentId != null && match.tournamentId!.trim().isNotEmpty) {
      throw Exception('لا يمكن إلغاء مباريات البطولة من هذا المسار.');
    }
    if (match.organizerId != actorId) {
      throw Exception('فقط منظم المباراة يمكنه إلغاء هذه المباراة.');
    }
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception('المباراة مجمّدة ولا يمكن إلغاؤها.');
    }
    if (match.status == MatchStatus.cancelled) {
      throw Exception('تم إلغاء هذه المباراة بالفعل.');
    }
    if (match.status != MatchStatus.open && match.status != MatchStatus.full) {
      throw Exception('لا يمكن إلغاء المباراة بعد انطلاقها.');
    }
    if (match.scoreTeamA != null || match.scoreTeamB != null) {
      throw Exception('لا يمكن إلغاء مباراة لديها نتيجة مسجلة.');
    }
  }
}
