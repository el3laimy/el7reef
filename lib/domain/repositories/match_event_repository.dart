import '../entities/match_event.dart';

abstract class MatchEventRepository {
  Future<void> createEvent(MatchEvent event);
  Future<List<MatchEvent>> getEventsByMatchId(String matchId);
  Future<List<MatchEvent>> getGoalEventsByTournamentId(String tournamentId);
  Future<MatchEvent?> getMvpEventByMatchId(String matchId);
  Future<void> voidEvent(String eventId);
}
