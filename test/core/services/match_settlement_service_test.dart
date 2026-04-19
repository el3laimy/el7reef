import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/group_standing_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_tie_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('MatchSettlementService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl tournamentRepository;
    late TeamRepositoryImpl teamRepository;
    late MatchRepositoryImpl matchRepository;
    late TournamentRegistrationService registrationService;
    late TournamentLifecycleService lifecycleService;
    late MatchSettlementService settlementService;
    late GroupStandingSnapshotRepositoryImpl standingsRepository;
    late KnockoutTieRepositoryImpl tieRepository;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      matchRepository = MatchRepositoryImpl(db: firestore);
      registrationService = TournamentRegistrationService(firestore: firestore);
      lifecycleService = TournamentLifecycleService(firestore: firestore);
      settlementService = MatchSettlementService(
        firestore: firestore,
        tournamentLifecycleService: lifecycleService,
      );
      standingsRepository = GroupStandingSnapshotRepositoryImpl(
        firestore: firestore,
      );
      tieRepository = KnockoutTieRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 19, 22);

      await tournamentRepository.createTournament(
        Tournament(
          id: 'tournament-1',
          organizerId: 'organizer-1',
          name: 'Street Cup',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 4,
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

      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 10)),
      );
    });

    test(
      'group standings ignore unapproved scores and refresh automatically after approval',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final fixture = groupStage.fixtures.first;

        await settlementService.submitScore(
          matchId: fixture.id,
          scoreA: 2,
          scoreB: 0,
        );

        final scoredMatch = await matchRepository.getMatch(fixture.id);
        final pendingStandings = await lifecycleService.refreshGroupStandings(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 16)),
        );

        expect(scoredMatch?.status, MatchStatus.completed);
        expect(
          pendingStandings.single.entries.every((entry) => entry.points == 0),
          isTrue,
        );

        await settlementService.approveScore(matchId: fixture.id);

        final savedStandings = await standingsRepository.getGroupStageSnapshots(
          groupStage.groupStageId,
        );
        final winnerEntry = savedStandings.single.entries.firstWhere(
          (entry) => entry.participantId == fixture.teamAParticipantId,
        );
        final loserEntry = savedStandings.single.entries.firstWhere(
          (entry) => entry.participantId == fixture.teamBParticipantId,
        );

        expect(winnerEntry.points, 3);
        expect(winnerEntry.wins, 1);
        expect(loserEntry.losses, 1);
      },
    );

    test(
      'knockout bracket ignores unapproved scores and advances winner after approval',
      () async {
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
        final finalMatch = knockout.matches.single;

        await settlementService.submitScore(
          matchId: finalMatch.id,
          scoreA: 1,
          scoreB: 0,
        );

        final pendingProgress = await lifecycleService.refreshKnockoutProgress(
          tournamentId: 'tournament-1',
          now: now.add(const Duration(minutes: 26)),
        );
        final pendingTie = await tieRepository.getTie(knockout.ties.single.id);

        expect(pendingProgress?.bracket.championParticipantId, isNull);
        expect(pendingTie?.winnerParticipantId, isNull);

        await settlementService.approveScore(matchId: finalMatch.id);

        final advancedTie = await tieRepository.getTie(knockout.ties.single.id);
        expect(advancedTie?.winnerParticipantId, finalMatch.teamAParticipantId);
      },
    );
  });
}

(int, int) _groupScoreFor(String teamAId, String teamBId) {
  const matrix = <String, (int, int)>{
    'team-1|team-2': (2, 0),
    'team-1|team-3': (3, 1),
    'team-1|team-4': (2, 1),
    'team-2|team-3': (1, 0),
    'team-2|team-4': (2, 1),
    'team-3|team-4': (1, 0),
  };
  return matrix['$teamAId|$teamBId'] ?? (1, 0);
}
