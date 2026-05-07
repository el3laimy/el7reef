import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/match_attendance_status.dart';
import 'package:el7reef/core/enums/match_check_in_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/team_member_availability.dart';
import 'package:el7reef/core/enums/team_membership_role.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/tournament_top_scorers_resolver.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_ops_migration_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/models/match_check_in_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/group_standing_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_bracket_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_tie_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_group_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_check_in.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/tournament/controllers/tournament_detail_controller.dart';
import 'package:el7reef/features/tournament/controllers/tournament_operations_controller.dart';
import 'package:el7reef/features/tournament/views/tournament_detail_screen.dart';
import 'package:el7reef/features/tournament/views/tournament_operations_screens.dart';
import 'package:el7reef/services/auth_service.dart';

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

    Get.put<TournamentRepositoryImpl>(tournamentRepository, permanent: true);
    Get.put<TeamRepositoryImpl>(teamRepository, permanent: true);
    Get.put<GuestTeamRepositoryImpl>(
      GuestTeamRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<TournamentGroupRepositoryImpl>(
      TournamentGroupRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<GroupStandingSnapshotRepositoryImpl>(
      GroupStandingSnapshotRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<MatchRepositoryImpl>(
      MatchRepositoryImpl(db: firestore),
      permanent: true,
    );
    Get.put<TournamentTopScorersResolver>(
      TournamentTopScorersResolver(
        matchEventService: MatchEventService(
          repository: MatchEventRepositoryImpl(firestore: firestore),
        ),
      ),
      permanent: true,
    );
    Get.put<KnockoutBracketRepositoryImpl>(
      KnockoutBracketRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<KnockoutTieRepositoryImpl>(
      KnockoutTieRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<TournamentParticipantService>(
      TournamentParticipantService(firestore: firestore),
      permanent: true,
    );
    Get.put<TournamentOpsMigrationService>(
      TournamentOpsMigrationService(firestore: firestore),
      permanent: true,
    );
    Get.put<TournamentLifecycleService>(
      TournamentLifecycleService(firestore: firestore),
      permanent: true,
    );
    Get.put<TournamentFixtureService>(
      TournamentFixtureService(firestore: firestore),
      permanent: true,
    );
    Get.put<MatchSettlementService>(
      MatchSettlementService(
        firestore: firestore,
        tournamentLifecycleService: Get.find<TournamentLifecycleService>(),
      ),
      permanent: true,
    );
    Get.put<AuthService>(
      _FakeAuthService(currentUserId: 'organizer-1'),
      permanent: true,
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
    await teamRepository.createTeam(
      Team(
        id: 'team-3',
        name: 'Green Falcons',
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
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tournament Operations Dashboard'), findsWidgets);
    expect(find.text('Sync Participants'), findsNothing);
    expect(find.text('Manual Add Participant'), findsOneWidget);
    expect(find.text('Finalize Participants'), findsOneWidget);
    expect(
      find.textContaining('Backfill approved registrations'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('الخطوات التالية'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('جاهزية التشغيل'), findsOneWidget);
    expect(find.text('الخطوات التالية'), findsOneWidget);
    expect(find.text('قفل قائمة المشاركين'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Participants'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Participants'));
    await tester.pumpAndSettle();

    expect(find.text('Blue Sharks'), findsOneWidget);
    expect(find.text('Red Wolves'), findsOneWidget);
  });

  testWidgets('fixtures screen exposes operator filters and match actions', (
    tester,
  ) async {
    final lifecycleService = TournamentLifecycleService(firestore: firestore);
    await lifecycleService.finalizeParticipants(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final groupStage = await lifecycleService.startGroupStage(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    await Get.find<MatchRepositoryImpl>().updateMatch(
      groupStage.fixtures.single.copyWith(
        status: MatchStatus.pendingReview,
        scoreTeamA: 1,
        scoreTeamB: 1,
      ),
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentFixturesById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة fixtures'), findsOneWidget);
    expect(find.text('اختر يومًا'), findsOneWidget);
    expect(find.text('كل المجموعات'), findsOneWidget);
    expect(find.text('Matchday'), findsOneWidget);
    expect(find.text('Review & Approve'), findsOneWidget);
  });

  testWidgets('standings screen renders table columns and qualifier state', (
    tester,
  ) async {
    await _seedOfficialGroupStandings(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentStandingsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ترتيب المجموعات'), findsOneWidget);
    expect(find.textContaining('آخر تحديث:'), findsOneWidget);
    expect(find.text('Pts'), findsOneWidget);
    expect(find.text('Qualified'), findsWidgets);
    expect(find.text('Blue Sharks'), findsOneWidget);
  });

  testWidgets('bracket screen shows final summary and tie actions', (
    tester,
  ) async {
    final lifecycleService = await _seedOfficialGroupStandings(firestore);
    await lifecycleService.startKnockout(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentBracketById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ملخص الإقصاء'), findsOneWidget);
    expect(find.text('ملخص النهائي'), findsOneWidget);
    expect(find.text('النهائي'), findsOneWidget);
    expect(find.text('Matchday'), findsWidgets);
  });

  testWidgets('tournament detail screen shows champion label and ops links', (
    tester,
  ) async {
    await _seedOfficialGroupStandings(firestore);
    final tournament = await tournamentRepository.getTournament('tournament-1');
    await tournamentRepository.updateTournament(
      tournament!.copyWith(
        status: TournamentStatus.completed,
        currentGroupStageId: 'group-stage-1',
        winnerParticipantId:
            'participant::tournament-1::registeredTeam::team-1',
      ),
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('حالة التشغيل'), findsOneWidget);
    expect(find.text('هدافو البطولة'), findsOneWidget);
    expect(find.text('لم يتم تسجيل هدافين بعد'), findsOneWidget);
    expect(
      find.text('ستظهر هنا أهداف اللاعبين بعد تسجيل نتائج المباريات.'),
      findsOneWidget,
    );
    expect(find.text('شارك الهدافين'), findsNothing);
    expect(find.text('Blue Sharks'), findsWidgets);
    expect(find.text('الترتيب'), findsOneWidget);
    expect(find.text('لوحة تشغيل البطولة'), findsOneWidget);
  });

  testWidgets('tournament detail shows registered and guest top scorers', (
    tester,
  ) async {
    await _seedTopScorerGoals(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('هدافو البطولة'), findsOneWidget);
    expect(find.text('Ali Scorer'), findsOneWidget);
    expect(find.text('ضيف هداف'), findsOneWidget);
    expect(find.text('2 أهداف'), findsOneWidget);
    expect(find.text('1 هدف'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('شارك الهدافين'), findsOneWidget);
    expect(find.text('Temporary Scorer'), findsNothing);
  });

  testWidgets('registered top scorer row opens public player profile', (
    tester,
  ) async {
    await _seedTopScorerGoals(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    final registeredScorer = find.text('Ali Scorer');
    await tester.ensureVisible(registeredScorer);
    await tester.pumpAndSettle();
    await tester.tap(registeredScorer);
    await tester.pumpAndSettle();

    expect(find.text('profile:player:player-scorer'), findsOneWidget);
  });

  testWidgets('guest top scorer row opens public guest profile', (
    tester,
  ) async {
    await _seedTopScorerGoals(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    final guestScorer = find.text('ضيف هداف');
    await tester.ensureVisible(guestScorer);
    await tester.pumpAndSettle();
    await tester.tap(guestScorer);
    await tester.pumpAndSettle();

    expect(find.text('profile:guestPlayer:guest-scorer'), findsOneWidget);
  });

  testWidgets('tournament detail shows safe top scorers error state', (
    tester,
  ) async {
    await Get.delete<TournamentTopScorersResolver>(force: true);
    Get.put<TournamentTopScorersResolver>(
      _ThrowingTopScorersResolver(firestore),
      permanent: true,
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('هدافو البطولة'), findsOneWidget);
    expect(find.text('تعذر تحميل هدافي البطولة الآن.'), findsOneWidget);
    expect(find.textContaining('top scorers unavailable'), findsNothing);
  });

  testWidgets('organizer happy path navigates across tournament ops screens', (
    tester,
  ) async {
    final lifecycleService = await _seedOfficialGroupStandings(firestore);
    await lifecycleService.startKnockout(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Groups'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('مباريات المجموعة'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixtures'));
    await tester.pumpAndSettle();
    expect(find.text('إدارة fixtures'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standings'));
    await tester.pumpAndSettle();
    expect(find.text('ترتيب المجموعات'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bracket'));
    await tester.pumpAndSettle();
    expect(find.text('ملخص الإقصاء'), findsOneWidget);
  });

  testWidgets('participants screen groups active and withdrawn participants', (
    tester,
  ) async {
    final participantService = TournamentParticipantService(
      firestore: firestore,
    );
    final participants = await participantService.getTournamentParticipants(
      'tournament-1',
    );
    await participantService.withdrawParticipant(
      participantId: participants.first.id,
      actorId: 'organizer-1',
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentParticipantsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Participants'), findsOneWidget);
    expect(find.text('Withdrawn'), findsWidgets);
    expect(find.text('Blue Sharks'), findsOneWidget);
  });

  testWidgets('groups screen shows group fixture progress and qualifiers', (
    tester,
  ) async {
    await _seedOfficialGroupStandings(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentGroupsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('مباريات المجموعة'), findsOneWidget);
    expect(find.text('Qualified'), findsWidgets);
    expect(find.text('Blue Sharks vs Red Wolves'), findsOneWidget);
  });

  test(
    'operations controller derives human-readable labels from loaded state',
    () async {
      final groupRepository = TournamentGroupRepositoryImpl(
        firestore: firestore,
      );
      final standingRepository = GroupStandingSnapshotRepositoryImpl(
        firestore: firestore,
      );
      final matchRepository = MatchRepositoryImpl(db: firestore);
      final bracketRepository = KnockoutBracketRepositoryImpl(
        firestore: firestore,
      );
      final tieRepository = KnockoutTieRepositoryImpl(firestore: firestore);
      final participantService = TournamentParticipantService(
        firestore: firestore,
      );
      final lifecycleService = TournamentLifecycleService(firestore: firestore);
      final controller = _TestTournamentOperationsController(
        fixedTournamentId: 'tournament-1',
        tournamentRepository: tournamentRepository,
        groupRepository: groupRepository,
        matchRepository: matchRepository,
        teamRepository: teamRepository,
        guestTeamRepository: GuestTeamRepositoryImpl(firestore: firestore),
        standingRepository: standingRepository,
        bracketRepository: bracketRepository,
        tieRepository: tieRepository,
        participantService: participantService,
        migrationService: TournamentOpsMigrationService(firestore: firestore),
        lifecycleService: lifecycleService,
        fixtureService: TournamentFixtureService(firestore: firestore),
        authService: Get.find<AuthService>(),
        settlementService: MatchSettlementService(
          firestore: firestore,
          tournamentLifecycleService: lifecycleService,
        ),
      );

      await lifecycleService.finalizeParticipants(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
      );
      final groupStage = await lifecycleService.startGroupStage(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
      );
      await matchRepository.updateMatch(
        groupStage.fixtures.single.copyWith(
          scoreTeamA: 1,
          scoreTeamB: 0,
          status: MatchStatus.settled,
        ),
      );
      await lifecycleService.refreshGroupStandings(
        tournamentId: 'tournament-1',
      );
      await lifecycleService.startKnockout(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
      );

      await controller.refreshAll();

      final loadedFixture = controller.fixtures.firstWhere(
        (fixture) => fixture.stageType != null,
      );
      final loadedGroup = controller.groups.single;
      final loadedTie = controller.knockoutTies.single;

      expect(controller.groupLabelFor(loadedGroup.id), 'المجموعة A');
      expect(
        controller
            .participantsForGroup(loadedGroup.id)
            .map((participant) => participant.displayName),
        containsAll(<String>['Blue Sharks', 'Red Wolves']),
      );
      expect(
        controller.fixtureTeamLabel(loadedFixture, isHome: true),
        'Blue Sharks',
      );
      expect(
        controller.fixtureTeamLabel(loadedFixture, isHome: false),
        'Red Wolves',
      );
      expect(
        controller.participantLabelFor(loadedTie.participantAId),
        isNot(equals('TBD')),
      );
      expect(
        controller.groupLabelFor(controller.standings.single.groupId),
        'المجموعة A',
      );
    },
  );

  test(
    'non-organizer sees account A tournament as read-only operations state',
    () async {
      final lifecycleService = TournamentLifecycleService(firestore: firestore);
      final controller = _TestTournamentOperationsController(
        fixedTournamentId: 'tournament-1',
        tournamentRepository: tournamentRepository,
        groupRepository: TournamentGroupRepositoryImpl(firestore: firestore),
        matchRepository: MatchRepositoryImpl(db: firestore),
        teamRepository: teamRepository,
        guestTeamRepository: GuestTeamRepositoryImpl(firestore: firestore),
        standingRepository: GroupStandingSnapshotRepositoryImpl(
          firestore: firestore,
        ),
        bracketRepository: KnockoutBracketRepositoryImpl(firestore: firestore),
        tieRepository: KnockoutTieRepositoryImpl(firestore: firestore),
        participantService: TournamentParticipantService(firestore: firestore),
        migrationService: TournamentOpsMigrationService(firestore: firestore),
        lifecycleService: lifecycleService,
        fixtureService: TournamentFixtureService(firestore: firestore),
        authService: _FakeAuthService(currentUserId: 'account-b'),
        settlementService: MatchSettlementService(
          firestore: firestore,
          tournamentLifecycleService: lifecycleService,
        ),
      );

      await controller.refreshAll();

      expect(controller.tournament.value?.organizerId, 'organizer-1');
      expect(controller.canManageTournament, isFalse);
      expect(controller.canManualAddParticipants, isFalse);
      expect(controller.canFinalizeParticipantsAction, isFalse);
      expect(controller.canPublishFixtures, isFalse);

      await controller.syncApprovedRegistrations();

      expect(
        controller.errorMessage.value,
        'لا تملك صلاحية إدارة هذه البطولة.',
      );
    },
  );

  test('scheduleFixture updates local state without full refresh', () async {
    final controller = _buildTrackingController();
    final lifecycleService = TournamentLifecycleService(firestore: firestore);
    await lifecycleService.finalizeParticipants(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final groupStage = await lifecycleService.startGroupStage(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );

    await controller.refreshAll();
    controller.blockRefreshAll = true;

    final scheduledAt = DateTime(2026, 4, 20, 18, 30);
    await controller.scheduleFixture(
      fixtureId: groupStage.fixtures.single.id,
      scheduledAt: scheduledAt,
      venueId: 'Pitch 1',
    );

    final updatedFixture = controller.fixtures.firstWhere(
      (fixture) => fixture.id == groupStage.fixtures.single.id,
    );
    expect(updatedFixture.scheduledAt, scheduledAt);
    expect(updatedFixture.venueId, 'Pitch 1');
    expect(controller.refreshAllCalls, 1);
  });

  test('startFixture updates local state without full refresh', () async {
    final controller = _buildTrackingController();
    final lifecycleService = TournamentLifecycleService(firestore: firestore);
    await lifecycleService.finalizeParticipants(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    await lifecycleService.startGroupStage(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final publishedFixtures = await lifecycleService.publishFixtures(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final fixture = publishedFixtures.single;
    await _seedReadyRegisteredFixtureForOps(
      firestore: firestore,
      fixture: fixture,
      now: DateTime(2026, 4, 20, 18),
    );

    await controller.refreshAll();
    controller.blockRefreshAll = true;

    await controller.startFixture(fixture.id);

    final updatedFixture = controller.fixtures.firstWhere(
      (entry) => entry.id == fixture.id,
    );
    expect(updatedFixture.status, MatchStatus.live);
    expect(updatedFixture.startedAt, isNotNull);
    expect(updatedFixture.teamAPlayerIds, hasLength(2));
    expect(updatedFixture.teamBPlayerIds, hasLength(2));
    expect(controller.refreshAllCalls, 1);
  });

  test('participant actions update local state without full refresh', () async {
    final controller = _buildTrackingController();

    await controller.refreshAll();
    controller.blockRefreshAll = true;

    await controller.addManualParticipant(
      sourceType: TournamentParticipantSourceType.registeredTeam,
      sourceEntityId: 'team-3',
    );
    expect(
      controller.participants.any(
        (participant) => participant.displayName == 'Green Falcons',
      ),
      isTrue,
    );

    final participantToWithdraw = controller.participants.firstWhere(
      (participant) => participant.displayName == 'Blue Sharks',
    );
    await controller.updateParticipantSeed(
      participantId: participantToWithdraw.id,
      seed: 4,
    );
    expect(
      controller.participants
          .firstWhere(
            (participant) => participant.id == participantToWithdraw.id,
          )
          .seed,
      4,
    );
    await controller.withdrawParticipant(participantToWithdraw.id);

    final withdrawn = controller.participants.firstWhere(
      (participant) => participant.id == participantToWithdraw.id,
    );
    expect(withdrawn.status, TournamentParticipantStatus.withdrawn);
    await controller.reactivateParticipant(participantToWithdraw.id);
    final reactivated = controller.participants.firstWhere(
      (participant) => participant.id == participantToWithdraw.id,
    );
    expect(reactivated.status, TournamentParticipantStatus.approved);
    expect(controller.refreshAllCalls, 1);
  });

  test(
    'searchParticipantCandidates uses short-lived cache for repeated query',
    () async {
      final controller = _buildTrackingController();
      await controller.refreshAll();

      final firstResults = await controller.searchParticipantCandidates(
        query: 'Green',
        sourceType: TournamentParticipantSourceType.registeredTeam,
      );
      expect(
        firstResults.map((candidate) => candidate.displayName),
        contains('Green Falcons'),
      );

      await firestore.collection(FirebasePaths.teams).doc('team-3').delete();

      final cachedResults = await controller.searchParticipantCandidates(
        query: 'Green',
        sourceType: TournamentParticipantSourceType.registeredTeam,
      );
      expect(
        cachedResults.map((candidate) => candidate.displayName),
        contains('Green Falcons'),
      );
    },
  );

  testWidgets('participant picker auto-searches after debounce', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentParticipantsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manual Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Green');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Green Falcons'), findsOneWidget);
  });
}

Widget _buildOpsApp(String initialRoute) {
  return GetMaterialApp(
    initialRoute: initialRoute,
    getPages: <GetPage>[
      GetPage(
        name: AppRoutes.tournamentDetail,
        page: () => const TournamentDetailScreen(),
        binding: _TestTournamentDetailBinding(),
      ),
      GetPage(
        name: AppRoutes.playerProfile,
        page: () => Scaffold(
          body: Text(
            'profile:${Get.parameters['kind']}:${Get.parameters['id']}',
          ),
        ),
      ),
      GetPage(
        name: AppRoutes.organizerDashboard,
        page: () => const TournamentOperationsDashboardScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentParticipants,
        page: () => const TournamentParticipantsScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentGroups,
        page: () => const TournamentGroupsScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentFixtures,
        page: () => const TournamentFixturesScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentStandings,
        page: () => const TournamentStandingsScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentBracket,
        page: () => const TournamentBracketScreen(),
        binding: _TestTournamentOperationsBinding(),
      ),
    ],
  );
}

class _TestTournamentDetailBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentDetailController>()) {
      Get.put<TournamentDetailController>(
        TournamentDetailController(
          repository: Get.find<TournamentRepositoryImpl>(),
          participantService: Get.find<TournamentParticipantService>(),
          topScorersResolver: Get.isRegistered<TournamentTopScorersResolver>()
              ? Get.find<TournamentTopScorersResolver>()
              : null,
        ),
        permanent: true,
      );
    }
  }
}

class _TestTournamentOperationsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TournamentOperationsController>()) {
      Get.put<TournamentOperationsController>(
        TournamentOperationsController(
          tournamentRepository: Get.find<TournamentRepositoryImpl>(),
          groupRepository: Get.find<TournamentGroupRepositoryImpl>(),
          matchRepository: Get.find<MatchRepositoryImpl>(),
          teamRepository: Get.find<TeamRepositoryImpl>(),
          guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
          standingRepository: Get.find<GroupStandingSnapshotRepositoryImpl>(),
          bracketRepository: Get.find<KnockoutBracketRepositoryImpl>(),
          tieRepository: Get.find<KnockoutTieRepositoryImpl>(),
          participantService: Get.find<TournamentParticipantService>(),
          migrationService: Get.find<TournamentOpsMigrationService>(),
          lifecycleService: Get.find<TournamentLifecycleService>(),
          fixtureService: Get.find<TournamentFixtureService>(),
          authService: Get.find<AuthService>(),
          settlementService: Get.find<MatchSettlementService>(),
        ),
        permanent: true,
      );
    }
  }
}

class _TestTournamentOperationsController
    extends TournamentOperationsController {
  final String fixedTournamentId;

  _TestTournamentOperationsController({
    required this.fixedTournamentId,
    required super.tournamentRepository,
    required super.groupRepository,
    required super.matchRepository,
    required super.teamRepository,
    required super.guestTeamRepository,
    required super.standingRepository,
    required super.bracketRepository,
    required super.tieRepository,
    required super.participantService,
    required super.migrationService,
    required super.lifecycleService,
    required super.fixtureService,
    super.authService,
    super.settlementService,
  });

  @override
  String? get tournamentId => fixedTournamentId;
}

class _TrackingTournamentOperationsController
    extends _TestTournamentOperationsController {
  int refreshAllCalls = 0;
  bool blockRefreshAll = false;

  _TrackingTournamentOperationsController({
    required super.fixedTournamentId,
    required super.tournamentRepository,
    required super.groupRepository,
    required super.matchRepository,
    required super.teamRepository,
    required super.guestTeamRepository,
    required super.standingRepository,
    required super.bracketRepository,
    required super.tieRepository,
    required super.participantService,
    required super.migrationService,
    required super.lifecycleService,
    required super.fixtureService,
    super.authService,
    super.settlementService,
  });

  @override
  Future<void> refreshAll() async {
    refreshAllCalls += 1;
    if (blockRefreshAll) {
      throw StateError('refreshAll should not be called in this action path');
    }
    await super.refreshAll();
  }
}

_TrackingTournamentOperationsController _buildTrackingController() {
  return _TrackingTournamentOperationsController(
    fixedTournamentId: 'tournament-1',
    tournamentRepository: Get.find<TournamentRepositoryImpl>(),
    groupRepository: Get.find<TournamentGroupRepositoryImpl>(),
    matchRepository: Get.find<MatchRepositoryImpl>(),
    teamRepository: Get.find<TeamRepositoryImpl>(),
    guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
    standingRepository: Get.find<GroupStandingSnapshotRepositoryImpl>(),
    bracketRepository: Get.find<KnockoutBracketRepositoryImpl>(),
    tieRepository: Get.find<KnockoutTieRepositoryImpl>(),
    participantService: Get.find<TournamentParticipantService>(),
    migrationService: Get.find<TournamentOpsMigrationService>(),
    lifecycleService: Get.find<TournamentLifecycleService>(),
    fixtureService: Get.find<TournamentFixtureService>(),
    authService: Get.find<AuthService>(),
    settlementService: Get.find<MatchSettlementService>(),
  );
}

Future<TournamentLifecycleService> _seedOfficialGroupStandings(
  FakeFirebaseFirestore firestore,
) async {
  final lifecycleService = TournamentLifecycleService(firestore: firestore);
  final matchRepository = MatchRepositoryImpl(db: firestore);

  await lifecycleService.finalizeParticipants(
    tournamentId: 'tournament-1',
    actorId: 'organizer-1',
  );
  final groupStage = await lifecycleService.startGroupStage(
    tournamentId: 'tournament-1',
    actorId: 'organizer-1',
  );
  await matchRepository.updateMatch(
    groupStage.fixtures.single.copyWith(
      status: MatchStatus.settled,
      scoreTeamA: 2,
      scoreTeamB: 0,
    ),
  );
  await lifecycleService.refreshGroupStandings(tournamentId: 'tournament-1');
  return lifecycleService;
}

Future<void> _seedReadyRegisteredFixtureForOps({
  required FakeFirebaseFirestore firestore,
  required Match fixture,
  required DateTime now,
}) async {
  await _seedRegisteredCheckInForOps(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedRegisteredCheckInForOps(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
  await _seedRegisteredSnapshotForOps(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamAId!,
    now: now,
  );
  await _seedRegisteredSnapshotForOps(
    firestore: firestore,
    matchId: fixture.id,
    teamId: fixture.teamBId!,
    now: now,
  );
}

Future<void> _seedRegisteredCheckInForOps({
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

Future<void> _seedRegisteredSnapshotForOps({
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

Future<void> _seedTopScorerGoals(FakeFirebaseFirestore firestore) async {
  final service = MatchEventService(
    repository: MatchEventRepositoryImpl(firestore: firestore),
  );
  final now = DateTime(2026, 4, 20, 20);
  const registeredScorer = ParticipantRef(
    kind: ParticipantRefKind.player,
    id: 'player-scorer',
    displayName: 'Ali Scorer',
  );
  const guestScorer = ParticipantRef(
    kind: ParticipantRefKind.guestPlayer,
    id: 'guest-scorer',
    displayName: 'ضيف هداف',
    linkedPlayerId: 'claimed-player',
  );
  const temporaryScorer = ParticipantRef(
    kind: ParticipantRefKind.matchSidePlayer,
    id: 'temporary-scorer',
    displayName: 'Temporary Scorer',
  );

  await service.recordGoal(
    eventId: 'goal-tournament-1-player-1',
    matchId: 'match-top-scorers',
    tournamentId: 'tournament-1',
    sideKey: 'A',
    actor: registeredScorer,
    createdBy: 'organizer-1',
    now: now,
  );
  await service.recordGoal(
    eventId: 'goal-tournament-1-player-2',
    matchId: 'match-top-scorers',
    tournamentId: 'tournament-1',
    sideKey: 'A',
    actor: registeredScorer,
    createdBy: 'organizer-1',
    now: now.add(const Duration(seconds: 1)),
  );
  await service.recordGoal(
    eventId: 'goal-tournament-1-guest-1',
    matchId: 'match-top-scorers',
    tournamentId: 'tournament-1',
    sideKey: 'B',
    actor: guestScorer,
    createdBy: 'organizer-1',
    now: now.add(const Duration(seconds: 2)),
  );
  await service.recordGoal(
    eventId: 'goal-tournament-1-temporary-1',
    matchId: 'match-top-scorers',
    tournamentId: 'tournament-1',
    sideKey: 'B',
    actor: temporaryScorer,
    createdBy: 'organizer-1',
    now: now.add(const Duration(seconds: 3)),
  );
}

class _FakeAuthService extends GetxService implements AuthService {
  @override
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  @override
  final RxBool isLoading = false.obs;

  final String? _currentUserId;

  _FakeAuthService({required String? currentUserId})
    : _currentUserId = currentUserId;

  @override
  bool get isLoggedIn => _currentUserId != null;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}
}

class _ThrowingTopScorersResolver extends TournamentTopScorersResolver {
  _ThrowingTopScorersResolver(FakeFirebaseFirestore firestore)
    : super(
        matchEventService: MatchEventService(
          repository: MatchEventRepositoryImpl(firestore: firestore),
        ),
      );

  @override
  Future<List<TournamentTopScorerEntry>> getTopScorers(
    String tournamentId, {
    int limit = 10,
  }) {
    throw StateError('top scorers unavailable');
  }
}
