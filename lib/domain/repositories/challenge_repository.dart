import '../../domain/entities/challenge.dart';
import '../../core/enums/challenge_status.dart';

abstract class ChallengeRepository {
  Future<void> createChallenge(Challenge challenge);
  Future<void> updateChallengeStatus(String id, ChallengeStatus status, {String? matchId});
  Future<Challenge?> getChallenge(String id);
  Future<List<Challenge>> getSentChallenges(String userId);
  Future<List<Challenge>> getReceivedChallenges(String userId);
  Future<void> cancelChallenge(String id);
}
