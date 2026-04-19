import '../entities/guest_team.dart';

abstract class GuestTeamRepository {
  Future<GuestTeam?> getGuestTeam(String guestTeamId);
  Future<List<GuestTeam>> getGuestTeamsByIds(List<String> guestTeamIds);
  Future<void> createGuestTeam(GuestTeam guestTeam);
  Future<void> updateGuestTeam(GuestTeam guestTeam);
  Future<List<GuestTeam>> getTournamentGuestTeams(String tournamentId);
  Future<List<GuestTeam>> searchGuestTeams(String query);
  Future<void> archiveGuestTeam(String guestTeamId);
}
