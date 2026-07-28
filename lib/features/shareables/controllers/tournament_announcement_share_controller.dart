import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../models/tournament_announcement_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class TournamentAnnouncementShareController {
  const TournamentAnnouncementShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  TournamentInviteShareData? buildInviteIfEligible({
    required Tournament tournament,
  }) {
    final tournamentName = _requiredLabel(tournament.name);
    if (tournamentName == null ||
        _requiredLabel(tournament.id) == null ||
        !tournament.canRegister) {
      return null;
    }

    return TournamentInviteShareData(
      tournamentName: tournamentName,
      tournamentLogoUrl: tournament.logoUrl,
      teamSizeLabel:
          '${tournament.teamSize.value} ضد ${tournament.teamSize.value}',
      maxTeams: tournament.maxTeams,
      location: _optionalLabel(tournament.location),
      startDate: tournament.startDate,
      registrationDeadline: tournament.registrationDeadline,
      sharePayload: _payloadBuilder.tournamentInvite(
        tournamentId: tournament.id,
      ),
    );
  }

  UpcomingFixtureShareData? buildUpcomingFixtureIfEligible({
    required Tournament tournament,
    required Match fixture,
    required TournamentParticipant teamA,
    required TournamentParticipant teamB,
    DateTime? now,
  }) {
    final tournamentName = _requiredLabel(tournament.name);
    final teamAName = _requiredLabel(teamA.displayName);
    final teamBName = _requiredLabel(teamB.displayName);
    final scheduledAt = fixture.scheduledAt;
    final effectiveNow = now ?? DateTime.now();
    if (tournamentName == null ||
        _requiredLabel(tournament.id) == null ||
        _requiredLabel(fixture.id) == null ||
        teamAName == null ||
        teamBName == null ||
        scheduledAt == null ||
        !scheduledAt.isAfter(effectiveNow) ||
        fixture.fixtureStatus != FixtureStatus.published ||
        fixture.tournamentId != tournament.id ||
        !_matchesFixtureSide(fixture, teamA, isHome: true) ||
        !_matchesFixtureSide(fixture, teamB, isHome: false)) {
      return null;
    }

    return UpcomingFixtureShareData(
      tournamentName: tournamentName,
      tournamentLogoUrl: tournament.logoUrl,
      teamAName: teamAName,
      teamBName: teamBName,
      scheduledAt: scheduledAt,
      stageLabel: _stageLabel(fixture),
      location:
          _optionalLabel(fixture.venueId) ??
          _optionalLabel(fixture.location) ??
          _optionalLabel(tournament.location),
      sharePayload: _payloadBuilder.upcomingFixture(match: fixture),
    );
  }

  bool _matchesFixtureSide(
    Match fixture,
    TournamentParticipant participant, {
    required bool isHome,
  }) {
    final participantId = isHome
        ? fixture.teamAParticipantId
        : fixture.teamBParticipantId;
    final legacyTeamId = isHome ? fixture.teamAId : fixture.teamBId;
    return participantId == participant.id ||
        legacyTeamId == participant.sourceEntityId;
  }

  String _stageLabel(Match fixture) {
    final round = fixture.roundIndex;
    return switch (fixture.stageType) {
      TournamentStageType.groupStage when round != null =>
        'دور المجموعات · الجولة ${round + 1}',
      TournamentStageType.groupStage => 'دور المجموعات',
      TournamentStageType.knockoutStage when round != null =>
        'الأدوار الإقصائية · الجولة ${round + 1}',
      TournamentStageType.knockoutStage => 'الأدوار الإقصائية',
      null => 'مباراة بطولة',
    };
  }

  String? _requiredLabel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _optionalLabel(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
