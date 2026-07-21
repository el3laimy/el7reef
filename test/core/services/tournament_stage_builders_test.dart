import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/group_stage_builder.dart';
import 'package:el7reef/core/services/knockout_builder.dart';
import 'package:el7reef/core/services/participant_finalization_policy.dart';
import 'package:el7reef/data/models/knockout_bracket_model.dart';
import 'package:el7reef/data/models/knockout_tie_model.dart';
import 'package:el7reef/data/models/match_model.dart';
import 'package:el7reef/data/models/tournament_model.dart';
import 'package:el7reef/domain/entities/group_standing_snapshot.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_group_advancement_config.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';

void main() {
  final now = DateTime(2026, 7, 14, 20);

  group('GroupStageBuilder round robin', () {
    for (int participantCount = 3; participantCount <= 8; participantCount++) {
      test(
        'schedules $participantCount participants in conflict-free rounds',
        () {
          final participants = _participants(participantCount);
          final result = const GroupStageBuilder().build(
            tournament: _tournament(
              format: TournamentFormat.groupsOnly,
              maxTeams: participantCount,
              now: now,
            ),
            participants: participants,
            now: now,
          );

          expect(
            result.fixtures,
            hasLength(participantCount * (participantCount - 1) ~/ 2),
          );
          final expectedRoundCount = participantCount.isEven
              ? participantCount - 1
              : participantCount;
          final fixturesByRound = <int, List<Match>>{};
          for (final fixture in result.fixtures) {
            fixturesByRound
                .putIfAbsent(fixture.roundIndex!, () => <Match>[])
                .add(fixture);
          }
          expect(
            fixturesByRound.keys,
            unorderedEquals(List.generate(expectedRoundCount, (i) => i)),
          );

          final matchupKeys = <String>{};
          for (final roundFixtures in fixturesByRound.values) {
            final participantsInRound = <String>{};
            for (final fixture in roundFixtures) {
              expect(
                participantsInRound.add(fixture.teamAParticipantId!),
                isTrue,
              );
              expect(
                participantsInRound.add(fixture.teamBParticipantId!),
                isTrue,
              );
              matchupKeys.add(
                _pairKey(
                  fixture.teamAParticipantId!,
                  fixture.teamBParticipantId!,
                ),
              );
            }
          }
          expect(matchupKeys, hasLength(result.fixtures.length));

          final legacyFixtures = result.fixtures
              .map((fixture) => fixture.copyWith(roundIndex: 99))
              .toList(growable: false);
          final derived = const GroupStageBuilder().deriveDisplayRoundIndexes(
            fixtures: legacyFixtures,
            participantIds: participants.map((participant) => participant.id),
          );
          for (final fixture in result.fixtures) {
            expect(derived[fixture.id], fixture.roundIndex);
          }
        },
      );
    }

    test('builds a 48-team 12-group stage with 72 fixtures', () {
      final tournament = _tournament(
        format: TournamentFormat.groupsThenKnockout,
        maxTeams: 48,
        now: now,
        groupAdvancementConfig: const TournamentGroupAdvancementConfig(
          groupCount: 12,
          automaticQualifiersPerGroup: 2,
          bestRankedAdditionalQualifiers: 8,
        ),
      );
      final result = const GroupStageBuilder().build(
        tournament: tournament,
        participants: _participants(48),
        now: now,
      );

      expect(result.groups, hasLength(12));
      expect(result.fixtures, hasLength(72));
      expect(result.standings, hasLength(12));
      expect(
        result.groups.every((group) => group.participantIds.length == 4),
        isTrue,
      );
      expect(
        result.standings.every(
          (snapshot) => snapshot.qualifierParticipantIds.length == 2,
        ),
        isTrue,
      );
      for (final group in result.groups) {
        final groupFixtures = result.fixtures
            .where((fixture) => fixture.groupId == group.id)
            .toList(growable: false);
        expect(groupFixtures, hasLength(6));
        expect(groupFixtures.map((fixture) => fixture.roundIndex).toSet(), {
          0,
          1,
          2,
        });
      }

      final encoded = TournamentModel.fromEntity(tournament).toJson();
      final roundTrip = TournamentModel.fromJson(
        encoded,
        tournament.id,
      ).toEntity();
      expect(roundTrip.groupAdvancementConfig.groupCount, 12);
      expect(roundTrip.groupAdvancementConfig.automaticQualifiersPerGroup, 2);
      expect(
        roundTrip.groupAdvancementConfig.bestRankedAdditionalQualifiers,
        8,
      );
      expect(roundTrip.isFeatured, isFalse);
      expect(roundTrip.featuredPriority, 1000);

      final legacyRoundTrip = TournamentModel.fromJson(
        {...encoded}
          ..remove('isFeatured')
          ..remove('featuredPriority'),
        tournament.id,
      ).toEntity();
      expect(legacyRoundTrip.isFeatured, isFalse);
      expect(legacyRoundTrip.featuredPriority, 1000);
    });
  });

  group('KnockoutBuilder byes', () {
    for (int participantCount = 3; participantCount <= 16; participantCount++) {
      test(
        'keeps all $participantCount participants and assigns fair byes',
        () {
          final participants = _participants(participantCount);
          final result = const KnockoutBuilder().build(
            tournament: _tournament(
              format: TournamentFormat.knockoutOnly,
              maxTeams: participantCount,
              now: now,
            ),
            participants: participants,
            groups: const [],
            standings: const [],
            now: now,
          );
          final bracketSize = _nextPowerOfTwo(participantCount);
          final byeCount = bracketSize - participantCount;

          expect(result.bracket.bracketSize, bracketSize);
          expect(result.bracket.seedingMethod, KnockoutSeedingMethod.ranked);
          expect(
            result.bracket.qualifierParticipantIds.toSet(),
            participants.map((participant) => participant.id).toSet(),
          );
          expect(
            result.bracket.byeParticipantIds,
            unorderedEquals(
              participants.take(byeCount).map((participant) => participant.id),
            ),
          );
          expect(result.ties, hasLength(bracketSize - 1));
          expect(result.matches, hasLength(participantCount - 1));

          final firstRoundParticipants = result.ties
              .where((tie) => tie.roundIndex == 0)
              .expand((tie) => [tie.participantAId, tie.participantBId])
              .whereType<String>()
              .toList(growable: false);
          expect(firstRoundParticipants.toSet(), hasLength(participantCount));
          expect(
            firstRoundParticipants.toSet(),
            participants.map((participant) => participant.id).toSet(),
          );
          final byeTies = result.ties.where(
            (tie) => tie.resolutionType == KnockoutTieResolution.bye,
          );
          expect(byeTies, hasLength(byeCount));
          expect(
            byeTies.every(
              (tie) => tie.matchId == null && tie.winnerParticipantId != null,
            ),
            isTrue,
          );
        },
      );
    }

    test('persists a deterministic draw order when seeds are not unique', () {
      final tournament = _tournament(
        format: TournamentFormat.knockoutOnly,
        maxTeams: 5,
        now: now,
      );
      final participants = const ParticipantFinalizationPolicy().finalize(
        tournament: tournament,
        participants: _participants(5, uniqueSeeds: false)
            .map(
              (participant) => participant.copyWith(
                status: TournamentParticipantStatus.approved,
              ),
            )
            .toList(growable: false),
        now: now,
      );
      expect(
        participants.every((participant) => participant.seed == null),
        isTrue,
      );
      KnockoutBuildResult build() => const KnockoutBuilder().build(
        tournament: tournament,
        participants: participants,
        groups: const [],
        standings: const [],
        now: now,
      );

      final first = build();
      final second = build();
      expect(first.bracket.seedingMethod, KnockoutSeedingMethod.draw);
      expect(
        first.bracket.qualifierParticipantIds,
        second.bracket.qualifierParticipantIds,
      );
      expect(
        first.bracket.qualifierParticipantIds.toSet(),
        participants.map((participant) => participant.id).toSet(),
      );
      expect(
        first.bracket.byeParticipantIds,
        first.bracket.qualifierParticipantIds.take(3),
      );
      final bracketJson = KnockoutBracketModel.fromEntity(
        first.bracket,
      ).toJson();
      final bracketRoundTrip = KnockoutBracketModel.fromJson(
        bracketJson,
        first.bracket.id,
      ).toEntity();
      expect(bracketRoundTrip.seedingMethod, KnockoutSeedingMethod.draw);
      expect(
        bracketRoundTrip.byeParticipantIds,
        first.bracket.byeParticipantIds,
      );
    });

    test('advances 24 direct teams and the best eight third-place teams', () {
      final tournament = _tournament(
        format: TournamentFormat.groupsThenKnockout,
        maxTeams: 48,
        now: now,
        groupAdvancementConfig: const TournamentGroupAdvancementConfig(
          groupCount: 12,
          automaticQualifiersPerGroup: 2,
          bestRankedAdditionalQualifiers: 8,
        ),
      );
      final participants = _participants(48);
      final groupStage = const GroupStageBuilder().build(
        tournament: tournament,
        participants: participants,
        now: now,
      );
      final completedStandings = groupStage.standings
          .asMap()
          .entries
          .map((item) {
            final groupIndex = item.key;
            final snapshot = item.value;
            final entries = snapshot.entries
                .asMap()
                .entries
                .map((ranked) {
                  final entry = ranked.value;
                  return switch (ranked.key) {
                    0 => entry.copyWith(
                      played: 3,
                      wins: 3,
                      goalsFor: 7,
                      goalsAgainst: 1,
                    ),
                    1 => entry.copyWith(
                      played: 3,
                      wins: 2,
                      losses: 1,
                      goalsFor: 5,
                      goalsAgainst: 3,
                    ),
                    2 when groupIndex < 8 => entry.copyWith(
                      played: 3,
                      wins: 1,
                      losses: 2,
                      goalsFor: 3,
                      goalsAgainst: 4,
                      randomDrawOrder: groupIndex,
                    ),
                    2 => entry.copyWith(
                      played: 3,
                      draws: 2,
                      losses: 1,
                      goalsFor: 2,
                      goalsAgainst: 3,
                      randomDrawOrder: groupIndex,
                    ),
                    _ => entry.copyWith(
                      played: 3,
                      losses: 3,
                      goalsFor: 1,
                      goalsAgainst: 7,
                    ),
                  };
                })
                .toList(growable: false);
            return snapshot.copyWith(
              entries: entries,
              qualifierParticipantIds: entries
                  .take(2)
                  .map((entry) => entry.participantId)
                  .toList(growable: false),
            );
          })
          .toList(growable: false);

      final built = const KnockoutBuilder().build(
        tournament: tournament,
        participants: participants,
        groups: groupStage.groups,
        standings: completedStandings,
        now: now,
      );

      final expectedBestThirds = groupStage.groups
          .take(8)
          .map((group) => group.participantIds[2])
          .toSet();
      expect(built.bracket.qualifierParticipantIds, hasLength(32));
      expect(
        built.bracket.qualifierParticipantIds.toSet(),
        containsAll(expectedBestThirds),
      );
      expect(built.bracket.bracketSize, 32);
      expect(built.bracket.byeParticipantIds, isEmpty);
      expect(built.ties, hasLength(31));
      expect(built.matches, hasLength(31));
    });
  });

  test('penalties resolve a tied knockout without changing match goals', () {
    final participants = _participants(2);
    final built = const KnockoutBuilder().build(
      tournament: _tournament(
        format: TournamentFormat.knockoutOnly,
        maxTeams: 2,
        now: now,
      ),
      participants: participants,
      groups: const [],
      standings: const [],
      now: now,
    );
    final settledMatch = built.matches.single.copyWith(
      status: MatchStatus.settled,
      scoreTeamA: 1,
      scoreTeamB: 1,
      penaltyScoreTeamA: 5,
      penaltyScoreTeamB: 4,
      knockoutDecision: KnockoutDecision.teamA,
    );

    final progress = const KnockoutBuilder().synchronizeProgress(
      bracket: built.bracket,
      ties: built.ties,
      matches: [settledMatch],
      participantsById: {
        for (final participant in participants) participant.id: participant,
      },
      now: now.add(const Duration(minutes: 1)),
    );

    expect(settledMatch.scoreTeamA, 1);
    expect(settledMatch.scoreTeamB, 1);
    expect(settledMatch.winner, 'A');
    expect(
      progress.ties.single.resolutionType,
      KnockoutTieResolution.penalties,
    );
    expect(progress.ties.single.winnerParticipantId, participants.first.id);
    expect(progress.bracket.championParticipantId, participants.first.id);

    final matchJson = MatchModel.fromEntity(settledMatch).toJson();
    final matchRoundTrip = MatchModel.fromJson(
      matchJson,
      settledMatch.id,
    ).toEntity();
    expect(matchRoundTrip.penaltyScoreTeamA, 5);
    expect(matchRoundTrip.penaltyScoreTeamB, 4);
    expect(matchRoundTrip.knockoutDecision, KnockoutDecision.teamA);
    final tieJson = KnockoutTieModel.fromEntity(progress.ties.single).toJson();
    final tieRoundTrip = KnockoutTieModel.fromJson(
      tieJson,
      progress.ties.single.id,
    ).toEntity();
    expect(tieRoundTrip.resolutionType, KnockoutTieResolution.penalties);
  });

  test('inconsistent penalty data cannot advance a regulation-time winner', () {
    final participants = _participants(2);
    final built = const KnockoutBuilder().build(
      tournament: _tournament(
        format: TournamentFormat.knockoutOnly,
        maxTeams: 2,
        now: now,
      ),
      participants: participants,
      groups: const [],
      standings: const [],
      now: now,
    );
    final invalidMatch = built.matches.single.copyWith(
      status: MatchStatus.settled,
      scoreTeamA: 2,
      scoreTeamB: 1,
      penaltyScoreTeamA: 5,
      penaltyScoreTeamB: 4,
      knockoutDecision: KnockoutDecision.teamA,
    );

    final progress = const KnockoutBuilder().synchronizeProgress(
      bracket: built.bracket,
      ties: built.ties,
      matches: [invalidMatch],
      participantsById: {
        for (final participant in participants) participant.id: participant,
      },
      now: now.add(const Duration(minutes: 1)),
    );

    expect(invalidMatch.resolvedKnockoutDecision, isNull);
    expect(progress.ties.single.winnerParticipantId, isNull);
    expect(progress.bracket.championParticipantId, isNull);
  });
}

Tournament _tournament({
  required TournamentFormat format,
  required int maxTeams,
  required DateTime now,
  TournamentGroupAdvancementConfig groupAdvancementConfig =
      const TournamentGroupAdvancementConfig(),
}) {
  return Tournament(
    id: 'tournament-1',
    organizerId: 'organizer-1',
    name: 'كأس الحارة',
    format: format,
    teamSize: TournamentTeamSize.fiveVsFive,
    maxTeams: maxTeams,
    groupAdvancementConfig: groupAdvancementConfig,
    createdAt: now,
  );
}

List<TournamentParticipant> _participants(
  int count, {
  bool uniqueSeeds = true,
}) {
  final now = DateTime(2026, 7, 14, 19);
  return List.generate(
    count,
    (index) => TournamentParticipant(
      id: 'participant-${index + 1}',
      tournamentId: 'tournament-1',
      sourceType: TournamentParticipantSourceType.registeredTeam,
      sourceEntityId: 'team-${index + 1}',
      displayName: 'فريق ${index + 1}',
      status: TournamentParticipantStatus.finalized,
      seed: uniqueSeeds ? index + 1 : null,
      createdAt: now,
      updatedAt: now,
      finalizedAt: now,
    ),
    growable: false,
  );
}

int _nextPowerOfTwo(int value) {
  var size = 2;
  while (size < value) {
    size *= 2;
  }
  return size;
}

String _pairKey(String left, String right) =>
    left.compareTo(right) <= 0 ? '$left|$right' : '$right|$left';
