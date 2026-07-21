import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_event.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/mvp_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class MvpShareController {
  const MvpShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  MvpShareData? buildFromEvent({
    required Match match,
    required MatchEvent event,
    String? tournamentName,
    String teamALabel = '',
    String teamBLabel = '',
    String? photoUrl,
  }) {
    final displayName = _normalizedOptional(event.actor.displayName);
    final tournamentId = match.tournamentId?.trim();
    final eventTournamentId = _normalizedOptional(event.tournamentId);
    if (!_isShareableTournamentMatch(match) ||
        match.id.trim().isEmpty ||
        !event.isActive ||
        !event.isMvp ||
        event.matchId.trim() != match.id.trim() ||
        event.actor.id.trim().isEmpty ||
        (eventTournamentId != null && eventTournamentId != tournamentId) ||
        displayName == null) {
      return null;
    }
    return MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: displayName,
      isGuest: event.actor.kind == ParticipantRefKind.guestPlayer,
      tournamentName: _normalizedOptional(tournamentName),
      scoreLine: _scoreLine(match, teamALabel, teamBLabel),
      sideLabel: _sideLabel(event.sideKey, teamALabel, teamBLabel),
      photoUrl: _normalizedOptional(photoUrl),
      initials: _initials(displayName),
      sharePayload: _payloadBuilder.mvp(match: match, actor: event.actor),
    );
  }

  MvpShareData? buildFallback({
    required Match match,
    required String mvpPlayerId,
    String? displayName,
    bool isGuest = false,
    String? sideKey,
    String? tournamentName,
    String teamALabel = '',
    String teamBLabel = '',
    ParticipantRef? actor,
    String? photoUrl,
  }) {
    final normalizedPlayerId = mvpPlayerId.trim();
    final normalizedDisplayName = _normalizedOptional(displayName);
    if (!_isShareableTournamentMatch(match) ||
        normalizedPlayerId.isEmpty ||
        match.mvpPlayerId?.trim() != normalizedPlayerId ||
        normalizedDisplayName == null ||
        (actor != null && actor.id.trim() != normalizedPlayerId)) {
      return null;
    }
    return MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: normalizedDisplayName,
      isGuest: actor == null
          ? isGuest
          : actor.kind == ParticipantRefKind.guestPlayer,
      tournamentName: _normalizedOptional(tournamentName),
      scoreLine: _scoreLine(match, teamALabel, teamBLabel),
      sideLabel: sideKey == null
          ? null
          : _sideLabel(sideKey, teamALabel, teamBLabel),
      photoUrl: _normalizedOptional(photoUrl),
      initials: _initials(normalizedDisplayName),
      sharePayload: _payloadBuilder.mvp(match: match, actor: actor),
    );
  }

  bool _isShareableTournamentMatch(Match match) =>
      match.isOfficialTournamentResult &&
      (match.tournamentId?.trim().isNotEmpty ?? false);

  String? _scoreLine(Match match, String teamALabel, String teamBLabel) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    final normalizedTeamA = _normalizedOptional(teamALabel);
    final normalizedTeamB = _normalizedOptional(teamBLabel);
    if (scoreA == null ||
        scoreB == null ||
        normalizedTeamA == null ||
        normalizedTeamB == null) {
      return null;
    }
    return '$normalizedTeamA $scoreA - $scoreB $normalizedTeamB';
  }

  String? _sideLabel(String sideKey, String teamALabel, String teamBLabel) {
    final normalized = sideKey.trim().toUpperCase();
    if (normalized == 'A') return _normalizedOptional(teamALabel);
    if (normalized == 'B') return _normalizedOptional(teamBLabel);
    return null;
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _initials(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'ح';
    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }
}
