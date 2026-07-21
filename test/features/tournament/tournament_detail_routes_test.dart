import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/tournament/navigation/tournament_detail_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps tournament detail CTAs through AppRoutes helpers', () {
    const tournamentId = 'tournament-1';

    expect(
      TournamentDetailRoutes.participants(tournamentId),
      AppRoutes.tournamentParticipantsById(tournamentId),
    );
    expect(
      TournamentDetailRoutes.groups(tournamentId),
      AppRoutes.tournamentGroupsById(tournamentId),
    );
    expect(
      TournamentDetailRoutes.fixtures(tournamentId),
      AppRoutes.tournamentFixturesById(tournamentId),
    );
    expect(
      TournamentDetailRoutes.standings(tournamentId),
      AppRoutes.tournamentStandingsById(tournamentId),
    );
    expect(
      TournamentDetailRoutes.bracket(tournamentId),
      AppRoutes.tournamentBracketById(tournamentId),
    );
    expect(
      TournamentDetailRoutes.registration(tournamentId),
      AppRoutes.teamRegistrationForTournament(tournamentId),
    );
    expect(
      TournamentDetailRoutes.organizerDashboard(tournamentId),
      AppRoutes.organizerDashboardForTournament(tournamentId),
    );
  });

  test('opens only registered and guest public participant profiles', () {
    const registered = ParticipantRef(
      kind: ParticipantRefKind.player,
      id: 'player-1',
      displayName: 'مسجل',
    );
    const guest = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: ' guest-1 ',
      displayName: 'ضيف',
    );
    const temporary = ParticipantRef(
      kind: ParticipantRefKind.matchSidePlayer,
      id: 'temporary-1',
      displayName: 'مؤقت',
    );

    expect(
      TournamentDetailRoutes.participantProfile(registered),
      AppRoutes.playerProfileByKindAndId(
        kind: ParticipantRefKind.player.name,
        id: 'player-1',
      ),
    );
    expect(
      TournamentDetailRoutes.participantProfile(guest),
      AppRoutes.playerProfileByKindAndId(
        kind: ParticipantRefKind.guestPlayer.name,
        id: 'guest-1',
      ),
    );
    expect(TournamentDetailRoutes.participantProfile(temporary), isNull);
  });
}
