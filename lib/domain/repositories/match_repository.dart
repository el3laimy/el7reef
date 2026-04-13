import '../entities/match.dart';

/// عقد مستودع المباراة
abstract class MatchRepository {
  Future<Match?> getMatch(String matchId);
  Future<void> createMatch(Match match);
  Future<void> updateMatch(Match match);
  Future<List<Match>> getPlayerMatches(String playerId, {int limit = 20});
  Future<List<Match>> getLiveMatches({double? lat, double? lng, double radiusKm = 5});
  Future<void> submitScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    String? mvpPlayerId,
  });
  Future<void> approveScore(String matchId);
  Future<void> freezeMatch(String matchId);
  Future<void> unfreezeMatch(String matchId);
  Future<void> activateGoldenRating(String matchId);
}
