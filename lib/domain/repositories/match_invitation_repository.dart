import '../entities/match_invitation.dart';

abstract class MatchInvitationRepository {
  Future<void> createInvitation(MatchInvitation invitation);
  Future<void> updateInvitationStatus(String id, InvitationStatus status);
  Future<MatchInvitation?> getInvitation(String id);
  Future<List<MatchInvitation>> getPendingInvitationsForUser(String userId);
  Future<List<MatchInvitation>> getInvitationsForMatch(String matchId);
  Future<void> cancelInvitation(String id);
}
