import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/top_scorers_share_data.dart';
import '../services/pride_identity_image_resolver.dart';
import '../services/pride_share_payload_builder.dart';

class TopScorersShareController {
  const TopScorersShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  TopScorersShareData? build({
    required String tournamentId,
    required String tournamentName,
    required List<TournamentTopScorerEntry> scorers,
    int limit = 5,
    Map<String, String?> photoUrls = const {},
  }) {
    final normalizedTournamentId = tournamentId.trim();
    final normalizedName = tournamentName.trim();
    if (normalizedTournamentId.isEmpty ||
        normalizedName.isEmpty ||
        limit <= 0) {
      return null;
    }
    final limitedScorers = scorers
        .where(_hasConfirmedDisplayData)
        .take(limit)
        .toList(growable: false);
    if (limitedScorers.isEmpty) return null;

    return TopScorersShareData(
      title: 'هدافو البطولة',
      tournamentName: normalizedName,
      sharePayload: _payloadBuilder.topScorers(
        tournamentId: normalizedTournamentId,
      ),
      scorers: [
        for (final item in limitedScorers.indexed)
          TopScorersShareEntryData(
            rank: item.$1 + 1,
            displayName: item.$2.actor.displayName.trim(),
            goals: item.$2.goals,
            isGuest: item.$2.actor.kind == ParticipantRefKind.guestPlayer,
            photoUrl:
                photoUrls[PrideIdentityImageResolver.identityKey(
                  item.$2.actor,
                )],
            initials: _initials(item.$2.actor.displayName),
          ),
      ],
    );
  }

  bool _hasConfirmedDisplayData(TournamentTopScorerEntry entry) =>
      entry.goals > 0 &&
      entry.actor.id.trim().isNotEmpty &&
      entry.actor.displayName.trim().isNotEmpty;

  String _initials(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'ح';
    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }
}
