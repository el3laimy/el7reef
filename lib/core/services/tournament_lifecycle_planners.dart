import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/knockout_bracket.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/entities/tournament_participant.dart';
import '../enums/tournament_enums.dart';
import 'group_stage_builder.dart';
import 'tournament_completion_policy.dart';

class TournamentStandingsRefreshPlan {
  final List<GroupStandingSnapshot> snapshots;
  final List<GroupStandingSnapshot> changedSnapshots;

  const TournamentStandingsRefreshPlan({
    required this.snapshots,
    required this.changedSnapshots,
  });
}

class TournamentStandingsRefreshPlanner {
  final GroupStageBuilder _groupStageBuilder;

  const TournamentStandingsRefreshPlanner({
    GroupStageBuilder groupStageBuilder = const GroupStageBuilder(),
  }) : _groupStageBuilder = groupStageBuilder;

  TournamentStandingsRefreshPlan plan({
    required Tournament tournament,
    required Iterable<TournamentGroup> groups,
    required Iterable<TournamentParticipant> participants,
    required Iterable<Match> fixtures,
    required Iterable<GroupStandingSnapshot> existingSnapshots,
    required DateTime now,
  }) {
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final existingById = {
      for (final snapshot in existingSnapshots) snapshot.id: snapshot,
    };
    final allFixtures = fixtures.toList(growable: false);
    final snapshots = <GroupStandingSnapshot>[];
    final changedSnapshots = <GroupStandingSnapshot>[];

    for (final group in groups) {
      final recalculated = _groupStageBuilder.recalculateSnapshot(
        tournament: tournament,
        group: group,
        participantsById: participantsById,
        matches: allFixtures
            .where((match) => match.groupId == group.id)
            .toList(growable: false),
        now: now,
      );
      final existing = existingById[recalculated.id];
      if (existing != null && _equivalent(existing, recalculated)) {
        snapshots.add(existing);
        continue;
      }
      final snapshotToPersist = recalculated.copyWith(
        createdAt: existing?.createdAt ?? recalculated.createdAt,
        updatedAt: now,
      );
      snapshots.add(snapshotToPersist);
      changedSnapshots.add(snapshotToPersist);
    }
    return TournamentStandingsRefreshPlan(
      snapshots: snapshots,
      changedSnapshots: changedSnapshots,
    );
  }

  bool _equivalent(GroupStandingSnapshot left, GroupStandingSnapshot right) {
    if (left.tournamentId != right.tournamentId ||
        left.groupStageId != right.groupStageId ||
        left.groupId != right.groupId ||
        !_orderedEquals(
          left.qualifierParticipantIds,
          right.qualifierParticipantIds,
        ) ||
        !_orderedEquals(left.tiebreakerOrder, right.tiebreakerOrder) ||
        left.entries.length != right.entries.length) {
      return false;
    }
    for (var index = 0; index < left.entries.length; index += 1) {
      final leftEntry = left.entries[index];
      final rightEntry = right.entries[index];
      if (leftEntry.participantId != rightEntry.participantId ||
          leftEntry.displayName != rightEntry.displayName ||
          leftEntry.played != rightEntry.played ||
          leftEntry.wins != rightEntry.wins ||
          leftEntry.draws != rightEntry.draws ||
          leftEntry.losses != rightEntry.losses ||
          leftEntry.goalsFor != rightEntry.goalsFor ||
          leftEntry.goalsAgainst != rightEntry.goalsAgainst ||
          leftEntry.rank != rightEntry.rank ||
          leftEntry.randomDrawOrder != rightEntry.randomDrawOrder) {
        return false;
      }
    }
    return true;
  }

  bool _orderedEquals<T>(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class TournamentCompletionPlanner {
  final TournamentCompletionPolicy _completionPolicy;

  const TournamentCompletionPlanner({
    TournamentCompletionPolicy completionPolicy =
        const TournamentCompletionPolicy(),
  }) : _completionPolicy = completionPolicy;

  Tournament complete({
    required Tournament tournament,
    required KnockoutBracket? bracket,
    required List<GroupStandingSnapshot> standings,
  }) {
    final winnerParticipantId = _completionPolicy.determineWinnerParticipantId(
      tournament: tournament,
      bracket: bracket,
      standings: standings,
    );
    return tournament.copyWith(
      status: TournamentStatus.completed,
      winnerParticipantId: winnerParticipantId,
    );
  }
}
