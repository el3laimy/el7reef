import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_event.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/mvp_share_data.dart';

class MvpShareController {
  const MvpShareController();

  MvpShareData buildFromEvent({
    required Match match,
    required MatchEvent event,
    String? tournamentName,
    String teamALabel = 'فريق A',
    String teamBLabel = 'فريق B',
  }) {
    return MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: _displayName(event.actor.displayName),
      isGuest: event.actor.kind == ParticipantRefKind.guestPlayer,
      tournamentName: _tournamentName(tournamentName),
      scoreLine: _scoreLine(match, teamALabel, teamBLabel),
      sideLabel: _sideLabel(event.sideKey, teamALabel, teamBLabel),
    );
  }

  MvpShareData buildFallback({
    required Match match,
    required String mvpPlayerId,
    String? displayName,
    bool isGuest = false,
    String? sideKey,
    String? tournamentName,
    String teamALabel = 'فريق A',
    String teamBLabel = 'فريق B',
  }) {
    return MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: _displayName(displayName ?? mvpPlayerId),
      isGuest: isGuest,
      tournamentName: _tournamentName(tournamentName),
      scoreLine: _scoreLine(match, teamALabel, teamBLabel),
      sideLabel: sideKey == null
          ? null
          : _sideLabel(sideKey, teamALabel, teamBLabel),
    );
  }

  String _displayName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'نجم المباراة' : trimmed;
  }

  String _tournamentName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'بطولة الحريف';
    return trimmed;
  }

  String? _scoreLine(Match match, String teamALabel, String teamBLabel) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    if (scoreA == null || scoreB == null) return null;
    return '${_label(teamALabel, fallback: 'فريق A')} $scoreA - $scoreB ${_label(teamBLabel, fallback: 'فريق B')}';
  }

  String? _sideLabel(String sideKey, String teamALabel, String teamBLabel) {
    final normalized = sideKey.trim().toUpperCase();
    if (normalized == 'A') return _label(teamALabel, fallback: 'فريق A');
    if (normalized == 'B') return _label(teamBLabel, fallback: 'فريق B');
    return null;
  }

  String _label(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
