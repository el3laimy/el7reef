import '../entities/match.dart';
import '../../core/enums/tournament_ops_enums.dart';

/// عقد مستودع المباراة
abstract class MatchRepository {
  Future<Match?> getMatch(String matchId);
  Future<void> createMatch(Match match);
  Future<void> upsertMatches(List<Match> matches);
  Future<void> updateMatch(Match match);
  Future<List<Match>> getPlayerMatches(String playerId, {int limit = 20});
  Future<List<Match>> getLiveMatches({
    double? lat,
    double? lng,
    double radiusKm = 5,
  });
  Future<List<Match>> getTournamentMatches({
    required String tournamentId,
    TournamentStageType? stageType,
    String? groupStageId,
    String? groupId,
    String? knockoutTieId,
  });
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
  Future<void> cancelMatch(String matchId);
  Future<void> addPlayerToMatch({
    required String matchId,
    required String playerId,
    required String side,
  });
  Future<void> removePlayerFromMatch({
    required String matchId,
    required String playerId,
    required String side,
  });
}
