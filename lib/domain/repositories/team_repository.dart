import '../entities/team.dart';

/// عقد مستودع الفريق
abstract class TeamRepository {
  Future<Team?> getTeam(String teamId);
  Future<List<Team>> getTeamsByIds(List<String> teamIds);
  Future<void> createTeam(Team team);
  Future<void> updateTeam(Team team);
  Future<List<Team>> getPlayerTeams(String playerId);
  Future<void> addPlayerToTeam(String teamId, String playerId);
  Future<void> removePlayerFromTeam(String teamId, String playerId);
  Future<List<Team>> searchTeams(String query);

  /// Role Management
  Future<void> leaveTeam(String teamId, String playerId);
  Future<void> transferOwnership(
    String teamId,
    String currentOwnerId,
    String newOwnerId,
  );
  Future<void> promoteToViceCaptain(
    String teamId,
    String ownerId,
    String targetId,
  );
  Future<void> kickPlayer(String teamId, String actionUserId, String targetId);
}
