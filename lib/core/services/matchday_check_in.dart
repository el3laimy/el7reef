part of 'matchday_service.dart';

class _MatchdayCheckInService extends _MatchdayServiceBase {
  _MatchdayCheckInService({
    super.firestore,
    super.tournamentPermissionService,
    super.teamRosterPolicy,
    super.uuid,
  });

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

    final membershipIds =
        memberships.map((membership) => membership.id).toSet();
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
            status: membershipStatuses[membership.id] ??
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

    await firestore.runTransaction((transaction) async {
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

    final guestPlayers =
        await _loadGuestPlayersByIds(guestPlayerStatuses.keys);
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

    await firestore.runTransaction((transaction) async {
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
}
