import '../entities/tournament.dart';

/// عقد مستودع الدورة
abstract class TournamentRepository {
  Future<Tournament?> getTournament(String tournamentId);
  Future<void> createTournament(Tournament tournament);
  Future<void> updateTournament(Tournament tournament);
  Future<List<Tournament>> getLiveTournaments({int limit = 20});
  Future<List<Tournament>> getOrganizerTournaments(String organizerId);
  Future<List<Tournament>> getPlayerTournaments(String teamId);
  Future<void> registerTeam(String tournamentId, String teamId);
  Future<void> unregisterTeam(String tournamentId, String teamId);
  Future<void> updateStatus(String tournamentId, String status);
  Future<void> addGroupRound(String tournamentId, String roundId);
  Future<void> addKnockoutRound(String tournamentId, String roundId);
}
