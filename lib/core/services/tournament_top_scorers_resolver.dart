import '../../data/repositories/match_repository_impl.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/participant_ref.dart';
import '../../domain/repositories/guest_player_repository.dart';
import 'claimed_participant_identity_resolver.dart';
import 'match_event_service.dart';

class TournamentTopScorerEntry {
  final ParticipantRef actor;
  final int goals;
  final String? teamDisplayName;

  const TournamentTopScorerEntry({
    required this.actor,
    required this.goals,
    this.teamDisplayName,
  });
}

class TournamentTopScorersSnapshot {
  final List<TournamentTopScorerEntry> scorers;
  final int officialMatchCount;

  const TournamentTopScorersSnapshot({
    required this.scorers,
    required this.officialMatchCount,
  });

  bool get hasOfficialResultsWithoutScorerDetails =>
      officialMatchCount > 0 && scorers.isEmpty;
}

class TournamentTopScorersResolver {
  final MatchEventService _matchEventService;
  final MatchRepositoryImpl? _matchRepository;
  final GuestPlayerRepository? _guestPlayerRepository;

  TournamentTopScorersResolver({
    MatchEventService? matchEventService,
    MatchRepositoryImpl? matchRepository,
    GuestPlayerRepository? guestPlayerRepository,
  }) : _matchEventService = matchEventService ?? MatchEventService(),
       _matchRepository = matchRepository,
       _guestPlayerRepository = guestPlayerRepository;

  Future<List<TournamentTopScorerEntry>> getTopScorers(
    String tournamentId, {
    int limit = 10,
  }) async {
    final snapshot = await getTopScorersSnapshot(tournamentId, limit: limit);
    return snapshot.scorers;
  }

  Future<TournamentTopScorersSnapshot> getTopScorersSnapshot(
    String tournamentId, {
    int limit = 10,
  }) async {
    final normalizedTournamentId = tournamentId.trim();
    if (normalizedTournamentId.isEmpty || limit <= 0) {
      return const TournamentTopScorersSnapshot(
        scorers: <TournamentTopScorerEntry>[],
        officialMatchCount: 0,
      );
    }

    final events = await _matchEventService.getTournamentGoalEvents(
      normalizedTournamentId,
    );
    final officialMatches = await _loadOfficialTournamentMatches(
      normalizedTournamentId,
    );
    final canonicalActors = await ClaimedParticipantIdentityResolver(
      guestPlayerRepository: _guestPlayerRepository,
    ).resolveAll(events.map((event) => event.actor));
    final totals = <String, _ScorerAccumulator>{};

    for (final event in events) {
      final match = officialMatches[event.matchId];
      if (match == null) {
        continue;
      }

      final actor =
          canonicalActors[_participantKey(event.actor)] ?? event.actor;
      if (!_isTournamentLeaderboardActor(actor)) {
        continue;
      }

      final key = _scorerKey(actor);
      totals.update(
        key,
        (accumulator) => accumulator.increment(),
        ifAbsent: () => _ScorerAccumulator(actor: actor, goals: 1),
      );
    }

    final entries = totals.values
        .map(
          (accumulator) => TournamentTopScorerEntry(
            actor: accumulator.actor,
            goals: accumulator.goals,
          ),
        )
        .toList(growable: false);
    entries.sort(_compareEntries);
    return TournamentTopScorersSnapshot(
      scorers: entries.take(limit).toList(growable: false),
      officialMatchCount: officialMatches.length,
    );
  }

  String _participantKey(ParticipantRef actor) =>
      '${actor.kind.name}:${actor.id}';

  Future<Map<String, Match>> _loadOfficialTournamentMatches(
    String tournamentId,
  ) async {
    final matches = await (_matchRepository ?? MatchRepositoryImpl())
        .getTournamentMatches(tournamentId: tournamentId);
    return {
      for (final match in matches)
        if (match.isOfficialTournamentResult) match.id: match,
    };
  }

  bool _isTournamentLeaderboardActor(ParticipantRef actor) {
    return actor.kind == ParticipantRefKind.player ||
        actor.kind == ParticipantRefKind.guestPlayer;
  }

  String _scorerKey(ParticipantRef actor) => '${actor.kind.name}:${actor.id}';

  int _compareEntries(
    TournamentTopScorerEntry left,
    TournamentTopScorerEntry right,
  ) {
    final goalsCompare = right.goals.compareTo(left.goals);
    if (goalsCompare != 0) return goalsCompare;

    final nameCompare = left.actor.displayName.toLowerCase().compareTo(
      right.actor.displayName.toLowerCase(),
    );
    if (nameCompare != 0) return nameCompare;

    final idCompare = left.actor.id.compareTo(right.actor.id);
    if (idCompare != 0) return idCompare;

    return left.actor.kind.name.compareTo(right.actor.kind.name);
  }
}

class _ScorerAccumulator {
  final ParticipantRef actor;
  final int goals;

  const _ScorerAccumulator({required this.actor, required this.goals});

  _ScorerAccumulator increment() {
    return _ScorerAccumulator(actor: actor, goals: goals + 1);
  }
}
