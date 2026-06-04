part of 'matchday_controller.dart';

extension MatchdaySideDiscovery on MatchdayController {
  Future<List<MatchdayManagedSide>> _discoverManagedSides({
    required Match match,
    required Tournament? tournament,
  }) async {
    final actorId = currentUserId;
    if (actorId == null) {
      return const [];
    }

    final organizerLevel = await _hasOrganizerLevelAccess(
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

  Future<bool> _hasOrganizerLevelAccess({
    required Match match,
    required Tournament? tournament,
    required String actorId,
  }) async {
    if (tournament == null) {
      return match.organizerId == actorId;
    }
    if (tournament.organizerId == actorId) {
      return true;
    }
    return hasTournamentAssistantPermission(
      tournament,
      actorId,
      TournamentAssistantPermissionKey.canStartMatch,
    );
  }

  bool _canManageRegisteredTeam(Team team, String actorId) {
    return team.ownerId == actorId || team.viceCaptainIds.contains(actorId);
  }
}
