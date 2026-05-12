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

part 'matchday_side_discovery.dart';
part 'matchday_side_state.dart';

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
