import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
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
      'approved registrations are backfilled into participants before finalize',
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
