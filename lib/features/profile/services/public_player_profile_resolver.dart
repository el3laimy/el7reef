import '../../../core/services/match_event_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_event.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/repositories/match_repository.dart';
import '../models/public_player_profile_data.dart';

class PublicPlayerProfileResolver {
  final PlayerRepositoryImpl _playerRepository;
  final GuestPlayerRepositoryImpl _guestPlayerRepository;
  final MatchEventService _matchEventService;
  final MatchRepository _matchRepository;
  final String? Function() _currentUserId;

  PublicPlayerProfileResolver({
    PlayerRepositoryImpl? playerRepository,
    GuestPlayerRepositoryImpl? guestPlayerRepository,
    MatchEventService? matchEventService,
    MatchRepository? matchRepository,
    String? Function()? currentUserId,
  }) : _playerRepository = playerRepository ?? PlayerRepositoryImpl(),
       _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _matchEventService = matchEventService ?? MatchEventService(),
       _matchRepository = matchRepository ?? MatchRepositoryImpl(),
       _currentUserId = currentUserId ?? (() => null);

  Future<PublicPlayerProfileData?> resolve({
    required String kind,
    required String id,
  }) async {
    final actorKind = _parseKind(kind);
    final actorId = id.trim();
    if (actorKind == null || actorId.isEmpty) return null;

    final actorEvents = actorKind == ParticipantRefKind.player
        ? await _eventsForRegisteredPlayer(actorId)
        : await _matchEventService.getEventsForActor(
            actorKind: actorKind,
            actorId: actorId,
          );
    final events = await _officialEvents(actorEvents);

    return switch (actorKind) {
      ParticipantRefKind.player => _resolvePlayer(actorId, events),
      ParticipantRefKind.guestPlayer => _resolveGuestPlayer(actorId, events),
      ParticipantRefKind.matchSidePlayer => null,
    };
  }

  Future<PublicPlayerProfileData?> _resolvePlayer(
    String playerId,
    List<MatchEvent> events,
  ) async {
    final player = await _playerRepository.getPlayer(playerId);
    if (player == null && events.isEmpty) return null;

    return PublicPlayerProfileData(
      kind: ParticipantRefKind.player,
      id: playerId,
      displayName: _displayName(player?.name, events, fallback: 'لاعب'),
      photoUrl:
          _normalizeOptional(player?.photoThumbUrl) ??
          _normalizeOptional(player?.photoUrl),
      totalGoals: _countGoals(events),
      totalMvps: _countMvps(events),
    );
  }

  Future<PublicPlayerProfileData?> _resolveGuestPlayer(
    String guestPlayerId,
    List<MatchEvent> events,
  ) async {
    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      guestPlayerId,
    );
    if (guestPlayer == null && events.isEmpty) return null;

    final linkedPlayerId =
        _normalizeOptional(guestPlayer?.linkedPlayerId) ??
        _eventLinkedPlayerId(events);

    return PublicPlayerProfileData(
      kind: ParticipantRefKind.guestPlayer,
      id: guestPlayerId,
      displayName: _displayName(
        guestPlayer?.displayName,
        events,
        fallback: 'لاعب ضيف',
      ),
      totalGoals: _countGoals(events),
      totalMvps: _countMvps(events),
      linkedPlayerId: linkedPlayerId,
      isClaimed: linkedPlayerId != null || (guestPlayer?.isClaimed ?? false),
    );
  }

  ParticipantRefKind? _parseKind(String value) {
    final normalized = value.trim();
    if (normalized == ParticipantRefKind.player.name) {
      return ParticipantRefKind.player;
    }
    if (normalized == ParticipantRefKind.guestPlayer.name) {
      return ParticipantRefKind.guestPlayer;
    }
    return null;
  }

  int _countGoals(List<MatchEvent> events) =>
      events.where((event) => event.isActive && event.isGoal).length;

  int _countMvps(List<MatchEvent> events) =>
      events.where((event) => event.isActive && event.isMvp).length;

  Future<List<MatchEvent>> _eventsForRegisteredPlayer(String playerId) async {
    final isOwnProfile = _normalizeOptional(_currentUserId()) == playerId;
    final linkedGuests = isOwnProfile
        ? await _guestPlayerRepository.getGuestPlayersLinkedToPlayer(playerId)
        : const <GuestPlayer>[];
    final eventGroups = await Future.wait(<Future<List<MatchEvent>>>[
      _matchEventService.getEventsForActor(
        actorKind: ParticipantRefKind.player,
        actorId: playerId,
      ),
      for (final guest in linkedGuests)
        _matchEventService.getEventsForActor(
          actorKind: ParticipantRefKind.guestPlayer,
          actorId: guest.id,
        ),
    ]);
    final eventsById = <String, MatchEvent>{};
    for (final events in eventGroups) {
      for (final event in events) {
        eventsById[event.id] = event;
      }
    }
    return eventsById.values.toList(growable: false);
  }

  Future<List<MatchEvent>> _officialEvents(List<MatchEvent> events) async {
    if (events.isEmpty) return const <MatchEvent>[];
    final matchIds = events.map((event) => event.matchId).toSet();
    final matches = await Future.wait(matchIds.map(_matchRepository.getMatch));
    final officialMatchIds = <String>{
      for (final Match? match in matches)
        if (match != null && match.isOfficialTournamentResult) match.id,
    };
    return events
        .where((event) => officialMatchIds.contains(event.matchId))
        .toList(growable: false);
  }

  String _displayName(
    String? sourceName,
    List<MatchEvent> events, {
    required String fallback,
  }) {
    final source = _normalizeOptional(sourceName);
    if (source != null) return source;
    for (final event in events) {
      final eventName = _normalizeOptional(event.actor.displayName);
      if (eventName != null) return eventName;
    }
    return fallback;
  }

  String? _eventLinkedPlayerId(List<MatchEvent> events) {
    for (final event in events) {
      final linkedPlayerId = _normalizeOptional(event.actor.linkedPlayerId);
      if (linkedPlayerId != null) return linkedPlayerId;
    }
    return null;
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
