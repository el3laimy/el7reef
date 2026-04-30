import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../core/services/matchday_service.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_lineup_entry.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';

class MatchSideLineupEditorController extends GetxController {
  final AuthSession _authSession;
  final MatchRepositoryImpl _matchRepository;
  final MatchSideRepositoryImpl _matchSideRepository;
  final MatchSidePlayerRepositoryImpl _matchSidePlayerRepository;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepository;
  final MatchdayService _matchdayService;

  MatchSideLineupEditorController({
    required AuthSession authSession,
    required MatchRepositoryImpl matchRepository,
    required MatchSideRepositoryImpl matchSideRepository,
    required MatchSidePlayerRepositoryImpl matchSidePlayerRepository,
    required MatchLineupSnapshotRepositoryImpl snapshotRepository,
    required MatchdayService matchdayService,
  }) : _authSession = authSession,
       _matchRepository = matchRepository,
       _matchSideRepository = matchSideRepository,
       _matchSidePlayerRepository = matchSidePlayerRepository,
       _snapshotRepository = snapshotRepository,
       _matchdayService = matchdayService;

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<Match?> match = Rx<Match?>(null);
  final Rx<MatchSide?> matchSide = Rx<MatchSide?>(null);
  final Rx<MatchLineupSnapshot?> confirmedSnapshot = Rx<MatchLineupSnapshot?>(
    null,
  );
  final RxList<LineupPlayer> roster = <LineupPlayer>[].obs;
  final RxList<FormationSlot> slots = <FormationSlot>[].obs;
  final RxInt playerCount = 5.obs;
  final RxString formationCode = getDefaultFormation(5).obs;

  String get matchId => Get.parameters['matchId'] ?? Get.parameters['id'] ?? '';
  String get sideKey =>
      (Get.parameters['sideKey'] ?? Get.parameters['side'] ?? '')
          .trim()
          .toUpperCase();
  String? get currentUserId => _authSession.currentUserId;
  bool get isConfirmed => confirmedSnapshot.value != null;
  bool get canEdit => !isConfirmed && !isSaving.value;
  String get sideName => matchSide.value?.displayName ?? 'فريق $sideKey';

  Map<String, LineupPlayer> get playersByKey => {
    for (final player in roster) player.key: player,
  };

  List<LineupPlayer> get benchPlayers {
    final onPitch = slots
        .map((slot) => slot.occupantKey)
        .whereType<String>()
        .toSet();
    return roster
        .where((player) => !onPitch.contains(player.key))
        .toList(growable: false);
  }

  List<String> get starterMatchSidePlayerIds {
    return slots
        .map((slot) => slot.matchSidePlayerId)
        .whereType<String>()
        .toList(growable: false);
  }

  List<String> get benchMatchSidePlayerIds {
    final starters = starterMatchSidePlayerIds.toSet();
    return roster
        .map((player) => player.id)
        .where((id) => !starters.contains(id))
        .toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    loadLineup();
  }

  Future<void> loadLineup() async {
    if (matchId.isEmpty || (sideKey != 'A' && sideKey != 'B')) {
      errorMessage.value = 'رابط تشكيلة الطرف المؤقت غير مكتمل.';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loadedMatch = await _matchRepository.getMatch(matchId);
      if (loadedMatch == null) {
        throw Exception('تعذر تحميل المباراة.');
      }
      if (loadedMatch.tournamentId != null &&
          loadedMatch.tournamentId!.isNotEmpty) {
        throw Exception('تشكيلة الطرف المؤقت متاحة للمباريات الودية فقط.');
      }

      final side = await _matchSideRepository.getSide(
        matchId: matchId,
        sideKey: sideKey,
      );
      if (side == null) {
        throw Exception('طرف المباراة المؤقت غير موجود. افتح اللوبي أولاً.');
      }
      if (!side.isTemporary) {
        throw Exception('هذا الطرف فريق رسمي، استخدم محرر الفريق الرسمي.');
      }
      _ensureCanEditSide(loadedMatch, side);

      final sidePlayers = await _matchSidePlayerRepository.getPlayersForSide(
        matchId: matchId,
        sideKey: sideKey,
      );
      final snapshot = await _snapshotRepository.getSnapshotByMatchSideId(
        matchId: matchId,
        matchSideId: side.id,
      );

      match.value = loadedMatch;
      matchSide.value = side;
      roster.assignAll(sidePlayers.map(_lineupPlayerFromSidePlayer));
      confirmedSnapshot.value = snapshot;

      if (snapshot != null) {
        _seedFromSnapshot(snapshot);
      } else {
        _seedEditableRoster(loadedMatch);
      }
    } catch (error) {
      errorMessage.value = _readableError(error);
    } finally {
      isLoading.value = false;
    }
  }

  void changeFormation(String code) {
    if (!canEdit || !isValidFormationForPlayerCount(playerCount.value, code)) {
      return;
    }
    formationCode.value = code;
    final generated = FormationEngine.generateFormationSlots(
      playerCount: playerCount.value,
      formationCode: code,
    );
    final result = LineupUtils.preserveAssignments(
      oldSlots: slots,
      newSlots: generated,
      playersByKey: playersByKey,
    );
    slots.assignAll(result.slots);
  }

  void resetLayout() {
    if (!canEdit) return;
    final currentStarters = LineupUtils.playersForSlots(
      slots: slots,
      playersByKey: playersByKey,
    );
    final generated = FormationEngine.generateFormationSlots(
      playerCount: playerCount.value,
      formationCode: formationCode.value,
    );
    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: currentStarters,
    );
    slots.assignAll(assigned.slots);
  }

  void assignPlayerToSlot(LineupPlayer player, FormationSlot slot) {
    if (!canEdit) return;
    slots.assignAll(
      LineupUtils.assignPlayerToSlot(
        slots: slots,
        player: player,
        slotId: slot.id,
      ),
    );
  }

  void dropPlayerOnSlot(LineupPlayer draggedPlayer, FormationSlot targetSlot) {
    if (!canEdit) return;
    final currentSlots = slots.toList(growable: false);
    final draggedKey = draggedPlayer.key;
    final sourceIndex = currentSlots.indexWhere(
      (slot) => slot.occupantKey == draggedKey,
    );
    final targetIndex = currentSlots.indexWhere(
      (slot) => slot.id == targetSlot.id,
    );
    if (targetIndex == -1 || sourceIndex == targetIndex) return;

    final updatedSlots = currentSlots.toList(growable: true);
    final oldTargetSlot = updatedSlots[targetIndex];
    if (sourceIndex == -1) {
      updatedSlots[targetIndex] = oldTargetSlot.assignPlayer(draggedPlayer);
      _assignUniqueSlots(updatedSlots);
      return;
    }

    final oldSourceSlot = updatedSlots[sourceIndex];
    if (oldTargetSlot.isEmpty) {
      updatedSlots[sourceIndex] = oldSourceSlot.clearPlayer();
      updatedSlots[targetIndex] = oldTargetSlot.assignPlayer(draggedPlayer);
      _assignUniqueSlots(updatedSlots);
      return;
    }

    final targetMatchSidePlayerId = oldTargetSlot.matchSidePlayerId;
    final targetIsCaptain = oldTargetSlot.isCaptain;
    updatedSlots[targetIndex] = oldTargetSlot.assignPlayer(draggedPlayer);
    updatedSlots[sourceIndex] = oldSourceSlot.copyWith(
      playerId: null,
      guestPlayerId: null,
      matchSidePlayerId: targetMatchSidePlayerId,
      isCaptain: targetIsCaptain,
    );
    _assignUniqueSlots(updatedSlots);
  }

  void movePlayerToBench(LineupPlayer player) {
    if (!canEdit) return;
    slots.assignAll(
      LineupUtils.removePlayerFromSlots(slots: slots, player: player),
    );
  }

  Future<bool> saveConfirmedLineup() async {
    final actorId = currentUserId;
    final side = matchSide.value;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return false;
    }
    if (side == null) {
      Get.snackbar('خطأ', 'تعذر تحديد طرف المباراة.');
      return false;
    }
    if (starterMatchSidePlayerIds.length != playerCount.value) {
      final confirmed = await _confirmIncompleteLineup();
      if (!confirmed) return false;
    }

    try {
      isSaving.value = true;
      final snapshot = await _matchdayService.lockMatchSideLineup(
        matchId: matchId,
        matchSideId: side.id,
        sideKey: sideKey,
        actorId: actorId,
        starterMatchSidePlayerIds: starterMatchSidePlayerIds,
        benchMatchSidePlayerIds: benchMatchSidePlayerIds,
        formationCode: formationCode.value,
        formationLabel: formationCode.value,
        slotAssignments: _buildSlotAssignments(),
      );
      confirmedSnapshot.value = snapshot;
      _seedFromSnapshot(snapshot);
      return true;
    } catch (error) {
      Get.snackbar('تعذر حفظ التشكيلة', _readableError(error));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _seedEditableRoster(Match loadedMatch) {
    final count = normalizeMatchTeamSize(loadedMatch.teamSize);
    playerCount.value = count;
    formationCode.value = getDefaultFormation(count);
    final generated = FormationEngine.generateFormationSlots(
      playerCount: count,
      formationCode: formationCode.value,
    );
    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: roster.take(count).toList(growable: false),
    );
    slots.assignAll(assigned.slots);
  }

  void _seedFromSnapshot(MatchLineupSnapshot snapshot) {
    final count = normalizeMatchTeamSize(
      snapshot.playerCount ?? match.value?.teamSize ?? snapshot.starters.length,
    );
    final savedCode = snapshot.formationCode ?? snapshot.formationLabel ?? '';
    final code = isValidFormationForPlayerCount(count, savedCode)
        ? savedCode
        : getDefaultFormation(count);
    playerCount.value = count;
    formationCode.value = code;
    roster.assignAll(
      [
        ...snapshot.starters,
        ...snapshot.bench,
      ].map(_lineupPlayerFromEntry).toList(growable: false),
    );

    if (_hasCompleteSavedAssignments(snapshot)) {
      slots.assignAll(
        snapshot.starters
            .map((entry) {
              final player = _lineupPlayerFromEntry(entry);
              return FormationSlot(
                id: entry.slotId!,
                role: _parseSlotRole(entry.slotRole) ?? SlotRole.mid,
                lineIndex: entry.lineIndex!,
                slotIndex: entry.slotIndex!,
                x: entry.slotX ?? 50,
                y: entry.slotY ?? 50,
                matchSidePlayerId: player.id,
              );
            })
            .toList(growable: false),
      );
      return;
    }

    final generated = FormationEngine.generateFormationSlots(
      playerCount: count,
      formationCode: code,
    );
    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: snapshot.starters.map(_lineupPlayerFromEntry).toList(),
    );
    slots.assignAll(assigned.slots);
  }

  LineupPlayer _lineupPlayerFromSidePlayer(MatchSidePlayer player) {
    return LineupPlayer(
      id: player.id,
      name: player.displayName,
      number: player.shirtNumber,
      preferredPosition: player.position,
      isRegistered: false,
      isTemporary: true,
    );
  }

  LineupPlayer _lineupPlayerFromEntry(MatchLineupEntry entry) {
    return LineupPlayer(
      id: entry.matchSidePlayerId ?? entry.participantId,
      name: entry.displayName,
      preferredPosition: entry.position,
      isRegistered: false,
      isTemporary: true,
    );
  }

  List<SlotAssignment> _buildSlotAssignments() {
    final assignments = <SlotAssignment>[];
    for (final slot in slots) {
      if (slot.isEmpty) continue;
      final matchSidePlayerId = slot.matchSidePlayerId;
      if (matchSidePlayerId == null) continue;
      assert(!matchSidePlayerId.startsWith('player:'));
      assert(!matchSidePlayerId.startsWith('guest:'));
      assignments.add(
        SlotAssignment(
          membershipId: matchSidePlayerId,
          slotId: slot.id,
          slotRole: slot.role.name,
          lineIndex: slot.lineIndex,
          slotIndex: slot.slotIndex,
          slotX: slot.x,
          slotY: slot.y,
        ),
      );
    }
    return assignments;
  }

  bool _hasCompleteSavedAssignments(MatchLineupSnapshot snapshot) {
    if (snapshot.starters.isEmpty) return false;
    return snapshot.starters.every((entry) {
      return entry.slotId?.trim().isNotEmpty == true &&
          _parseSlotRole(entry.slotRole) != null &&
          entry.lineIndex != null &&
          entry.slotIndex != null &&
          entry.slotX != null &&
          entry.slotY != null;
    });
  }

  SlotRole? _parseSlotRole(String? raw) {
    if (raw == null) return null;
    for (final role in SlotRole.values) {
      if (role.name == raw) return role;
    }
    return null;
  }

  void _assignUniqueSlots(List<FormationSlot> updatedSlots) {
    assert(_hasUniqueOccupants(updatedSlots));
    if (!_hasUniqueOccupants(updatedSlots)) return;
    slots.assignAll(updatedSlots);
  }

  bool _hasUniqueOccupants(List<FormationSlot> value) {
    final seen = <String>{};
    for (final slot in value) {
      final key = slot.occupantKey;
      if (key == null) continue;
      if (!seen.add(key)) return false;
    }
    return true;
  }

  void _ensureCanEditSide(Match loadedMatch, MatchSide side) {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }
    if (loadedMatch.organizerId == actorId ||
        side.captainUserId == actorId ||
        side.managedByUserIds.contains(actorId)) {
      return;
    }
    throw Exception('لا تملك صلاحية تعديل تشكيلة هذا الطرف.');
  }

  Future<bool> _confirmIncompleteLineup() async {
    final selectedStarters = starterMatchSidePlayerIds.length;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('التشكيلة غير مكتملة'),
        content: Text(
          'تم اختيار $selectedStarters من أصل ${playerCount.value} لاعبين. '
          'هل تريد حفظ التشكيلة بهذه الخانات الفارغة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إكمال التشكيلة'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('حفظ رغم النقص'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _readableError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}
