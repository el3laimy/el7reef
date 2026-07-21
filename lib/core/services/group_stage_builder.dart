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
      requestedGroupCount: tournament.groupAdvancementConfig.groupCount,
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
        tournament.format == TournamentFormat.groupsThenKnockout
        ? tournament.groupAdvancementConfig.automaticQualifiersPerGroup
        : 0;
    _validateAdvancementConfig(
      tournament: tournament,
      participantCount: finalizedParticipants.length,
      groupsCount: groupsCount,
      qualifiersPerGroup: qualifiersPerGroup,
    );

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
      final rounds = _roundRobinRounds(groupParticipants);
      for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
        for (final pairing in rounds[roundIndex]) {
          slotNumber += 1;
          final homeParticipant = pairing.$1;
          final awayParticipant = pairing.$2;
          fixtures.add(
            Match(
              id: 'fixture::$groupStageId::$groupId::$slotNumber',
              organizerId: tournament.organizerId,
              teamAId: homeParticipant.sourceEntityId,
              teamBId: awayParticipant.sourceEntityId,
              teamAParticipantId: homeParticipant.id,
              teamBParticipantId: awayParticipant.id,
              status: MatchStatus.open,
              teamSize: tournament.teamSize.value,
              isOrganized: true,
              tournamentId: tournament.id,
              stageType: TournamentStageType.groupStage,
              groupId: groupId,
              groupStageId: groupStageId,
              roundIndex: roundIndex,
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

  /// Reconstructs correct visual rounds for legacy fixtures without rewriting
  /// their stored roundIndex values.
  Map<String, int> deriveDisplayRoundIndexes({
    required Iterable<Match> fixtures,
    required Iterable<String> participantIds,
  }) {
    final roundByPair = <String, int>{};
    final rounds = _roundRobinRounds(participantIds.toList(growable: false));
    for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
      for (final pairing in rounds[roundIndex]) {
        roundByPair[_pairKey(pairing.$1, pairing.$2)] = roundIndex;
      }
    }

    final result = <String, int>{};
    for (final fixture in fixtures) {
      final participantAId = fixture.teamAParticipantId;
      final participantBId = fixture.teamBParticipantId;
      if (participantAId == null || participantBId == null) continue;
      final roundIndex = roundByPair[_pairKey(participantAId, participantBId)];
      if (roundIndex != null) {
        result[fixture.id] = roundIndex;
      }
    }
    return result;
  }

  List<List<(T, T)>> _roundRobinRounds<T>(List<T> participants) {
    if (participants.length < 2) return const [];

    final rotation = <T?>[...participants];
    if (rotation.length.isOdd) {
      rotation.add(null);
    }
    final rounds = <List<(T, T)>>[];
    final roundCount = rotation.length - 1;
    final matchesPerRound = rotation.length ~/ 2;

    for (int roundIndex = 0; roundIndex < roundCount; roundIndex++) {
      final pairings = <(T, T)>[];
      for (int pairIndex = 0; pairIndex < matchesPerRound; pairIndex++) {
        final left = rotation[pairIndex];
        final right = rotation[rotation.length - 1 - pairIndex];
        if (left == null || right == null) continue;
        pairings.add(
          (roundIndex + pairIndex).isEven ? (left, right) : (right, left),
        );
      }
      rounds.add(pairings);

      final last = rotation.removeLast();
      rotation.insert(1, last);
    }
    return rounds;
  }

  String _pairKey(String left, String right) =>
      left.compareTo(right) <= 0 ? '$left\u0000$right' : '$right\u0000$left';

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
        tournament.format == TournamentFormat.groupsThenKnockout
        ? tournament.groupAdvancementConfig.automaticQualifiersPerGroup
        : 0;
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
    required int? requestedGroupCount,
  }) {
    if (requestedGroupCount != null) {
      if (requestedGroupCount < 1 || requestedGroupCount > 26) {
        throw Exception('عدد المجموعات يجب أن يكون بين 1 و26.');
      }
      if (requestedGroupCount > participantCount ~/ 2) {
        throw Exception('كل مجموعة تحتاج فريقين على الأقل.');
      }
      return requestedGroupCount;
    }
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

  void _validateAdvancementConfig({
    required Tournament tournament,
    required int participantCount,
    required int groupsCount,
    required int qualifiersPerGroup,
  }) {
    if (tournament.format != TournamentFormat.groupsThenKnockout) {
      return;
    }
    final additional =
        tournament.groupAdvancementConfig.bestRankedAdditionalQualifiers;
    if (qualifiersPerGroup < 1) {
      throw Exception('يجب تأهيل فريق واحد على الأقل من كل مجموعة.');
    }
    final smallestGroupSize = participantCount ~/ groupsCount;
    if (qualifiersPerGroup > smallestGroupSize) {
      throw Exception('عدد المتأهلين المباشرين أكبر من حجم أصغر مجموعة.');
    }
    if (additional < 0 || additional > groupsCount) {
      throw Exception('عدد أفضل المراكز الإضافية غير صالح.');
    }
    if (additional > 0 && qualifiersPerGroup >= smallestGroupSize) {
      throw Exception('لا توجد مراكز إضافية متاحة للمفاضلة بين المجموعات.');
    }
    final totalQualifiers = (qualifiersPerGroup * groupsCount) + additional;
    if (totalQualifiers < 2 || totalQualifiers > participantCount) {
      throw Exception('إجمالي المتأهلين إلى الإقصائيات غير صالح.');
    }
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
