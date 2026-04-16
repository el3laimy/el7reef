import '../entities/team_membership.dart';

abstract class TeamMembershipRepository {
  Future<TeamMembership?> getMembership(String membershipId);
  Future<void> createMembership(TeamMembership membership);
  Future<void> updateMembership(TeamMembership membership);
  Future<List<TeamMembership>> getTeamMemberships(
    String teamId, {
    bool includeInactive = false,
  });
  Future<TeamMembership?> getMembershipByPlayerId({
    required String teamId,
    required String playerId,
  });
  Future<TeamMembership?> getMembershipByGuestPlayerId({
    required String teamId,
    required String guestPlayerId,
  });
}
