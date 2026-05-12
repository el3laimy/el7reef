import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/knockout_bracket_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_group_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('TournamentLifecycleService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl tournamentRepository;
    late TeamRepositoryImpl teamRepository;
    late MatchRepositoryImpl matchRepository;
    late TournamentGroupRepositoryImpl groupRepository;
    late KnockoutBracketRepositoryImpl bracketRepository;
    late TournamentRegistrationService registrationService;
    late TournamentParticipantService participantService;
    late TournamentLifecycleService lifecycleService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      matchRepository = MatchRepositoryImpl(db: firestore);
      groupRepository = TournamentGroupRepositoryImpl(firestore: firestore);
      bracketRepository = KnockoutBracketRepositoryImpl(firestore: firestore);
      registrationService = TournamentRegistrationService(firestore: firestore);
      participantService = TournamentParticipantService(firestore: firestore);
      lifecycleService = TournamentLifecycleService(firestore: firestore);
      now = DateTime(2026, 4, 19, 20);

      await tournamentRepository.createTournament(
        Tournament(
          id: 'tournament-1',
          organizerId: 'organizer-1',
          name: 'Street Cup',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 8,
          status: TournamentStatus.registration,
          createdAt: now,
        ),
      );

      for (int index = 1; index <= 4; index++) {
        await teamRepository.createTeam(
          Team(
            id: 'team-$index',
            name: 'Team $index',
            ownerId: 'organizer-1',
            playerIds: const ['organizer-1'],
            createdAt: now,
          ),
        );
        await registrationService.registerTeam(
          tournamentId: 'tournament-1',
          teamId: 'team-$index',
          actorId: 'organizer-1',
          now: now.add(Duration(minutes: index)),
        );
      }
    });

    test(
      'finalize -> group stage -> knockout -> champion flow works',
      () async {
        final finalized = await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final publishedFixtures = await lifecycleService.publishFixtures(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 16)),
        );

        expect(finalized, hasLength(4));
        expect(
          finalized.every((participant) => participant.isFinalized),
          isTrue,
        );
        expect(groupStage.groups, hasLength(1));
        expect(groupStage.fixtures, hasLength(6));
        expect(
          publishedFixtures.every((fixture) => fixture.publishedAt != null),
          isTrue,
        );

        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }

        final standings = await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );

        expect(standings, hasLength(1));
        expect(standings.single.entries.first.displayName, 'Team 1');
        expect(knockout.ties, hasLength(1));
        expect(knockout.matches.single.teamAId, isNotNull);
        expect(knockout.matches.single.teamBId, isNotNull);

        final finalMatch = knockout.matches.single.copyWith(
          scoreTeamA: 2,
          scoreTeamB: 0,
          status: MatchStatus.settled,
        );
        await matchRepository.updateMatch(finalMatch);
        final progress = await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 30)),
        );
        final completedTournament = await lifecycleService.completeTournament(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 35)),
        );

        expect(progress, isNotNull);
        expect(progress!.bracket.championParticipantId, isNotNull);
        expect(completedTournament.status, TournamentStatus.completed);
        expect(completedTournament.winnerParticipantId, isNotNull);

        final savedBracket = await bracketRepository.getBracket(
          completedTournament.currentKnockoutBracketId!,
        );
        expect(
          savedBracket?.championParticipantId,
          completedTournament.winnerParticipantId,
        );
      },
    );

    test(
      'publishFixtures is a no-op when all fixtures are already published',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        final firstPublished = await lifecycleService.publishFixtures(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 16)),
        );
        final fixtureDocBefore = await firestore
            .collection(FirebasePaths.matches)
            .doc(groupStage.fixtures.first.id)
            .get();
        final auditBefore = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'fixturesPublished')
            .get();

        final secondPublished = await lifecycleService.publishFixtures(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final fixtureDocAfter = await firestore
            .collection(FirebasePaths.matches)
            .doc(groupStage.fixtures.first.id)
            .get();
        final auditAfter = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'fixturesPublished')
            .get();

        expect(firstPublished, hasLength(groupStage.fixtures.length));
        expect(secondPublished, hasLength(groupStage.fixtures.length));
        expect(
          fixtureDocAfter.data()?['publishedAt'],
          fixtureDocBefore.data()?['publishedAt'],
        );
        expect(auditAfter.docs, hasLength(auditBefore.docs.length));
      },
    );

    test(
      'startGroupStage is idempotent and does not duplicate fixtures',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );

        final first = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final second = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );

        final groups = await groupRepository.getTournamentGroups(
          'tournament-1',
          groupStageId: first.groupStageId,
        );
        final fixtures = await matchRepository.getTournamentMatches(
          tournamentId: 'tournament-1',
        );

        expect(second.groupStageId, first.groupStageId);
        expect(groups, hasLength(1));
        expect(fixtures, hasLength(6));
      },
    );

    test(
      'finalizeParticipants is idempotent and does not rewrite finalized state',
      () async {
        final participantId = participantService.participantIdFor(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: 'team-1',
        );

        final firstFinalized = await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final firstTournamentDoc = await firestore
            .collection(FirebasePaths.tournaments)
            .doc('tournament-1')
            .get();
        final firstParticipantDoc = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final firstAuditSnapshot = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantsFinalized')
            .get();

        final secondFinalized = await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final secondTournamentDoc = await firestore
            .collection(FirebasePaths.tournaments)
            .doc('tournament-1')
            .get();
        final secondParticipantDoc = await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(participantId)
            .get();
        final secondAuditSnapshot = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'participantsFinalized')
            .get();

        expect(firstFinalized, hasLength(4));
        expect(secondFinalized, hasLength(4));
        expect(
          secondTournamentDoc.data()?['participantListFinalizedAt'],
          firstTournamentDoc.data()?['participantListFinalizedAt'],
        );
        expect(
          secondParticipantDoc.data()?['updatedAt'],
          firstParticipantDoc.data()?['updatedAt'],
        );
        expect(
          secondAuditSnapshot.docs,
          hasLength(firstAuditSnapshot.docs.length),
        );
      },
    );

    test(
      'refreshGroupStandings avoids rewriting snapshots when results are unchanged',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        final snapshotId = groupStage.standings.single.id;
        final beforeRefreshDoc = await firestore
            .collection(FirebasePaths.groupStandingSnapshots)
            .doc(snapshotId)
            .get();
        final beforeRefreshUpdatedAt =
            (beforeRefreshDoc.data()?['updatedAt'] as num?)?.toInt();

        final refreshed = await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 30)),
        );

        final afterRefreshDoc = await firestore
            .collection(FirebasePaths.groupStandingSnapshots)
            .doc(snapshotId)
            .get();
        final afterRefreshUpdatedAt =
            (afterRefreshDoc.data()?['updatedAt'] as num?)?.toInt();

        expect(refreshed, hasLength(1));
        expect(afterRefreshUpdatedAt, beforeRefreshUpdatedAt);
      },
    );

    test(
      'refreshKnockoutProgress avoids rewriting bracket and ties when state is unchanged',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );

        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }

        await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );

        final bracketDocBefore = await firestore
            .collection(FirebasePaths.knockoutBrackets)
            .doc(knockout.bracket.id)
            .get();
        final tieDocBefore = await firestore
            .collection(FirebasePaths.knockoutTies)
            .doc(knockout.ties.single.id)
            .get();
        final bracketUpdatedAtBefore =
            (bracketDocBefore.data()?['updatedAt'] as num?)?.toInt();
        final tieUpdatedAtBefore = (tieDocBefore.data()?['updatedAt'] as num?)
            ?.toInt();

        final refreshed = await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 40)),
        );

        final bracketDocAfter = await firestore
            .collection(FirebasePaths.knockoutBrackets)
            .doc(knockout.bracket.id)
            .get();
        final tieDocAfter = await firestore
            .collection(FirebasePaths.knockoutTies)
            .doc(knockout.ties.single.id)
            .get();
        final bracketUpdatedAtAfter =
            (bracketDocAfter.data()?['updatedAt'] as num?)?.toInt();
        final tieUpdatedAtAfter = (tieDocAfter.data()?['updatedAt'] as num?)
            ?.toInt();

        expect(refreshed, isNotNull);
        expect(bracketUpdatedAtAfter, bracketUpdatedAtBefore);
        expect(tieUpdatedAtAfter, tieUpdatedAtBefore);
      },
    );

    test(
      'completeTournament is idempotent after champion is already set',
      () async {
        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 10)),
        );
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }

        await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 20)),
        );
        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 25)),
        );
        await matchRepository.updateMatch(
          knockout.matches.single.copyWith(
            scoreTeamA: 2,
            scoreTeamB: 0,
            status: MatchStatus.settled,
          ),
        );
        await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 30)),
        );

        final firstCompleted = await lifecycleService.completeTournament(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 35)),
        );
        final auditCountBefore = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'tournamentCompleted')
            .get();

        final secondCompleted = await lifecycleService.completeTournament(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 45)),
        );
        final auditCountAfter = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'tournamentCompleted')
            .get();

        expect(secondCompleted.status, TournamentStatus.completed);
        expect(
          secondCompleted.winnerParticipantId,
          firstCompleted.winnerParticipantId,
        );
        expect(auditCountAfter.docs, hasLength(auditCountBefore.docs.length));
      },
    );

    test(
      'non-organizer lifecycle mutations fail before writing operation state',
      () async {
        expect(
          () => lifecycleService.finalizeParticipants(
            tournamentId: 'tournament-1',
            actorId: 'account-b',
            now: now.add(const Duration(minutes: 10)),
          ),
          _throwsTournamentUnauthorized,
        );
        var participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );
        expect(
          participants.any((participant) => participant.isFinalized),
          false,
        );

        await lifecycleService.finalizeParticipants(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 11)),
        );

        expect(
          () => lifecycleService.startGroupStage(
            tournamentId: 'tournament-1',
            actorId: 'account-b',
            now: now.add(const Duration(minutes: 12)),
          ),
          _throwsTournamentUnauthorized,
        );
        final groupsAfterDeniedStart = await firestore
            .collection(FirebasePaths.tournamentGroups)
            .get();
        expect(groupsAfterDeniedStart.docs, isEmpty);

        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 13)),
        );

        expect(
          () => lifecycleService.publishFixtures(
            tournamentId: 'tournament-1',
            actorId: 'account-b',
            now: now.add(const Duration(minutes: 14)),
          ),
          _throwsTournamentUnauthorized,
        );
        final draftFixtures = await matchRepository.getTournamentMatches(
          tournamentId: 'tournament-1',
        );
        expect(
          draftFixtures.every(
            (fixture) => fixture.fixtureStatus == FixtureStatus.draft,
          ),
          isTrue,
        );

        for (final fixture in groupStage.fixtures) {
          final score = _groupScoreFor(fixture.teamAId!, fixture.teamBId!);
          await matchRepository.updateMatch(
            fixture.copyWith(
              scoreTeamA: score.$1,
              scoreTeamB: score.$2,
              status: MatchStatus.settled,
            ),
          );
        }
        await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );

        expect(
          () => lifecycleService.startKnockout(
            tournamentId: 'tournament-1',
            actorId: 'account-b',
            now: now.add(const Duration(minutes: 16)),
          ),
          _throwsTournamentUnauthorized,
        );
        final bracketsAfterDeniedStart = await firestore
            .collection(FirebasePaths.knockoutBrackets)
            .get();
        expect(bracketsAfterDeniedStart.docs, isEmpty);

        final knockout = await lifecycleService.startKnockout(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 17)),
        );
        await matchRepository.updateMatch(
          knockout.matches.single.copyWith(
            scoreTeamA: 2,
            scoreTeamB: 0,
            status: MatchStatus.settled,
          ),
        );
        await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 18)),
        );

        expect(
          () => lifecycleService.completeTournament(
            tournamentId: 'tournament-1',
            actorId: 'account-b',
            now: now.add(const Duration(minutes: 19)),
          ),
          _throwsTournamentUnauthorized,
        );
        final tournament = await tournamentRepository.getTournament(
          'tournament-1',
        );
        expect(tournament?.status, isNot(TournamentStatus.completed));

        participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );
        expect(
          participants.every((participant) => participant.isFinalized),
          true,
        );
      },
    );

    test(
      'approved registrations sync into participants during registration flow',
      () async {
        final participants = await participantService.getTournamentParticipants(
          'tournament-1',
        );

        expect(participants, hasLength(4));
        expect(
          participants.every(
            (participant) => participant.sourceRegistrationId != null,
          ),
          isTrue,
        );
      },
    );
  });
}

Matcher get _throwsTournamentUnauthorized => throwsA(
  predicate(
    (error) => error.toString().contains('لا تملك صلاحية إدارة هذه البطولة'),
  ),
);

(int, int) _groupScoreFor(String teamAId, String teamBId) {
  const matrix = <String, (int, int)>{
    'team-1|team-2': (2, 0),
    'team-1|team-3': (3, 1),
    'team-1|team-4': (2, 1),
    'team-2|team-3': (2, 0),
    'team-2|team-4': (1, 0),
    'team-3|team-4': (1, 0),
  };
  final directKey = '$teamAId|$teamBId';
  final reverseKey = '$teamBId|$teamAId';
  if (matrix.containsKey(directKey)) {
    return matrix[directKey]!;
  }
  final reversed = matrix[reverseKey];
  if (reversed != null) {
    return (reversed.$2, reversed.$1);
  }
  return (0, 0);
}
