import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_attendance_status.dart';
import '../../core/enums/match_check_in_status.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../core/enums/tournament_registration_status.dart';
import '../../core/lineup/formation_library.dart';
import '../../core/lineup/lineup_types.dart';
import '../../data/models/guest_player_model.dart';
import '../../data/models/guest_team_model.dart';
import '../../data/models/match_attendance_model.dart';
import '../../data/models/match_check_in_model.dart';
import '../../data/models/match_lineup_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_substitution_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_membership_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_registration_model.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_attendance.dart';
import '../../domain/entities/match_check_in.dart';
import '../../domain/entities/match_lineup_entry.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/entities/match_substitution.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_registration.dart';
import 'team_roster_policy.dart';
import 'tournament_permission_service.dart';

enum MatchdayCheckInOutcome { checkedIn, verified }

class MatchdayCheckInResult {
  final MatchdayCheckInOutcome outcome;
  final MatchCheckIn checkIn;
  final int attendanceCount;

  const MatchdayCheckInResult({
    required this.outcome,
    required this.checkIn,
    required this.attendanceCount,
  });
}

class MatchdayLineupValidationResult {
  final Match match;
  final MatchCheckIn checkIn;
  final int? requiredStarterCount;
  final int eligibleParticipants;
  final List<MatchLineupEntry> starters;
  final List<MatchLineupEntry> bench;

  const MatchdayLineupValidationResult({
    required this.match,
    required this.checkIn,
    required this.requiredStarterCount,
    required this.eligibleParticipants,
    required this.starters,
    required this.bench,
  });
}

enum MatchdayLineupLockOutcome { locked, alreadyLocked }

class MatchdayLineupLockResult {
  final MatchdayLineupLockOutcome outcome;
  final MatchLineupSnapshot snapshot;
  final MatchdayLineupValidationResult validation;

  const MatchdayLineupLockResult({
    required this.outcome,
    required this.snapshot,
    required this.validation,
  });
}

class MatchdaySubstitutionResult {
  final MatchSubstitution substitution;
  final MatchAttendance outgoingAttendance;
  final MatchAttendance incomingAttendance;

  const MatchdaySubstitutionResult({
    required this.substitution,
    required this.outgoingAttendance,
    required this.incomingAttendance,
  });
}

class MatchdayService {
  final FirebaseFirestore _firestore;
  final TournamentPermissionService _tournamentPermissionService;
  final TeamRosterPolicy _teamRosterPolicy;
  final Uuid _uuid;

  MatchdayService({
    FirebaseFirestore? firestore,
    TournamentPermissionService? tournamentPermissionService,
    TeamRosterPolicy? teamRosterPolicy,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _tournamentPermissionService =
           tournamentPermissionService ?? TournamentPermissionService(),
       _teamRosterPolicy = teamRosterPolicy ?? const TeamRosterPolicy(),
       _uuid = uuid ?? const Uuid();

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection(FirebasePaths.teams);

  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      _firestore.collection(FirebasePaths.guestTeams);

  CollectionReference<Map<String, dynamic>> get _playersRef =>
      _firestore.collection(FirebasePaths.players);

  CollectionReference<Map<String, dynamic>> get _guestPlayersRef =>
      _firestore.collection(FirebasePaths.guestPlayers);

  CollectionReference<Map<String, dynamic>> get _teamMembershipsRef =>
      _firestore.collection(FirebasePaths.teamMemberships);

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);

  CollectionReference<Map<String, dynamic>> get _registrationsRef =>
      _firestore.collection(FirebasePaths.tournamentRegistrations);

  CollectionReference<Map<String, dynamic>> get _checkInsRef =>
      _firestore.collection(FirebasePaths.matchCheckIns);

  CollectionReference<Map<String, dynamic>> get _attendancesRef =>
      _firestore.collection(FirebasePaths.matchAttendances);

  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);

  CollectionReference<Map<String, dynamic>> get _substitutionsRef =>
      _firestore.collection(FirebasePaths.matchSubstitutions);

  Future<MatchdayCheckInResult> checkInRegisteredTeam({
    required String matchId,
    required String teamId,
    required String actorId,
    Map<String, MatchAttendanceStatus> membershipStatuses = const {},
    String? notes,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadRegisteredContext(
      matchId: matchId,
      teamId: teamId,
      actorId: actorId,
    );
    final memberships = await _loadActiveMemberships(teamId);
    if (memberships.isEmpty) {
      throw Exception('لا يمكن تنفيذ check-in لفريق لا يملك قائمة نشطة.');
    }

    final membershipIds = memberships
        .map((membership) => membership.id)
        .toSet();
    for (final membershipId in membershipStatuses.keys) {
      if (!membershipIds.contains(membershipId)) {
        throw Exception('توجد عضوية غير معروفة داخل check-in الحالي.');
      }
    }

    final attendanceDrafts = memberships
        .map(
          (membership) => MatchAttendance(
            id: _registeredAttendanceId(
              matchId: matchId,
              teamId: teamId,
              membershipId: membership.id,
            ),
            matchId: matchId,
            teamId: teamId,
            tournamentRegistrationId: context.registration?.id,
            checkInId: _registeredCheckInId(matchId: matchId, teamId: teamId),
            teamMembershipId: membership.id,
            playerId: membership.playerId,
            guestPlayerId: membership.guestPlayerId,
            claimedFromGuestPlayerId: membership.claimedFromGuestPlayerId,
            status:
                membershipStatuses[membership.id] ??
                _defaultAttendanceStatusForMembership(membership),
            createdBy: actorId,
            createdAt: effectiveNow,
            updatedAt: effectiveNow,
            markedBy: actorId,
            markedAt: effectiveNow,
            notes: _normalizeOptionalText(notes),
          ),
        )
        .toList(growable: false);

    final existingCheckIn = await _getCheckInByTeamId(
      matchId: matchId,
      teamId: teamId,
    );
    final checkInId = _registeredCheckInId(matchId: matchId, teamId: teamId);
    final outcome = context.canVerify
        ? MatchdayCheckInOutcome.verified
        : MatchdayCheckInOutcome.checkedIn;
    final targetStatus = existingCheckIn?.isVerified == true
        ? MatchCheckInStatus.verified
        : (context.canVerify
              ? MatchCheckInStatus.verified
              : MatchCheckInStatus.checkedIn);
    final updatedCheckIn = MatchCheckIn(
      id: checkInId,
      matchId: matchId,
      teamId: teamId,
      tournamentRegistrationId: context.registration?.id,
      status: targetStatus,
      createdBy: existingCheckIn?.createdBy ?? actorId,
      createdAt: existingCheckIn?.createdAt ?? effectiveNow,
      updatedAt: effectiveNow,
      checkedInBy: actorId,
      checkedInAt: effectiveNow,
      verifiedBy: targetStatus == MatchCheckInStatus.verified
          ? actorId
          : existingCheckIn?.verifiedBy,
      verifiedAt: targetStatus == MatchCheckInStatus.verified
          ? effectiveNow
          : existingCheckIn?.verifiedAt,
      notes: _normalizeOptionalText(notes) ?? existingCheckIn?.notes,
    );

    await _firestore.runTransaction((transaction) async {
      final checkInRef = _checkInsRef.doc(checkInId);
      final checkInSnapshot = await transaction.get(checkInRef);
      final attendanceSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final attendance in attendanceDrafts) {
        final attendanceRef = _attendancesRef.doc(attendance.id);
        attendanceSnapshots[attendance.id] = await transaction.get(
          attendanceRef,
        );
      }

      if (checkInSnapshot.exists && checkInSnapshot.data() != null) {
        transaction.update(
          checkInRef,
          MatchCheckInModel.fromEntity(updatedCheckIn).toJson(),
        );
      } else {
        transaction.set(
          checkInRef,
          MatchCheckInModel.fromEntity(updatedCheckIn).toJson(),
        );
      }

      for (final attendance in attendanceDrafts) {
        final attendanceRef = _attendancesRef.doc(attendance.id);
        final attendanceSnapshot = attendanceSnapshots[attendance.id]!;
        if (attendanceSnapshot.exists && attendanceSnapshot.data() != null) {
          final existingAttendance = MatchAttendanceModel.fromJson(
            attendanceSnapshot.data()!,
            attendanceSnapshot.id,
          ).toEntity();
          final updatedAttendance = attendance.copyWith(
            createdBy: existingAttendance.createdBy,
            createdAt: existingAttendance.createdAt,
            notes: attendance.notes ?? existingAttendance.notes,
          );
          transaction.update(
            attendanceRef,
            MatchAttendanceModel.fromEntity(updatedAttendance).toJson(),
          );
        } else {
          transaction.set(
            attendanceRef,
            MatchAttendanceModel.fromEntity(attendance).toJson(),
          );
        }
      }
    });

    return MatchdayCheckInResult(
      outcome: outcome,
      checkIn: updatedCheckIn,
      attendanceCount: attendanceDrafts.length,
    );
  }

  Future<MatchdayCheckInResult> checkInGuestTeam({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required Map<String, MatchAttendanceStatus> guestPlayerStatuses,
    String? notes,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadGuestContext(
      matchId: matchId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    if (guestPlayerStatuses.isEmpty) {
      throw Exception('لا يمكن تنفيذ check-in لفريق ضيف بدون لاعبين.');
    }

    final guestPlayers = await _loadGuestPlayersByIds(guestPlayerStatuses.keys);
    final missingGuestPlayerId = guestPlayerStatuses.keys.firstWhere(
      (guestPlayerId) => !guestPlayers.containsKey(guestPlayerId),
      orElse: () => '',
    );
    if (missingGuestPlayerId.isNotEmpty) {
      throw Exception('يوجد لاعب ضيف غير موجود داخل check-in الحالي.');
    }

    final attendanceDrafts = guestPlayerStatuses.entries
        .map(
          (entry) => MatchAttendance(
            id: _guestAttendanceId(
              matchId: matchId,
              guestTeamId: guestTeamId,
              guestPlayerId: entry.key,
            ),
            matchId: matchId,
            guestTeamId: guestTeamId,
            tournamentRegistrationId: context.registration?.id,
            checkInId: _guestCheckInId(
              matchId: matchId,
              guestTeamId: guestTeamId,
            ),
            guestPlayerId: entry.key,
            status: entry.value,
            createdBy: actorId,
            createdAt: effectiveNow,
            updatedAt: effectiveNow,
            markedBy: actorId,
            markedAt: effectiveNow,
            notes: _normalizeOptionalText(notes),
          ),
        )
        .toList(growable: false);

    final existingCheckIn = await _getCheckInByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final checkInId = _guestCheckInId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final outcome = context.canVerify
        ? MatchdayCheckInOutcome.verified
        : MatchdayCheckInOutcome.checkedIn;
    final targetStatus = existingCheckIn?.isVerified == true
        ? MatchCheckInStatus.verified
        : (context.canVerify
              ? MatchCheckInStatus.verified
              : MatchCheckInStatus.checkedIn);
    final updatedCheckIn = MatchCheckIn(
      id: checkInId,
      matchId: matchId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: context.registration?.id,
      status: targetStatus,
      createdBy: existingCheckIn?.createdBy ?? actorId,
      createdAt: existingCheckIn?.createdAt ?? effectiveNow,
      updatedAt: effectiveNow,
      checkedInBy: actorId,
      checkedInAt: effectiveNow,
      verifiedBy: targetStatus == MatchCheckInStatus.verified
          ? actorId
          : existingCheckIn?.verifiedBy,
      verifiedAt: targetStatus == MatchCheckInStatus.verified
          ? effectiveNow
          : existingCheckIn?.verifiedAt,
      notes: _normalizeOptionalText(notes) ?? existingCheckIn?.notes,
    );

    await _firestore.runTransaction((transaction) async {
      final checkInRef = _checkInsRef.doc(checkInId);
      final checkInSnapshot = await transaction.get(checkInRef);
      final attendanceSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final attendance in attendanceDrafts) {
        final attendanceRef = _attendancesRef.doc(attendance.id);
        attendanceSnapshots[attendance.id] = await transaction.get(
          attendanceRef,
        );
      }

      if (checkInSnapshot.exists && checkInSnapshot.data() != null) {
        transaction.update(
          checkInRef,
          MatchCheckInModel.fromEntity(updatedCheckIn).toJson(),
        );
      } else {
        transaction.set(
          checkInRef,
          MatchCheckInModel.fromEntity(updatedCheckIn).toJson(),
        );
      }

      for (final attendance in attendanceDrafts) {
        final attendanceRef = _attendancesRef.doc(attendance.id);
        final attendanceSnapshot = attendanceSnapshots[attendance.id]!;
        if (attendanceSnapshot.exists && attendanceSnapshot.data() != null) {
          final existingAttendance = MatchAttendanceModel.fromJson(
            attendanceSnapshot.data()!,
            attendanceSnapshot.id,
          ).toEntity();
          final updatedAttendance = attendance.copyWith(
            createdBy: existingAttendance.createdBy,
            createdAt: existingAttendance.createdAt,
            notes: attendance.notes ?? existingAttendance.notes,
          );
          transaction.update(
            attendanceRef,
            MatchAttendanceModel.fromEntity(updatedAttendance).toJson(),
          );
        } else {
          transaction.set(
            attendanceRef,
            MatchAttendanceModel.fromEntity(attendance).toJson(),
          );
        }
      }
    });

    return MatchdayCheckInResult(
      outcome: outcome,
      checkIn: updatedCheckIn,
      attendanceCount: attendanceDrafts.length,
    );
  }

  Future<MatchdayLineupValidationResult> validateRegisteredTeamLineup({
    required String matchId,
    required String teamId,
    required String actorId,
    required List<String> starterMembershipIds,
    List<String> benchMembershipIds = const [],
    bool allowIncompleteFriendlyLineup = false,
  }) async {
    final context = await _loadRegisteredContext(
      matchId: matchId,
      teamId: teamId,
      actorId: actorId,
    );
    final checkIn = await _requireCheckedInTeam(
      matchId: matchId,
      teamId: teamId,
    );
    final memberships = await _loadActiveMemberships(teamId);
    final membershipMap = {
      for (final membership in memberships) membership.id: membership,
    };
    final attendances = await _getAttendancesForTeam(
      matchId: matchId,
      teamId: teamId,
    );
    final attendanceMap = {
      for (final attendance in attendances)
        if (attendance.teamMembershipId != null)
          attendance.teamMembershipId!: attendance,
    };

    _ensureUniqueLineupSelection(
      starters: starterMembershipIds,
      bench: benchMembershipIds,
    );
    final requiredStarterCount = _resolveRequiredStarterCount(
      match: context.match,
      tournament: context.tournament,
    );
    _assertStarterCount(
      requiredStarterCount: requiredStarterCount,
      selectedStarters: starterMembershipIds.length,
      allowIncompleteLineup:
          allowIncompleteFriendlyLineup &&
          context.tournament == null &&
          !context.match.isOrganized,
    );

    final selectedMembershipIds = <String>{
      ...starterMembershipIds,
      ...benchMembershipIds,
    };
    final playerIds = <String>{};
    final guestPlayerIds = <String>{};
    for (final membershipId in selectedMembershipIds) {
      final membership = membershipMap[membershipId];
      if (membership == null) {
        throw Exception('يوجد لاعب غير موجود داخل قائمة الفريق الحالية.');
      }
      if (membership.status == TeamMembershipStatus.inactive) {
        throw Exception('لا يمكن اختيار لاعب غير نشط داخل تشكيل المباراة.');
      }
      if (membership.playerId != null) {
        playerIds.add(membership.playerId!);
      }
      if (membership.guestPlayerId != null) {
        guestPlayerIds.add(membership.guestPlayerId!);
      }
    }

    final players = await _loadPlayersByIds(playerIds);
    final guestPlayers = await _loadGuestPlayersByIds(guestPlayerIds);
    final starters = await _buildRegisteredEntries(
      selectedIds: starterMembershipIds,
      membershipMap: membershipMap,
      attendanceMap: attendanceMap,
      players: players,
      guestPlayers: guestPlayers,
    );
    final bench = await _buildRegisteredEntries(
      selectedIds: benchMembershipIds,
      membershipMap: membershipMap,
      attendanceMap: attendanceMap,
      players: players,
      guestPlayers: guestPlayers,
    );

    return MatchdayLineupValidationResult(
      match: context.match,
      checkIn: checkIn,
      requiredStarterCount: requiredStarterCount,
      eligibleParticipants: attendances
          .where((attendance) => attendance.isPresent)
          .length,
      starters: starters,
      bench: bench,
    );
  }

  Future<MatchdayLineupValidationResult> validateGuestTeamLineup({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required List<String> starterGuestPlayerIds,
    List<String> benchGuestPlayerIds = const [],
    bool allowIncompleteFriendlyLineup = false,
  }) async {
    final context = await _loadGuestContext(
      matchId: matchId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final checkIn = await _requireCheckedInGuestTeam(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final attendances = await _getAttendancesForGuestTeam(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final attendanceMap = {
      for (final attendance in attendances)
        if (attendance.guestPlayerId != null)
          attendance.guestPlayerId!: attendance,
    };

    _ensureUniqueLineupSelection(
      starters: starterGuestPlayerIds,
      bench: benchGuestPlayerIds,
    );
    final requiredStarterCount = _resolveRequiredStarterCount(
      match: context.match,
      tournament: context.tournament,
    );
    _assertStarterCount(
      requiredStarterCount: requiredStarterCount,
      selectedStarters: starterGuestPlayerIds.length,
      allowIncompleteLineup:
          allowIncompleteFriendlyLineup &&
          context.tournament == null &&
          !context.match.isOrganized,
    );

    final selectedGuestPlayerIds = <String>{
      ...starterGuestPlayerIds,
      ...benchGuestPlayerIds,
    };
    final guestPlayers = await _loadGuestPlayersByIds(selectedGuestPlayerIds);
    final missingGuestPlayerId = selectedGuestPlayerIds.firstWhere(
      (guestPlayerId) => !guestPlayers.containsKey(guestPlayerId),
      orElse: () => '',
    );
    if (missingGuestPlayerId.isNotEmpty) {
      throw Exception('يوجد لاعب ضيف غير معروف داخل تشكيل المباراة.');
    }

    final starters = _buildGuestEntries(
      selectedIds: starterGuestPlayerIds,
      attendanceMap: attendanceMap,
      guestPlayers: guestPlayers,
    );
    final bench = _buildGuestEntries(
      selectedIds: benchGuestPlayerIds,
      attendanceMap: attendanceMap,
      guestPlayers: guestPlayers,
    );

    return MatchdayLineupValidationResult(
      match: context.match,
      checkIn: checkIn,
      requiredStarterCount: requiredStarterCount,
      eligibleParticipants: attendances
          .where((attendance) => attendance.isPresent)
          .length,
      starters: starters,
      bench: bench,
    );
  }

  Future<MatchdayLineupLockResult> lockRegisteredTeamLineup({
    required String matchId,
    required String teamId,
    required String actorId,
    required List<String> starterMembershipIds,
    List<String> benchMembershipIds = const [],
    bool allowIncompleteFriendlyLineup = false,
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadRegisteredContext(
      matchId: matchId,
      teamId: teamId,
      actorId: actorId,
    );
    final validation = await validateRegisteredTeamLineup(
      matchId: matchId,
      teamId: teamId,
      actorId: actorId,
      starterMembershipIds: starterMembershipIds,
      benchMembershipIds: benchMembershipIds,
      allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
    );
    final attendances = await _getAttendancesForTeam(
      matchId: matchId,
      teamId: teamId,
    );
    final attendanceUpdates = _buildLockAttendanceUpdates(
      attendances: attendances,
      starterAttendanceIds: validation.starters
          .map((entry) => entry.attendanceId)
          .toSet(),
      benchAttendanceIds: validation.bench
          .map((entry) => entry.attendanceId)
          .toSet(),
      actorId: actorId,
      now: effectiveNow,
    );
    final snapshotId = _registeredSnapshotId(matchId: matchId, teamId: teamId);
    final snapshotRef = _snapshotsRef.doc(snapshotId);

    final transactionResult = await _firestore
        .runTransaction<_SnapshotTransactionResult>((transaction) async {
          final snapshotSnapshot = await transaction.get(snapshotRef);
          if (snapshotSnapshot.exists && snapshotSnapshot.data() != null) {
            return _SnapshotTransactionResult(
              outcome: MatchdayLineupLockOutcome.alreadyLocked,
              snapshot: MatchLineupSnapshotModel.fromJson(
                snapshotSnapshot.data()!,
                snapshotSnapshot.id,
              ).toEntity(),
            );
          }

          final matchSnapshot = await transaction.get(_matchesRef.doc(matchId));
          if (!matchSnapshot.exists || matchSnapshot.data() == null) {
            throw Exception('المباراة المطلوبة غير موجودة.');
          }
          final match = MatchModel.fromJson(
            matchSnapshot.data()!,
            matchSnapshot.id,
          ).toEntity();
          _ensureMatchAvailableForPreKickoff(match);

          final decoratedStarters = _decorateEntriesWithSlotAssignments(
            entries: validation.starters,
            slotAssignments: slotAssignments,
          );
          final decoratedBench = _decorateEntriesWithSlotAssignments(
            entries: validation.bench,
            slotAssignments: slotAssignments,
          );
          final snapshot = MatchLineupSnapshot(
            id: snapshotId,
            matchId: matchId,
            teamId: teamId,
            tournamentRegistrationId: context.registration?.id,
            checkInId: validation.checkIn.id,
            starters: decoratedStarters,
            bench: decoratedBench,
            lockedBy: actorId,
            lockedAt: effectiveNow,
            playerCount: validation.requiredStarterCount,
            formationCode: _normalizeOptionalText(formationCode),
            formationLabel: _normalizeOptionalText(formationLabel),
            notes: _normalizeOptionalText(notes),
          );
          transaction.set(
            snapshotRef,
            MatchLineupSnapshotModel.fromEntity(snapshot).toJson(),
          );
          transaction.update(_matchesRef.doc(matchId), {
            'lineupSnapshotIds.$teamId': snapshotId,
          });
          _applyAttendanceUpdates(
            transaction: transaction,
            updatesByAttendanceId: attendanceUpdates,
          );
          return _SnapshotTransactionResult(
            outcome: MatchdayLineupLockOutcome.locked,
            snapshot: snapshot,
          );
        });

    return MatchdayLineupLockResult(
      outcome: transactionResult.outcome,
      snapshot: transactionResult.snapshot,
      validation: validation,
    );
  }

  Future<MatchdayLineupLockResult> lockGuestTeamLineup({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required List<String> starterGuestPlayerIds,
    List<String> benchGuestPlayerIds = const [],
    bool allowIncompleteFriendlyLineup = false,
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadGuestContext(
      matchId: matchId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final validation = await validateGuestTeamLineup(
      matchId: matchId,
      guestTeamId: guestTeamId,
      actorId: actorId,
      starterGuestPlayerIds: starterGuestPlayerIds,
      benchGuestPlayerIds: benchGuestPlayerIds,
      allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
    );
    final attendances = await _getAttendancesForGuestTeam(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final attendanceUpdates = _buildLockAttendanceUpdates(
      attendances: attendances,
      starterAttendanceIds: validation.starters
          .map((entry) => entry.attendanceId)
          .toSet(),
      benchAttendanceIds: validation.bench
          .map((entry) => entry.attendanceId)
          .toSet(),
      actorId: actorId,
      now: effectiveNow,
    );
    final snapshotId = _guestSnapshotId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final snapshotRef = _snapshotsRef.doc(snapshotId);

    final transactionResult = await _firestore
        .runTransaction<_SnapshotTransactionResult>((transaction) async {
          final snapshotSnapshot = await transaction.get(snapshotRef);
          if (snapshotSnapshot.exists && snapshotSnapshot.data() != null) {
            return _SnapshotTransactionResult(
              outcome: MatchdayLineupLockOutcome.alreadyLocked,
              snapshot: MatchLineupSnapshotModel.fromJson(
                snapshotSnapshot.data()!,
                snapshotSnapshot.id,
              ).toEntity(),
            );
          }

          final matchSnapshot = await transaction.get(_matchesRef.doc(matchId));
          if (!matchSnapshot.exists || matchSnapshot.data() == null) {
            throw Exception('المباراة المطلوبة غير موجودة.');
          }
          final match = MatchModel.fromJson(
            matchSnapshot.data()!,
            matchSnapshot.id,
          ).toEntity();
          _ensureMatchAvailableForPreKickoff(match);

          final decoratedStarters = _decorateEntriesWithSlotAssignments(
            entries: validation.starters,
            slotAssignments: slotAssignments,
            useGuestPlayerIdAsKey: true,
          );
          final decoratedBench = _decorateEntriesWithSlotAssignments(
            entries: validation.bench,
            slotAssignments: slotAssignments,
            useGuestPlayerIdAsKey: true,
          );
          final snapshot = MatchLineupSnapshot(
            id: snapshotId,
            matchId: matchId,
            guestTeamId: guestTeamId,
            tournamentRegistrationId: context.registration?.id,
            checkInId: validation.checkIn.id,
            starters: decoratedStarters,
            bench: decoratedBench,
            lockedBy: actorId,
            lockedAt: effectiveNow,
            playerCount: validation.requiredStarterCount,
            formationCode: _normalizeOptionalText(formationCode),
            formationLabel: _normalizeOptionalText(formationLabel),
            notes: _normalizeOptionalText(notes),
          );
          transaction.set(
            snapshotRef,
            MatchLineupSnapshotModel.fromEntity(snapshot).toJson(),
          );
          transaction.update(_matchesRef.doc(matchId), {
            'guestLineupSnapshotIds.$guestTeamId': snapshotId,
          });
          _applyAttendanceUpdates(
            transaction: transaction,
            updatesByAttendanceId: attendanceUpdates,
          );
          return _SnapshotTransactionResult(
            outcome: MatchdayLineupLockOutcome.locked,
            snapshot: snapshot,
          );
        });

    return MatchdayLineupLockResult(
      outcome: transactionResult.outcome,
      snapshot: transactionResult.snapshot,
      validation: validation,
    );
  }

  Future<MatchdaySubstitutionResult> recordRegisteredTeamSubstitution({
    required String matchId,
    required String teamId,
    required String actorId,
    required String outgoingAttendanceId,
    required String incomingAttendanceId,
    required int minute,
    String? notes,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadRegisteredContext(
      matchId: matchId,
      teamId: teamId,
      actorId: actorId,
      requirePreKickoff: false,
    );
    final checkIn = await _requireCheckedInTeam(
      matchId: matchId,
      teamId: teamId,
    );
    final snapshot = await _requireSnapshotByTeamId(
      matchId: matchId,
      teamId: teamId,
    );

    return _recordSubstitution(
      matchId: matchId,
      actorId: actorId,
      outgoingAttendanceId: outgoingAttendanceId,
      incomingAttendanceId: incomingAttendanceId,
      minute: minute,
      teamId: teamId,
      tournamentRegistrationId: context.registration?.id,
      checkInId: checkIn.id,
      lineupSnapshotId: snapshot.id,
      allowedAttendanceIds: {
        ...snapshot.starters.map((entry) => entry.attendanceId),
        ...snapshot.bench.map((entry) => entry.attendanceId),
      },
      notes: notes,
      now: effectiveNow,
    );
  }

  Future<MatchdaySubstitutionResult> recordGuestTeamSubstitution({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required String outgoingAttendanceId,
    required String incomingAttendanceId,
    required int minute,
    String? notes,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final context = await _loadGuestContext(
      matchId: matchId,
      guestTeamId: guestTeamId,
      actorId: actorId,
      requirePreKickoff: false,
    );
    final checkIn = await _requireCheckedInGuestTeam(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    final snapshot = await _requireSnapshotByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );

    return _recordSubstitution(
      matchId: matchId,
      actorId: actorId,
      outgoingAttendanceId: outgoingAttendanceId,
      incomingAttendanceId: incomingAttendanceId,
      minute: minute,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: context.registration?.id,
      checkInId: checkIn.id,
      lineupSnapshotId: snapshot.id,
      allowedAttendanceIds: {
        ...snapshot.starters.map((entry) => entry.attendanceId),
        ...snapshot.bench.map((entry) => entry.attendanceId),
      },
      notes: notes,
      now: effectiveNow,
    );
  }

  Future<_RegisteredSideContext> _loadRegisteredContext({
    required String matchId,
    required String teamId,
    required String actorId,
    bool requirePreKickoff = true,
  }) async {
    final match = await _requireMatch(matchId);
    if (requirePreKickoff) {
      _ensureMatchAvailableForPreKickoff(match);
    }

    final team = await _requireTeam(teamId);
    final tournament = await _loadTournamentIfNeeded(match.tournamentId);
    final hasOrganizerLevelAccess = _hasOrganizerLevelAccess(
      match: match,
      tournament: tournament,
      actorId: actorId,
    );

    if (!hasOrganizerLevelAccess &&
        !_teamRosterPolicy.canManageRoster(team: team, actorId: actorId)) {
      throw Exception('لا تملك صلاحية إدارة check-in أو lineup لهذا الفريق.');
    }

    final registration = await _loadApprovedRegistrationForTeam(
      tournamentId: match.tournamentId,
      teamId: teamId,
    );
    _assertRegisteredTeamBelongsToMatch(
      match: match,
      teamId: teamId,
      hasApprovedTournamentRegistration: registration != null,
    );

    return _RegisteredSideContext(
      match: match,
      team: team,
      tournament: tournament,
      registration: registration,
      canVerify: hasOrganizerLevelAccess,
    );
  }

  Future<_GuestSideContext> _loadGuestContext({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    bool requirePreKickoff = true,
  }) async {
    final match = await _requireMatch(matchId);
    if (requirePreKickoff) {
      _ensureMatchAvailableForPreKickoff(match);
    }

    final guestTeam = await _requireGuestTeam(guestTeamId);
    final tournament = await _loadTournamentIfNeeded(match.tournamentId);
    final hasOrganizerLevelAccess = _hasOrganizerLevelAccess(
      match: match,
      tournament: tournament,
      actorId: actorId,
    );

    if (!hasOrganizerLevelAccess && guestTeam.creatorId != actorId) {
      throw Exception(
        'لا تملك صلاحية إدارة check-in أو lineup لهذا الفريق الضيف.',
      );
    }

    final registration = await _loadApprovedRegistrationForGuestTeam(
      tournamentId: match.tournamentId,
      guestTeamId: guestTeamId,
    );
    _assertGuestTeamBelongsToMatch(
      match: match,
      hasApprovedTournamentRegistration: registration != null,
    );

    return _GuestSideContext(
      match: match,
      guestTeam: guestTeam,
      tournament: tournament,
      registration: registration,
      canVerify: hasOrganizerLevelAccess,
    );
  }

  Future<Match> _requireMatch(String matchId) async {
    final snapshot = await _matchesRef.doc(matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('المباراة المطلوبة غير موجودة.');
    }
    return MatchModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Team> _requireTeam(String teamId) async {
    final snapshot = await _teamsRef.doc(teamId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الفريق المسجل المطلوب غير موجود.');
    }
    return TeamModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<GuestTeam> _requireGuestTeam(String guestTeamId) async {
    final snapshot = await _guestTeamsRef.doc(guestTeamId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الفريق الضيف المطلوب غير موجود.');
    }
    return GuestTeamModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Tournament?> _loadTournamentIfNeeded(String? tournamentId) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الدورة المرتبطة بالمباراة غير موجودة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<TournamentRegistration?> _loadApprovedRegistrationForTeam({
    required String? tournamentId,
    required String teamId,
  }) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _registrationsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw Exception('الفريق غير مسجل داخل الدورة المرتبطة بهذه المباراة.');
    }
    final registration = TournamentRegistrationModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
    if (registration.status != TournamentRegistrationStatus.approved) {
      throw Exception('لا يمكن تشغيل matchday لفريق لم يتم اعتماد تسجيله بعد.');
    }
    return registration;
  }

  Future<TournamentRegistration?> _loadApprovedRegistrationForGuestTeam({
    required String? tournamentId,
    required String guestTeamId,
  }) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _registrationsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw Exception(
        'الفريق الضيف غير مسجل داخل الدورة المرتبطة بهذه المباراة.',
      );
    }
    final registration = TournamentRegistrationModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
    if (registration.status != TournamentRegistrationStatus.approved) {
      throw Exception(
        'لا يمكن تشغيل matchday لفريق ضيف لم يتم اعتماد تسجيله بعد.',
      );
    }
    return registration;
  }

  bool _hasOrganizerLevelAccess({
    required Match match,
    required Tournament? tournament,
    required String actorId,
  }) {
    if (match.organizerId == actorId) {
      return true;
    }
    if (tournament == null) {
      return false;
    }
    if (!tournament.assistants.any(
      (assistant) => assistant.userId == actorId,
    )) {
      return false;
    }
    return _tournamentPermissionService.canManageTeams(tournament, actorId);
  }

  void _assertRegisteredTeamBelongsToMatch({
    required Match match,
    required String teamId,
    required bool hasApprovedTournamentRegistration,
  }) {
    final assignedTeamIds = <String>[
      if (match.teamAId != null) match.teamAId!,
      if (match.teamBId != null) match.teamBId!,
    ];
    if (assignedTeamIds.contains(teamId)) {
      return;
    }
    if (assignedTeamIds.length >= 2 || !hasApprovedTournamentRegistration) {
      throw Exception('هذا الفريق ليس طرفًا صالحًا في المباراة الحالية.');
    }
  }

  void _assertGuestTeamBelongsToMatch({
    required Match match,
    required bool hasApprovedTournamentRegistration,
  }) {
    final assignedTeamIds = <String>[
      if (match.teamAId != null) match.teamAId!,
      if (match.teamBId != null) match.teamBId!,
    ];
    if (assignedTeamIds.length >= 2) {
      throw Exception(
        'المباراة الحالية لا تترك طرفًا متاحًا لفريق ضيف داخل flow الـ matchday.',
      );
    }
    if (match.tournamentId != null && !hasApprovedTournamentRegistration) {
      throw Exception('الفريق الضيف ليس معتمدًا لهذه المباراة داخل الدورة.');
    }
  }

  void _ensureMatchAvailableForPreKickoff(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception('المباراة مجمّدة ولا يمكن تعديل بيانات matchday لها.');
    }

    if (match.status == MatchStatus.live ||
        match.status == MatchStatus.completed ||
        match.status == MatchStatus.pendingReview ||
        match.status == MatchStatus.ratingWindow ||
        match.status == MatchStatus.settled) {
      throw Exception(
        'لا يمكن تنفيذ check-in أو lineup lock بعد انطلاق المباراة.',
      );
    }
  }

  void _ensureMatchAvailableForSubstitution(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception('المباراة مجمّدة ولا يمكن تعديل بيانات التبديلات.');
    }

    if (match.status == MatchStatus.completed ||
        match.status == MatchStatus.pendingReview ||
        match.status == MatchStatus.ratingWindow ||
        match.status == MatchStatus.settled) {
      throw Exception('لا يمكن تسجيل تبديلات بعد انتهاء المباراة.');
    }
  }

  Future<List<TeamMembership>> _loadActiveMemberships(String teamId) async {
    final snapshot = await _teamMembershipsRef
        .where('teamId', isEqualTo: teamId)
        .get();
    final memberships = snapshot.docs
        .map(
          (doc) => TeamMembershipModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .where(
          (membership) => membership.status != TeamMembershipStatus.inactive,
        )
        .toList(growable: true);
    memberships.sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
    return memberships;
  }

  Future<Map<String, Player>> _loadPlayersByIds(Set<String> playerIds) async {
    final result = <String, Player>{};
    for (final playerId in playerIds) {
      final snapshot = await _playersRef.doc(playerId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        continue;
      }
      result[playerId] = PlayerModel.fromJson(
        snapshot.data()!,
        snapshot.id,
      ).toEntity();
    }
    return result;
  }

  Future<Map<String, GuestPlayer>> _loadGuestPlayersByIds(
    Iterable<String> guestPlayerIds,
  ) async {
    final result = <String, GuestPlayer>{};
    for (final guestPlayerId in guestPlayerIds) {
      final snapshot = await _guestPlayersRef.doc(guestPlayerId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        continue;
      }
      result[guestPlayerId] = GuestPlayerModel.fromJson(
        snapshot.data()!,
        snapshot.id,
      ).toEntity();
    }
    return result;
  }

  Future<MatchCheckIn?> _getCheckInByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchCheckInModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchCheckIn?> _getCheckInByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchCheckInModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchLineupSnapshot?> _getSnapshotByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchLineupSnapshotModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchLineupSnapshot?> _getSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchLineupSnapshotModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchCheckIn> _requireCheckedInTeam({
    required String matchId,
    required String teamId,
  }) async {
    final checkIn = await _getCheckInByTeamId(matchId: matchId, teamId: teamId);
    if (checkIn == null || !checkIn.isCheckedIn) {
      throw Exception('يجب تنفيذ check-in للفريق أولاً قبل قفل التشكيل.');
    }
    return checkIn;
  }

  Future<MatchCheckIn> _requireCheckedInGuestTeam({
    required String matchId,
    required String guestTeamId,
  }) async {
    final checkIn = await _getCheckInByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    if (checkIn == null || !checkIn.isCheckedIn) {
      throw Exception('يجب تنفيذ check-in للفريق الضيف أولاً قبل قفل التشكيل.');
    }
    return checkIn;
  }

  Future<MatchLineupSnapshot> _requireSnapshotByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _getSnapshotByTeamId(
      matchId: matchId,
      teamId: teamId,
    );
    if (snapshot == null) {
      throw Exception('يجب قفل التشكيل أولاً قبل تسجيل التبديلات.');
    }
    return snapshot;
  }

  Future<MatchLineupSnapshot> _requireSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _getSnapshotByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    if (snapshot == null) {
      throw Exception('يجب قفل تشكيل الفريق الضيف أولاً قبل تسجيل التبديلات.');
    }
    return snapshot;
  }

  Future<List<MatchAttendance>> _getAttendancesForTeam({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _attendancesRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .get();
    final attendances = snapshot.docs
        .map(
          (doc) => MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    attendances.sort(
      (left, right) => left.createdAt.compareTo(right.createdAt),
    );
    return attendances;
  }

  Future<List<MatchAttendance>> _getAttendancesForGuestTeam({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _attendancesRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .get();
    final attendances = snapshot.docs
        .map(
          (doc) => MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    attendances.sort(
      (left, right) => left.createdAt.compareTo(right.createdAt),
    );
    return attendances;
  }

  Future<MatchdaySubstitutionResult> _recordSubstitution({
    required String matchId,
    required String actorId,
    required String outgoingAttendanceId,
    required String incomingAttendanceId,
    required int minute,
    String? teamId,
    String? guestTeamId,
    String? tournamentRegistrationId,
    required String checkInId,
    required String lineupSnapshotId,
    required Set<String> allowedAttendanceIds,
    String? notes,
    required DateTime now,
  }) async {
    if ((teamId != null) == (guestTeamId != null)) {
      throw Exception('يجب تحديد طرف واحد فقط لتسجيل التبديل.');
    }
    if (outgoingAttendanceId == incomingAttendanceId) {
      throw Exception('لا يمكن تسجيل تبديل على نفس اللاعب.');
    }
    if (minute < 0) {
      throw Exception('دقيقة التبديل يجب أن تكون صفر أو أكبر.');
    }
    if (!allowedAttendanceIds.contains(outgoingAttendanceId) ||
        !allowedAttendanceIds.contains(incomingAttendanceId)) {
      throw Exception('التبديل يجب أن يكون بين عناصر التشكيل المقفول فقط.');
    }

    final substitution = MatchSubstitution(
      id: _uuid.v4(),
      matchId: matchId,
      teamId: teamId,
      guestTeamId: guestTeamId,
      tournamentRegistrationId: tournamentRegistrationId,
      checkInId: checkInId,
      lineupSnapshotId: lineupSnapshotId,
      outgoingAttendanceId: outgoingAttendanceId,
      incomingAttendanceId: incomingAttendanceId,
      minute: minute,
      createdBy: actorId,
      createdAt: now,
      notes: _normalizeOptionalText(notes),
    );

    return _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(_matchesRef.doc(matchId));
      final outgoingSnapshot = await transaction.get(
        _attendancesRef.doc(outgoingAttendanceId),
      );
      final incomingSnapshot = await transaction.get(
        _attendancesRef.doc(incomingAttendanceId),
      );
      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw Exception('المباراة المطلوبة غير موجودة.');
      }
      if (!outgoingSnapshot.exists || outgoingSnapshot.data() == null) {
        throw Exception('سجل اللاعب الخارج غير موجود.');
      }
      if (!incomingSnapshot.exists || incomingSnapshot.data() == null) {
        throw Exception('سجل اللاعب البديل غير موجود.');
      }

      final match = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();
      _ensureMatchAvailableForSubstitution(match);

      final outgoingAttendance = MatchAttendanceModel.fromJson(
        outgoingSnapshot.data()!,
        outgoingSnapshot.id,
      ).toEntity();
      final incomingAttendance = MatchAttendanceModel.fromJson(
        incomingSnapshot.data()!,
        incomingSnapshot.id,
      ).toEntity();

      _assertAttendancesBelongToSameSide(
        outgoingAttendance: outgoingAttendance,
        incomingAttendance: incomingAttendance,
        teamId: teamId,
        guestTeamId: guestTeamId,
      );
      _assertSubstitutionParticipants(
        outgoingAttendance: outgoingAttendance,
        incomingAttendance: incomingAttendance,
      );

      final updatedOutgoing = outgoingAttendance.copyWith(
        played: true,
        currentlyOnPitch: false,
        lastExitedMinute: minute,
        updatedAt: now,
        participationUpdatedBy: actorId,
        participationUpdatedAt: now,
      );
      final updatedIncoming = incomingAttendance.copyWith(
        includedInLockedLineup: true,
        played: true,
        currentlyOnPitch: true,
        firstEnteredMinute: incomingAttendance.firstEnteredMinute ?? minute,
        lastExitedMinute: null,
        updatedAt: now,
        participationUpdatedBy: actorId,
        participationUpdatedAt: now,
      );

      transaction.update(
        _attendancesRef.doc(outgoingAttendanceId),
        MatchAttendanceModel.fromEntity(updatedOutgoing).toJson(),
      );
      transaction.update(
        _attendancesRef.doc(incomingAttendanceId),
        MatchAttendanceModel.fromEntity(updatedIncoming).toJson(),
      );
      transaction.set(
        _substitutionsRef.doc(substitution.id),
        MatchSubstitutionModel.fromEntity(substitution).toJson(),
      );

      return MatchdaySubstitutionResult(
        substitution: substitution,
        outgoingAttendance: updatedOutgoing,
        incomingAttendance: updatedIncoming,
      );
    });
  }

  Future<List<MatchLineupEntry>> _buildRegisteredEntries({
    required List<String> selectedIds,
    required Map<String, TeamMembership> membershipMap,
    required Map<String, MatchAttendance> attendanceMap,
    required Map<String, Player> players,
    required Map<String, GuestPlayer> guestPlayers,
  }) async {
    final entries = <MatchLineupEntry>[];
    for (final membershipId in selectedIds) {
      final membership = membershipMap[membershipId];
      final attendance = attendanceMap[membershipId];
      if (membership == null || attendance == null) {
        throw Exception('توجد عضوية لا تملك attendance matchday صالحًا.');
      }
      _assertAttendanceEligibleForLineup(attendance);

      if (membership.playerId != null) {
        final player = players[membership.playerId];
        entries.add(
          MatchLineupEntry(
            attendanceId: attendance.id,
            teamMembershipId: membership.id,
            playerId: membership.playerId,
            claimedFromGuestPlayerId: membership.claimedFromGuestPlayerId,
            role: membership.role,
            availability: membership.availability,
            attendanceStatus: attendance.status,
            displayName: player?.name ?? membership.playerId!,
            position: player?.position,
          ),
        );
      } else {
        final guestPlayer = guestPlayers[membership.guestPlayerId];
        entries.add(
          MatchLineupEntry(
            attendanceId: attendance.id,
            teamMembershipId: membership.id,
            guestPlayerId: membership.guestPlayerId,
            role: membership.role,
            availability: membership.availability,
            attendanceStatus: attendance.status,
            displayName: guestPlayer?.displayName ?? membership.guestPlayerId!,
            position: guestPlayer?.preferredPosition,
          ),
        );
      }
    }
    return entries;
  }

  /// Decorates pre-built [MatchLineupEntry] instances with pitch-position data
  /// from [slotAssignments].  The lookup key is [teamMembershipId] by default,
  /// or [guestPlayerId] when [useGuestPlayerIdAsKey] is true.
  List<MatchLineupEntry> _decorateEntriesWithSlotAssignments({
    required List<MatchLineupEntry> entries,
    required List<SlotAssignment> slotAssignments,
    bool useGuestPlayerIdAsKey = false,
  }) {
    if (slotAssignments.isEmpty) {
      return entries;
    }
    final assignmentMap = <String, SlotAssignment>{
      for (final assignment in slotAssignments)
        assignment.membershipId: assignment,
    };
    return entries.map((entry) {
      final lookupKey = useGuestPlayerIdAsKey
          ? entry.guestPlayerId
          : entry.teamMembershipId;
      if (lookupKey == null) return entry;
      final assignment = assignmentMap[lookupKey];
      if (assignment == null) return entry;
      return entry.copyWith(
        slotId: assignment.slotId,
        slotRole: assignment.slotRole,
        lineIndex: assignment.lineIndex,
        slotIndex: assignment.slotIndex,
        slotX: assignment.slotX,
        slotY: assignment.slotY,
      );
    }).toList(growable: false);
  }

  List<MatchLineupEntry> _buildGuestEntries({
    required List<String> selectedIds,
    required Map<String, MatchAttendance> attendanceMap,
    required Map<String, GuestPlayer> guestPlayers,
  }) {
    final entries = <MatchLineupEntry>[];
    for (final guestPlayerId in selectedIds) {
      final attendance = attendanceMap[guestPlayerId];
      final guestPlayer = guestPlayers[guestPlayerId];
      if (attendance == null || guestPlayer == null) {
        throw Exception('يوجد لاعب ضيف لا يملك attendance صالحًا في المباراة.');
      }
      _assertAttendanceEligibleForLineup(attendance);
      entries.add(
        MatchLineupEntry(
          attendanceId: attendance.id,
          guestPlayerId: guestPlayerId,
          role: TeamMembershipRole.player,
          availability: TeamMemberAvailability.available,
          attendanceStatus: attendance.status,
          displayName: guestPlayer.displayName,
          position: guestPlayer.preferredPosition,
        ),
      );
    }
    return entries;
  }

  Map<String, Map<String, dynamic>> _buildLockAttendanceUpdates({
    required List<MatchAttendance> attendances,
    required Set<String> starterAttendanceIds,
    required Set<String> benchAttendanceIds,
    required String actorId,
    required DateTime now,
  }) {
    final updatesByAttendanceId = <String, Map<String, dynamic>>{};
    final nowMillis = now.millisecondsSinceEpoch;
    for (final attendance in attendances) {
      final isStarter = starterAttendanceIds.contains(attendance.id);
      final isBench = benchAttendanceIds.contains(attendance.id);
      updatesByAttendanceId[attendance.id] = {
        'includedInLockedLineup': isStarter || isBench,
        'startedMatch': isStarter,
        'played': isStarter,
        'currentlyOnPitch': isStarter,
        'firstEnteredMinute': isStarter ? 0 : null,
        'lastExitedMinute': null,
        'participationUpdatedBy': actorId,
        'participationUpdatedAt': nowMillis,
        'updatedAt': nowMillis,
      };
    }
    return updatesByAttendanceId;
  }

  void _applyAttendanceUpdates({
    required Transaction transaction,
    required Map<String, Map<String, dynamic>> updatesByAttendanceId,
  }) {
    for (final entry in updatesByAttendanceId.entries) {
      transaction.update(_attendancesRef.doc(entry.key), entry.value);
    }
  }

  void _ensureUniqueLineupSelection({
    required List<String> starters,
    required List<String> bench,
  }) {
    if (starters.isEmpty) {
      throw Exception('يجب اختيار أساسي واحد على الأقل قبل قفل التشكيل.');
    }

    final startersSet = starters.toSet();
    if (startersSet.length != starters.length) {
      throw Exception('لا يمكن تكرار نفس اللاعب داخل قائمة الأساسيين.');
    }

    final benchSet = bench.toSet();
    if (benchSet.length != bench.length) {
      throw Exception('لا يمكن تكرار نفس اللاعب داخل قائمة الاحتياط.');
    }

    if (startersSet.intersection(benchSet).isNotEmpty) {
      throw Exception('لا يمكن أن يوجد اللاعب نفسه في الأساسي والاحتياط معًا.');
    }
  }

  int _resolveRequiredStarterCount({
    required Match match,
    required Tournament? tournament,
  }) {
    if (tournament != null) {
      return tournament.teamSize.value;
    }
    return normalizeMatchTeamSize(match.teamSize);
  }

  void _assertStarterCount({
    required int requiredStarterCount,
    required int selectedStarters,
    bool allowIncompleteLineup = false,
  }) {
    if (allowIncompleteLineup) {
      if (selectedStarters <= 0) {
        throw Exception('يجب اختيار أساسي واحد على الأقل قبل قفل التشكيل.');
      }
      if (selectedStarters > requiredStarterCount) {
        throw Exception(
          'لا يمكن اختيار أكثر من $requiredStarterCount لاعبين أساسيين لهذه المباراة.',
        );
      }
      return;
    }

    if (selectedStarters != requiredStarterCount) {
      throw Exception(
        'يجب اختيار $requiredStarterCount لاعبين أساسيين قبل قفل التشكيل.',
      );
    }
  }

  void _assertAttendanceEligibleForLineup(MatchAttendance attendance) {
    if (attendance.status == MatchAttendanceStatus.present ||
        attendance.status == MatchAttendanceStatus.late) {
      return;
    }
    throw Exception(
      'لا يمكن قفل التشكيل بلاعبين لم يتم تأكيد حضورهم في matchday.',
    );
  }

  void _assertAttendancesBelongToSameSide({
    required MatchAttendance outgoingAttendance,
    required MatchAttendance incomingAttendance,
    String? teamId,
    String? guestTeamId,
  }) {
    if (teamId != null) {
      if (outgoingAttendance.teamId != teamId ||
          incomingAttendance.teamId != teamId) {
        throw Exception('التبديل يجب أن يتم داخل نفس الفريق المسجل.');
      }
      return;
    }

    if (outgoingAttendance.guestTeamId != guestTeamId ||
        incomingAttendance.guestTeamId != guestTeamId) {
      throw Exception('التبديل يجب أن يتم داخل نفس الفريق الضيف.');
    }
  }

  void _assertSubstitutionParticipants({
    required MatchAttendance outgoingAttendance,
    required MatchAttendance incomingAttendance,
  }) {
    if (!outgoingAttendance.currentlyOnPitch) {
      throw Exception('اللاعب الخارج ليس داخل أرض الملعب حاليًا.');
    }
    if (incomingAttendance.currentlyOnPitch) {
      throw Exception('اللاعب البديل موجود بالفعل داخل أرض الملعب.');
    }
    if (!incomingAttendance.includedInLockedLineup) {
      throw Exception('اللاعب البديل يجب أن يكون ضمن التشكيل المقفول.');
    }
    _assertAttendanceEligibleForLineup(incomingAttendance);
  }

  MatchAttendanceStatus _defaultAttendanceStatusForMembership(
    TeamMembership membership,
  ) {
    return switch (membership.availability) {
      TeamMemberAvailability.available => MatchAttendanceStatus.present,
      TeamMemberAvailability.pending => MatchAttendanceStatus.pending,
      TeamMemberAvailability.unavailable ||
      TeamMemberAvailability.injured => MatchAttendanceStatus.absent,
    };
  }

  String _registeredCheckInId({
    required String matchId,
    required String teamId,
  }) {
    return 'match::$matchId::team::$teamId::checkin';
  }

  String _guestCheckInId({
    required String matchId,
    required String guestTeamId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::checkin';
  }

  String _registeredAttendanceId({
    required String matchId,
    required String teamId,
    required String membershipId,
  }) {
    return 'match::$matchId::team::$teamId::attendance::$membershipId';
  }

  String _guestAttendanceId({
    required String matchId,
    required String guestTeamId,
    required String guestPlayerId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::attendance::$guestPlayerId';
  }

  String _registeredSnapshotId({
    required String matchId,
    required String teamId,
  }) {
    return 'match::$matchId::team::$teamId::lineup';
  }

  String _guestSnapshotId({
    required String matchId,
    required String guestTeamId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::lineup';
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _RegisteredSideContext {
  final Match match;
  final Team team;
  final Tournament? tournament;
  final TournamentRegistration? registration;
  final bool canVerify;

  const _RegisteredSideContext({
    required this.match,
    required this.team,
    required this.tournament,
    required this.registration,
    required this.canVerify,
  });
}

class _GuestSideContext {
  final Match match;
  final GuestTeam guestTeam;
  final Tournament? tournament;
  final TournamentRegistration? registration;
  final bool canVerify;

  const _GuestSideContext({
    required this.match,
    required this.guestTeam,
    required this.tournament,
    required this.registration,
    required this.canVerify,
  });
}

class _SnapshotTransactionResult {
  final MatchdayLineupLockOutcome outcome;
  final MatchLineupSnapshot snapshot;

  const _SnapshotTransactionResult({
    required this.outcome,
    required this.snapshot,
  });
}
