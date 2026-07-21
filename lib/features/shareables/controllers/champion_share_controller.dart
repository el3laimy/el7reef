import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../models/champion_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class ChampionShareController {
  const ChampionShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  ChampionShareData? build({
    required Tournament tournament,
    required TournamentParticipant champion,
    String? logoUrl,
  }) {
    final tournamentId = _normalizedRequired(tournament.id);
    final tournamentName = _normalizedRequired(tournament.name);
    final championId = _normalizedRequired(champion.id);
    final championName = _normalizedRequired(champion.displayName);
    final teamId = _normalizedRequired(champion.sourceEntityId);
    if (tournamentId == null ||
        tournamentName == null ||
        championId == null ||
        championName == null ||
        teamId == null ||
        tournament.status != TournamentStatus.completed ||
        champion.tournamentId.trim() != tournamentId ||
        tournament.winnerParticipantId?.trim() != championId) {
      return null;
    }
    final teamKind = champion.sourceType.name;
    return ChampionShareData(
      tournamentName: tournamentName,
      championName: championName,
      teamKindLabel:
          champion.sourceType == TournamentParticipantSourceType.guestTeam
          ? 'فريق ضيف'
          : 'فريق مسجل',
      logoUrl: _normalizedOptional(logoUrl),
      initials: _initials(championName),
      sharePayload: _payloadBuilder.champion(
        tournamentId: tournamentId,
        teamId: teamId,
        teamKind: teamKind,
      ),
    );
  }

  String? _normalizedRequired(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
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
