import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/top_scorers_share_data.dart';

class TopScorersShareController {
  const TopScorersShareController();

  TopScorersShareData build({
    required String tournamentName,
    required List<TournamentTopScorerEntry> scorers,
    int limit = 5,
  }) {
    final normalizedName = tournamentName.trim();
    final limitedScorers = limit <= 0
        ? const <TournamentTopScorerEntry>[]
        : scorers.take(limit).toList(growable: false);

    return TopScorersShareData(
      title: 'هدافو البطولة',
      tournamentName: normalizedName.isEmpty ? 'بطولة الحريف' : normalizedName,
      scorers: [
        for (final item in limitedScorers.indexed)
          TopScorersShareEntryData(
            rank: item.$1 + 1,
            displayName: _displayName(item.$2.actor.displayName),
            goals: item.$2.goals,
            isGuest: item.$2.actor.kind == ParticipantRefKind.guestPlayer,
          ),
      ],
    );
  }

  String _displayName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'لاعب' : trimmed;
  }
}
