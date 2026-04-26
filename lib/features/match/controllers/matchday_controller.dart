import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/enums/tournament_registration_status.dart';
import '../../../core/services/matchday_service.dart';
import '../../../core/services/tournament_permission_service.dart';
import '../../../app/routes/app_routes.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/match_attendance_repository_impl.dart';
import '../../../data/repositories/match_check_in_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/match_substitution_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_registration_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_attendance.dart';
import '../../../domain/entities/match_check_in.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_substitution.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_membership.dart';
import '../../../domain/entities/tournament.dart';
import '../models/friendly_match_side_view.dart';

enum MatchdayManagedSideKind { registeredTeam, guestTeam }

enum MatchdayLineupSlot { starter, bench }

class MatchdayManagedSide {
  final String key;
  final MatchdayManagedSideKind kind;
  final String label;
  final String subtitle;
  final String accessLabel;
  final String? teamId;
  final String? guestTeamId;
  final bool usesOpenMatchSlot;
  final MatchCheckIn? checkIn;
  final MatchLineupSnapshot? snapshot;

  const MatchdayManagedSide({
    required this.key,
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.accessLabel,
    this.teamId,
    this.guestTeamId,
    this.usesOpenMatchSlot = false,
    this.checkIn,
    this.snapshot,
  });

  bool get isRegisteredTeam => kind == MatchdayManagedSideKind.registeredTeam;
  bool get isGuestTeam => kind == MatchdayManagedSideKind.guestTeam;

  MatchdayManagedSide copyWith({
    MatchCheckIn? checkIn,
    MatchLineupSnapshot? snapshot,
  }) {
    return MatchdayManagedSide(
      key: key,
      kind: kind,
      label: label,
      subtitle: subtitle,
      accessLabel: accessLabel,
      teamId: teamId,
      guestTeamId: guestTeamId,
      usesOpenMatchSlot: usesOpenMatchSlot,
      checkIn: checkIn,
      snapshot: snapshot,
    );
  }
}

class MatchdayParticipantDraft {
  final String selectionId;
  final String displayName;
  final String? position;
  final bool isGuest;
  final TeamMembershipStatus? membershipStatus;
  final MatchAttendance? attendance;
  final String? playerId;
  final String? guestPlayerId;

  const MatchdayParticipantDraft({
    required this.selectionId,
    required this.displayName,
    this.position,
    required this.isGuest,
    this.membershipStatus,
    this.attendance,
    this.playerId,
    this.guestPlayerId,
  });

  String get statusSeedLabel {
    return switch (membershipStatus) {
      TeamMembershipStatus.starter => 'أساسي',
      TeamMembershipStatus.bench => 'احتياط',
      TeamMembershipStatus.inactive => 'غير نشط',
      null => isGuest ? 'ضيف' : 'لاعب',
    };
  }
}

class MatchdayController extends GetxController {
  final String matchId;
  final AuthSession _authSession;
  final MatchdayService _matchdayService;
  final MatchRepositoryImpl _matchRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final TournamentRegistrationRepositoryImpl _registrationRepository;
  final TeamRepositoryImpl _teamRepository;
  final GuestTeamRepositoryImpl _guestTeamRepository;
  final TeamMembershipRepositoryImpl _membershipRepository;
  final PlayerRepositoryImpl _playerRepository;
  final GuestPlayerRepositoryImpl _guestPlayerRepository;
  final MatchCheckInRepositoryImpl _checkInRepository;
  final MatchAttendanceRepositoryImpl _attendanceRepository;
  final MatchLineupSnapshotRepositoryImpl _snapshotRepository;
  final MatchSideRepositoryImpl _matchSideRepository;
  final MatchSubstitutionRepositoryImpl _substitutionRepository;
  final TournamentPermissionService _tournamentPermissionService;

  MatchdayController({
    required this.matchId,
    required AuthSession authSession,
    required MatchdayService matchdayService,
    required MatchRepositoryImpl matchRepository,
    required TournamentRepositoryImpl tournamentRepository,
    required TournamentRegistrationRepositoryImpl registrationRepository,
    required TeamRepositoryImpl teamRepository,
    required GuestTeamRepositoryImpl guestTeamRepository,
    required TeamMembershipRepositoryImpl membershipRepository,
    required PlayerRepositoryImpl playerRepository,
    required GuestPlayerRepositoryImpl guestPlayerRepository,
    required MatchCheckInRepositoryImpl checkInRepository,
    required MatchAttendanceRepositoryImpl attendanceRepository,
    required MatchLineupSnapshotRepositoryImpl snapshotRepository,
    required MatchSideRepositoryImpl matchSideRepository,
    required MatchSubstitutionRepositoryImpl substitutionRepository,
    required TournamentPermissionService tournamentPermissionService,
  }) : _authSession = authSession,
       _matchdayService = matchdayService,
       _matchRepository = matchRepository,
       _tournamentRepository = tournamentRepository,
       _registrationRepository = registrationRepository,
       _teamRepository = teamRepository,
       _guestTeamRepository = guestTeamRepository,
       _membershipRepository = membershipRepository,
       _playerRepository = playerRepository,
       _guestPlayerRepository = guestPlayerRepository,
       _checkInRepository = checkInRepository,
       _attendanceRepository = attendanceRepository,
       _snapshotRepository = snapshotRepository,
       _matchSideRepository = matchSideRepository,
       _substitutionRepository = substitutionRepository,
       _tournamentPermissionService = tournamentPermissionService;

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<Match?> match = Rx<Match?>(null);
  final Rx<Tournament?> tournament = Rx<Tournament?>(null);
  final RxString sideADisplayName = 'فريق A'.obs;
  final RxString sideBDisplayName = 'فريق B'.obs;
  final RxList<MatchdayManagedSide> managedSides = <MatchdayManagedSide>[].obs;
  final RxString selectedSideKey = ''.obs;

  final Rx<MatchCheckIn?> activeCheckIn = Rx<MatchCheckIn?>(null);
  final Rx<MatchLineupSnapshot?> activeSnapshot = Rx<MatchLineupSnapshot?>(
    null,
  );
  final RxList<MatchSubstitution> sideSubstitutions = <MatchSubstitution>[].obs;
  final RxList<MatchdayParticipantDraft> participants =
      <MatchdayParticipantDraft>[].obs;

  final RxMap<String, MatchAttendanceStatus> attendanceDrafts =
      <String, MatchAttendanceStatus>{}.obs;
  final RxMap<String, String> lineupDrafts = <String, String>{}.obs;

  final RxnString selectedOutgoingAttendanceId = RxnString();
  final RxnString selectedIncomingAttendanceId = RxnString();
  final TextEditingController substitutionMinuteController =
      TextEditingController();

  String? get currentUserId => _authSession.currentUserId;
  bool get isLoggedIn => currentUserId != null && currentUserId!.isNotEmpty;
  bool get isFriendlyMatchHost {
    final currentMatch = match.value;
    final actorId = currentUserId;
    return currentMatch != null &&
        currentMatch.tournamentId == null &&
        actorId != null &&
        actorId.isNotEmpty &&
        currentMatch.organizerId == actorId;
  }

  bool get hasFormalMatchdaySides {
    final currentMatch = match.value;
    if (currentMatch == null) return false;
    return currentMatch.teamAId != null ||
        currentMatch.teamBId != null ||
        currentMatch.tournamentId != null;
  }

  MatchdayManagedSide? get selectedSide {
    for (final side in managedSides) {
      if (side.key == selectedSideKey.value) {
        return side;
      }
    }
    return null;
  }

  int? get requiredStarterCount =>
      tournament.value?.teamSize.value ?? match.value?.teamSize;
  bool get isLineupLocked => activeSnapshot.value != null;
  bool get isMatchLive => match.value?.status == MatchStatus.live;
  bool get canEditPreKickoff =>
      !isLineupLocked &&
      !isMatchLive &&
      match.value?.status != MatchStatus.completed &&
      match.value?.status != MatchStatus.pendingReview &&
      match.value?.status != MatchStatus.ratingWindow &&
      match.value?.status != MatchStatus.settled &&
      match.value?.status != MatchStatus.frozen &&
      match.value?.isFrozen != true;

  List<MatchdayParticipantDraft> get eligibleLineupParticipants => participants
      .where((participant) => _isEligibleForLineup(participant.selectionId))
      .toList(growable: false);

  List<MatchAttendance> get currentOnPitchAttendances => participants
      .map((participant) => participant.attendance)
      .whereType<MatchAttendance>()
      .where((attendance) => attendance.currentlyOnPitch)
      .toList(growable: false);

  List<MatchAttendance> get availableIncomingAttendances => participants
      .map((participant) => participant.attendance)
      .whereType<MatchAttendance>()
      .where(
        (attendance) =>
            !attendance.currentlyOnPitch && attendance.includedInLockedLineup,
      )
      .toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    loadMatchday();
  }

  @override
  void onClose() {
    substitutionMinuteController.dispose();
    super.onClose();
  }

  Future<void> loadMatchday() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedMatch = await _matchRepository.getMatch(matchId);
      if (loadedMatch == null) {
        errorMessage.value = 'تعذر العثور على المباراة المطلوبة.';
        return;
      }

      final loadedTournament = loadedMatch.tournamentId == null
          ? null
          : await _tournamentRepository.getTournament(
              loadedMatch.tournamentId!,
            );

      match.value = loadedMatch;
      tournament.value = loadedTournament;
      await _loadFriendlySideDisplayNames(loadedMatch);

      final sides = await _discoverManagedSides(
        match: loadedMatch,
        tournament: loadedTournament,
      );
      managedSides.assignAll(sides);

      if (sides.isEmpty) {
        selectedSideKey.value = '';
        await _resetSelectedSideState();
        return;
      }

      final preferredSide =
          sides.any((side) => side.key == selectedSideKey.value)
          ? selectedSideKey.value
          : sides.first.key;
      selectedSideKey.value = preferredSide;
      await _loadSelectedSideState();
    } catch (error) {
      errorMessage.value = _formatError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFriendlySideDisplayNames(Match loadedMatch) async {
    sideADisplayName.value = 'فريق A';
    sideBDisplayName.value = 'فريق B';
    if (loadedMatch.tournamentId != null) {
      return;
    }

    final teamIds = <String>[
      if (loadedMatch.teamAId != null && loadedMatch.teamAId!.isNotEmpty)
        loadedMatch.teamAId!,
      if (loadedMatch.teamBId != null && loadedMatch.teamBId!.isNotEmpty)
        loadedMatch.teamBId!,
    ];
    final results = await Future.wait<dynamic>([
      _teamRepository.getTeamsByIds(teamIds),
      _matchSideRepository.getMatchSides(loadedMatch.id),
    ]);
    final teams = results[0] as List<Team>;
    final sides = results[1] as List<MatchSide>;
    final sideViews = FriendlyMatchSideView.fromMatch(
      match: loadedMatch,
      teamsById: {for (final team in teams) team.id: team},
      sides: sides,
    );
    for (final side in sideViews) {
      if (side.sideKey == 'A') {
        sideADisplayName.value = side.displayName;
      } else if (side.sideKey == 'B') {
        sideBDisplayName.value = side.displayName;
      }
    }
  }

  Future<void> selectSide(String sideKey) async {
    if (sideKey == selectedSideKey.value) {
      return;
    }
    selectedSideKey.value = sideKey;
    await _loadSelectedSideState();
  }

  void setAttendanceStatus(String selectionId, MatchAttendanceStatus status) {
    attendanceDrafts[selectionId] = status;
    if (!_isEligibleForLineup(selectionId)) {
      lineupDrafts.remove(selectionId);
    }
  }

  void setLineupSlot(String selectionId, MatchdayLineupSlot? slot) {
    if (!_isEligibleForLineup(selectionId)) {
      lineupDrafts.remove(selectionId);
      return;
    }
    if (slot == null) {
      lineupDrafts.remove(selectionId);
      return;
    }
    lineupDrafts[selectionId] = slot.name;
  }

  Future<void> submitCheckIn() async {
    final side = selectedSide;
    final actorId = currentUserId;
    if (side == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      if (side.isRegisteredTeam) {
        final membershipStatuses = <String, MatchAttendanceStatus>{};
        for (final participant in participants) {
          membershipStatuses[participant.selectionId] =
              attendanceDrafts[participant.selectionId] ??
              MatchAttendanceStatus.pending;
        }
        final result = await _matchdayService.checkInRegisteredTeam(
          matchId: matchId,
          teamId: side.teamId!,
          actorId: actorId,
          membershipStatuses: membershipStatuses,
        );
        _showSnack(
          'تم الحضور',
          result.outcome == MatchdayCheckInOutcome.verified
              ? 'تم حفظ check-in واعتماده مباشرة.'
              : 'تم حفظ check-in بنجاح.',
        );
      } else {
        final guestPlayerStatuses = <String, MatchAttendanceStatus>{};
        for (final participant in participants) {
          final status =
              attendanceDrafts[participant.selectionId] ??
              MatchAttendanceStatus.pending;
          if (status != MatchAttendanceStatus.pending ||
              participant.attendance != null) {
            guestPlayerStatuses[participant.selectionId] = status;
          }
        }
        final result = await _matchdayService.checkInGuestTeam(
          matchId: matchId,
          guestTeamId: side.guestTeamId!,
          actorId: actorId,
          guestPlayerStatuses: guestPlayerStatuses,
        );
        _showSnack(
          'تم الحضور',
          result.outcome == MatchdayCheckInOutcome.verified
              ? 'تم حفظ check-in واعتماده مباشرة.'
              : 'تم حفظ check-in للفريق الضيف.',
        );
      }
      await _loadSelectedSideState();
    } catch (error) {
      _showErrorSnack(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> lockLineup() async {
    final side = selectedSide;
    final actorId = currentUserId;
    if (side == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      final starterIds = _selectedIdsForSlot(MatchdayLineupSlot.starter);
      final benchIds = _selectedIdsForSlot(MatchdayLineupSlot.bench);

      if (side.isRegisteredTeam) {
        final result = await _matchdayService.lockRegisteredTeamLineup(
          matchId: matchId,
          teamId: side.teamId!,
          actorId: actorId,
          starterMembershipIds: starterIds,
          benchMembershipIds: benchIds,
        );
        _showSnack(
          'تم قفل التشكيل',
          result.outcome == MatchdayLineupLockOutcome.alreadyLocked
              ? 'هذا التشكيل مقفول بالفعل وتم تحميل نسخته الحالية.'
              : 'تم قفل التشكيل بنجاح.',
        );
      } else {
        final result = await _matchdayService.lockGuestTeamLineup(
          matchId: matchId,
          guestTeamId: side.guestTeamId!,
          actorId: actorId,
          starterGuestPlayerIds: starterIds,
          benchGuestPlayerIds: benchIds,
        );
        _showSnack(
          'تم قفل التشكيل',
          result.outcome == MatchdayLineupLockOutcome.alreadyLocked
              ? 'هذا التشكيل مقفول بالفعل وتم تحميل نسخته الحالية.'
              : 'تم قفل تشكيل الفريق الضيف بنجاح.',
        );
      }
      await _loadSelectedSideState();
    } catch (error) {
      _showErrorSnack(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> recordSubstitution() async {
    final side = selectedSide;
    final actorId = currentUserId;
    final outgoingAttendanceId = selectedOutgoingAttendanceId.value;
    final incomingAttendanceId = selectedIncomingAttendanceId.value;
    final minute = int.tryParse(substitutionMinuteController.text.trim());
    if (side == null ||
        actorId == null ||
        outgoingAttendanceId == null ||
        incomingAttendanceId == null ||
        minute == null) {
      _showSnack('بيانات ناقصة', 'حدّد اللاعب الخارج والبديل والدقيقة أولاً.');
      return;
    }

    try {
      isSubmitting.value = true;
      if (side.isRegisteredTeam) {
        await _matchdayService.recordRegisteredTeamSubstitution(
          matchId: matchId,
          teamId: side.teamId!,
          actorId: actorId,
          outgoingAttendanceId: outgoingAttendanceId,
          incomingAttendanceId: incomingAttendanceId,
          minute: minute,
        );
      } else {
        await _matchdayService.recordGuestTeamSubstitution(
          matchId: matchId,
          guestTeamId: side.guestTeamId!,
          actorId: actorId,
          outgoingAttendanceId: outgoingAttendanceId,
          incomingAttendanceId: incomingAttendanceId,
          minute: minute,
        );
      }

      selectedOutgoingAttendanceId.value = null;
      selectedIncomingAttendanceId.value = null;
      substitutionMinuteController.clear();
      _showSnack('تم تسجيل التبديل', 'تم تحديث played-truth والتبديل بنجاح.');
      await _loadSelectedSideState();
    } catch (error) {
      _showErrorSnack(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  MatchAttendanceStatus statusFor(String selectionId) =>
      attendanceDrafts[selectionId] ?? MatchAttendanceStatus.pending;

  MatchdayLineupSlot? lineupSlotFor(String selectionId) {
    final rawValue = lineupDrafts[selectionId];
    if (rawValue == MatchdayLineupSlot.starter.name) {
      return MatchdayLineupSlot.starter;
    }
    if (rawValue == MatchdayLineupSlot.bench.name) {
      return MatchdayLineupSlot.bench;
    }
    return null;
  }

  String substitutionLabel(String attendanceId) {
    for (final participant in participants) {
      if (participant.attendance?.id == attendanceId) {
        return participant.displayName;
      }
    }
    return attendanceId;
  }

  /// Whether the current lineup can be unlocked for re-editing.
  bool get canUnlockLineup {
    final currentMatch = match.value;
    final snapshot = activeSnapshot.value;
    final actorId = currentUserId;
    if (currentMatch == null ||
        snapshot == null ||
        actorId == null ||
        actorId.isEmpty) {
      return false;
    }
    if (!_isPreKickoffUnlockStatus(currentMatch)) {
      return false;
    }
    final currentTournament = tournament.value;
    if (currentTournament != null) {
      return _tournamentPermissionService.canManageTeams(
        currentTournament,
        actorId,
      );
    }
    return currentMatch.organizerId == actorId;
  }

  /// Deletes the active snapshot so the lineup can be re-edited.
  Future<void> unlockLineup() async {
    final snapshot = activeSnapshot.value;
    if (snapshot == null) return;
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      _showSnack('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }

    try {
      isSubmitting.value = true;
      await _matchdayService.unlockLineup(
        matchId: matchId,
        snapshotId: snapshot.id,
        actorId: actorId,
      );
      activeSnapshot.value = null;
      _showSnack('تم فك القفل', 'يمكنك تعديل التشكيلة من جديد.');
      await _loadSelectedSideState();
    } catch (error) {
      _showErrorSnack(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  bool _isPreKickoffUnlockStatus(Match currentMatch) {
    if (currentMatch.isFrozen || currentMatch.status == MatchStatus.frozen) {
      return false;
    }
    return currentMatch.status != MatchStatus.live &&
        currentMatch.status != MatchStatus.completed &&
        currentMatch.status != MatchStatus.pendingReview &&
        currentMatch.status != MatchStatus.ratingWindow &&
        currentMatch.status != MatchStatus.settled &&
        currentMatch.status != MatchStatus.cancelled;
  }

  /// Navigates to TeamLineupEditorScreen for the currently selected
  /// registered team. Guest teams use the in-place matchday editor.
  void openLineupEditor() {
    final side = selectedSide;
    if (side == null) return;

    if (side.isRegisteredTeam) {
      Get.toNamed(
        AppRoutes.teamLineupEditorForMatch(
          matchId: matchId,
          teamId: side.teamId!,
        ),
      );
    } else {
      _showSnack(
        'فريق ضيف',
        'استخدم محرر التشكيلة الحالي لإدارة الفريق الضيف.',
      );
    }
  }

  Future<List<MatchdayManagedSide>> _discoverManagedSides({
    required Match match,
    required Tournament? tournament,
  }) async {
    final actorId = currentUserId;
    if (actorId == null) {
      return const [];
    }

    final organizerLevel = _hasOrganizerLevelAccess(
      match: match,
      tournament: tournament,
      actorId: actorId,
    );
    final sides = <MatchdayManagedSide>[];
    final seenKeys = <String>{};
    final assignedTeamIds = <String>[
      if (match.teamAId != null && match.teamAId!.isNotEmpty) match.teamAId!,
      if (match.teamBId != null && match.teamBId!.isNotEmpty) match.teamBId!,
    ];

    final assignedTeams = await _teamRepository.getTeamsByIds(assignedTeamIds);
    for (final team in assignedTeams) {
      final canManage =
          organizerLevel || _canManageRegisteredTeam(team, actorId);
      if (!canManage) {
        continue;
      }
      final key = 'team::${team.id}';
      if (!seenKeys.add(key)) {
        continue;
      }
      sides.add(
        MatchdayManagedSide(
          key: key,
          kind: MatchdayManagedSideKind.registeredTeam,
          label: team.name,
          subtitle: 'فريق مسجل',
          accessLabel: organizerLevel ? 'منظم' : 'قائد/نائب',
          teamId: team.id,
        ),
      );
    }

    if (match.tournamentId == null || assignedTeamIds.length >= 2) {
      return sides;
    }

    final registrations = await _registrationRepository
        .getTournamentRegistrations(match.tournamentId!);
    final approvedRegistrations = registrations
        .where(
          (registration) =>
              registration.status == TournamentRegistrationStatus.approved,
        )
        .toList(growable: false);
    final registeredTeamIds = approvedRegistrations
        .map((registration) => registration.teamId)
        .whereType<String>()
        .where((teamId) => teamId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final guestTeamIds = approvedRegistrations
        .map((registration) => registration.guestTeamId)
        .whereType<String>()
        .where((guestTeamId) => guestTeamId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final registeredTeams = await _teamRepository.getTeamsByIds(
      registeredTeamIds,
    );
    final guestTeams = await _guestTeamRepository.getGuestTeamsByIds(
      guestTeamIds,
    );
    final registeredTeamsById = {
      for (final team in registeredTeams) team.id: team,
    };
    final guestTeamsById = {
      for (final guestTeam in guestTeams) guestTeam.id: guestTeam,
    };

    for (final registration in approvedRegistrations) {
      if (registration.teamId != null) {
        final team = registeredTeamsById[registration.teamId!];
        if (team == null) {
          continue;
        }
        final canManage =
            organizerLevel || _canManageRegisteredTeam(team, actorId);
        if (!canManage) {
          continue;
        }
        final key = 'team::${team.id}';
        if (!seenKeys.add(key)) {
          continue;
        }
        sides.add(
          MatchdayManagedSide(
            key: key,
            kind: MatchdayManagedSideKind.registeredTeam,
            label: team.name,
            subtitle: assignedTeamIds.contains(team.id)
                ? 'فريق مسجل'
                : 'فريق مسجل على الطرف المفتوح',
            accessLabel: organizerLevel ? 'منظم' : 'قائد/نائب',
            teamId: team.id,
            usesOpenMatchSlot: !assignedTeamIds.contains(team.id),
          ),
        );
        continue;
      }

      if (registration.guestTeamId != null) {
        final guestTeam = guestTeamsById[registration.guestTeamId!];
        if (guestTeam == null) {
          continue;
        }
        final canManage = organizerLevel || guestTeam.creatorId == actorId;
        if (!canManage) {
          continue;
        }
        final key = 'guest::${guestTeam.id}';
        if (!seenKeys.add(key)) {
          continue;
        }
        sides.add(
          MatchdayManagedSide(
            key: key,
            kind: MatchdayManagedSideKind.guestTeam,
            label: guestTeam.name,
            subtitle: 'فريق ضيف على الطرف المفتوح',
            accessLabel: organizerLevel ? 'منظم' : 'منشئ الفريق',
            guestTeamId: guestTeam.id,
            usesOpenMatchSlot: true,
          ),
        );
      }
    }

    return sides;
  }

  Future<void> _loadSelectedSideState() async {
    final side = selectedSide;
    if (side == null) {
      await _resetSelectedSideState();
      return;
    }

    if (side.isRegisteredTeam) {
      await _loadRegisteredSideState(side);
    } else {
      await _loadGuestSideState(side);
    }
  }

  Future<void> _loadRegisteredSideState(MatchdayManagedSide side) async {
    final teamId = side.teamId!;
    final results = await Future.wait<dynamic>([
      _checkInRepository.getCheckInByTeamId(matchId: matchId, teamId: teamId),
      _attendanceRepository.getTeamAttendances(
        matchId: matchId,
        teamId: teamId,
      ),
      _snapshotRepository.getSnapshotByTeamId(matchId: matchId, teamId: teamId),
      _substitutionRepository.getTeamSubstitutions(
        matchId: matchId,
        teamId: teamId,
      ),
      _membershipRepository.getTeamMemberships(teamId),
    ]);
    final checkIn = results[0] as MatchCheckIn?;
    final attendances = results[1] as List<MatchAttendance>;
    final snapshot = results[2] as MatchLineupSnapshot?;
    final substitutions = results[3] as List<MatchSubstitution>;
    final memberships = results[4] as List<TeamMembership>;

    final playerIds = memberships
        .map((membership) => membership.playerId)
        .whereType<String>()
        .toSet();
    final guestPlayerIds = memberships
        .map((membership) => membership.guestPlayerId)
        .whereType<String>()
        .toSet();
    final playerLoadResults = await Future.wait<dynamic>([
      _loadPlayersByIds(playerIds),
      _loadGuestPlayersByIds(guestPlayerIds),
    ]);
    final players = playerLoadResults[0] as Map<String, Player>;
    final guestPlayers = playerLoadResults[1] as Map<String, GuestPlayer>;
    final attendancesByMembershipId = <String, MatchAttendance>{
      for (final attendance in attendances)
        if (attendance.teamMembershipId != null)
          attendance.teamMembershipId!: attendance,
    };

    final drafts = memberships
        .map(
          (membership) => MatchdayParticipantDraft(
            selectionId: membership.id,
            displayName: membership.playerId != null
                ? (players[membership.playerId!]?.name ?? 'لاعب مسجل')
                : (guestPlayers[membership.guestPlayerId!]?.displayName ??
                      'لاعب ضيف'),
            position: membership.playerId != null
                ? players[membership.playerId!]?.position
                : guestPlayers[membership.guestPlayerId!]?.preferredPosition,
            isGuest: membership.isGuest,
            membershipStatus: membership.status,
            attendance: attendancesByMembershipId[membership.id],
            playerId: membership.playerId,
            guestPlayerId: membership.guestPlayerId,
          ),
        )
        .toList(growable: false);

    _applySelectedSideSnapshot(
      side: side,
      checkIn: checkIn,
      snapshot: snapshot,
      substitutions: substitutions,
      participantDrafts: drafts,
    );
  }

  Future<void> _loadGuestSideState(MatchdayManagedSide side) async {
    final guestTeamId = side.guestTeamId!;
    final results = await Future.wait<dynamic>([
      _checkInRepository.getCheckInByGuestTeamId(
        matchId: matchId,
        guestTeamId: guestTeamId,
      ),
      _attendanceRepository.getTeamAttendances(
        matchId: matchId,
        guestTeamId: guestTeamId,
      ),
      _snapshotRepository.getSnapshotByGuestTeamId(
        matchId: matchId,
        guestTeamId: guestTeamId,
      ),
      _substitutionRepository.getTeamSubstitutions(
        matchId: matchId,
        guestTeamId: guestTeamId,
      ),
      _guestPlayerRepository.getGuestTeamPlayers(guestTeamId),
    ]);
    final checkIn = results[0] as MatchCheckIn?;
    final attendances = results[1] as List<MatchAttendance>;
    final snapshot = results[2] as MatchLineupSnapshot?;
    final substitutions = results[3] as List<MatchSubstitution>;
    final guestTeamPlayers = results[4] as List<GuestPlayer>;

    final candidateGuestPlayers = <String, GuestPlayer>{};
    for (final guestPlayer in guestTeamPlayers) {
      candidateGuestPlayers[guestPlayer.id] = guestPlayer;
    }
    final missingGuestPlayerIds = <String>[];
    for (final attendance in attendances) {
      final guestPlayerId = attendance.guestPlayerId;
      if (guestPlayerId == null ||
          candidateGuestPlayers.containsKey(guestPlayerId)) {
        continue;
      }
      missingGuestPlayerIds.add(guestPlayerId);
    }
    final missingGuestPlayers = await _guestPlayerRepository
        .getGuestPlayersByIds(missingGuestPlayerIds);
    for (final guestPlayer in missingGuestPlayers) {
      candidateGuestPlayers[guestPlayer.id] = guestPlayer;
    }

    final attendancesByGuestPlayerId = <String, MatchAttendance>{
      for (final attendance in attendances)
        if (attendance.guestPlayerId != null)
          attendance.guestPlayerId!: attendance,
    };

    final drafts =
        candidateGuestPlayers.values
            .map(
              (guestPlayer) => MatchdayParticipantDraft(
                selectionId: guestPlayer.id,
                displayName: guestPlayer.displayName,
                position: guestPlayer.preferredPosition,
                isGuest: true,
                attendance: attendancesByGuestPlayerId[guestPlayer.id],
                guestPlayerId: guestPlayer.id,
              ),
            )
            .toList()
          ..sort(
            (left, right) => left.displayName.compareTo(right.displayName),
          );

    _applySelectedSideSnapshot(
      side: side,
      checkIn: checkIn,
      snapshot: snapshot,
      substitutions: substitutions,
      participantDrafts: drafts,
    );
  }

  void _applySelectedSideSnapshot({
    required MatchdayManagedSide side,
    required MatchCheckIn? checkIn,
    required MatchLineupSnapshot? snapshot,
    required List<MatchSubstitution> substitutions,
    required List<MatchdayParticipantDraft> participantDrafts,
  }) {
    activeCheckIn.value = checkIn;
    activeSnapshot.value = snapshot;
    sideSubstitutions.assignAll(substitutions);
    participants.assignAll(participantDrafts);

    final updatedSides = managedSides
        .map(
          (entry) => entry.key == side.key
              ? entry.copyWith(checkIn: checkIn, snapshot: snapshot)
              : entry,
        )
        .toList(growable: false);
    managedSides.assignAll(updatedSides);

    _seedAttendanceDrafts(participantDrafts);
    _seedLineupDrafts(participantDrafts, snapshot);
    selectedOutgoingAttendanceId.value = null;
    selectedIncomingAttendanceId.value = null;
    substitutionMinuteController.clear();
  }

  void _seedAttendanceDrafts(List<MatchdayParticipantDraft> participantDrafts) {
    final seeded = <String, MatchAttendanceStatus>{};
    for (final participant in participantDrafts) {
      final existingAttendance = participant.attendance;
      if (existingAttendance != null) {
        seeded[participant.selectionId] = existingAttendance.status;
        continue;
      }
      if (participant.isGuest) {
        seeded[participant.selectionId] = MatchAttendanceStatus.pending;
        continue;
      }
      seeded[participant.selectionId] = switch (participant.membershipStatus) {
        TeamMembershipStatus.inactive => MatchAttendanceStatus.absent,
        _ => MatchAttendanceStatus.present,
      };
    }
    attendanceDrafts.assignAll(seeded);
  }

  void _seedLineupDrafts(
    List<MatchdayParticipantDraft> participantDrafts,
    MatchLineupSnapshot? snapshot,
  ) {
    final seeded = <String, String>{};
    if (snapshot != null) {
      for (final entry in snapshot.starters) {
        final selectionId = entry.teamMembershipId ?? entry.guestPlayerId;
        if (selectionId != null) {
          seeded[selectionId] = MatchdayLineupSlot.starter.name;
        }
      }
      for (final entry in snapshot.bench) {
        final selectionId = entry.teamMembershipId ?? entry.guestPlayerId;
        if (selectionId != null) {
          seeded[selectionId] = MatchdayLineupSlot.bench.name;
        }
      }
      lineupDrafts.assignAll(seeded);
      return;
    }

    final eligible = participantDrafts
        .where((participant) => _isEligibleForLineup(participant.selectionId))
        .toList(growable: false);
    final starters = <MatchdayParticipantDraft>[];
    final bench = <MatchdayParticipantDraft>[];

    if (selectedSide?.isRegisteredTeam == true) {
      for (final participant in eligible) {
        if (participant.membershipStatus == TeamMembershipStatus.starter) {
          starters.add(participant);
        } else if (participant.membershipStatus == TeamMembershipStatus.bench) {
          bench.add(participant);
        }
      }
    } else {
      starters.addAll(eligible);
    }

    final requiredCount = requiredStarterCount ?? 1;
    final starterIds = <String>{};
    for (final participant in starters) {
      if (starterIds.length >= requiredCount) {
        bench.add(participant);
        continue;
      }
      starterIds.add(participant.selectionId);
      seeded[participant.selectionId] = MatchdayLineupSlot.starter.name;
    }

    for (final participant in eligible) {
      if (seeded.containsKey(participant.selectionId)) {
        continue;
      }
      if (bench.any(
        (benchParticipant) =>
            benchParticipant.selectionId == participant.selectionId,
      )) {
        seeded[participant.selectionId] = MatchdayLineupSlot.bench.name;
      }
    }
    lineupDrafts.assignAll(seeded);
  }

  List<String> _selectedIdsForSlot(MatchdayLineupSlot slot) {
    final ids = <String>[];
    for (final participant in participants) {
      if (!_isEligibleForLineup(participant.selectionId)) {
        continue;
      }
      if (lineupDrafts[participant.selectionId] == slot.name) {
        ids.add(participant.selectionId);
      }
    }
    return ids;
  }

  bool _isEligibleForLineup(String selectionId) {
    final status =
        attendanceDrafts[selectionId] ?? MatchAttendanceStatus.pending;
    return status == MatchAttendanceStatus.present ||
        status == MatchAttendanceStatus.late;
  }

  bool _hasOrganizerLevelAccess({
    required Match match,
    required Tournament? tournament,
    required String actorId,
  }) {
    if (tournament == null) {
      return match.organizerId == actorId;
    }
    if (tournament.organizerId == actorId) {
      return true;
    }
    if (!tournament.assistants.any(
      (assistant) => assistant.userId == actorId,
    )) {
      return false;
    }
    return _tournamentPermissionService.canManageTeams(tournament, actorId);
  }

  bool _canManageRegisteredTeam(Team team, String actorId) {
    return team.ownerId == actorId || team.viceCaptainIds.contains(actorId);
  }

  Future<Map<String, Player>> _loadPlayersByIds(Set<String> playerIds) async {
    final players = await _playerRepository.getPlayersByIds(
      playerIds.toList(growable: false),
    );
    return {for (final player in players) player.id: player};
  }

  Future<Map<String, GuestPlayer>> _loadGuestPlayersByIds(
    Set<String> guestPlayerIds,
  ) async {
    final guestPlayers = await _guestPlayerRepository.getGuestPlayersByIds(
      guestPlayerIds.toList(growable: false),
    );
    return {
      for (final guestPlayer in guestPlayers) guestPlayer.id: guestPlayer,
    };
  }

  Future<void> _resetSelectedSideState() async {
    activeCheckIn.value = null;
    activeSnapshot.value = null;
    sideSubstitutions.clear();
    participants.clear();
    attendanceDrafts.clear();
    lineupDrafts.clear();
    selectedOutgoingAttendanceId.value = null;
    selectedIncomingAttendanceId.value = null;
    substitutionMinuteController.clear();
  }

  String _formatError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    return raw;
  }

  void _showSnack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _showErrorSnack(Object error) {
    _showSnack('تعذر إكمال العملية', _formatError(error));
  }
}
