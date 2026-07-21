import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/app/theme/app_theme.dart';
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
import 'package:el7reef/core/services/guest_team_roster_service.dart';
import 'package:el7reef/core/services/tournament_audit_emitter.dart';
import 'package:el7reef/core/services/tournament_top_scorers_resolver.dart';
import 'package:el7reef/core/services/tournament_fixture_service.dart';
import 'package:el7reef/core/services/tournament_lifecycle_service.dart';
import 'package:el7reef/core/services/tournament_ops_migration_service.dart';
import 'package:el7reef/core/services/tournament_participant_service.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/core/widgets/section_state_card.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/models/match_check_in_model.dart';
import 'package:el7reef/data/models/match_lineup_snapshot_model.dart';
import 'package:el7reef/data/models/tournament_participant_model.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/group_standing_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_bracket_repository_impl.dart';
import 'package:el7reef/data/repositories/knockout_tie_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_assistant_permission_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_group_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_check_in.dart';
import 'package:el7reef/domain/entities/match_lineup_entry.dart';
import 'package:el7reef/domain/entities/match_lineup_snapshot.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/tournament/controllers/tournament_detail_controller.dart';
import 'package:el7reef/features/tournament/controllers/tournament_operations_controller.dart';
import 'package:el7reef/features/tournament/bindings/tournament_guest_team_roster_binding.dart';
import 'package:el7reef/features/tournament/views/tournament_detail_screen.dart';
import 'package:el7reef/features/tournament/views/tournament_guest_team_roster_screen.dart';
import 'package:el7reef/features/tournament/views/tournament_organizer_guard.dart';
import 'package:el7reef/features/tournament/views/tournament_operations_screens.dart';
import 'package:el7reef/core/auth/auth_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TournamentRepositoryImpl tournamentRepository;
  late TeamRepositoryImpl teamRepository;
  late GuestTeamRepositoryImpl guestTeamRepository;
  late GuestPlayerRepositoryImpl guestPlayerRepository;
  late TournamentAssistantPermissionRepositoryImpl
  assistantPermissionRepository;
  late TournamentRegistrationService registrationService;
  late _FakeAuthService authService;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    tournamentRepository = TournamentRepositoryImpl(db: firestore);
    teamRepository = TeamRepositoryImpl(firestore: firestore);
    guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    assistantPermissionRepository = TournamentAssistantPermissionRepositoryImpl(
      firestore: firestore,
    );
    registrationService = TournamentRegistrationService(firestore: firestore);

    Get.put<TournamentRepositoryImpl>(tournamentRepository, permanent: true);
    Get.put<TeamRepositoryImpl>(teamRepository, permanent: true);
    Get.put<GuestTeamRepositoryImpl>(guestTeamRepository, permanent: true);
    Get.put<GuestPlayerRepositoryImpl>(guestPlayerRepository, permanent: true);
    Get.put<TournamentAuditEmitter>(
      TournamentAuditEmitter(firestore: firestore),
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
          firestore: firestore,
        ),
        matchRepository: MatchRepositoryImpl(db: firestore),
        guestPlayerRepository: guestPlayerRepository,
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
        allowLocalFallback: true,
      ),
      permanent: true,
    );
    Get.put<GuestTeamRosterService>(
      GuestTeamRosterService(
        guestPlayerRepository: guestPlayerRepository,
        guestTeamRepository: guestTeamRepository,
        tournamentRepository: tournamentRepository,
        assistantPermissionRepository: assistantPermissionRepository,
        auditEmitter: Get.find<TournamentAuditEmitter>(),
      ),
      permanent: true,
    );
    authService = _FakeAuthService(currentUserId: 'organizer-1');
    Get.put<AuthService>(authService, permanent: true);

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
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('غرفة تحكم البطولة'), findsWidgets);
    expect(find.text('مزامنة الفرق المعتمدة'), findsNothing);
    expect(find.text('قفل قائمة الفرق'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('إضافة فريق يدويًا'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إضافة فريق يدويًا'), findsOneWidget);
    expect(
      find.textContaining('Backfill approved registrations'),
      findsNothing,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.text('جاهزية التشغيل'), findsOneWidget);
    expect(find.text('الخطوة التالية'), findsOneWidget);
    expect(find.text('قفل قائمة الفرق'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('الفرق المشاركة'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('الفرق المشاركة'));
    await tester.pumpAndSettle();

    expect(find.text('Blue Sharks'), findsOneWidget);
    expect(find.text('Red Wolves'), findsOneWidget);
  });

  testWidgets('new tournament dashboard has no horizontal overflow at 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime(2026, 7, 17);
    await tournamentRepository.createTournament(
      Tournament(
        id: 'empty-tournament',
        organizerId: 'organizer-1',
        name: 'CodexFixedE2ECup20260717',
        format: TournamentFormat.groupsThenKnockout,
        teamSize: TournamentTeamSize.fiveVsFive,
        maxTeams: 8,
        visibility: TournamentVisibility.public,
        discoverable: true,
        status: TournamentStatus.registration,
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      _buildOpsApp(
        AppRoutes.organizerDashboardForTournament('empty-tournament'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أضف أول فريق'), findsWidgets);
    expect(
      find.text('يمكن إضافة اللاعبين مباشرة بعد إنشاء الفريق.'),
      findsOneWidget,
    );
    expect(find.text('0 فريق نشط جاهز'), findsOneWidget);
    expect(find.text('مفتوحة للتعديل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operations dashboard keeps section error scoped to dashboard', (
    tester,
  ) async {
    const errorMessage = 'تعذر تحديث بيانات التشغيل الآن.';

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    Get.find<TournamentOperationsController>().errorMessage.value =
        errorMessage;
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SectionStateCard),
        matching: find.text(errorMessage),
      ),
      findsOneWidget,
    );
    expect(find.text('قفل قائمة الفرق'), findsWidgets);
    expect(find.text('حاول تاني'), findsNothing);
  });

  testWidgets('direct operations route is blocked for non-organizer', (
    tester,
  ) async {
    authService.setCurrentUserId('account-b');

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('غرفة تحكم البطولة'), findsNothing);
    expect(find.text('إضافة فريق يدويًا'), findsNothing);
    expect(find.text('Street Cup'), findsWidgets);
    expect(find.text('إدارة البطولة'), findsNothing);
  });

  testWidgets('operations route closes when account changes to non-organizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('غرفة تحكم البطولة'), findsWidgets);
    final controller = Get.find<TournamentOperationsController>();

    authService.setCurrentUserId('account-b');
    await controller.refreshAll();
    await tester.pumpAndSettle();

    expect(controller.canManageTournament, isFalse);
    expect(controller.tournament.value?.id, 'tournament-1');
    expect(find.text('غرفة تحكم البطولة'), findsNothing);
    expect(find.text('إضافة فريق يدويًا'), findsNothing);
    expect(find.text('Street Cup'), findsWidgets);
    expect(find.text('إدارة البطولة'), findsNothing);
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

    expect(find.text('مباريات البطولة'), findsOneWidget);
    expect(find.text('فلاتر متقدمة'), findsOneWidget);
    expect(find.text('اختر يومًا'), findsNothing);
    expect(find.text('كل المجموعات'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('advanced-fixtures-filter-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر يومًا'), findsOneWidget);
    expect(find.text('كل المجموعات'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('fixture-manage-${groupStage.fixtures.single.id}')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(ValueKey('fixture-manage-${groupStage.fixtures.single.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('fixture-primary-${groupStage.fixtures.single.id}')),
      findsOneWidget,
    );

    final reviewButton = find.byKey(
      ValueKey('fixture-primary-${groupStage.fixtures.single.id}'),
    );
    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('score:${groupStage.fixtures.single.id}'), findsOneWidget);
  });

  testWidgets('live fixture becomes the organizer do-now action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lifecycleService = TournamentLifecycleService(firestore: firestore);
    await lifecycleService.finalizeParticipants(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final groupStage = await lifecycleService.startGroupStage(
      tournamentId: 'tournament-1',
      actorId: 'organizer-1',
    );
    final liveFixture = groupStage.fixtures.single.copyWith(
      status: MatchStatus.live,
    );
    await Get.find<MatchRepositoryImpl>().updateMatch(liveFixture);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.organizerDashboardForTournament('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('سجّل النتيجة الآن'), findsWidgets);
    final doNowButton = find.widgetWithText(FilledButton, 'سجّل النتيجة الآن');
    await tester.scrollUntilVisible(
      doNowButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(doNowButton);
    await tester.pumpAndSettle();
    expect(find.text('score:${liveFixture.id}'), findsOneWidget);
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
    expect(find.text('نقطة'), findsWidgets);
    expect(find.text('متأهل'), findsWidgets);
    expect(find.text('Blue Sharks'), findsOneWidget);
  });

  testWidgets('bracket screen shows the knockout journey and tie actions', (
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

    expect(
      find.byKey(const ValueKey('bracket-screen-summary-bar')),
      findsOneWidget,
    );
    expect(find.text('الطريق إلى الكأس'), findsOneWidget);
    expect(find.text('النهائي'), findsWidgets);
    await tester.tap(find.text('الجولات'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('إدارة المباراة'), findsWidgets);
  });

  testWidgets('organizer sees one clear management CTA on tournament detail', (
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

    expect(find.text('Street Cup'), findsWidgets);
    expect(find.text('إدارة البطولة'), findsOneWidget);
    expect(find.text('حالة التشغيل'), findsNothing);
    expect(find.text('لوحة تشغيل البطولة'), findsNothing);
    expect(find.text('هدافو البطولة'), findsOneWidget);
    expect(
      find.text('النتائج محفوظة، تفاصيل الهدافين غير مسجلة'),
      findsOneWidget,
    );
    expect(
      find.text(
        'تم اعتماد 1 مباراة، لكن النتائج المستوردة لا تتضمن أسماء مسجلي الأهداف؛ لذلك لن نعرض ترتيبًا أو كارت مشاركة غير مؤكد.',
      ),
      findsOneWidget,
    );
    expect(find.text('تفاصيل الهدافين غير مسجلة'), findsOneWidget);
    expect(find.text('لم يتم تسجيل هدافين بعد'), findsNothing);
    expect(find.text('شارك لوحة الهدافين'), findsNothing);
  });

  testWidgets(
    'non-organizer sees public tournament detail without admin operations',
    (tester) async {
      authService.setCurrentUserId('account-b');

      await tester.pumpWidget(
        _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Street Cup'), findsWidgets);
      expect(find.text('حجم الفريق'), findsOneWidget);
      expect(find.text('التسجيلات'), findsOneWidget);
      expect(find.text('هدافو البطولة'), findsOneWidget);
      expect(find.text('إدارة البطولة'), findsNothing);
      expect(find.text('حالة التشغيل'), findsNothing);
      expect(find.text('لوحة تشغيل البطولة'), findsNothing);
      expect(find.text('الفرق'), findsOneWidget);
      expect(find.text('المجموعات'), findsOneWidget);
      expect(find.text('المباريات'), findsOneWidget);
      expect(find.text('الإقصائيات'), findsOneWidget);
    },
  );

  testWidgets(
    'tournament detail stays readable at 360dp and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildOpsApp(
          AppRoutes.tournamentDetailById('tournament-1'),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Street Cup'), findsWidgets);
      expect(find.text('حجم الفريق'), findsOneWidget);
      expect(find.text('التسجيلات'), findsOneWidget);
      expect(find.text('داخل البطولة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-07-18 long tournament title stays readable while hero collapses',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final tournament = await tournamentRepository.getTournament(
        'tournament-1',
      );
      const longName = 'كأس العالم 2026، محاكاة المنظم للبطولة الكبرى';
      await tournamentRepository.updateTournament(
        tournament!.copyWith(name: longName),
      );

      await tester.pumpWidget(
        _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -44));
      await tester.pumpAndSettle();

      expect(find.text(longName), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('organizer management CTA navigates to operations dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('إدارة البطولة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إدارة البطولة'));
    await tester.pumpAndSettle();

    expect(find.text('غرفة تحكم البطولة'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('إضافة فريق يدويًا'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إضافة فريق يدويًا'), findsOneWidget);
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
    expect(find.text('شارك لوحة الهدافين'), findsOneWidget);
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

  testWidgets('claimed guest scorer row opens the registered player profile', (
    tester,
  ) async {
    await _seedTopScorerGoals(firestore, claimedGuest: true);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentDetailById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ضيف'), findsNothing);
    final claimedScorer = find.text('ضيف هداف');
    await tester.ensureVisible(claimedScorer);
    await tester.pumpAndSettle();
    await tester.tap(claimedScorer);
    await tester.pumpAndSettle();

    expect(find.text('profile:player:claimed-player'), findsOneWidget);
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

    Future<void> openDashboardDestination(String label) async {
      final target = find.text(label);
      await tester.scrollUntilVisible(
        target,
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await openDashboardDestination('المجموعات');
    expect(find.text('مباريات المجموعة'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await openDashboardDestination('المباريات');
    expect(find.text('مباريات البطولة'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await openDashboardDestination('الترتيب');
    expect(find.text('ترتيب المجموعات'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();
    await openDashboardDestination('الإقصائيات');
    expect(
      find.byKey(const ValueKey('bracket-screen-summary-bar')),
      findsOneWidget,
    );
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
    final withdrawnParticipant = participants.first;
    final activeParticipant = participants.last;
    await participantService.withdrawParticipant(
      participantId: withdrawnParticipant.id,
      actorId: 'organizer-1',
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentParticipantsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('participant-search-field')), findsOne);
    expect(find.text(activeParticipant.displayName), findsOneWidget);

    await tester.tap(find.text('المنسحبة 1'));
    await tester.pumpAndSettle();

    expect(find.text(withdrawnParticipant.displayName), findsOneWidget);
    expect(find.text(activeParticipant.displayName), findsNothing);
  });

  testWidgets(
    '2026-07-18 large participant list searches and filters without card sprawl',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final participantService = Get.find<TournamentParticipantService>();
      final now = DateTime(2026, 7, 18, 12);

      for (var index = 0; index < 24; index++) {
        final id = 'world-team-$index';
        final name = index == 17
            ? 'الأرجنتين (ARG)'
            : 'منتخب ${(index + 1).toString().padLeft(2, '0')}';
        await guestTeamRepository.createGuestTeam(
          GuestTeam(
            id: id,
            name: name,
            normalizedName: name.toLowerCase(),
            creatorId: 'organizer-1',
            tournamentIds: const ['tournament-1'],
            createdAt: now,
            updatedAt: now,
          ),
        );
        final participant = await participantService.addManualParticipant(
          tournamentId: 'tournament-1',
          sourceType: TournamentParticipantSourceType.guestTeam,
          sourceEntityId: id,
          actorId: 'organizer-1',
          now: now.add(Duration(minutes: index)),
          refreshTournamentSummary: false,
        );
        final groupedParticipant = participant.copyWith(
          groupId: index < 12 ? 'group-a' : 'group-b',
        );
        await firestore
            .collection(FirebasePaths.tournamentParticipants)
            .doc(groupedParticipant.id)
            .set(
              TournamentParticipantModel.fromEntity(
                groupedParticipant,
              ).toJson(),
            );
      }

      await tester.pumpWidget(
        _buildOpsApp(AppRoutes.tournamentParticipantsById('tournament-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('26 فريق ظاهر'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('participant-search-field')),
        'الأرجنتين',
      );
      await tester.pumpAndSettle();

      expect(find.text('الأرجنتين (ARG)'), findsOneWidget);
      expect(find.text('1 فريق ظاهر'), findsOneWidget);

      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('participant-group-group-a')));
      await tester.pumpAndSettle();

      expect(find.text('12 فريق ظاهر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('groups screen shows group fixture progress and qualifiers', (
    tester,
  ) async {
    await _seedOfficialGroupStandings(firestore);

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentGroupsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('مباريات المجموعة'), findsOneWidget);
    expect(find.text('متأهل'), findsWidgets);
    expect(find.text('Blue Sharks ضد Red Wolves'), findsOneWidget);
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
          allowLocalFallback: true,
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
    'complete tournament immediately presents the champion celebration',
    () async {
      final lifecycleService = TournamentLifecycleService(firestore: firestore);
      final matchRepository = MatchRepositoryImpl(db: firestore);
      final controller = _CelebrationTrackingTournamentOperationsController(
        fixedTournamentId: 'tournament-1',
        tournamentRepository: tournamentRepository,
        groupRepository: TournamentGroupRepositoryImpl(firestore: firestore),
        matchRepository: matchRepository,
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
        authService: authService,
        settlementService: MatchSettlementService(
          firestore: firestore,
          tournamentLifecycleService: lifecycleService,
          allowLocalFallback: true,
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
      for (final fixture in groupStage.fixtures) {
        await matchRepository.updateMatch(
          fixture.copyWith(
            scoreTeamA: 2,
            scoreTeamB: 0,
            status: MatchStatus.settled,
          ),
        );
      }
      await lifecycleService.refreshGroupStandings(
        tournamentId: 'tournament-1',
      );
      final knockout = await lifecycleService.startKnockout(
        tournamentId: 'tournament-1',
        actorId: 'organizer-1',
      );
      for (final fixture in knockout.matches) {
        await matchRepository.updateMatch(
          fixture.copyWith(
            scoreTeamA: 3,
            scoreTeamB: 1,
            status: MatchStatus.settled,
          ),
        );
      }
      await lifecycleService.refreshKnockoutProgress(
        tournamentId: 'tournament-1',
      );
      await controller.refreshAll();

      await controller.completeTournament();

      expect(controller.tournament.value?.status, TournamentStatus.completed);
      expect(controller.celebrationCount, 1);
      expect(controller.celebratedTournament?.winnerParticipantId, isNotEmpty);
    },
  );

  test('operations controller fails closed for non-organizer', () async {
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
        allowLocalFallback: true,
      ),
    );

    await controller.refreshAll();

    expect(controller.tournament.value?.id, 'tournament-1');
    expect(controller.canManageTournament, isFalse);
    expect(controller.canManualAddParticipants, isFalse);
    expect(controller.canFinalizeParticipantsAction, isFalse);
    expect(controller.canPublishFixtures, isFalse);
    expect(controller.errorMessage.value, isEmpty);
  });

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

    await tester.tap(find.text('إضافة فريق'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Green');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Green Falcons'), findsOneWidget);
  });

  testWidgets('guest participant opens operational guest roster screen', (
    tester,
  ) async {
    final now = DateTime(2026, 4, 20, 20);
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-1',
        name: 'ضيوف الحارة',
        normalizedName: 'ضيوف الحارة',
        creatorId: 'organizer-1',
        tournamentIds: const ['tournament-1'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await Get.find<TournamentParticipantService>().addManualParticipant(
      tournamentId: 'tournament-1',
      sourceType: TournamentParticipantSourceType.guestTeam,
      sourceEntityId: 'guest-team-1',
      actorId: 'organizer-1',
      now: now.add(const Duration(minutes: 1)),
    );

    await tester.pumpWidget(
      _buildOpsApp(AppRoutes.tournamentParticipantsById('tournament-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('participant-search-field')),
      'ضيوف الحارة',
    );
    await tester.pumpAndSettle();
    expect(find.text('ضيوف الحارة'), findsWidgets);
    await tester.tap(
      find.byKey(
        const ValueKey(
          'participant-roster-participant::tournament-1::guestTeam::guest-team-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TournamentGuestTeamRosterScreen), findsOneWidget);
    expect(find.text('ضيوف الحارة'), findsOneWidget);
    expect(find.text('إضافة أول لاعب'), findsOneWidget);

    await tester.tap(find.text('إضافة أول لاعب'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'حسن الضيف');
    await tester.enterText(find.byType(TextField).at(2), '9');
    await tester.enterText(find.byType(TextField).at(3), 'مهاجم');
    await tester.tap(find.text('إضافة اللاعب'));
    await tester.pumpAndSettle();

    expect(find.text('حسن الضيف'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.textContaining('مهاجم'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}

Widget _buildOpsApp(String initialRoute, {double textScale = 1}) {
  return GetMaterialApp(
    locale: const Locale('ar', 'EG'),
    fallbackLocale: const Locale('ar', 'EG'),
    textDirection: TextDirection.rtl,
    theme: AppTheme.darkTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
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
        name: AppRoutes.scoreApproval,
        page: () => Scaffold(body: Text('score:${Get.parameters['matchId']}')),
      ),
      GetPage(
        name: AppRoutes.organizerDashboard,
        page: () => const TournamentOrganizerGuard(
          child: TournamentOperationsDashboardScreen(),
        ),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentParticipants,
        page: () => const TournamentOrganizerGuard(
          child: TournamentParticipantsScreen(),
        ),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentGroups,
        page: () =>
            const TournamentOrganizerGuard(child: TournamentGroupsScreen()),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentFixtures,
        page: () =>
            const TournamentOrganizerGuard(child: TournamentFixturesScreen()),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentStandings,
        page: () =>
            const TournamentOrganizerGuard(child: TournamentStandingsScreen()),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentBracket,
        page: () =>
            const TournamentOrganizerGuard(child: TournamentBracketScreen()),
        binding: _TestTournamentOperationsBinding(),
      ),
      GetPage(
        name: AppRoutes.tournamentGuestTeamRoster,
        page: () => const TournamentGuestTeamRosterScreen(),
        binding: TournamentGuestTeamRosterBinding(),
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

class _CelebrationTrackingTournamentOperationsController
    extends _TestTournamentOperationsController {
  int celebrationCount = 0;
  Tournament? celebratedTournament;

  _CelebrationTrackingTournamentOperationsController({
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
  Future<void> showChampionCelebration(Tournament updatedTournament) async {
    celebrationCount += 1;
    celebratedTournament = updatedTournament;
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

Future<void> _seedTopScorerGoals(
  FakeFirebaseFirestore firestore, {
  bool claimedGuest = false,
}) async {
  final service = MatchEventService(
    repository: MatchEventRepositoryImpl(firestore: firestore),
    firestore: firestore,
  );
  final now = DateTime(2026, 4, 20, 20);
  const registeredScorer = ParticipantRef(
    kind: ParticipantRefKind.player,
    id: 'player-scorer',
    displayName: 'Ali Scorer',
  );
  final guestScorer = ParticipantRef(
    kind: ParticipantRefKind.guestPlayer,
    id: 'guest-scorer',
    displayName: 'ضيف هداف',
    linkedPlayerId: claimedGuest ? 'claimed-player' : null,
  );
  const temporaryScorer = ParticipantRef(
    kind: ParticipantRefKind.matchSidePlayer,
    id: 'temporary-scorer',
    displayName: 'Temporary Scorer',
  );

  await firestore
      .collection(FirebasePaths.matches)
      .doc('match-top-scorers')
      .set({
        'organizerId': 'organizer-1',
        'tournamentId': 'tournament-1',
        'status': MatchStatus.settled.name,
        'scoreTeamA': 2,
        'scoreTeamB': 1,
        'isOrganized': true,
        'createdAt': now.millisecondsSinceEpoch,
      });

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

  @override
  final Rx<AuthProfileStatus> profileStatus =
      AuthProfileStatus.unauthenticated.obs;

  @override
  final RxString profileErrorMessage = ''.obs;

  String? _currentUserId;

  _FakeAuthService({required String? currentUserId}) {
    setCurrentUserId(currentUserId);
  }

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    final now = DateTime(2026, 4, 19, 22);
    currentPlayer.value = userId == null
        ? null
        : Player(
            id: userId,
            name: 'Test User $userId',
            createdAt: now,
            lastActiveAt: now,
          );
    profileStatus.value = userId == null
        ? AuthProfileStatus.unauthenticated
        : AuthProfileStatus.ready;
  }

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
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {
    setCurrentUserId(null);
  }
}

class _ThrowingTopScorersResolver extends TournamentTopScorersResolver {
  _ThrowingTopScorersResolver(FakeFirebaseFirestore firestore)
    : super(
        matchEventService: MatchEventService(
          repository: MatchEventRepositoryImpl(firestore: firestore),
          firestore: firestore,
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
