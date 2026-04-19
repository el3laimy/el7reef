import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_ops_migration_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/group_standing_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_bracket_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_tie_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_group_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TournamentRepositoryImpl tournamentRepository;
  late TeamRepositoryImpl teamRepository;
  late TournamentRegistrationService registrationService;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    tournamentRepository = TournamentRepositoryImpl(db: firestore);
    teamRepository = TeamRepositoryImpl(firestore: firestore);
    registrationService = TournamentRegistrationService(firestore: firestore);

    Get.put<TournamentRepositoryImpl>(tournamentRepository);
    Get.put<TeamRepositoryImpl>(teamRepository);
    Get.put<GuestTeamRepositoryImpl>(
      GuestTeamRepositoryImpl(firestore: firestore),
    );
    Get.put<TournamentGroupRepositoryImpl>(
      TournamentGroupRepositoryImpl(firestore: firestore),
    );
    Get.put<GroupStandingSnapshotRepositoryImpl>(
      GroupStandingSnapshotRepositoryImpl(firestore: firestore),
    );
    Get.put<MatchRepositoryImpl>(MatchRepositoryImpl(db: firestore));
    Get.put<KnockoutBracketRepositoryImpl>(
      KnockoutBracketRepositoryImpl(firestore: firestore),
    );
    Get.put<KnockoutTieRepositoryImpl>(
      KnockoutTieRepositoryImpl(firestore: firestore),
    );
    Get.put<TournamentParticipantService>(
      TournamentParticipantService(firestore: firestore),
    );
    Get.put<TournamentOpsMigrationService>(
      TournamentOpsMigrationService(firestore: firestore),
    );
    Get.put<TournamentLifecycleService>(
      TournamentLifecycleService(firestore: firestore),
    );
    Get.put<TournamentFixtureService>(
      TournamentFixtureService(firestore: firestore),
    );

    final now = DateTime(2026, 4, 19, 22);
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
    await teamRepository.createTeam(
      Team(
        id: 'team-1',
        name: 'Blue Sharks',
        ownerId: 'organizer-1',
        playerIds: const ['organizer-1'],
        createdAt: now,
      ),
    );
    await teamRepository.createTeam(
      Team(
        id: 'team-2',
        name: 'Red Wolves',
        ownerId: 'organizer-1',
        playerIds: const ['organizer-1'],
        createdAt: now,
      ),
    );
    await registrationService.registerTeam(
      tournamentId: 'tournament-1',
      teamId: 'team-1',
      actorId: 'organizer-1',
      now: now.add(const Duration(minutes: 1)),
    );
    await registrationService.registerTeam(
      tournamentId: 'tournament-1',
      teamId: 'team-2',
      actorId: 'organizer-1',
      now: now.add(const Duration(minutes: 2)),
    );
  });

  tearDown(Get.reset);

  testWidgets('operations dashboard route shows real tournament controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.organizerDashboardForTournament('tournament-1'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tournament Operations Dashboard'), findsWidgets);
    expect(find.text('Sync Participants'), findsOneWidget);
    expect(find.text('Manual Add Participant'), findsOneWidget);
    expect(find.text('Finalize Participants'), findsOneWidget);
    expect(find.text('Participants'), findsWidgets);

    await tester.tap(find.text('Participants').last);
    await tester.pumpAndSettle();

    expect(find.text('Blue Sharks'), findsOneWidget);
    expect(find.text('Red Wolves'), findsOneWidget);
  });
}
