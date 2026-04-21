import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_check_in_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/models/match_check_in_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_check_in.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
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

    test('scheduleFixture is a no-op when schedule is unchanged', () async {
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
      final auditBefore = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'fixtureScheduled')
          .where('entityId', isEqualTo: fixture.id)
          .get();

      final unchanged = await fixtureService.scheduleFixture(
        matchId: fixture.id,
        actorId: 'organizer-1',
        scheduledAt: scheduledAt,
        venueId: 'Pitch-1',
      );
      final auditAfter = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'fixtureScheduled')
          .where('entityId', isEqualTo: fixture.id)
          .get();

      expect(unchanged.scheduledAt, scheduledAt);
      expect(unchanged.venueId, 'Pitch-1');
      expect(auditAfter.docs, hasLength(auditBefore.docs.length));
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

    test(
      'startMatch promotes a published fixture to live and projects locked rosters',
      () async {
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
        final fixture = publishedFixtures.first;

        await _seedRegisteredFixtureReadyState(
          firestore: firestore,
          fixture: fixture,
          now: now.add(const Duration(minutes: 17)),
        );

        final started = await fixtureService.startMatch(
          matchId: fixture.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 18)),
        );

        final savedFixture = await matchRepository.getMatch(fixture.id);
        final auditEvents = await firestore
            .collection(FirebasePaths.auditEvents)
            .where('action', isEqualTo: 'fixtureStarted')
            .where('entityId', isEqualTo: fixture.id)
            .get();

        expect(groupStage.fixtures, isNotEmpty);
        expect(started.status, MatchStatus.live);
        expect(started.startedAt, isNotNull);
        expect(started.teamAPlayerIds, hasLength(2));
        expect(started.teamBPlayerIds, hasLength(2));
        expect(savedFixture?.status, MatchStatus.live);
        expect(savedFixture?.teamAPlayerIds, started.teamAPlayerIds);
        expect(savedFixture?.teamBPlayerIds, started.teamBPlayerIds);
        expect(auditEvents.docs, hasLength(1));
      },
    );

    test('startMatch is blocked until both sides are ready', () async {
      await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 15)),
      );
      final publishedFixtures = await lifecycleService.publishFixtures(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 16)),
      );
      final fixture = publishedFixtures.first;

      await _seedSingleRegisteredCheckIn(
        firestore: firestore,
        matchId: fixture.id,
        teamId: fixture.teamAId!,
        now: now.add(const Duration(minutes: 17)),
      );

      expect(
        () => fixtureService.startMatch(
          matchId: fixture.id,
          actorId: 'organizer-1',
          now: now.add(const Duration(minutes: 18)),
        ),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('check-in') ||
                error.toString().contains('التشكيل'),
          ),
        ),
      );
    });

    test('startMatch is idempotent once fixture is already live', () async {
      await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 15)),
      );
      final publishedFixtures = await lifecycleService.publishFixtures(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 16)),
      );
      final fixture = publishedFixtures.first;

      await _seedRegisteredFixtureReadyState(
        firestore: firestore,
        fixture: fixture,
        now: now.add(const Duration(minutes: 17)),
      );

      await fixtureService.startMatch(
        matchId: fixture.id,
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 18)),
      );
      final auditBefore = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'fixtureStarted')
          .where('entityId', isEqualTo: fixture.id)
          .get();

      final secondStart = await fixtureService.startMatch(
        matchId: fixture.id,
        actorId: 'organizer-1',
        now: now.add(const Duration(minutes: 19)),
      );
      final auditAfter = await firestore
          .collection(FirebasePaths.auditEvents)
          .where('action', isEqualTo: 'fixtureStarted')
          .where('entityId', isEqualTo: fixture.id)
          .get();

      expect(secondStart.status, MatchStatus.live);
      expect(auditAfter.docs, hasLength(auditBefore.docs.length));
    });
  });
}

Future<void> _seedRegisteredFixtureReadyState({
  required FakeFirebaseFirestore firestore,
  required Match fixture,
  required DateTime now,
}) async {
  await _seedSingleRegisteredCheckIn(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedSingleRegisteredCheckIn(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
  await _seedSingleRegisteredSnapshot(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedSingleRegisteredSnapshot(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
}

Future<void> _seedSingleRegisteredCheckIn({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  required String teamId,
  required DateTime now,
}) async {
  final checkIn = MatchCheckIn(
    id: 'checkin::$matchId::$teamId',
    matchId: matchId,
    teamId: teamId,
    status: MatchCheckInStatus.verified,
    createdBy: 'organizer-1',
    createdAt: now,
    updatedAt: now,
    checkedInBy: 'organizer-1',
    checkedInAt: now,
    verifiedBy: 'organizer-1',
    verifiedAt: now,
  );
  await firestore
      .collection(FirebasePaths.matchCheckIns)
      .doc(checkIn.id)
      .set(MatchCheckInModel.fromEntity(checkIn).toJson());
}

Future<void> _seedSingleRegisteredSnapshot({
  required FakeFirebaseFirestore firestore,
  required String matchId,
  required String teamId,
  required DateTime now,
}) async {
  final snapshot = MatchLineupSnapshot(
    id: 'snapshot::$matchId::$teamId',
    matchId: matchId,
    teamId: teamId,
    checkInId: 'checkin::$matchId::$teamId',
    starters: <MatchLineupEntry>[
      MatchLineupEntry(
        attendanceId: 'attendance::$matchId::$teamId::starter',
        teamMembershipId: 'membership::$teamId::starter',
        playerId: '$teamId-player-1',
        role: TeamMembershipRole.player,
        availability: TeamMemberAvailability.available,
        attendanceStatus: MatchAttendanceStatus.present,
        displayName: '$teamId Starter',
      ),
    ],
    bench: <MatchLineupEntry>[
      MatchLineupEntry(
        attendanceId: 'attendance::$matchId::$teamId::bench',
        teamMembershipId: 'membership::$teamId::bench',
        playerId: '$teamId-player-2',
        role: TeamMembershipRole.player,
        availability: TeamMemberAvailability.available,
        attendanceStatus: MatchAttendanceStatus.present,
        displayName: '$teamId Bench',
      ),
    ],
    lockedBy: 'organizer-1',
    lockedAt: now,
  );
  await firestore
      .collection(FirebasePaths.matchLineupSnapshots)
      .doc(snapshot.id)
      .set(MatchLineupSnapshotModel.fromEntity(snapshot).toJson());
}
