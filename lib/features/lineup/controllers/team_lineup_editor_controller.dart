import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../core/services/matchday_service.dart';
import '../../../core/services/team_roster_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_lineup_entry.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_membership.dart';
import '../../../domain/entities/tournament.dart';

class TeamLineupEditorMember {
  final TeamMembership membership;
  final LineupPlayer player;

  const TeamLineupEditorMember({
    required this.membership,
    required this.player,
  });
}

class TeamLineupEditorController extends GetxController {
  final AuthSession _authSession;
  final MatchRepositoryImpl _matchRepository;
  final TeamRepositoryImpl _teamRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final TeamMembershipRepositoryImpl _membershipRepository;
  final PlayerRepositoryImpl _playerRepository;
  final GuestPlayerRepositoryImpl _guestPlayerRepository;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepository;
  final MatchdayService _matchdayService;
  final TeamRosterService _teamRosterService;
  final Uuid _uuid;

  TeamLineupEditorController({
    required AuthSession authSession,
    required MatchRepositoryImpl matchRepository,
    required TeamRepositoryImpl teamRepository,
    required TournamentRepositoryImpl tournamentRepository,
    required TeamMembershipRepositoryImpl membershipRepository,
    required PlayerRepositoryImpl playerRepository,
    required GuestPlayerRepositoryImpl guestPlayerRepository,
    required MatchLineupSnapshotRepositoryImpl snapshotRepository,
    required MatchdayService matchdayService,
    required TeamRosterService teamRosterService,
    Uuid? uuid,
  }) : _authSession = authSession,
       _matchRepository = matchRepository,
       _teamRepository = teamRepository,
       _tournamentRepository = tournamentRepository,
       _membershipRepository = membershipRepository,
       _playerRepository = playerRepository,
       _guestPlayerRepository = guestPlayerRepository,
       _snapshotRepository = snapshotRepository,
       _matchdayService = matchdayService,
       _teamRosterService = teamRosterService,
       _uuid = uuid ?? const Uuid();

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<Match?> match = Rx<Match?>(null);
  final Rx<Team?> team = Rx<Team?>(null);
  final Rx<Tournament?> tournament = Rx<Tournament?>(null);
  final Rx<MatchLineupSnapshot?> confirmedSnapshot = Rx<MatchLineupSnapshot?>(
    null,
  );

  final RxList<TeamLineupEditorMember> members = <TeamLineupEditorMember>[].obs;
  final RxList<FormationSlot> slots = <FormationSlot>[].obs;
  final RxInt playerCount = 5.obs;
  final RxString formationCode = getDefaultFormation(5).obs;

  String get matchId => Get.parameters['matchId'] ?? Get.parameters['id'] ?? '';
  String get teamId => Get.parameters['teamId'] ?? '';
  String? get currentUserId => _authSession.currentUserId;
  bool get isConfirmed => confirmedSnapshot.value != null;
  bool get canEdit => !isConfirmed && !isSaving.value;
  String get teamName => team.value?.name ?? 'الفريق';
  String? get teamLogoUrl => team.value?.logoUrl;

  Map<String, LineupPlayer> get playersByKey => {
    for (final member in members) member.player.key: member.player,
  };

  List<LineupPlayer> get benchPlayers {
    final onPitch = slots
        .map((slot) => slot.occupantKey)
        .whereType<String>()
        .toSet();
    return members
        .where(
          (member) => member.membership.status != TeamMembershipStatus.inactive,
        )
        .map((member) => member.player)
        .where((player) => !onPitch.contains(player.key))
        .toList(growable: false);
  }

  List<String> get starterMembershipIds {
    return slots
        .map((slot) => slot.playerId ?? slot.guestPlayerId)
        .whereType<String>()
        .toList(growable: false);
  }

  List<String> get benchMembershipIds {
    final starters = starterMembershipIds.toSet();
    return members
        .where(
          (member) => member.membership.status != TeamMembershipStatus.inactive,
        )
        .map((member) => member.membership.id)
        .where((id) => !starters.contains(id))
        .toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    loadLineup();
  }

  Future<void> loadLineup() async {
    if (matchId.isEmpty || teamId.isEmpty) {
      errorMessage.value = 'رابط شاشة التشكيلة غير مكتمل.';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedMatch = await _matchRepository.getMatch(matchId);
      final loadedTeam = await _teamRepository.getTeam(teamId);
      if (loadedMatch == null || loadedTeam == null) {
        throw Exception('تعذر تحميل المباراة أو الفريق.');
      }
      final loadedTournament = loadedMatch.tournamentId == null
          ? null
          : await _tournamentRepository.getTournament(
              loadedMatch.tournamentId!,
            );
      final snapshot = await _snapshotRepository.getSnapshotByTeamId(
        matchId: matchId,
        teamId: teamId,
      );

      match.value = loadedMatch;
      team.value = loadedTeam;
      tournament.value = loadedTournament;
      confirmedSnapshot.value = snapshot;

      if (snapshot != null) {
        _seedFromSnapshot(snapshot);
      } else {
        await _seedEditableRoster(loadedMatch, loadedTournament);
      }
    } catch (error) {
      errorMessage.value = _readableError(error);
    } finally {
      isLoading.value = false;
    }
  }

  void changePlayerCount(int count) {
    if (!canEdit) return;
    final nextCount = clampSupportedPlayerCount(count);
    final previousStarters = starterMembershipIds.toSet();
    playerCount.value = nextCount;
    if (!isValidFormationForPlayerCount(nextCount, formationCode.value)) {
      formationCode.value = getDefaultFormation(nextCount);
    }
    final generated = FormationEngine.generateFormationSlots(
      playerCount: nextCount,
      formationCode: formationCode.value,
    );
    final result = LineupUtils.preserveAssignments(
      oldSlots: slots,
      newSlots: generated,
      playersByKey: playersByKey,
    );
    slots.assignAll(result.slots);
    final moved = previousStarters
        .difference(starterMembershipIds.toSet())
        .length;
    if (moved > 0) {
      Get.snackbar('تم تحديث الخطة', 'تم نقل $moved لاعب إلى البدلاء.');
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
    final result = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: currentStarters,
    );
    slots.assignAll(result.slots);
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
    if (targetIndex == -1 || sourceIndex == targetIndex) {
      return;
    }

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

    final targetPlayerId = oldTargetSlot.playerId;
    final targetGuestPlayerId = oldTargetSlot.guestPlayerId;
    final targetMatchSidePlayerId = oldTargetSlot.matchSidePlayerId;
    final targetIsCaptain = oldTargetSlot.isCaptain;
    updatedSlots[targetIndex] = oldTargetSlot.assignPlayer(draggedPlayer);
    updatedSlots[sourceIndex] = oldSourceSlot.copyWith(
      playerId: targetPlayerId,
      guestPlayerId: targetGuestPlayerId,
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

  Future<bool> addGuestPlayer(String name, {int? number}) async {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('خطأ', 'اسم اللاعب الضيف مطلوب.');
      return false;
    }

    final now = DateTime.now();
    final guestPlayer = GuestPlayer(
      id: _uuid.v4(),
      displayName: trimmed,
      normalizedName: trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      jerseyNumber: number,
      teamId: teamId,
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      isSaving.value = true;
      await _guestPlayerRepository.createGuestPlayer(guestPlayer);
      await _teamRosterService.addGuestPlayer(
        teamId: teamId,
        actorId: actorId,
        guestPlayerId: guestPlayer.id,
        status: TeamMembershipStatus.bench,
        availability: TeamMemberAvailability.available,
      );
      await loadLineup();
      Get.snackbar('تم', 'تمت إضافة ${guestPlayer.displayName} إلى البدلاء.');
      return true;
    } catch (error) {
      Get.snackbar('خطأ', _readableError(error));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveConfirmedLineup() async {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    final starters = starterMembershipIds;
    var allowIncompleteFriendlyLineup = false;
    if (starters.length != playerCount.value) {
      final currentMatch = match.value;
      final isFriendly =
          currentMatch != null &&
          currentMatch.tournamentId == null &&
          !currentMatch.isOrganized;
      if (!isFriendly) {
        Get.snackbar(
          'التشكيلة غير مكتملة',
          'أكمل ${playerCount.value} لاعبين أساسيين قبل حفظ التشكيلة.',
        );
        return;
      }
      final confirmed = await _confirmIncompleteFriendlyLineup(
        selectedStarters: starters.length,
      );
      if (!confirmed) {
        return;
      }
      allowIncompleteFriendlyLineup = true;
    }

    try {
      isSaving.value = true;
      final attendanceStatuses = <String, MatchAttendanceStatus>{
        for (final member in members)
          member.membership.id:
              member.membership.status == TeamMembershipStatus.inactive
              ? MatchAttendanceStatus.absent
              : MatchAttendanceStatus.present,
      };
      await _matchdayService.checkInRegisteredTeam(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        membershipStatuses: attendanceStatuses,
      );
      final result = await _matchdayService.lockRegisteredTeamLineup(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        starterMembershipIds: starters,
        benchMembershipIds: benchMembershipIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
        formationCode: formationCode.value,
        formationLabel: formationCode.value,
        slotAssignments: _buildSlotAssignments(),
      );
      confirmedSnapshot.value = result.snapshot;
      _seedFromSnapshot(result.snapshot);
      Get.snackbar('تم حفظ التشكيلة', 'تم تثبيت نسخة المباراة بنجاح.');
    } catch (error) {
      Get.snackbar('تعذر حفظ التشكيلة', _readableError(error));
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _seedEditableRoster(
    Match loadedMatch,
    Tournament? loadedTournament,
  ) async {
    final memberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );
    final playerIds = memberships
        .map((membership) => membership.playerId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final guestIds = memberships
        .map((membership) => membership.guestPlayerId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final players = {
      for (final player in await _playerRepository.getPlayersByIds(playerIds))
        player.id: player,
    };
    final guests = {
      for (final guest in await _guestPlayerRepository.getGuestPlayersByIds(
        guestIds,
      ))
        guest.id: guest,
    };
    final resolvedMembers = memberships
        .map((membership) => _memberFromMembership(membership, players, guests))
        .toList(growable: false);
    members.assignAll(resolvedMembers);

    final defaultCount = normalizeMatchTeamSize(
      loadedTournament?.teamSize.value ?? loadedMatch.teamSize,
    );
    playerCount.value = defaultCount;
    formationCode.value = getDefaultFormation(defaultCount);
    final generated = FormationEngine.generateFormationSlots(
      playerCount: playerCount.value,
      formationCode: formationCode.value,
    );
    final starters = resolvedMembers
        .where(
          (member) => member.membership.status == TeamMembershipStatus.starter,
        )
        .map((member) => member.player)
        .toList(growable: false);
    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: starters,
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
    final lineupPlayers = snapshot.starters
        .map(_playerFromSnapshotEntry)
        .toList(growable: false);

    // If snapshot carries exact slot positions, use them directly.
    final hasSavedSlots = snapshot.starters.any(
      (entry) => entry.hasSlotAssignment,
    );
    if (hasSavedSlots) {
      slots.assignAll(
        snapshot.starters
            .map((entry) {
              final player = _playerFromSnapshotEntry(entry);
              return FormationSlot(
                id: entry.slotId!,
                role: _parseSlotRole(entry.slotRole),
                lineIndex: entry.lineIndex ?? 0,
                slotIndex: entry.slotIndex ?? 0,
                x: entry.slotX ?? 50,
                y: entry.slotY ?? 50,
                playerId: player.isRegistered ? player.id : null,
                guestPlayerId: player.isGuest ? player.id : null,
                matchSidePlayerId: player.isTemporary ? player.id : null,
              );
            })
            .toList(growable: false),
      );
    } else {
      // Legacy fallback: auto-assign players to generated formation.
      final generated = FormationEngine.generateFormationSlots(
        playerCount: count,
        formationCode: code,
      );
      final assigned = LineupUtils.assignPlayersToGeneratedSlots(
        slots: generated,
        starters: lineupPlayers,
      );
      slots.assignAll(assigned.slots);
    }

    members.assignAll(
      [...snapshot.starters, ...snapshot.bench].map((entry) {
        final player = _playerFromSnapshotEntry(entry);
        return TeamLineupEditorMember(
          membership: TeamMembership(
            id: player.id,
            teamId: teamId,
            playerId: player.isRegistered ? player.id : null,
            guestPlayerId: player.isRegistered ? null : player.id,
            status: snapshot.starters.contains(entry)
                ? TeamMembershipStatus.starter
                : TeamMembershipStatus.bench,
            joinedAt: snapshot.lockedAt,
            updatedAt: snapshot.lockedAt,
          ),
          player: player,
        );
      }),
    );
  }

  SlotRole _parseSlotRole(String? raw) {
    if (raw == null) return SlotRole.mid;
    for (final role in SlotRole.values) {
      if (role.name == raw) return role;
    }
    return SlotRole.mid;
  }

  TeamLineupEditorMember _memberFromMembership(
    TeamMembership membership,
    Map<String, Player> players,
    Map<String, GuestPlayer> guests,
  ) {
    if (membership.playerId != null) {
      final player = players[membership.playerId!];
      return TeamLineupEditorMember(
        membership: membership,
        player: LineupPlayer(
          id: membership.id,
          name: player?.name ?? 'لاعب مسجل',
          username: player?.username,
          photoUrl: player?.photoThumbUrl ?? player?.photoUrl,
          preferredPosition: player?.position,
          isRegistered: true,
        ),
      );
    }
    final guest = guests[membership.guestPlayerId!];
    return TeamLineupEditorMember(
      membership: membership,
      player: LineupPlayer(
        id: membership.id,
        name: guest?.displayName ?? 'لاعب ضيف',
        number: guest?.jerseyNumber,
        preferredPosition: guest?.preferredPosition,
        isRegistered: false,
      ),
    );
  }

  LineupPlayer _playerFromSnapshotEntry(MatchLineupEntry entry) {
    return LineupPlayer(
      id: entry.teamMembershipId ?? entry.participantId,
      name: entry.displayName,
      preferredPosition: entry.position,
      isRegistered: entry.playerId != null,
      isTemporary: entry.matchSidePlayerId != null,
    );
  }

  /// Builds [SlotAssignment] list from the current pitch slots, mapping each
  /// occupied slot to the corresponding membership ID.
  List<SlotAssignment> _buildSlotAssignments() {
    final assignments = <SlotAssignment>[];
    for (final slot in slots) {
      if (slot.isEmpty) continue;
      final membershipId = slot.playerId ?? slot.guestPlayerId;
      if (membershipId == null) continue;
      assert(!membershipId.startsWith('player:'));
      assert(!membershipId.startsWith('guest:'));
      assignments.add(
        SlotAssignment(
          membershipId: membershipId,
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

  void _assignUniqueSlots(List<FormationSlot> updatedSlots) {
    assert(_hasUniqueOccupants(updatedSlots));
    if (!_hasUniqueOccupants(updatedSlots)) {
      return;
    }
    slots.assignAll(updatedSlots);
  }

  bool _hasUniqueOccupants(List<FormationSlot> value) {
    final seen = <String>{};
    for (final slot in value) {
      final key = slot.occupantKey;
      if (key == null) continue;
      if (!seen.add(key)) {
        return false;
      }
    }
    return true;
  }

  String _readableError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  Future<bool> _confirmIncompleteFriendlyLineup({
    required int selectedStarters,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('التشكيلة غير مكتملة'),
        content: Text(
          'تم اختيار $selectedStarters من أصل ${playerCount.value} لاعبين. '
          'هذه مباراة ودية، هل تريد حفظ التشكيلة بهذه الخانات الفارغة؟',
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
}
