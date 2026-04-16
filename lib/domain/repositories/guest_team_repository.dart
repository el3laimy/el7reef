import '../entities/guest_team.dart';

abstract class GuestTeamRepository {
  Future<GuestTeam?> getGuestTeam(String guestTeamId);
  Future<void> createGuestTeam(GuestTeam guestTeam);
  Future<void> updateGuestTeam(GuestTeam guestTeam);
  Future<List<GuestTeam>> getTournamentGuestTeams(String tournamentId);
  Future<void> archiveGuestTeam(String guestTeamId);
}
