import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_enums.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/entities/tournament_participant.dart';

class GroupStageBuildResult {
  final String groupStageId;
  final List<TournamentGroup> groups;
  final List<Match> fixtures;
  final List<GroupStandingSnapshot> standings;

  const GroupStageBuildResult({
    required this.groupStageId,
    required this.groups,
    required this.fixtures,
    required this.standings,
  });
}

class GroupStageBuilder {
  const GroupStageBuilder();

  String groupStageIdFor(String tournamentId) => 'group-stage::$tournamentId';

  GroupStageBuildResult build({
    required Tournament tournament,
    required List<TournamentParticipant> participants,
    required DateTime now,
  }) {
    if (tournament.format == TournamentFormat.knockoutOnly) {
      throw Exception('هذه البطولة لا تستخدم مرحلة المجموعات.');
    }

    final finalizedParticipants = participants
        .where(
          (participant) =>
              participant.status == TournamentParticipantStatus.finalized,
        )
        .toList(growable: true);
    if (finalizedParticipants.length < 2) {
      throw Exception('لا يمكن إنشاء مرحلة المجموعات قبل قفل المشاركين.');
    }

    finalizedParticipants.sort(
      (left, right) => (left.seed ?? 1 << 20).compareTo(right.seed ?? 1 << 20),
    );

    final groupStageId = groupStageIdFor(tournament.id);
    final groupsCount = _determineGroupCount(
      participantCount: finalizedParticipants.length,
      format: tournament.format,
    );
    final distributedGroups = List<List<TournamentParticipant>>.generate(
      groupsCount,
      (_) => <TournamentParticipant>[],
    );
    for (int index = 0; index < finalizedParticipants.length; index++) {
      final lap = index ~/ groupsCount;
      final offset = index % groupsCount;
      final targetIndex = lap.isEven ? offset : (groupsCount - 1 - offset);
      distributedGroups[targetIndex].add(finalizedParticipants[index]);
    }

    final groups = <TournamentGroup>[];
    final fixtures = <Match>[];
    final standings = <GroupStandingSnapshot>[];
    final qualifiersPerGroup =
        tournament.format == TournamentFormat.groupsThenKnockout ? 2 : 0;

    for (
      int groupIndex = 0;
      groupIndex < distributedGroups.length;
      groupIndex++
    ) {
      final groupId = 'group::$groupStageId::$groupIndex';
      final groupParticipants = distributedGroups[groupIndex];
      final group = TournamentGroup(
        id: groupId,
        tournamentId: tournament.id,
        groupStageId: groupStageId,
        name: 'المجموعة ${String.fromCharCode(65 + groupIndex)}',
        order: groupIndex,
        participantIds: groupParticipants.map((entry) => entry.id).toList(),
        createdAt: now,
        updatedAt: now,
      );
      groups.add(group);

      final randomDrawSeed = groupParticipants.asMap().map(
        (index, participant) =>
            MapEntry(participant.id, participant.seed ?? index),
      );
      final initialEntries = groupParticipants
          .map(
            (participant) => GroupStandingEntry(
              participantId: participant.id,
              displayName: participant.displayName,
              randomDrawOrder: randomDrawSeed[participant.id] ?? 0,
            ),
          )
          .toList(growable: false);

      standings.add(
        GroupStandingSnapshot(
          id: 'standing::$groupStageId::$groupId',
          tournamentId: tournament.id,
          groupStageId: groupStageId,
          groupId: groupId,
          tiebreakerOrder: tournament.groupStandingsConfig.tiebreakerOrder,
          entries: _rankEntries(
            initialEntries,
            tournament.groupStandingsConfig.tiebreakerOrder,
          ),
          qualifierParticipantIds: qualifiersPerGroup == 0
              ? const []
              : initialEntries
                    .take(qualifiersPerGroup)
                    .map((entry) => entry.participantId)
                    .toList(growable: false),
          createdAt: now,
          updatedAt: now,
        ),
      );

      int slotNumber = 0;
      for (
        int homeIndex = 0;
        homeIndex < groupParticipants.length;
        homeIndex++
      ) {
        for (
          int awayIndex = homeIndex + 1;
          awayIndex < groupParticipants.length;
          awayIndex++
        ) {
          slotNumber += 1;
          final homeParticipant = groupParticipants[homeIndex];
          final awayParticipant = groupParticipants[awayIndex];
          fixtures.add(
            Match(
              id: 'fixture::$groupStageId::$groupId::$slotNumber',
              organizerId: tournament.organizerId,
              teamAId: homeParticipant.sourceEntityId,
              teamBId: awayParticipant.sourceEntityId,
              teamAParticipantId: homeParticipant.id,
              teamBParticipantId: awayParticipant.id,
              status: MatchStatus.open,
              isOrganized: true,
              tournamentId: tournament.id,
              stageType: TournamentStageType.groupStage,
              groupId: groupId,
              groupStageId: groupStageId,
              roundIndex: groupIndex + 1,
              slotNumber: slotNumber,
              fixtureStatus: FixtureStatus.draft,
              createdAt: now,
            ),
          );
        }
      }
    }

    return GroupStageBuildResult(
      groupStageId: groupStageId,
      groups: groups,
      fixtures: fixtures,
      standings: standings,
    );
  }

  GroupStandingSnapshot recalculateSnapshot({
    required Tournament tournament,
    required TournamentGroup group,
    required Map<String, TournamentParticipant> participantsById,
    required List<Match> matches,
    required DateTime now,
  }) {
    final baseline = <String, GroupStandingEntry>{};
    for (int index = 0; index < group.participantIds.length; index++) {
      final participant = participantsById[group.participantIds[index]];
      if (participant == null) {
        continue;
      }
      baseline[participant.id] = GroupStandingEntry(
        participantId: participant.id,
        displayName: participant.displayName,
        randomDrawOrder: participant.seed ?? index,
      );
    }

    for (final match in matches) {
      if (!match.isOfficialTournamentResult ||
          match.teamAParticipantId == null ||
          match.teamBParticipantId == null) {
        continue;
      }
      final home = baseline[match.teamAParticipantId!];
      final away = baseline[match.teamBParticipantId!];
      if (home == null || away == null) {
        continue;
      }

      if (match.scoreTeamA! > match.scoreTeamB!) {
        baseline[home.participantId] = _applyResult(
          home,
          isWin: true,
          isDraw: false,
          goalsFor: match.scoreTeamA!,
          goalsAgainst: match.scoreTeamB!,
        );
        baseline[away.participantId] = _applyResult(
          away,
          isWin: false,
          isDraw: false,
          goalsFor: match.scoreTeamB!,
          goalsAgainst: match.scoreTeamA!,
        );
      } else if (match.scoreTeamB! > match.scoreTeamA!) {
        baseline[home.participantId] = _applyResult(
          home,
          isWin: false,
          isDraw: false,
          goalsFor: match.scoreTeamA!,
          goalsAgainst: match.scoreTeamB!,
        );
        baseline[away.participantId] = _applyResult(
          away,
          isWin: true,
          isDraw: false,
          goalsFor: match.scoreTeamB!,
          goalsAgainst: match.scoreTeamA!,
        );
      } else {
        baseline[home.participantId] = _applyResult(
          home,
          isWin: false,
          isDraw: true,
          goalsFor: match.scoreTeamA!,
          goalsAgainst: match.scoreTeamB!,
        );
        baseline[away.participantId] = _applyResult(
          away,
          isWin: false,
          isDraw: true,
          goalsFor: match.scoreTeamB!,
          goalsAgainst: match.scoreTeamA!,
        );
      }
    }

    final ranked = _rankEntries(
      baseline.values.toList(growable: false),
      tournament.groupStandingsConfig.tiebreakerOrder,
    );
    final qualifiersPerGroup =
        tournament.format == TournamentFormat.groupsThenKnockout ? 2 : 0;
    return GroupStandingSnapshot(
      id: 'standing::${group.groupStageId}::${group.id}',
      tournamentId: group.tournamentId,
      groupStageId: group.groupStageId,
      groupId: group.id,
      tiebreakerOrder: tournament.groupStandingsConfig.tiebreakerOrder,
      entries: ranked,
      qualifierParticipantIds: qualifiersPerGroup == 0
          ? const []
          : ranked
                .take(qualifiersPerGroup)
                .map((entry) => entry.participantId)
                .toList(growable: false),
      createdAt: now,
      updatedAt: now,
    );
  }

  int _determineGroupCount({
    required int participantCount,
    required TournamentFormat format,
  }) {
    if (format == TournamentFormat.groupsOnly || participantCount <= 4) {
      return 1;
    }
    const candidates = <int>[8, 4, 2, 1];
    for (final candidate in candidates) {
      if (candidate <= participantCount ~/ 3) {
        return candidate;
      }
    }
    return 1;
  }

  GroupStandingEntry _applyResult(
    GroupStandingEntry entry, {
    required bool isWin,
    required bool isDraw,
    required int goalsFor,
    required int goalsAgainst,
  }) {
    return entry.copyWith(
      played: entry.played + 1,
      wins: entry.wins + (isWin ? 1 : 0),
      draws: entry.draws + (isDraw ? 1 : 0),
      losses: entry.losses + (!isWin && !isDraw ? 1 : 0),
      goalsFor: entry.goalsFor + goalsFor,
      goalsAgainst: entry.goalsAgainst + goalsAgainst,
    );
  }

  List<GroupStandingEntry> _rankEntries(
    List<GroupStandingEntry> entries,
    List<GroupStandingsMetric> tiebreakers,
  ) {
    final ranked = [...entries];
    ranked.sort((left, right) {
      for (final metric in tiebreakers) {
        final comparison = switch (metric) {
          GroupStandingsMetric.points => right.points.compareTo(left.points),
          GroupStandingsMetric.goalDifference => right.goalDifference.compareTo(
            left.goalDifference,
          ),
          GroupStandingsMetric.goalsFor => right.goalsFor.compareTo(
            left.goalsFor,
          ),
          GroupStandingsMetric.randomDraw => left.randomDrawOrder.compareTo(
            right.randomDrawOrder,
          ),
        };
        if (comparison != 0) {
          return comparison;
        }
      }
      return left.displayName.compareTo(right.displayName);
    });
    return ranked
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(rank: entry.key + 1))
        .toList(growable: false);
  }
}
