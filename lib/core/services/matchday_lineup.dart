part of 'matchday_service.dart';

class _MatchdayLineupService extends _MatchdayServiceBase {
  _MatchdayLineupService({
    super.firestore,
    super.tournamentPermissionService,
    super.teamRosterPolicy,
    super.uuid,
  });

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
    final guestPlayers =
        await _loadGuestPlayersByIds(selectedGuestPlayerIds);
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
    final snapshotId =
        _registeredSnapshotId(matchId: matchId, teamId: teamId);
    final snapshotRef = _snapshotsRef.doc(snapshotId);

    final transactionResult =
        await firestore.runTransaction<_SnapshotTransactionResult>(
      (transaction) async {
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

        final matchSnapshot =
            await transaction.get(_matchesRef.doc(matchId));
        if (!matchSnapshot.exists || matchSnapshot.data() == null) {
          throw Exception('المباراة المطلوبة غير موجودة.');
        }
        final match = MatchModel.fromJson(
          matchSnapshot.data()!,
          matchSnapshot.id,
        ).toEntity();
        _ensureMatchAvailableForPreKickoff(match);
        _assertSlotAssignmentsBelongToStarters(
          starters: validation.starters,
          slotAssignments: slotAssignments,
        );

        final decoratedStarters = _decorateEntriesWithSlotAssignments(
          entries: validation.starters,
          slotAssignments: slotAssignments,
        );
        final snapshot = MatchLineupSnapshot(
          id: snapshotId,
          matchId: matchId,
          teamId: teamId,
          tournamentRegistrationId: context.registration?.id,
          checkInId: validation.checkIn.id,
          starters: decoratedStarters,
          bench: validation.bench,
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
      },
    );

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
    final snapshotId =
        _guestSnapshotId(matchId: matchId, guestTeamId: guestTeamId);
    final snapshotRef = _snapshotsRef.doc(snapshotId);

    final transactionResult =
        await firestore.runTransaction<_SnapshotTransactionResult>(
      (transaction) async {
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

        final matchSnapshot =
            await transaction.get(_matchesRef.doc(matchId));
        if (!matchSnapshot.exists || matchSnapshot.data() == null) {
          throw Exception('المباراة المطلوبة غير موجودة.');
        }
        final match = MatchModel.fromJson(
          matchSnapshot.data()!,
          matchSnapshot.id,
        ).toEntity();
        _ensureMatchAvailableForPreKickoff(match);
        _assertSlotAssignmentsBelongToStarters(
          starters: validation.starters,
          slotAssignments: slotAssignments,
          useGuestPlayerIdAsKey: true,
        );

        final decoratedStarters = _decorateEntriesWithSlotAssignments(
          entries: validation.starters,
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
          bench: validation.bench,
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
      },
    );

    return MatchdayLineupLockResult(
      outcome: transactionResult.outcome,
      snapshot: transactionResult.snapshot,
      validation: validation,
    );
  }

  Future<MatchLineupSnapshot> lockMatchSideLineup({
    required String matchId,
    required String matchSideId,
    required String sideKey,
    required String actorId,
    required List<String> starterMatchSidePlayerIds,
    List<String> benchMatchSidePlayerIds = const [],
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final normalizedSide = _normalizeSideKey(sideKey);
    if (actorId.trim().isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    final match = await _requireMatch(matchId);
    _ensureMatchAvailableForPreKickoff(match);
    if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
      throw Exception('تشكيلات الأطراف المؤقتة متاحة للمباريات الودية فقط.');
    }

    final side = await _requireMatchSide(
      matchId: matchId,
      matchSideId: matchSideId,
      sideKey: normalizedSide,
    );
    _ensureCanManageMatchSideLineup(
      match: match,
      side: side,
      actorId: actorId,
    );
    if (!side.isTemporary) {
      throw Exception('استخدم محرر الفريق الرسمي لهذا الطرف.');
    }

    _ensureUniqueLineupSelection(
      starters: starterMatchSidePlayerIds,
      bench: benchMatchSidePlayerIds,
    );
    final requiredStarterCount = normalizeMatchTeamSize(match.teamSize);
    _assertStarterCount(
      requiredStarterCount: requiredStarterCount,
      selectedStarters: starterMatchSidePlayerIds.length,
      allowIncompleteLineup: true,
    );

    final sidePlayers =
        await _loadMatchSidePlayers(matchId, normalizedSide);
    final sidePlayerMap = {
      for (final player in sidePlayers) player.id: player,
    };
    final selectedIds = <String>{
      ...starterMatchSidePlayerIds,
      ...benchMatchSidePlayerIds,
    };
    final missingPlayerId = selectedIds.firstWhere(
      (playerId) => !sidePlayerMap.containsKey(playerId),
      orElse: () => '',
    );
    if (missingPlayerId.isNotEmpty) {
      throw Exception('يوجد لاعب مؤقت لا ينتمي لهذا الطرف.');
    }

    final starters = _buildMatchSideEntries(
      selectedIds: starterMatchSidePlayerIds,
      sidePlayerMap: sidePlayerMap,
    );
    final bench = _buildMatchSideEntries(
      selectedIds: benchMatchSidePlayerIds,
      sidePlayerMap: sidePlayerMap,
    );
    _assertSlotAssignmentsBelongToStarters(
      starters: starters,
      slotAssignments: slotAssignments,
      useMatchSidePlayerIdAsKey: true,
    );

    final snapshotId = _matchSideSnapshotId(
      matchId: matchId,
      matchSideId: matchSideId,
    );
    final snapshotRef = _snapshotsRef.doc(snapshotId);
    final decoratedStarters = _decorateEntriesWithSlotAssignments(
      entries: starters,
      slotAssignments: slotAssignments,
      useMatchSidePlayerIdAsKey: true,
    );
    final snapshot = MatchLineupSnapshot(
      id: snapshotId,
      matchId: matchId,
      matchSideId: matchSideId,
      sideKey: normalizedSide,
      starters: decoratedStarters,
      bench: bench,
      lockedBy: actorId,
      lockedAt: effectiveNow,
      playerCount: requiredStarterCount,
      formationCode: _normalizeOptionalText(formationCode),
      formationLabel: _normalizeOptionalText(formationLabel),
      notes: _normalizeOptionalText(notes),
    );

    return firestore.runTransaction<MatchLineupSnapshot>(
      (transaction) async {
        final existingSnapshot = await transaction.get(snapshotRef);
        if (existingSnapshot.exists && existingSnapshot.data() != null) {
          return MatchLineupSnapshotModel.fromJson(
            existingSnapshot.data()!,
            existingSnapshot.id,
          ).toEntity();
        }

        final matchSnapshot =
            await transaction.get(_matchesRef.doc(matchId));
        if (!matchSnapshot.exists || matchSnapshot.data() == null) {
          throw Exception('المباراة المطلوبة غير موجودة.');
        }
        final transactionMatch = MatchModel.fromJson(
          matchSnapshot.data()!,
          matchSnapshot.id,
        ).toEntity();
        _ensureMatchAvailableForPreKickoff(transactionMatch);
        transaction.set(
          snapshotRef,
          MatchLineupSnapshotModel.fromEntity(snapshot).toJson(),
        );
        transaction.update(_matchesRef.doc(matchId), {
          'matchSideLineupSnapshotIds.$matchSideId': snapshotId,
        });
        return snapshot;
      },
    );
  }

  Future<void> unlockLineup({
    required String matchId,
    required String snapshotId,
    required String actorId,
  }) async {
    if (actorId.trim().isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    await firestore.runTransaction((transaction) async {
      final matchRef = _matchesRef.doc(matchId);
      final snapshotRef = _snapshotsRef.doc(snapshotId);
      final matchSnapshot = await transaction.get(matchRef);
      final lineupSnapshot = await transaction.get(snapshotRef);

      if (!matchSnapshot.exists || matchSnapshot.data() == null) {
        throw Exception('المباراة المطلوبة غير موجودة.');
      }
      if (!lineupSnapshot.exists || lineupSnapshot.data() == null) {
        throw Exception('التشكيلة المقفولة غير موجودة.');
      }

      final match = MatchModel.fromJson(
        matchSnapshot.data()!,
        matchSnapshot.id,
      ).toEntity();
      final snapshot = MatchLineupSnapshotModel.fromJson(
        lineupSnapshot.data()!,
        lineupSnapshot.id,
      ).toEntity();

      if (snapshot.matchId != match.id) {
        throw Exception('التشكيلة لا تخص هذه المباراة.');
      }
      _ensureMatchAvailableForPreKickoff(match);

      final tournament = await _loadTournamentForTransaction(
        transaction: transaction,
        tournamentId: match.tournamentId,
      );
      _ensureCanUnlockLineup(
        match: match,
        tournament: tournament,
        actorId: actorId,
      );

      transaction.delete(snapshotRef);
      final updates = <String, Object?>{};
      if (snapshot.teamId != null) {
        updates['lineupSnapshotIds.${snapshot.teamId}'] =
            FieldValue.delete();
      }
      if (snapshot.guestTeamId != null) {
        updates['guestLineupSnapshotIds.${snapshot.guestTeamId}'] =
            FieldValue.delete();
      }
      if (snapshot.matchSideId != null) {
        updates['matchSideLineupSnapshotIds.${snapshot.matchSideId}'] =
            FieldValue.delete();
      }
      if (updates.isNotEmpty) {
        transaction.update(matchRef, updates);
      }
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
        throw Exception(
          'توجد عضوية لا تملك attendance matchday صالحًا.',
        );
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
            displayName:
                guestPlayer?.displayName ?? membership.guestPlayerId!,
            position: guestPlayer?.preferredPosition,
          ),
        );
      }
    }
    return entries;
  }

  List<MatchLineupEntry> _decorateEntriesWithSlotAssignments({
    required List<MatchLineupEntry> entries,
    required List<SlotAssignment> slotAssignments,
    bool useGuestPlayerIdAsKey = false,
    bool useMatchSidePlayerIdAsKey = false,
  }) {
    if (slotAssignments.isEmpty) {
      return entries;
    }
    final assignmentMap = <String, SlotAssignment>{
      for (final assignment in slotAssignments)
        assignment.membershipId: assignment,
    };

    return entries
        .map((entry) {
          final lookupKey = useGuestPlayerIdAsKey
              ? entry.guestPlayerId
              : useMatchSidePlayerIdAsKey
                  ? entry.matchSidePlayerId
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
        })
        .toList(growable: false);
  }

  void _assertSlotAssignmentsBelongToStarters({
    required List<MatchLineupEntry> starters,
    required List<SlotAssignment> slotAssignments,
    bool useGuestPlayerIdAsKey = false,
    bool useMatchSidePlayerIdAsKey = false,
  }) {
    if (slotAssignments.isEmpty) return;

    final starterIds = starters
        .map((entry) => useGuestPlayerIdAsKey
            ? entry.guestPlayerId
            : useMatchSidePlayerIdAsKey
                ? entry.matchSidePlayerId
                : entry.teamMembershipId)
        .whereType<String>()
        .toSet();
    final invalidIds = slotAssignments
        .map((assignment) => assignment.membershipId)
        .where((membershipId) => !starterIds.contains(membershipId))
        .toSet();
    if (invalidIds.isNotEmpty) {
      throw Exception(
        'توجد slot assignment للاعب غير أساسي في التشكيلة.',
      );
    }
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
        throw Exception(
          'يوجد لاعب ضيف لا يملك attendance صالحًا في المباراة.',
        );
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

  List<MatchLineupEntry> _buildMatchSideEntries({
    required List<String> selectedIds,
    required Map<String, MatchSidePlayer> sidePlayerMap,
  }) {
    final entries = <MatchLineupEntry>[];
    for (final matchSidePlayerId in selectedIds) {
      final sidePlayer = sidePlayerMap[matchSidePlayerId];
      if (sidePlayer == null) {
        throw Exception('يوجد لاعب مؤقت غير موجود داخل طرف المباراة.');
      }
      entries.add(
        MatchLineupEntry(
          attendanceId: 'matchSidePlayer::$matchSidePlayerId',
          matchSidePlayerId: matchSidePlayerId,
          role: TeamMembershipRole.player,
          availability: TeamMemberAvailability.available,
          attendanceStatus: MatchAttendanceStatus.present,
          displayName: sidePlayer.displayName,
          position: sidePlayer.position,
          ratingEligible:
              sidePlayer.ratingEligible && sidePlayer.isRegistered,
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
      throw Exception(
        'لا يمكن أن يوجد اللاعب نفسه في الأساسي والاحتياط معًا.',
      );
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
        throw Exception(
          'يجب اختيار أساسي واحد على الأقل قبل قفل التشكيل.',
        );
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

}
