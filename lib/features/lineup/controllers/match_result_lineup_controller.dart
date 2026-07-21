import 'package:get/get.dart';

import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../core/services/claimed_participant_identity_resolver.dart';
import '../../../core/services/match_event_service.dart';
import '../../shareables/services/pride_identity_image_resolver.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_event.dart';
import '../../../domain/entities/match_lineup_entry.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/team.dart';
import '../../match/models/friendly_match_side_view.dart';

class ResultLineupSide {
  final String label;
  final String? logoUrl;
  final MatchLineupSnapshot? snapshot;

  const ResultLineupSide({required this.label, this.logoUrl, this.snapshot});
}

class MvpPublicProfileTarget {
  final ParticipantRefKind kind;
  final String id;

  const MvpPublicProfileTarget({required this.kind, required this.id});
}

class MatchResultLineupController extends GetxController {
  final MatchRepositoryImpl _matchRepository;
  final TeamRepositoryImpl _teamRepository;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepository;
  final MatchSideRepositoryImpl _matchSideRepository;
  final MatchSidePlayerRepositoryImpl _matchSidePlayerRepository;
  final MatchEventService _matchEventService;
  final TournamentRepositoryImpl _tournamentRepository;
  final PrideIdentityImageResolver _identityImageResolver;
  final ClaimedParticipantIdentityResolver _claimedIdentityResolver;

  MatchResultLineupController({
    required MatchRepositoryImpl matchRepository,
    required TeamRepositoryImpl teamRepository,
    required MatchLineupSnapshotRepositoryImpl snapshotRepository,
    required MatchSideRepositoryImpl matchSideRepository,
    required MatchSidePlayerRepositoryImpl matchSidePlayerRepository,
    required MatchEventService matchEventService,
    required TournamentRepositoryImpl tournamentRepository,
    PrideIdentityImageResolver? identityImageResolver,
    ClaimedParticipantIdentityResolver? claimedIdentityResolver,
  }) : _matchRepository = matchRepository,
       _teamRepository = teamRepository,
       _snapshotRepository = snapshotRepository,
       _matchSideRepository = matchSideRepository,
       _matchSidePlayerRepository = matchSidePlayerRepository,
       _matchEventService = matchEventService,
       _tournamentRepository = tournamentRepository,
       _identityImageResolver =
           identityImageResolver ?? PrideIdentityImageResolver(),
       _claimedIdentityResolver =
           claimedIdentityResolver ?? ClaimedParticipantIdentityResolver();

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Match?> match = Rx<Match?>(null);
  final RxMap<String, Team> teams = <String, Team>{}.obs;
  final RxList<MatchSide> matchSides = <MatchSide>[].obs;
  final RxList<MatchSidePlayer> matchSidePlayers = <MatchSidePlayer>[].obs;
  final RxList<MatchLineupSnapshot> snapshots = <MatchLineupSnapshot>[].obs;
  final Rx<MatchEvent?> mvpEvent = Rx<MatchEvent?>(null);
  final RxList<MatchEvent> goalEvents = <MatchEvent>[].obs;
  final RxString tournamentName = ''.obs;

  String get matchId => Get.parameters['matchId'] ?? Get.parameters['id'] ?? '';

  ResultLineupSide get homeSide {
    final currentMatch = match.value;
    final teamId = currentMatch?.teamAId;
    final team = teamId == null ? null : teams[teamId];
    // FriendlyMatchSideView reads matchSides, so renamed temporary sides feed
    // both the result screen and the share-card data.
    final sideView = _friendlySideView('A');
    return ResultLineupSide(
      label: sideView?.displayName ?? team?.name ?? 'فريق A',
      logoUrl: team?.logoUrl,
      snapshot: _snapshotForSide(sideKey: 'A', teamId: teamId),
    );
  }

  ResultLineupSide get awaySide {
    final currentMatch = match.value;
    final teamId = currentMatch?.teamBId;
    final team = teamId == null ? null : teams[teamId];
    // FriendlyMatchSideView reads matchSides, so renamed temporary sides feed
    // both the result screen and the share-card data.
    final sideView = _friendlySideView('B');
    return ResultLineupSide(
      label: sideView?.displayName ?? team?.name ?? 'فريق B',
      logoUrl: team?.logoUrl,
      snapshot: _snapshotForSide(sideKey: 'B', teamId: teamId),
    );
  }

  @override
  void onInit() {
    super.onInit();
    loadResultLineup();
  }

  Future<void> loadResultLineup() async {
    if (matchId.isEmpty) {
      errorMessage.value = 'رابط المباراة غير مكتمل.';
      isLoading.value = false;
      return;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loadedMatch = await _matchRepository.getMatch(matchId);
      if (loadedMatch == null) {
        throw Exception('تعذر العثور على المباراة.');
      }
      final loadedSnapshots = await _snapshotRepository.getMatchSnapshots(
        matchId,
      );
      final loadedTeams = await _teamRepository.getTeamsByIds([
        if (loadedMatch.teamAId != null) loadedMatch.teamAId!,
        if (loadedMatch.teamBId != null) loadedMatch.teamBId!,
      ]);
      final loadedSides = loadedMatch.tournamentId == null
          ? await _matchSideRepository.getMatchSides(loadedMatch.id)
          : <MatchSide>[];
      final loadedSidePlayers = loadedMatch.tournamentId == null
          ? await _matchSidePlayerRepository.getMatchPlayers(loadedMatch.id)
          : <MatchSidePlayer>[];
      final loadedMvpEvent = await _loadMvpEventSafely(loadedMatch.id);
      final loadedGoalEvents = await _loadGoalEventsSafely(loadedMatch.id);
      final canonicalMvpEvent = loadedMvpEvent?.copyWith(
        actor: await _claimedIdentityResolver.resolve(loadedMvpEvent.actor),
      );
      final canonicalGoalEvents = await Future.wait(
        loadedGoalEvents.map(
          (event) async => event.copyWith(
            actor: await _claimedIdentityResolver.resolve(event.actor),
          ),
        ),
      );
      final loadedTournamentName = await _loadTournamentNameSafely(
        loadedMatch.tournamentId,
      );

      match.value = loadedMatch;
      snapshots.assignAll(loadedSnapshots);
      teams.assignAll({for (final team in loadedTeams) team.id: team});
      matchSides.assignAll(loadedSides);
      matchSidePlayers.assignAll(loadedSidePlayers);
      mvpEvent.value = canonicalMvpEvent;
      goalEvents.assignAll(canonicalGoalEvents);
      tournamentName.value = loadedTournamentName;
    } catch (error) {
      errorMessage.value = _readableError(error);
    } finally {
      isLoading.value = false;
    }
  }

  bool get hasShareableMvp {
    if (mvpEvent.value != null) return true;
    final mvpPlayerId = match.value?.mvpPlayerId?.trim();
    return mvpPlayerId != null && mvpPlayerId.isNotEmpty;
  }

  Future<String?> mvpPhotoUrl() async {
    final event = mvpEvent.value;
    if (event != null) {
      return _identityImageResolver.imageUrlFor(event.actor);
    }
    final target = mvpProfileTarget;
    if (target == null) return null;
    return _identityImageResolver.imageUrlFor(
      ParticipantRef(kind: target.kind, id: target.id, displayName: target.id),
    );
  }

  Future<String?> participantPhotoUrl(ParticipantRef actor) {
    return _identityImageResolver.imageUrlFor(actor);
  }

  MvpPublicProfileTarget? get mvpProfileTarget {
    final event = mvpEvent.value;
    if (event != null) {
      return _profileTargetForKindAndId(event.actor.kind, event.actor.id);
    }

    final mvpPlayerId = match.value?.mvpPlayerId?.trim();
    if (mvpPlayerId == null || mvpPlayerId.isEmpty) return null;
    final entry = _lineupEntryForParticipantId(mvpPlayerId);
    if (entry?.playerId != null) {
      return _profileTargetForKindAndId(
        ParticipantRefKind.player,
        entry!.playerId!,
      );
    }
    if (entry?.guestPlayerId != null) {
      return _profileTargetForKindAndId(
        ParticipantRefKind.guestPlayer,
        entry!.guestPlayerId!,
      );
    }
    return null;
  }

  String? displayNameForParticipantId(String participantId) {
    final entry = _lineupEntryForParticipantId(participantId);
    final entryName = entry?.displayName.trim();
    if (entryName != null && entryName.isNotEmpty) return entryName;

    final sidePlayer = matchSidePlayers.firstWhereOrNull(
      (player) => player.id == participantId,
    );
    final sidePlayerName = sidePlayer?.displayName.trim();
    if (sidePlayerName != null && sidePlayerName.isNotEmpty) {
      return sidePlayerName;
    }
    return null;
  }

  bool isGuestParticipantId(String participantId) {
    return _lineupEntryForParticipantId(participantId)?.isGuest ?? false;
  }

  String? sideKeyForParticipantId(String participantId) {
    for (final snapshot in snapshots) {
      final hasEntry = [
        ...snapshot.starters,
        ...snapshot.bench,
      ].any((entry) => entry.participantId == participantId);
      if (!hasEntry) continue;
      final sideKey = snapshot.sideKey?.trim().toUpperCase();
      if (sideKey == 'A' || sideKey == 'B') return sideKey;
      final currentMatch = match.value;
      if (currentMatch?.teamAId != null &&
          snapshot.teamId == currentMatch!.teamAId) {
        return 'A';
      }
      if (currentMatch?.teamBId != null &&
          snapshot.teamId == currentMatch!.teamBId) {
        return 'B';
      }
      final matchId = currentMatch?.id;
      if (matchId != null) {
        if (snapshot.matchSideId == '${matchId}_A') return 'A';
        if (snapshot.matchSideId == '${matchId}_B') return 'B';
      }
    }
    return null;
  }

  String formationForSnapshot(MatchLineupSnapshot? snapshot) {
    final count = playerCountForSnapshot(snapshot);
    if (snapshot == null) {
      return getDefaultFormation(count);
    }
    final label = snapshot.formationCode ?? snapshot.formationLabel ?? '';
    return isValidFormationForPlayerCount(count, label)
        ? label
        : getDefaultFormation(count);
  }

  int playerCountForSnapshot(MatchLineupSnapshot? snapshot) {
    return normalizeMatchTeamSize(
      snapshot?.playerCount ?? match.value?.teamSize,
    );
  }

  Map<String, LineupPlayer> playersByKeyForSnapshot(
    MatchLineupSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return const {};
    }
    final players = [
      ...snapshot.starters,
      ...snapshot.bench,
    ].map(_lineupPlayerFromEntry);
    return {for (final player in players) player.key: player};
  }

  List<FormationSlot> slotsForSnapshot(MatchLineupSnapshot? snapshot) {
    if (snapshot == null) {
      final count = playerCountForSnapshot(null);
      return FormationEngine.generateFormationSlots(
        playerCount: count,
        formationCode: getDefaultFormation(count),
      );
    }

    // Exact saved rendering is only safe when every starter has complete data.
    if (_hasCompleteSavedAssignments(snapshot)) {
      return _slotsFromSavedAssignment(snapshot);
    }

    // Legacy fallback: auto-assign players to generated formation slots.
    final count = playerCountForSnapshot(snapshot);
    final formation = formationForSnapshot(snapshot);
    final generated = FormationEngine.generateFormationSlots(
      playerCount: count,
      formationCode: formation,
    );
    final starters = snapshot.starters.map(_lineupPlayerFromEntry).toList();
    return LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: starters,
    ).slots;
  }

  /// Builds [FormationSlot] instances from the exact positions saved inside
  /// each [MatchLineupEntry] of the snapshot.
  List<FormationSlot> _slotsFromSavedAssignment(MatchLineupSnapshot snapshot) {
    return snapshot.starters
        .map((entry) {
          final player = _lineupPlayerFromEntry(entry);
          return FormationSlot(
            id: entry.slotId!,
            role: _parseSlotRole(entry.slotRole)!,
            lineIndex: entry.lineIndex!,
            slotIndex: entry.slotIndex!,
            x: entry.slotX ?? 50,
            y: entry.slotY ?? 50,
            playerId: player.isRegistered ? player.id : null,
            guestPlayerId: player.isGuest ? player.id : null,
            matchSidePlayerId: player.isTemporary ? player.id : null,
          );
        })
        .toList(growable: false);
  }

  bool _hasCompleteSavedAssignments(MatchLineupSnapshot snapshot) {
    if (snapshot.starters.isEmpty) {
      return false;
    }
    return snapshot.starters.every(_hasCompleteSavedAssignment);
  }

  bool _hasCompleteSavedAssignment(MatchLineupEntry entry) {
    final slotId = entry.slotId;
    return slotId != null &&
        slotId.trim().isNotEmpty &&
        _parseSlotRole(entry.slotRole) != null &&
        entry.lineIndex != null &&
        entry.slotIndex != null &&
        entry.slotX != null &&
        entry.slotY != null;
  }

  SlotRole? _parseSlotRole(String? raw) {
    if (raw == null) return null;
    for (final role in SlotRole.values) {
      if (role.name == raw) return role;
    }
    return null;
  }

  List<LineupPlayer> benchForSnapshot(MatchLineupSnapshot? snapshot) {
    if (snapshot == null) {
      return const [];
    }
    return snapshot.bench.map(_lineupPlayerFromEntry).toList(growable: false);
  }

  MatchLineupSnapshot? _snapshotForSide({
    required String sideKey,
    required String? teamId,
  }) {
    if (teamId != null) {
      for (final snapshot in snapshots) {
        if (snapshot.teamId == teamId) {
          return snapshot;
        }
      }
    }
    final currentMatch = match.value;
    final matchSideId = currentMatch == null
        ? null
        : '${currentMatch.id}_${sideKey.trim().toUpperCase()}';
    if (matchSideId == null) return null;
    for (final snapshot in snapshots) {
      if (snapshot.matchSideId == matchSideId ||
          snapshot.sideKey?.trim().toUpperCase() ==
              sideKey.trim().toUpperCase()) {
        return snapshot;
      }
    }
    return null;
  }

  LineupPlayer _lineupPlayerFromEntry(MatchLineupEntry entry) {
    return LineupPlayer(
      id: entry.participantId,
      name: entry.displayName,
      preferredPosition: entry.position,
      isRegistered: entry.playerId != null,
      isTemporary: entry.matchSidePlayerId != null,
    );
  }

  FriendlyMatchSideView? _friendlySideView(String sideKey) {
    final currentMatch = match.value;
    if (currentMatch == null || currentMatch.tournamentId != null) {
      return null;
    }
    final views = FriendlyMatchSideView.fromMatch(
      match: currentMatch,
      teamsById: teams,
      sides: matchSides,
      sidePlayers: matchSidePlayers,
    );
    for (final side in views) {
      if (side.sideKey == sideKey) return side;
    }
    return null;
  }

  Future<MatchEvent?> _loadMvpEventSafely(String matchId) async {
    try {
      return await _matchEventService.getMvpEvent(matchId);
    } catch (error) {
      AppLogger.warning(
        'MatchResultLineupController._loadMvpEventSafely',
        error,
      );
      return null;
    }
  }

  Future<List<MatchEvent>> _loadGoalEventsSafely(String matchId) async {
    try {
      final events = await _matchEventService.getMatchEvents(matchId);
      return events
          .where((event) => event.isActive && event.isGoal)
          .toList(growable: false);
    } catch (error) {
      AppLogger.warning(
        'MatchResultLineupController._loadGoalEventsSafely',
        error,
      );
      return const <MatchEvent>[];
    }
  }

  Future<String> _loadTournamentNameSafely(String? tournamentId) async {
    final normalized = tournamentId?.trim();
    if (normalized == null || normalized.isEmpty) return '';
    try {
      return (await _tournamentRepository.getTournament(
            normalized,
          ))?.name.trim() ??
          '';
    } catch (error) {
      AppLogger.warning(
        'MatchResultLineupController._loadTournamentNameSafely',
        error,
      );
      return '';
    }
  }

  MatchLineupEntry? _lineupEntryForParticipantId(String participantId) {
    for (final snapshot in snapshots) {
      for (final entry in [...snapshot.starters, ...snapshot.bench]) {
        if (entry.participantId == participantId) return entry;
      }
    }
    return null;
  }

  MvpPublicProfileTarget? _profileTargetForKindAndId(
    ParticipantRefKind kind,
    String id,
  ) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    if (kind == ParticipantRefKind.player ||
        kind == ParticipantRefKind.guestPlayer) {
      return MvpPublicProfileTarget(kind: kind, id: normalizedId);
    }
    return null;
  }

  String _readableError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}
