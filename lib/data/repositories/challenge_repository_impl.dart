import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../../core/enums/challenge_status.dart';
import '../models/challenge_model.dart';

class ChallengeRepositoryImpl implements ChallengeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _challengesRef =>
      _firestore.collection(FirebasePaths.challenges);

  @override
  Future<void> createChallenge(Challenge challenge) async {
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
  }

  @override
  Future<void> updateChallengeStatus(String id, ChallengeStatus status, {String? matchId}) async {
    final Map<String, dynamic> data = {
      'status': status.name,
      'respondedAt': FieldValue.serverTimestamp(),
    };
    if (matchId != null) {
      data['matchId'] = matchId;
    }
    await _challengesRef.doc(id).update(data);
  }

  @override
  Future<Challenge?> getChallenge(String id) async {
    final doc = await _challengesRef.doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ChallengeModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  @override
  Future<List<Challenge>> getSentChallenges(String userId) async {
    final snapshot = await _challengesRef
        .where('challengerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<List<Challenge>> getReceivedChallenges(String userId) async {
    final snapshot = await _challengesRef
        .where('challengedId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<void> cancelChallenge(String id) async {
    await updateChallengeStatus(id, ChallengeStatus.cancelled);
  }
}
