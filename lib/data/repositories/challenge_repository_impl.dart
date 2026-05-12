import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/challenge_status.dart';
import '../../core/errors/firebase_error_handler.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../models/challenge_model.dart';
import '../models/match_model.dart';

class ChallengeRepositoryImpl implements ChallengeRepository {
  final FirebaseFirestore _firestore;

  ChallengeRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _challengesRef =>
      _firestore.collection(FirebasePaths.challenges);
  CollectionReference get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);

  @override
  Future<void> createChallenge(Challenge challenge) async {
    return FirebaseErrorHandler.guard(() async {
      final model = ChallengeModel(
        id: challenge.id,
        challengerId: challenge.challengerId,
        challengedId: challenge.challengedId,
        challengerTeamId: challenge.challengerTeamId,
        challengedTeamId: challenge.challengedTeamId,
        matchId: challenge.matchId,
        status: challenge.status,
        message: challenge.message,
        location: challenge.location,
        teamSize: challenge.teamSize,
        createdAt: challenge.createdAt,
        respondedAt: challenge.respondedAt,
        expiresAt: challenge.expiresAt,
      );
      await _challengesRef.doc(challenge.id).set(model.toJson());
    });
  }

  @override
  Future<void> updateChallengeStatus(
    String id,
    ChallengeStatus status, {
    String? matchId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final Map<String, dynamic> data = {
        'status': status.name,
        'respondedAt': FieldValue.serverTimestamp(),
      };
      if (matchId != null) {
        data['matchId'] = matchId;
      }
      await _challengesRef.doc(id).update(data);
    });
  }

  @override
  Future<Challenge?> getChallenge(String id) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _challengesRef.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return ChallengeModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    });
  }

  @override
  Future<List<Challenge>> getSentChallenges(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _challengesRef
          .where('challengerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => ChallengeModel.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<Challenge>> getReceivedChallenges(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _challengesRef
          .where('challengedId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => ChallengeModel.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }

  @override
  Future<void> cancelChallenge(String id) async {
    await updateChallengeStatus(id, ChallengeStatus.cancelled);
  }

  @override
  Future<void> acceptChallengeWithMatch(Match match) async {
    return FirebaseErrorHandler.guard(() async {
      final challengeId = match.id;
      final matchData = MatchModel.fromEntity(match).toJson();
      await _firestore.runTransaction((transaction) async {
        final challengeSnapshot =
            await transaction.get(_challengesRef.doc(challengeId));
        if (!challengeSnapshot.exists) {
          throw Exception('التحدي غير موجود');
        }
        transaction.update(_challengesRef.doc(challengeId), {
          'status': ChallengeStatus.accepted.name,
          'matchId': challengeId,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_matchesRef.doc(challengeId), matchData);
      });
    });
  }
}
