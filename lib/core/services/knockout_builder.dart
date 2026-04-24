import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_enums.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/knockout_bracket.dart';
import '../../domain/entities/knockout_tie.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/entities/tournament_participant.dart';

class KnockoutBuildResult {
  final KnockoutBracket bracket;
  final List<KnockoutTie> ties;
  final List<Match> matches;

  const KnockoutBuildResult({
    required this.bracket,
    required this.ties,
    required this.matches,
  });
}

class KnockoutProgressResult {
  final KnockoutBracket bracket;
  final List<KnockoutTie> ties;
  final List<Match> matches;

  const KnockoutProgressResult({
    required this.bracket,
    required this.ties,
    required this.matches,
  });
}

class KnockoutBuilder {
  const KnockoutBuilder();

  String bracketIdFor(String tournamentId) => 'knockout::$tournamentId';

  KnockoutBuildResult build({
    required Tournament tournament,
    required List<TournamentParticipant> participants,
    required List<TournamentGroup> groups,
    required List<GroupStandingSnapshot> standings,
    required DateTime now,
  }) {
    final qualifierIds = _buildQualifierList(
      tournament: tournament,
      participants: participants,
      groups: groups,
      standings: standings,
    );
    if (qualifierIds.length < 2 || !_isPowerOfTwo(qualifierIds.length)) {
      throw Exception('عدد المتأهلين الحالي لا يدعم single elimination.');
    }

    final participantMap = {
      for (final participant in participants) participant.id: participant,
    };
    final bracketId = bracketIdFor(tournament.id);
    final bracket = KnockoutBracket(
      id: bracketId,
      tournamentId: tournament.id,
      qualifierParticipantIds: qualifierIds,
      createdAt: now,
      updatedAt: now,
    );

    final roundCount = _roundCountFor(qualifierIds.length);
    final ties = <KnockoutTie>[];
    final matches = <Match>[];
    var currentRoundParticipants = qualifierIds;

    for (int roundIndex = 0; roundIndex < roundCount; roundIndex++) {
      final tiesInRound = currentRoundParticipants.length ~/ 2;
      final isFirstRound = roundIndex == 0;
      for (int slotNumber = 0; slotNumber < tiesInRound; slotNumber++) {
        final tieId = 'tie::$bracketId::$roundIndex::$slotNumber';
        final nextRoundTies = _tiesCountForRemainingRounds(
          totalParticipants: qualifierIds.length,
          roundIndex: roundIndex + 1,
        );
        final nextTieId = roundIndex + 1 < roundCount
            ? 'tie::$bracketId::${roundIndex + 1}::${slotNumber ~/ 2}'
            : null;
        final participantAId = isFirstRound
            ? currentRoundParticipants[slotNumber * 2]
            : null;
        final participantBId = isFirstRound
            ? currentRoundParticipants[(slotNumber * 2) + 1]
            : null;
        final matchId = 'fixture::$bracketId::$roundIndex::$slotNumber';

        ties.add(
          KnockoutTie(
            id: tieId,
            tournamentId: tournament.id,
            bracketId: bracketId,
            roundIndex: roundIndex,
            slotNumber: slotNumber,
            participantAId: participantAId,
            participantBId: participantBId,
            matchId: matchId,
            nextTieId: nextTieId,
            createdAt: now,
            updatedAt: now,
          ),
        );
        matches.add(
          Match(
            id: matchId,
            organizerId: tournament.organizerId,
            teamAId: participantAId == null
                ? null
                : participantMap[participantAId]?.sourceEntityId,
            teamBId: participantBId == null
                ? null
                : participantMap[participantBId]?.sourceEntityId,
            teamAParticipantId: participantAId,
            teamBParticipantId: participantBId,
            status: MatchStatus.open,
            teamSize: tournament.teamSize.value,
            isOrganized: true,
            tournamentId: tournament.id,
            stageType: TournamentStageType.knockoutStage,
            knockoutTieId: tieId,
            roundIndex: roundIndex,
            slotNumber: slotNumber,
            fixtureStatus: FixtureStatus.draft,
            createdAt: now,
          ),
        );
        if (nextRoundTies == 0) {
          continue;
        }
      }
      currentRoundParticipants = List<String>.filled(tiesInRound, '');
    }

    return KnockoutBuildResult(bracket: bracket, ties: ties, matches: matches);
  }

  KnockoutProgressResult synchronizeProgress({
    required KnockoutBracket bracket,
    required List<KnockoutTie> ties,
    required List<Match> matches,
    required Map<String, TournamentParticipant> participantsById,
    required DateTime now,
  }) {
    final tieById = {for (final tie in ties) tie.id: tie};
    final matchById = {for (final match in matches) match.id: match};
    var updatedBracket = bracket;

    final sortedTies = [...ties]
      ..sort((left, right) {
        if (left.roundIndex != right.roundIndex) {
          return left.roundIndex.compareTo(right.roundIndex);
        }
        return left.slotNumber.compareTo(right.slotNumber);
      });

    for (final originalTie in sortedTies) {
      var tie = tieById[originalTie.id]!;
      final match = tie.matchId == null ? null : matchById[tie.matchId!];
      if (match != null &&
          tie.winnerParticipantId == null &&
          match.isOfficialTournamentResult &&
          match.teamAParticipantId != null &&
          match.teamBParticipantId != null &&
          match.scoreTeamA != match.scoreTeamB) {
        tie = tie.copyWith(
          winnerParticipantId: match.scoreTeamA! > match.scoreTeamB!
              ? match.teamAParticipantId
              : match.teamBParticipantId,
          updatedAt: now,
        );
        tieById[tie.id] = tie;
      }

      if (tie.winnerParticipantId == null || tie.nextTieId == null) {
        continue;
      }

      final nextTie = tieById[tie.nextTieId!];
      if (nextTie == null) {
        continue;
      }
      final isFirstChild = tie.slotNumber.isEven;
      final patchedNextTie = nextTie.copyWith(
        participantAId: isFirstChild
            ? tie.winnerParticipantId
            : nextTie.participantAId,
        participantBId: isFirstChild
            ? nextTie.participantBId
            : tie.winnerParticipantId,
        updatedAt: now,
      );
      tieById[nextTie.id] = patchedNextTie;
      if (patchedNextTie.matchId != null &&
          matchById.containsKey(patchedNextTie.matchId)) {
        final downstreamMatch = matchById[patchedNextTie.matchId!]!;
        matchById[patchedNextTie.matchId!] = downstreamMatch.copyWith(
          teamAParticipantId: patchedNextTie.participantAId,
          teamBParticipantId: patchedNextTie.participantBId,
          teamAId: patchedNextTie.participantAId == null
              ? null
              : participantsById[patchedNextTie.participantAId!]
                    ?.sourceEntityId,
          teamBId: patchedNextTie.participantBId == null
              ? null
              : participantsById[patchedNextTie.participantBId!]
                    ?.sourceEntityId,
        );
      }
    }

    final finalTie = tieById.values.fold<KnockoutTie?>(null, (current, tie) {
      if (current == null) {
        return tie;
      }
      if (tie.roundIndex > current.roundIndex) {
        return tie;
      }
      if (tie.roundIndex == current.roundIndex &&
          tie.slotNumber > current.slotNumber) {
        return tie;
      }
      return current;
    });
    if (finalTie?.winnerParticipantId != null) {
      updatedBracket = updatedBracket.copyWith(
        championParticipantId: finalTie!.winnerParticipantId,
        updatedAt: now,
      );
    }

    return KnockoutProgressResult(
      bracket: updatedBracket,
      ties: tieById.values.toList(growable: false),
      matches: matchById.values.toList(growable: false),
    );
  }

  List<String> _buildQualifierList({
    required Tournament tournament,
    required List<TournamentParticipant> participants,
    required List<TournamentGroup> groups,
    required List<GroupStandingSnapshot> standings,
  }) {
    if (tournament.format == TournamentFormat.knockoutOnly) {
      final finalizedParticipants = participants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.finalized,
          )
          .toList(growable: true);
      finalizedParticipants.sort(
        (left, right) =>
            (left.seed ?? 1 << 20).compareTo(right.seed ?? 1 << 20),
      );
      final size = _largestSupportedBracketSize(finalizedParticipants.length);
      return finalizedParticipants
          .take(size)
          .map((participant) => participant.id)
          .toList(growable: false);
    }

    final sortedGroups = [...groups]
      ..sort((left, right) => left.order.compareTo(right.order));
    final standingsByGroupId = {
      for (final snapshot in standings) snapshot.groupId: snapshot,
    };
    final winners = <String>[];
    final runnersUp = <String>[];
    for (final group in sortedGroups) {
      final snapshot = standingsByGroupId[group.id];
      if (snapshot == null || snapshot.entries.length < 2) {
        throw Exception('لا يمكن بدء الإقصاء قبل اكتمال ترتيب المجموعات.');
      }
      winners.add(snapshot.entries[0].participantId);
      runnersUp.add(snapshot.entries[1].participantId);
    }

    final qualifierIds = <String>[];
    for (int index = 0; index < winners.length; index++) {
      qualifierIds.add(winners[index]);
      qualifierIds.add(runnersUp[(runnersUp.length - 1) - index]);
    }
    return qualifierIds;
  }

  int _largestSupportedBracketSize(int participantCount) {
    const supported = <int>[64, 32, 16, 8, 4, 2];
    for (final size in supported) {
      if (participantCount >= size) {
        return size;
      }
    }
    return 2;
  }

  bool _isPowerOfTwo(int value) => value >= 2 && (value & (value - 1)) == 0;

  int _roundCountFor(int participants) {
    var rounds = 0;
    var current = participants;
    while (current > 1) {
      rounds += 1;
      current ~/= 2;
    }
    return rounds;
  }

  int _tiesCountForRemainingRounds({
    required int totalParticipants,
    required int roundIndex,
  }) {
    final roundCount = _roundCountFor(totalParticipants);
    if (roundIndex >= roundCount) {
      return 0;
    }
    return totalParticipants >> (roundIndex + 1);
  }
}
