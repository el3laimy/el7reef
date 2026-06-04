part of 'matchday_service.dart';

class _MatchdaySubstitutionService extends _MatchdayServiceBase {
  _MatchdaySubstitutionService({
    super.firestore,
    super.teamRosterPolicy,
    super.uuid,
  });

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
      throw Exception(
        'التبديل يجب أن يكون بين عناصر التشكيل المقفول فقط.',
      );
    }

    final substitution = MatchSubstitution(
      id: uuid.v4(),
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

    return firestore.runTransaction((transaction) async {
      final matchSnapshot =
          await transaction.get(_matchesRef.doc(matchId));
      final outgoingSnapshot =
          await transaction.get(_attendancesRef.doc(outgoingAttendanceId));
      final incomingSnapshot =
          await transaction.get(_attendancesRef.doc(incomingAttendanceId));
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
        firstEnteredMinute:
            incomingAttendance.firstEnteredMinute ?? minute,
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
}
