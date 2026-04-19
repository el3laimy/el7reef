import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  group('TournamentFixtureService', () {
    late FakeFirebaseFirestore firestore;
    late TournamentRepositoryImpl tournamentRepository;
    late TeamRepositoryImpl teamRepository;
    late MatchRepositoryImpl matchRepository;
    late TournamentRegistrationService registrationService;
    late TournamentLifecycleService lifecycleService;
    late TournamentFixtureService fixtureService;
    late DateTime now;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      tournamentRepository = TournamentRepositoryImpl(db: firestore);
      teamRepository = TeamRepositoryImpl(firestore: firestore);
      matchRepository = MatchRepositoryImpl(db: firestore);
      registrationService = TournamentRegistrationService(firestore: firestore);
      lifecycleService = TournamentLifecycleService(firestore: firestore);
      fixtureService = TournamentFixtureService(firestore: firestore);
      now = DateTime(2026, 4, 20, 18);

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

      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 10)),
      );
    });

    test('scheduleFixture stores scheduled time and venue', () async {
      final groupStage = await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 15)),
      );
      final fixture = groupStage.fixtures.first;
      final scheduledAt = now.add(const Duration(days: 1, hours: 2));

      await fixtureService.scheduleFixture(
        matchId: fixture.id,
        actorId: 'organizer-1',
        scheduledAt: scheduledAt,
        venueId: 'Pitch-1',
      );

      final savedFixture = await matchRepository.getMatch(fixture.id);
      expect(savedFixture, isNotNull);
      expect(savedFixture!.scheduledAt, scheduledAt);
      expect(savedFixture.venueId, 'Pitch-1');
    });

    test(
      'regenerateGroupStage rebuilds draft fixtures before publish',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final fixture = groupStage.fixtures.first;

        await fixtureService.scheduleFixture(
          matchId: fixture.id,
          actorId: 'organizer-1',
          scheduledAt: now.add(const Duration(days: 1)),
          venueId: 'Pitch-2',
        );

        final regenerated = await fixtureService.regenerateGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        );

        final refreshedFixture = await matchRepository.getMatch(fixture.id);

        expect(regenerated.fixtures, hasLength(6));
        expect(refreshedFixture, isNotNull);
        expect(refreshedFixture!.scheduledAt, isNull);
        expect(refreshedFixture.venueId, isNull);
      },
    );

    test('regenerateGroupStage is blocked after publish', () async {
      await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 15)),
      );
      await lifecycleService.publishFixtures(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 16)),
      );

      expect(
        () => fixtureService.regenerateGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 20)),
        ),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('لا يمكن إعادة توليد المجموعات'),
          ),
        ),
      );
    });

    test(
      'regenerateGroupStage is blocked after scores are submitted',
      () async {
        final groupStage = await lifecycleService.startGroupStage(
          tournamentId: 'tournament-1',
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 15)),
        );
        final fixture = groupStage.fixtures.first;

        await matchRepository.updateMatch(
          fixture.copyWith(
            scoreTeamA: 2,
            scoreTeamB: 1,
            status: MatchStatus.completed,
          ),
        );

        expect(
          () => fixtureService.regenerateGroupStage(
            tournamentId: 'tournament-1',
            actorId: 'organizer-1',
            now: now.add(const Duration(minutes: 20)),
          ),
          throwsA(
            predicate(
              (error) =>
                  error.toString().contains('لا يمكن إعادة توليد المجموعات'),
            ),
          ),
        );
      },
    );
  });
}
