import '../entities/fantasy_league_lifecycle.dart';

/// Persistence contract for fantasy league lifecycle state.
abstract class FantasyLifecycleRepository {
  Future<FantasyLeagueLifecycle?> getLeagueLifecycle(String leagueId);

  Future<void> saveLeagueLifecycle(FantasyLeagueLifecycle lifecycle);
}
