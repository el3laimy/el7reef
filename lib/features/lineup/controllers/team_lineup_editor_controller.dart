import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/match_status.dart';
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

part 'team_lineup_editor_ops.dart';

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
  final RxBool isLineupDirty = false.obs;
  final Rxn<LineupDragPayload> selectedLineupPayload = Rxn<LineupDragPayload>();
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
  bool get canEdit {
    final status = match.value?.status;
    final isMatchActive =
        status == MatchStatus.open || status == MatchStatus.full;
    return isMatchActive && !isSaving.value;
  }

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

  String? get selectedLineupPlayerKey =>
      selectedLineupPayload.value?.player.key;

  String? get selectedLineupPlayerName =>
      selectedLineupPayload.value?.player.name;

  bool get selectedLineupPlayerCanMoveToBench =>
      selectedLineupPayload.value?.sourceSlotId != null;

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
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
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
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
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
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
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
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
  }

  void dropPlayerOnSlot(LineupDragPayload payload, FormationSlot targetSlot) {
    if (!canEdit) return;
    _assignUniqueSlots(
      LineupUtils.movePlayerToSlot(
        slots: slots,
        payload: payload,
        targetSlotId: targetSlot.id,
      ),
    );
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
  }

  void movePlayerToBench(LineupPlayer player) {
    if (!canEdit) return;
    slots.assignAll(
      LineupUtils.removePlayerFromSlots(slots: slots, player: player),
    );
    isLineupDirty.value = true;
    selectedLineupPayload.value = null;
  }

  void selectLineupPlayer(LineupPlayer player, {String? sourceSlotId}) {
    if (!canEdit) return;
    final current = selectedLineupPayload.value;
    if (current?.player.key == player.key &&
        current?.sourceSlotId == sourceSlotId) {
      selectedLineupPayload.value = null;
      return;
    }
    selectedLineupPayload.value = LineupDragPayload(
      player: player,
      sourceSlotId: sourceSlotId,
    );
  }

  bool moveSelectedLineupPlayerToSlot(FormationSlot targetSlot) {
    final payload = selectedLineupPayload.value;
    if (!canEdit || payload == null) return false;
    if (payload.sourceSlotId == targetSlot.id) {
      selectedLineupPayload.value = null;
      return true;
    }
    dropPlayerOnSlot(payload, targetSlot);
    selectedLineupPayload.value = null;
    return true;
  }

  bool moveSelectedLineupPlayerToBench() {
    final payload = selectedLineupPayload.value;
    if (!canEdit || payload == null || payload.fromBench) {
      return false;
    }
    movePlayerToBench(payload.player);
    selectedLineupPayload.value = null;
    return true;
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
    isLineupDirty.value = false;
    selectedLineupPayload.value = null;
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

    final hasSavedSlots = snapshot.starters.any(
      (entry) => entry.hasSlotAssignment,
    );
    if (hasSavedSlots) {
      final generated = FormationEngine.generateFormationSlots(
        playerCount: count,
        formationCode: code,
      );
      final slotMap = {for (final slot in generated) slot.id: slot};
      for (final entry in snapshot.starters) {
        if (entry.hasSlotAssignment && entry.slotId != null) {
          final slot = slotMap[entry.slotId];
          if (slot != null) {
            final player = _playerFromSnapshotEntry(entry);
            slotMap[entry.slotId!] = slot.copyWith(
              role: _parseSlotRole(entry.slotRole),
              lineIndex: entry.lineIndex ?? slot.lineIndex,
              slotIndex: entry.slotIndex ?? slot.slotIndex,
              x: entry.slotX ?? slot.x,
              y: entry.slotY ?? slot.y,
              playerId: player.isRegistered ? player.id : null,
              guestPlayerId: player.isGuest ? player.id : null,
              matchSidePlayerId: player.isTemporary ? player.id : null,
            );
          }
        }
      }
      slots.assignAll(slotMap.values.toList());
    } else {
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
    isLineupDirty.value = false;
    selectedLineupPayload.value = null;

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
