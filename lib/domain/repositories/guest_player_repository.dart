import '../entities/guest_player.dart';

abstract class GuestPlayerRepository {
  Future<GuestPlayer?> getGuestPlayer(String guestPlayerId);
  Future<List<GuestPlayer>> getGuestPlayersByIds(List<String> guestPlayerIds);
  Future<void> createGuestPlayer(GuestPlayer guestPlayer);
  Future<void> updateGuestPlayer(GuestPlayer guestPlayer);
  Future<List<GuestPlayer>> getTeamGuestPlayers(String teamId);
  Future<List<GuestPlayer>> getTournamentGuestPlayers(String tournamentId);
  Future<void> archiveGuestPlayer(String guestPlayerId);
}
