import '../entities/tournament_registration.dart';

abstract class TournamentRegistrationRepository {
  Future<TournamentRegistration?> getRegistration(String registrationId);
  Future<void> createRegistration(TournamentRegistration registration);
  Future<void> updateRegistration(TournamentRegistration registration);
  Future<List<TournamentRegistration>> getTournamentRegistrations(
    String tournamentId,
  );
  Future<TournamentRegistration?> getRegistrationByTeamId({
    required String tournamentId,
    required String teamId,
  });
  Future<TournamentRegistration?> getRegistrationByGuestTeamId({
    required String tournamentId,
    required String guestTeamId,
  });
  Future<List<TournamentRegistration>> getRegistrationsByTeamId(String teamId);
  Future<List<TournamentRegistration>> getRegistrationsByGuestTeamId(
    String guestTeamId,
  );
}
