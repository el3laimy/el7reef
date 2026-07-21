import '../../../app/routes/app_routes.dart';
import '../../../domain/entities/participant_ref.dart';

class TournamentDetailRoutes {
  const TournamentDetailRoutes._();

  static String participants(String tournamentId) =>
      AppRoutes.tournamentParticipantsById(tournamentId);

  static String groups(String tournamentId) =>
      AppRoutes.tournamentGroupsById(tournamentId);

  static String fixtures(String tournamentId) =>
      AppRoutes.tournamentFixturesById(tournamentId);

  static String standings(String tournamentId) =>
      AppRoutes.tournamentStandingsById(tournamentId);

  static String bracket(String tournamentId) =>
      AppRoutes.tournamentBracketById(tournamentId);

  static String registration(String tournamentId) =>
      AppRoutes.teamRegistrationForTournament(tournamentId);

  static String organizerDashboard(String tournamentId) =>
      AppRoutes.organizerDashboardForTournament(tournamentId);

  static String? participantProfile(ParticipantRef participant) {
    final id = participant.id.trim();
    if (id.isEmpty ||
        (participant.kind != ParticipantRefKind.player &&
            participant.kind != ParticipantRefKind.guestPlayer)) {
      return null;
    }
    return AppRoutes.playerProfileByKindAndId(
      kind: participant.kind.name,
      id: id,
    );
  }
}
