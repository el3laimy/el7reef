import '../../../core/navigation/app_link_route_parser.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/share_payload.dart';

class PrideSharePayloadBuilder {
  const PrideSharePayloadBuilder();

  SharePayload matchResult({required Match match}) {
    return SharePayload(
      cardType: ShareCardType.matchResult,
      entityType: ShareEntityType.match,
      entityId: match.id,
      tournamentId: match.tournamentId,
      matchId: match.id,
      targetUrl: _matchUrl(match.id),
      campaignSource: 'match_result_card',
    );
  }

  SharePayload mvp({required Match match, ParticipantRef? actor}) {
    final profileActor = _profileActor(actor);
    if (profileActor == null) {
      return SharePayload(
        cardType: ShareCardType.mvp,
        entityType: ShareEntityType.match,
        entityId: match.id,
        tournamentId: match.tournamentId,
        matchId: match.id,
        targetUrl: _matchUrl(match.id),
        campaignSource: 'mvp_card',
      );
    }

    return SharePayload(
      cardType: ShareCardType.mvp,
      entityType: profileActor.kind == ParticipantRefKind.player
          ? ShareEntityType.player
          : ShareEntityType.guestPlayer,
      entityId: profileActor.id,
      tournamentId: match.tournamentId,
      matchId: match.id,
      targetUrl: _playerUrl(profileActor),
      campaignSource: 'mvp_card',
    );
  }

  SharePayload topScorers({required String tournamentId}) {
    return SharePayload(
      cardType: ShareCardType.topScorers,
      entityType: ShareEntityType.tournament,
      entityId: tournamentId,
      tournamentId: tournamentId,
      targetUrl: _tournamentUrl(tournamentId),
      campaignSource: 'top_scorers_card',
    );
  }

  SharePayload lineup({
    required String matchId,
    required String lineupId,
    String? tournamentId,
  }) {
    return SharePayload(
      cardType: ShareCardType.lineup,
      entityType: ShareEntityType.lineup,
      entityId: lineupId,
      tournamentId: tournamentId,
      matchId: matchId,
      targetUrl: _matchUrl(matchId, showLineup: true),
      campaignSource: 'lineup_card',
    );
  }

  SharePayload champion({
    required String tournamentId,
    required String teamId,
    required String teamKind,
  }) {
    return SharePayload(
      cardType: ShareCardType.champion,
      entityType: ShareEntityType.team,
      entityId: teamId,
      tournamentId: tournamentId,
      targetUrl: _teamUrl(teamKind: teamKind, teamId: teamId),
      campaignSource: 'champion_card',
    );
  }

  SharePayload player({
    required ParticipantRef actor,
    String? tournamentId,
    String? matchId,
  }) {
    final profileActor = _profileActor(actor);
    if (profileActor == null) {
      throw ArgumentError.value(
        actor.kind,
        'actor.kind',
        'A player card requires a registered or guest player.',
      );
    }

    return SharePayload(
      cardType: ShareCardType.player,
      entityType: profileActor.kind == ParticipantRefKind.player
          ? ShareEntityType.player
          : ShareEntityType.guestPlayer,
      entityId: profileActor.id,
      tournamentId: tournamentId,
      matchId: matchId,
      targetUrl: _playerUrl(profileActor),
      campaignSource: 'player_card',
    );
  }

  SharePayload team({
    required String teamId,
    required String teamKind,
    String? tournamentId,
  }) {
    return SharePayload(
      cardType: ShareCardType.team,
      entityType: ShareEntityType.team,
      entityId: teamId,
      tournamentId: tournamentId,
      targetUrl: _teamUrl(teamKind: teamKind, teamId: teamId),
      campaignSource: 'team_card',
    );
  }

  SharePayload tournamentInvite({required String tournamentId}) {
    return SharePayload(
      cardType: ShareCardType.tournamentInvite,
      entityType: ShareEntityType.tournament,
      entityId: tournamentId,
      tournamentId: tournamentId,
      targetUrl: _tournamentUrl(tournamentId),
      campaignSource: 'tournament_invite_card',
    );
  }

  SharePayload upcomingFixture({required Match match}) {
    return SharePayload(
      cardType: ShareCardType.upcomingFixture,
      entityType: ShareEntityType.match,
      entityId: match.id,
      tournamentId: match.tournamentId,
      matchId: match.id,
      targetUrl: _matchUrl(match.id),
      campaignSource: 'upcoming_fixture_card',
    );
  }

  SharePayload goalScorer({
    required Match match,
    required ParticipantRef actor,
  }) {
    return _playerMoment(
      cardType: ShareCardType.goalScorer,
      campaignSource: 'goal_scorer_card',
      actor: actor,
      tournamentId: match.tournamentId,
      matchId: match.id,
    );
  }

  SharePayload qualification({
    required String tournamentId,
    required String teamId,
    required String teamKind,
    String? matchId,
  }) {
    return SharePayload(
      cardType: ShareCardType.qualification,
      entityType: ShareEntityType.team,
      entityId: teamId,
      tournamentId: tournamentId,
      matchId: matchId,
      targetUrl: _teamUrl(teamKind: teamKind, teamId: teamId),
      campaignSource: 'qualification_card',
    );
  }

  SharePayload groupStandings({required String tournamentId}) {
    return SharePayload(
      cardType: ShareCardType.groupStandings,
      entityType: ShareEntityType.tournament,
      entityId: tournamentId,
      tournamentId: tournamentId,
      targetUrl: _tournamentUrl(tournamentId),
      campaignSource: 'group_standings_card',
    );
  }

  SharePayload knockoutBracket({required String tournamentId}) {
    return SharePayload(
      cardType: ShareCardType.knockoutBracket,
      entityType: ShareEntityType.tournament,
      entityId: tournamentId,
      tournamentId: tournamentId,
      targetUrl: _tournamentUrl(tournamentId),
      campaignSource: 'knockout_bracket_card',
    );
  }

  SharePayload playerMilestone({
    required ParticipantRef actor,
    String? tournamentId,
    String? matchId,
  }) {
    return _playerMoment(
      cardType: ShareCardType.playerMilestone,
      campaignSource: 'player_milestone_card',
      actor: actor,
      tournamentId: tournamentId,
      matchId: matchId,
    );
  }

  Uri _matchUrl(String matchId, {bool showLineup = false}) {
    return Uri(
      scheme: 'https',
      host: AppLinkRouteParser.pilotWebHost,
      pathSegments: ['match', matchId],
      queryParameters: showLineup ? const {'view': 'lineup'} : null,
    );
  }

  SharePayload _playerMoment({
    required ShareCardType cardType,
    required String campaignSource,
    required ParticipantRef actor,
    String? tournamentId,
    String? matchId,
  }) {
    final profileActor = _profileActor(actor);
    if (profileActor == null) {
      throw ArgumentError.value(
        actor.kind,
        'actor.kind',
        'A player moment requires a registered or guest player.',
      );
    }
    return SharePayload(
      cardType: cardType,
      entityType: profileActor.kind == ParticipantRefKind.player
          ? ShareEntityType.player
          : ShareEntityType.guestPlayer,
      entityId: profileActor.id,
      tournamentId: tournamentId,
      matchId: matchId,
      targetUrl: _playerUrl(profileActor),
      campaignSource: campaignSource,
    );
  }

  Uri _tournamentUrl(String tournamentId) {
    return Uri(
      scheme: 'https',
      host: AppLinkRouteParser.pilotWebHost,
      pathSegments: ['tournament', tournamentId],
    );
  }

  Uri _playerUrl(ParticipantRef actor) {
    return Uri(
      scheme: 'https',
      host: AppLinkRouteParser.pilotWebHost,
      pathSegments: ['player', actor.kind.name, actor.id],
    );
  }

  Uri _teamUrl({required String teamKind, required String teamId}) {
    final normalizedKind = switch (teamKind.trim()) {
      'registeredTeam' => 'registeredTeam',
      'guestTeam' => 'guestTeam',
      _ => throw ArgumentError.value(
        teamKind,
        'teamKind',
        'Must be registeredTeam or guestTeam.',
      ),
    };
    return Uri(
      scheme: 'https',
      host: AppLinkRouteParser.pilotWebHost,
      pathSegments: ['team', normalizedKind, teamId],
    );
  }

  ParticipantRef? _profileActor(ParticipantRef? actor) {
    if (actor == null || actor.id.trim().isEmpty) return null;
    return switch (actor.kind) {
      ParticipantRefKind.player || ParticipantRefKind.guestPlayer => actor,
      ParticipantRefKind.matchSidePlayer => null,
    };
  }
}
