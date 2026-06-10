import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/team_membership_role.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/services/team_formation_service.dart';
import '../../../core/services/team_roster_service.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_formation_template.dart';
import '../../../domain/entities/team_membership.dart';
import '../../../domain/entities/team_roster_snapshot.dart';
import '../../../domain/repositories/guest_player_repository.dart';
import '../../../domain/repositories/player_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../core/services/share_link_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';

part 'team_roster_ops.dart';

typedef TeamRosterShareText = Future<void> Function(String text);

class TeamRosterMemberViewData {
  final TeamMembership membership;
  final String displayName;
  final String? secondaryText;
  final String? position;
  final String? avatarUrl;
  final bool isGuest;
  final bool isGuestClaimedOrLinked;

  const TeamRosterMemberViewData({
    required this.membership,
    required this.displayName,
    this.secondaryText,
    this.position,
    this.avatarUrl,
    required this.isGuest,
    this.isGuestClaimedOrLinked = false,
  });
}

class TeamRosterController extends GetxController {
  final AuthSession _authSession;
  final TeamRepository _teamRepository;
  final TeamRosterService _teamRosterService;
  final TeamFormationService _teamFormationService;
  final PlayerRepository _playerRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final ShareLinkService _shareLinkService;
  final TeamRosterShareText _shareText;
  final Uuid _uuid;

  TeamRosterController({
    required AuthSession authSession,
    required TeamRepository teamRepository,
    required TeamRosterService teamRosterService,
    required TeamFormationService teamFormationService,
    required PlayerRepository playerRepository,
    required GuestPlayerRepository guestPlayerRepository,
    required ShareLinkService shareLinkService,
    TeamRosterShareText? shareText,
    Uuid? uuid,
  }) : _authSession = authSession,
       _teamRepository = teamRepository,
       _teamRosterService = teamRosterService,
       _teamFormationService = teamFormationService,
       _playerRepository = playerRepository,
       _guestPlayerRepository = guestPlayerRepository,
       _shareLinkService = shareLinkService,
       _shareText =
           shareText ??
           ((text) async {
             await Share.share(text);
           }),
       _uuid = uuid ?? const Uuid();

  final Rxn<Team> team = Rxn<Team>();
  final RxList<TeamRosterMemberViewData> rosterMembers =
      <TeamRosterMemberViewData>[].obs;
  final RxList<Player> playerSearchResults = <Player>[].obs;
  final RxList<TeamFormationTemplate> formationTemplates =
      <TeamFormationTemplate>[].obs;
  final RxList<TeamRosterSnapshot> rosterSnapshots = <TeamRosterSnapshot>[].obs;

  // --- Visual Lineup/Formation Variables ---
  final RxList<FormationSlot> visualSlots = <FormationSlot>[].obs;
  final RxList<LineupPlayer> visualBench = <LineupPlayer>[].obs;
  final RxInt visualPlayerCount = 5.obs;
  final RxString visualFormationCode = getDefaultFormation(5).obs;
  final RxBool isLineupDirty = false.obs;

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isSearchingPlayers = false.obs;
  final RxString errorMessage = ''.obs;

  final registeredSearchController = TextEditingController();
  final guestNameController = TextEditingController();
  final guestPositionController = TextEditingController();
  final guestJerseyController = TextEditingController();
  final templateNameController = TextEditingController();
  final templateFormationController = TextEditingController();
  final snapshotLabelController = TextEditingController();
  final snapshotFormationController = TextEditingController();

  Timer? _searchDebounce;

  String? get teamId => Get.parameters['id'];
  String? get currentUserId => _authSession.currentUserId;

  bool get canManageRoster {
    final currentTeam = team.value;
    final userId = currentUserId;
    if (currentTeam == null || userId == null) {
      return false;
    }
    return currentTeam.ownerId == userId ||
        currentTeam.viceCaptainIds.contains(userId);
  }

  List<TeamRosterMemberViewData> membersByStatus(TeamMembershipStatus status) {
    return rosterMembers
        .where((entry) => entry.membership.status == status)
        .toList(growable: false);
  }

  int countByStatus(TeamMembershipStatus status) {
    return rosterMembers
        .where((entry) => entry.membership.status == status)
        .length;
  }

  String get currentFormationSummary {
    return 'أساسي ${countByStatus(TeamMembershipStatus.starter)} • '
        'احتياط ${countByStatus(TeamMembershipStatus.bench)} • '
        'غير نشط ${countByStatus(TeamMembershipStatus.inactive)}';
  }

  @override
  void onInit() {
    super.onInit();
    registeredSearchController.addListener(_onSearchChanged);
    loadTeamRoster();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    registeredSearchController.dispose();
    guestNameController.dispose();
    guestPositionController.dispose();
    guestJerseyController.dispose();
    templateNameController.dispose();
    templateFormationController.dispose();
    snapshotLabelController.dispose();
    snapshotFormationController.dispose();
    super.onClose();
  }

  Future<void> loadTeamRoster() async {
    final targetTeamId = teamId;
    if (targetTeamId == null || targetTeamId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد الفريق المطلوب.';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedTeam = await _teamRepository.getTeam(targetTeamId);
      if (loadedTeam == null) {
        errorMessage.value = 'الفريق المطلوب غير موجود.';
        team.value = null;
        rosterMembers.clear();
        return;
      }

      team.value = loadedTeam;

      final memberships = await _teamRosterService.getTeamRoster(
        targetTeamId,
        includeInactive: true,
      );
      final templates = await _teamFormationService.getTeamTemplates(
        targetTeamId,
      );
      final snapshots = await _teamFormationService.getRecentSnapshots(
        targetTeamId,
      );

      final resolvedMembers = await Future.wait(
        memberships.map(_buildViewDataForMembership),
      );
      rosterMembers.assignAll(_sortedMembers(resolvedMembers));
      formationTemplates.assignAll(templates);
      rosterSnapshots.assignAll(snapshots);

      initVisualLineup(); // التهيئة البصرية فور تحميل البيانات
    } catch (e) {
      errorMessage.value = _readableError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addRegisteredPlayer(
    Player player, {
    TeamMembershipStatus status = TeamMembershipStatus.bench,
  }) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamRosterService.addRegisteredPlayer(
        teamId: targetTeamId,
        actorId: actorId,
        playerId: player.id,
        status: status,
      );
      clearPlayerSearch();
      await loadTeamRoster();
      Get.back();
      Get.snackbar('تم', 'تمت إضافة ${player.name} إلى قائمة الفريق.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> createGuestPlayerAndAdd({
    required String displayName,
    required TeamMembershipStatus status,
  }) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return;
    }

    final effectiveName = displayName.trim();
    if (effectiveName.isEmpty) {
      Get.snackbar('خطأ', 'اسم اللاعب الضيف مطلوب.');
      return;
    }

    final jerseyNumber = int.tryParse(guestJerseyController.text.trim());
    final now = DateTime.now();
    final guestPlayer = GuestPlayer(
      id: _uuid.v4(),
      displayName: effectiveName,
      normalizedName: _normalizeName(effectiveName),
      jerseyNumber: jerseyNumber,
      preferredPosition: _emptyToNull(guestPositionController.text),
      teamId: targetTeamId,
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      isSubmitting.value = true;
      await _guestPlayerRepository.createGuestPlayer(guestPlayer);
      await _teamRosterService.addGuestPlayer(
        teamId: targetTeamId,
        actorId: actorId,
        guestPlayerId: guestPlayer.id,
        status: status,
      );
      clearGuestForm();
      await loadTeamRoster();
      Get.back();
      Get.snackbar('تم', 'تمت إضافة اللاعب الضيف ${guestPlayer.displayName}.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> changeMemberStatus(
    TeamMembership membership,
    TeamMembershipStatus status,
  ) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamRosterService.updateMembershipStatus(
        teamId: targetTeamId,
        actorId: actorId,
        membershipId: membership.id,
        status: status,
      );
      await loadTeamRoster();
      Get.snackbar('تم', 'تم تحديث حالة اللاعب داخل القائمة.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> changeAvailability(
    TeamMembership membership,
    TeamMemberAvailability availability,
  ) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamRosterService.updateAvailability(
        teamId: targetTeamId,
        actorId: actorId,
        membershipId: membership.id,
        availability: availability,
      );
      await loadTeamRoster();
      Get.snackbar('تم', 'تم تحديث حالة التوفر.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> changeRole(
    TeamMembership membership,
    TeamMembershipRole role,
  ) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamRosterService.updateMembershipRole(
        teamId: targetTeamId,
        actorId: actorId,
        membershipId: membership.id,
        role: role,
      );
      await loadTeamRoster();
      Get.snackbar('تم', 'تم تحديث دور اللاعب داخل الفريق.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> removeMembership(TeamMembership membership) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamRosterService.removeMembership(
        teamId: targetTeamId,
        actorId: actorId,
        membershipId: membership.id,
      );
      await loadTeamRoster();
      Get.snackbar('تم', 'تمت إزالة اللاعب من القائمة النشطة.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  void clearPlayerSearch() {
    registeredSearchController.clear();
    playerSearchResults.clear();
    isSearchingPlayers.value = false;
  }

  void clearGuestForm() {
    guestNameController.clear();
    guestPositionController.clear();
    guestJerseyController.clear();
  }

  void clearTemplateForm() {
    templateNameController.clear();
    templateFormationController.clear();
  }

  void clearSnapshotForm() {
    snapshotLabelController.clear();
    snapshotFormationController.clear();
  }

  Future<TeamRosterMemberViewData> _buildViewDataForMembership(
    TeamMembership membership,
  ) async {
    if (membership.playerId != null) {
      final player = await _playerRepository.getPlayer(membership.playerId!);
      return TeamRosterMemberViewData(
        membership: membership,
        displayName: player?.name ?? membership.playerId!,
        secondaryText: player?.displayUsername,
        position: player?.position,
        avatarUrl: player?.photoUrl,
        isGuest: false,
      );
    }

    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      membership.guestPlayerId!,
    );
    final isClaimedOrLinked =
        guestPlayer?.isClaimed == true || guestPlayer?.hasLinkedPlayer == true;
    return TeamRosterMemberViewData(
      membership: membership,
      displayName: guestPlayer?.displayName ?? membership.guestPlayerId!,
      secondaryText: guestPlayer?.phoneNumber,
      position: guestPlayer?.preferredPosition,
      isGuest: true,
      isGuestClaimedOrLinked: isClaimedOrLinked,
    );
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }

    final query = registeredSearchController.text.trim();
    if (query.isEmpty) {
      playerSearchResults.clear();
      isSearchingPlayers.value = false;
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performPlayerSearch(query);
    });
  }

  Future<void> _performPlayerSearch(String query) async {
    try {
      isSearchingPlayers.value = true;
      final existingPlayerIds = rosterMembers
          .map((entry) => entry.membership.playerId)
          .whereType<String>()
          .toSet();
      final results = await _playerRepository.searchPlayers(query);
      playerSearchResults.assignAll(
        results.where((player) => !existingPlayerIds.contains(player.id)),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر البحث عن اللاعبين الآن.');
    } finally {
      isSearchingPlayers.value = false;
    }
  }

  List<TeamRosterMemberViewData> _sortedMembers(
    List<TeamRosterMemberViewData> entries,
  ) {
    final statusOrder = <TeamMembershipStatus, int>{
      TeamMembershipStatus.starter: 0,
      TeamMembershipStatus.bench: 1,
      TeamMembershipStatus.inactive: 2,
    };
    final roleOrder = <TeamMembershipRole, int>{
      TeamMembershipRole.owner: 0,
      TeamMembershipRole.viceCaptain: 1,
      TeamMembershipRole.manager: 2,
      TeamMembershipRole.assistantManager: 3,
      TeamMembershipRole.player: 4,
    };

    final sorted = List<TeamRosterMemberViewData>.from(entries)
      ..sort((a, b) {
        final statusCompare = (statusOrder[a.membership.status] ?? 99)
            .compareTo(statusOrder[b.membership.status] ?? 99);
        if (statusCompare != 0) {
          return statusCompare;
        }

        final roleCompare = (roleOrder[a.membership.role] ?? 99).compareTo(
          roleOrder[b.membership.role] ?? 99,
        );
        if (roleCompare != 0) {
          return roleCompare;
        }

        return a.displayName.compareTo(b.displayName);
      });

    return sorted;
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _readableError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  // =========================================================================
  // --- منطق الملعب والتشكيل البصري (Visual Lineup / Formation Logic) ---
  // =========================================================================

  LineupPlayer _toLineupPlayer(TeamRosterMemberViewData member) {
    return LineupPlayer(
      id: member.membership.id,
      name: member.displayName,
      username: member.isGuest ? null : member.secondaryText,
      photoUrl: member.avatarUrl,
      preferredPosition: member.position,
      isRegistered: !member.isGuest,
    );
  }

  List<LineupPlayer> get allVisualPlayers {
    return rosterMembers
        .where((member) => member.membership.status != TeamMembershipStatus.inactive)
        .map(_toLineupPlayer)
        .toList();
  }

  void _refreshVisualBench() {
    final onPitch = visualSlots
        .map((slot) => slot.occupantKey)
        .whereType<String>()
        .toSet();
    final bench = allVisualPlayers
        .where((player) => !onPitch.contains(player.key))
        .toList();
    visualBench.assignAll(bench);
  }

  void initVisualLineup() {
    isLineupDirty.value = false;
    
    final starters = rosterMembers
        .where((member) => member.membership.status == TeamMembershipStatus.starter)
        .map(_toLineupPlayer)
        .toList();

    int count = starters.length;
    if (count < 5 || count > 11) {
      count = 7;
    }
    visualPlayerCount.value = count;
    visualFormationCode.value = getDefaultFormation(count);

    final generated = FormationEngine.generateFormationSlots(
      playerCount: visualPlayerCount.value,
      formationCode: visualFormationCode.value,
    );

    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: starters,
    );

    visualSlots.assignAll(assigned.slots);
    _refreshVisualBench();
  }

  void changeVisualPlayerCount(int count) {
    if (!canManageRoster) return;
    final nextCount = clampSupportedPlayerCount(count);
    visualPlayerCount.value = nextCount;
    if (!isValidFormationForPlayerCount(nextCount, visualFormationCode.value)) {
      visualFormationCode.value = getDefaultFormation(nextCount);
    }
    
    final generated = FormationEngine.generateFormationSlots(
      playerCount: nextCount,
      formationCode: visualFormationCode.value,
    );
    
    final result = LineupUtils.preserveAssignments(
      oldSlots: visualSlots,
      newSlots: generated,
      playersByKey: {for (final p in allVisualPlayers) p.key: p},
    );
    
    visualSlots.assignAll(result.slots);
    _refreshVisualBench();
    isLineupDirty.value = true;
  }

  void changeVisualFormation(String code) {
    if (!canManageRoster || !isValidFormationForPlayerCount(visualPlayerCount.value, code)) {
      return;
    }
    visualFormationCode.value = code;
    final generated = FormationEngine.generateFormationSlots(
      playerCount: visualPlayerCount.value,
      formationCode: code,
    );
    final result = LineupUtils.preserveAssignments(
      oldSlots: visualSlots,
      newSlots: generated,
      playersByKey: {for (final p in allVisualPlayers) p.key: p},
    );
    visualSlots.assignAll(result.slots);
    _refreshVisualBench();
    isLineupDirty.value = true;
  }

  void resetVisualLayout() {
    if (!canManageRoster) return;
    final currentStarters = LineupUtils.playersForSlots(
      slots: visualSlots,
      playersByKey: {for (final p in allVisualPlayers) p.key: p},
    );
    final generated = FormationEngine.generateFormationSlots(
      playerCount: visualPlayerCount.value,
      formationCode: visualFormationCode.value,
    );
    final result = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: currentStarters,
    );
    visualSlots.assignAll(result.slots);
    _refreshVisualBench();
    isLineupDirty.value = true;
  }

  void assignPlayerToVisualSlot(LineupPlayer player, FormationSlot slot) {
    if (!canManageRoster) return;
    visualSlots.assignAll(
      LineupUtils.assignPlayerToSlot(
        slots: visualSlots,
        player: player,
        slotId: slot.id,
      ),
    );
    _refreshVisualBench();
    isLineupDirty.value = true;
  }

  void dropPlayerOnVisualSlot(FormationSlot targetSlot, LineupPlayer draggedPlayer) {
    if (!canManageRoster) return;
    final currentSlots = visualSlots.toList(growable: false);
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
      _assignUniqueVisualSlots(updatedSlots);
      _refreshVisualBench();
      isLineupDirty.value = true;
      return;
    }

    final oldSourceSlot = updatedSlots[sourceIndex];
    if (oldTargetSlot.isEmpty) {
      updatedSlots[sourceIndex] = oldSourceSlot.clearPlayer();
      updatedSlots[targetIndex] = oldTargetSlot.assignPlayer(draggedPlayer);
      _assignUniqueVisualSlots(updatedSlots);
      _refreshVisualBench();
      isLineupDirty.value = true;
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
    _assignUniqueVisualSlots(updatedSlots);
    _refreshVisualBench();
    isLineupDirty.value = true;
  }

  void _assignUniqueVisualSlots(List<FormationSlot> updatedSlots) {
    assert(_hasUniqueOccupants(updatedSlots));
    if (!_hasUniqueOccupants(updatedSlots)) {
      return;
    }
    visualSlots.assignAll(updatedSlots);
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

  void movePlayerToVisualBench(LineupPlayer player) {
    if (!canManageRoster) return;
    visualSlots.assignAll(
      LineupUtils.removePlayerFromSlots(slots: visualSlots, player: player),
    );
    _refreshVisualBench();
    isLineupDirty.value = true;
  }
}
