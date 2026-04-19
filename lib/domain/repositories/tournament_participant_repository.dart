import '../entities/tournament_participant.dart';

abstract class TournamentParticipantRepository {
  Future<TournamentParticipant?> getParticipant(String participantId);
  Future<void> createParticipant(TournamentParticipant participant);
  Future<void> updateParticipant(TournamentParticipant participant);
  Future<void> deleteParticipant(String participantId);
  Future<List<TournamentParticipant>> getTournamentParticipants(
    String tournamentId,
  );
  Future<TournamentParticipant?> getParticipantBySource({
    required String tournamentId,
    required String sourceEntityId,
  });
}
