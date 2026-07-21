import '../entities/guest_player.dart';

abstract class GuestPlayerRepository {
  Future<GuestPlayer?> getGuestPlayer(String guestPlayerId);
  Future<List<GuestPlayer>> getGuestPlayersByIds(List<String> guestPlayerIds);
  Future<List<GuestPlayer>> getGuestPlayersLinkedToPlayer(String playerId);
  Future<void> createGuestPlayer(GuestPlayer guestPlayer);
  Future<void> updateGuestPlayer(GuestPlayer guestPlayer);
  Future<List<GuestPlayer>> getTeamGuestPlayers(String teamId);
  Future<List<GuestPlayer>> getGuestTeamPlayers(String guestTeamId);
  Future<List<GuestPlayer>> getPublicTournamentGuestTeamPlayers({
    required String tournamentId,
    required String guestTeamId,
  });
  Future<List<GuestPlayer>> getTournamentGuestPlayers(String tournamentId);
  Future<void> archiveGuestPlayer(String guestPlayerId);
}
