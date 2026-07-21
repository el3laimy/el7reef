import 'dart:math';

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

class _KnockoutQualifierPlan {
  final List<String> orderedParticipantIds;
  final List<String?> firstRoundSlots;
  final KnockoutSeedingMethod seedingMethod;

  const _KnockoutQualifierPlan({
    required this.orderedParticipantIds,
    required this.firstRoundSlots,
    required this.seedingMethod,
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
    final qualifierPlan = _buildQualifierPlan(
      tournament: tournament,
      participants: participants,
      groups: groups,
      standings: standings,
      now: now,
    );
    final qualifierIds = qualifierPlan.orderedParticipantIds;
    if (qualifierIds.length < 2) {
      throw Exception('يجب وجود فريقين على الأقل لبدء الإقصائيات.');
    }

    final participantMap = {
      for (final participant in participants) participant.id: participant,
    };
    final bracketId = bracketIdFor(tournament.id);
    final bracketSize = qualifierPlan.firstRoundSlots.length;
    final roundCount = _roundCountFor(bracketSize);
    final ties = <KnockoutTie>[];
    final matches = <Match>[];

    for (int roundIndex = 0; roundIndex < roundCount; roundIndex++) {
      final tiesInRound = bracketSize >> (roundIndex + 1);
      final isFirstRound = roundIndex == 0;
      for (int slotNumber = 0; slotNumber < tiesInRound; slotNumber++) {
        final tieId = 'tie::$bracketId::$roundIndex::$slotNumber';
        final nextTieId = roundIndex + 1 < roundCount
            ? 'tie::$bracketId::${roundIndex + 1}::${slotNumber ~/ 2}'
            : null;
        final participantAId = isFirstRound
            ? qualifierPlan.firstRoundSlots[slotNumber * 2]
            : null;
        final participantBId = isFirstRound
            ? qualifierPlan.firstRoundSlots[(slotNumber * 2) + 1]
            : null;
        final isBye =
            isFirstRound &&
            ((participantAId == null) != (participantBId == null));
        if (isFirstRound && participantAId == null && participantBId == null) {
          throw StateError('توزيع الإقصائيات أنشأ مواجهة فارغة.');
        }
        final winnerParticipantId = isBye
            ? participantAId ?? participantBId
            : null;
        final matchId = isBye
            ? null
            : 'fixture::$bracketId::$roundIndex::$slotNumber';

        ties.add(
          KnockoutTie(
            id: tieId,
            tournamentId: tournament.id,
            bracketId: bracketId,
            roundIndex: roundIndex,
            slotNumber: slotNumber,
            participantAId: participantAId,
            participantBId: participantBId,
            winnerParticipantId: winnerParticipantId,
            matchId: matchId,
            nextTieId: nextTieId,
            resolutionType: isBye
                ? KnockoutTieResolution.bye
                : KnockoutTieResolution.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
        if (matchId != null) {
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
        }
      }
    }

    final byeParticipantIds = ties
        .where((tie) => tie.resolutionType == KnockoutTieResolution.bye)
        .map((tie) => tie.winnerParticipantId!)
        .toList(growable: false);
    final bracket = KnockoutBracket(
      id: bracketId,
      tournamentId: tournament.id,
      qualifierParticipantIds: qualifierIds,
      seedingMethod: qualifierPlan.seedingMethod,
      byeParticipantIds: byeParticipantIds,
      createdAt: now,
      updatedAt: now,
    );
    final initialized = synchronizeProgress(
      bracket: bracket,
      ties: ties,
      matches: matches,
      participantsById: participantMap,
      now: now,
    );
    return KnockoutBuildResult(
      bracket: initialized.bracket,
      ties: initialized.ties,
      matches: initialized.matches,
    );
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
      final decision = match?.resolvedKnockoutDecision;
      if (match != null &&
          tie.winnerParticipantId == null &&
          match.isOfficialTournamentResult &&
          match.teamAParticipantId != null &&
          match.teamBParticipantId != null &&
          decision != null) {
        tie = tie.copyWith(
          winnerParticipantId: decision == KnockoutDecision.teamA
              ? match.teamAParticipantId
              : match.teamBParticipantId,
          resolutionType: match.knockoutResolution,
          updatedAt: now,
        );
        tieById[tie.id] = tie;
      } else if (match != null &&
          tie.winnerParticipantId != null &&
          tie.resolutionType == KnockoutTieResolution.pending &&
          match.isOfficialTournamentResult &&
          decision != null) {
        final resolvedWinner = decision == KnockoutDecision.teamA
            ? match.teamAParticipantId
            : match.teamBParticipantId;
        if (resolvedWinner == tie.winnerParticipantId) {
          tie = tie.copyWith(
            resolutionType: match.knockoutResolution,
            updatedAt: now,
          );
          tieById[tie.id] = tie;
        }
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

  _KnockoutQualifierPlan _buildQualifierPlan({
    required Tournament tournament,
    required List<TournamentParticipant> participants,
    required List<TournamentGroup> groups,
    required List<GroupStandingSnapshot> standings,
    required DateTime now,
  }) {
    if (tournament.format == TournamentFormat.knockoutOnly) {
      final finalizedParticipants = participants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.finalized,
          )
          .toList(growable: true);
      if (finalizedParticipants.length < 2) {
        return const _KnockoutQualifierPlan(
          orderedParticipantIds: [],
          firstRoundSlots: [],
          seedingMethod: KnockoutSeedingMethod.ranked,
        );
      }

      final seeds = finalizedParticipants
          .map((participant) => participant.seed)
          .toList(growable: false);
      final hasUniqueSeeds =
          seeds.every((seed) => seed != null && seed > 0) &&
          seeds.whereType<int>().toSet().length == finalizedParticipants.length;
      final seedingMethod = hasUniqueSeeds
          ? KnockoutSeedingMethod.ranked
          : KnockoutSeedingMethod.draw;
      if (hasUniqueSeeds) {
        finalizedParticipants.sort((left, right) {
          final seedComparison = left.seed!.compareTo(right.seed!);
          return seedComparison != 0
              ? seedComparison
              : left.id.compareTo(right.id);
        });
      } else {
        finalizedParticipants.sort(
          (left, right) => left.id.compareTo(right.id),
        );
        finalizedParticipants.shuffle(
          Random(
            _drawSeed(
              tournamentId: tournament.id,
              now: now,
              participantIds: finalizedParticipants
                  .map((participant) => participant.id)
                  .toList(growable: false),
            ),
          ),
        );
      }

      final orderedParticipantIds = finalizedParticipants
          .map((participant) => participant.id)
          .toList(growable: false);
      return _KnockoutQualifierPlan(
        orderedParticipantIds: orderedParticipantIds,
        firstRoundSlots: _seededFirstRoundSlots(orderedParticipantIds),
        seedingMethod: seedingMethod,
      );
    }

    final sortedGroups = [...groups]
      ..sort((left, right) => left.order.compareTo(right.order));
    final standingsByGroupId = {
      for (final snapshot in standings) snapshot.groupId: snapshot,
    };
    final directQualifiersByRank = List<List<String>>.generate(
      tournament.groupAdvancementConfig.automaticQualifiersPerGroup,
      (_) => <String>[],
    );
    final additionalCandidates = <GroupStandingEntry>[];
    for (final group in sortedGroups) {
      final snapshot = standingsByGroupId[group.id];
      final directPerGroup = directQualifiersByRank.length;
      final needsAdditionalCandidate =
          tournament.groupAdvancementConfig.bestRankedAdditionalQualifiers > 0;
      final requiredEntries =
          directPerGroup + (needsAdditionalCandidate ? 1 : 0);
      if (snapshot == null || snapshot.entries.length < requiredEntries) {
        throw Exception('لا يمكن بدء الإقصاء قبل اكتمال ترتيب المجموعات.');
      }
      for (int rankIndex = 0; rankIndex < directPerGroup; rankIndex++) {
        directQualifiersByRank[rankIndex].add(
          snapshot.entries[rankIndex].participantId,
        );
      }
      if (needsAdditionalCandidate) {
        additionalCandidates.add(snapshot.entries[directPerGroup]);
      }
    }

    final additionalCount =
        tournament.groupAdvancementConfig.bestRankedAdditionalQualifiers;
    additionalCandidates.sort(
      (left, right) => _compareStandingEntries(
        left,
        right,
        tournament.groupStandingsConfig.tiebreakerOrder,
      ),
    );
    final additionalQualifierIds = additionalCandidates
        .take(additionalCount)
        .map((entry) => entry.participantId)
        .toList(growable: false);

    if (directQualifiersByRank.length == 2 && additionalCount == 0) {
      final winners = directQualifiersByRank[0];
      final runnersUp = directQualifiersByRank[1];
      final qualifierIds = <String>[];
      for (int index = 0; index < winners.length; index++) {
        qualifierIds.add(winners[index]);
        qualifierIds.add(runnersUp[(runnersUp.length - 1) - index]);
      }
      final usesCrossPairing = _isPowerOfTwo(qualifierIds.length);
      final orderedParticipantIds = usesCrossPairing
          ? qualifierIds
          : <String>[...winners, ...runnersUp];
      final firstRoundSlots = usesCrossPairing
          ? orderedParticipantIds
                .map<String?>((participantId) => participantId)
                .toList()
          : _seededFirstRoundSlots(orderedParticipantIds);
      return _KnockoutQualifierPlan(
        orderedParticipantIds: orderedParticipantIds,
        firstRoundSlots: firstRoundSlots,
        seedingMethod: KnockoutSeedingMethod.groupCrossPairing,
      );
    }

    final orderedParticipantIds = <String>[
      for (final rankBucket in directQualifiersByRank) ...rankBucket,
      ...additionalQualifierIds,
    ];
    return _KnockoutQualifierPlan(
      orderedParticipantIds: orderedParticipantIds,
      firstRoundSlots: _seededFirstRoundSlots(orderedParticipantIds),
      seedingMethod: KnockoutSeedingMethod.groupCrossPairing,
    );
  }

  int _compareStandingEntries(
    GroupStandingEntry left,
    GroupStandingEntry right,
    List<GroupStandingsMetric> tiebreakers,
  ) {
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
    final nameComparison = left.displayName.compareTo(right.displayName);
    return nameComparison != 0
        ? nameComparison
        : left.participantId.compareTo(right.participantId);
  }

  List<String?> _seededFirstRoundSlots(List<String> orderedParticipantIds) {
    final bracketSize = _nextPowerOfTwo(orderedParticipantIds.length);
    final seedOrder = _standardSeedOrder(bracketSize);
    return seedOrder
        .map<String?>(
          (seed) => seed <= orderedParticipantIds.length
              ? orderedParticipantIds[seed - 1]
              : null,
        )
        .toList(growable: false);
  }

  List<int> _standardSeedOrder(int bracketSize) {
    var order = <int>[1, 2];
    var currentSize = 2;
    while (currentSize < bracketSize) {
      final nextSize = currentSize * 2;
      order = [
        for (final seed in order) ...[seed, nextSize + 1 - seed],
      ];
      currentSize = nextSize;
    }
    return order;
  }

  int _nextPowerOfTwo(int value) {
    var size = 2;
    while (size < value) {
      size *= 2;
    }
    return size;
  }

  int _drawSeed({
    required String tournamentId,
    required DateTime now,
    required List<String> participantIds,
  }) {
    final source =
        '$tournamentId|${now.microsecondsSinceEpoch}|${participantIds.join('|')}';
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
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
}
