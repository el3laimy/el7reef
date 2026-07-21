import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/team.dart';
import '../../team/models/public_team_profile_data.dart';
import '../models/team_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class TeamShareController {
  const TeamShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  TeamShareData buildRegistered({
    required Team team,
    String? tournamentId,
    String? tournamentName,
  }) {
    return _build(
      teamId: team.id,
      teamKind: 'registeredTeam',
      teamName: team.name,
      logoUrl: team.logoUrl,
      teamKindLabel: 'فريق مسجل',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      playerCount: team.playerCount,
      wins: team.wins,
      totalMatches: team.totalMatches,
    );
  }

  TeamShareData buildGuest({
    required GuestTeam team,
    String? tournamentId,
    String? tournamentName,
  }) {
    return _build(
      teamId: team.id,
      teamKind: 'guestTeam',
      teamName: team.name,
      logoUrl: team.logoUrl,
      teamKindLabel: 'فريق ضيف',
      tournamentId: tournamentId,
      tournamentName: tournamentName,
    );
  }

  TeamShareData buildPublic(PublicTeamProfileData profile) {
    return _build(
      teamId: profile.id,
      teamKind: profile.kind,
      teamName: profile.name,
      logoUrl: profile.logoUrl,
      teamKindLabel: profile.kindLabel,
      tournamentId: null,
      tournamentName: null,
      playerCount: profile.playerCount,
      wins: profile.wins,
      totalMatches: profile.totalMatches,
    );
  }

  TeamShareData _build({
    required String teamId,
    required String teamKind,
    required String teamName,
    required String? logoUrl,
    required String teamKindLabel,
    required String? tournamentId,
    required String? tournamentName,
    int? playerCount,
    int? wins,
    int? totalMatches,
  }) {
    final name = _label(teamName, fallback: 'فريق الحريف');
    return TeamShareData(
      teamName: name,
      initials: _initials(name),
      logoUrl: _normalizedOptional(logoUrl),
      teamKindLabel: teamKindLabel,
      tournamentName: _normalizedOptional(tournamentName),
      playerCount: playerCount,
      wins: wins,
      totalMatches: totalMatches,
      sharePayload: _payloadBuilder.team(
        teamId: teamId,
        teamKind: teamKind,
        tournamentId: tournamentId,
      ),
    );
  }

  String _label(String value, {required String fallback}) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'ح';
    if (words.length == 1) return _take(words.first, 2);
    return '${_take(words.first, 1)}${_take(words[1], 1)}';
  }

  String _take(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);
}
