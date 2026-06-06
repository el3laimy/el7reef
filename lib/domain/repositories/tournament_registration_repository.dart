import '../entities/tournament_registration.dart';

abstract class TournamentRegistrationRepository {
  Future<TournamentRegistration?> getRegistration(String registrationId);
  Future<void> createRegistration(TournamentRegistration registration);
  Future<void> updateRegistration(TournamentRegistration registration);
  Future<List<TournamentRegistration>> getTournamentRegistrations(
    String tournamentId,
  );
  Future<List<TournamentRegistration>> getApprovedTournamentRegistrations(
    String tournamentId,
  );
  Future<List<TournamentRegistration>> getTournamentRegistrationsForTeamIds({
    required String tournamentId,
    required List<String> teamIds,
  });
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
