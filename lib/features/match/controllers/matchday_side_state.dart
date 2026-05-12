part of 'matchday_controller.dart';

extension MatchdaySideState on MatchdayController {
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
}
