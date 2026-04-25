import 'package:get/get.dart';

import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_lineup_entry.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/team.dart';

class ResultLineupSide {
  final String label;
  final String? logoUrl;
  final MatchLineupSnapshot? snapshot;

  const ResultLineupSide({required this.label, this.logoUrl, this.snapshot});
}

class MatchResultLineupController extends GetxController {
  final MatchRepositoryImpl _matchRepository;
  final TeamRepositoryImpl _teamRepository;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepository;

  MatchResultLineupController({
    required MatchRepositoryImpl matchRepository,
    required TeamRepositoryImpl teamRepository,
    required MatchLineupSnapshotRepositoryImpl snapshotRepository,
  }) : _matchRepository = matchRepository,
       _teamRepository = teamRepository,
       _snapshotRepository = snapshotRepository;

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Match?> match = Rx<Match?>(null);
  final RxMap<String, Team> teams = <String, Team>{}.obs;
  final RxList<MatchLineupSnapshot> snapshots = <MatchLineupSnapshot>[].obs;

  String get matchId => Get.parameters['matchId'] ?? Get.parameters['id'] ?? '';

  ResultLineupSide get homeSide {
    final currentMatch = match.value;
    final teamId = currentMatch?.teamAId;
    final team = teamId == null ? null : teams[teamId];
    return ResultLineupSide(
      label: team?.name ?? 'الفريق الأول',
      logoUrl: team?.logoUrl,
      snapshot: _snapshotForTeam(teamId),
    );
  }

  ResultLineupSide get awaySide {
    final currentMatch = match.value;
    final teamId = currentMatch?.teamBId;
    final team = teamId == null ? null : teams[teamId];
    return ResultLineupSide(
      label: team?.name ?? 'الفريق الثاني',
      logoUrl: team?.logoUrl,
      snapshot: _snapshotForTeam(teamId),
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

      match.value = loadedMatch;
      snapshots.assignAll(loadedSnapshots);
      teams.assignAll({for (final team in loadedTeams) team.id: team});
    } catch (error) {
      errorMessage.value = _readableError(error);
    } finally {
      isLoading.value = false;
    }
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

  MatchLineupSnapshot? _snapshotForTeam(String? teamId) {
    if (teamId == null) {
      return null;
    }
    for (final snapshot in snapshots) {
      if (snapshot.teamId == teamId) {
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
      isRegistered: !entry.isGuest,
    );
  }

  String _readableError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}
