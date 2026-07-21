import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/errors/app_exceptions.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/features/tournament/controllers/tournament_controller.dart';
import 'package:el7reef/features/tournament/views/tournament_list_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeAuthService authService;

  setUp(() {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    authService = _FakeAuthService(currentUserId: 'organizer-1');

    Get.put<AuthService>(authService);
    Get.put<TournamentController>(
      TournamentController(
        authService: authService,
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('empty tournament list opens create tournament sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const GetMaterialApp(home: TournamentListScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.scrollUntilVisible(
      find.text('ابدأ دورة شعبية'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('لا توجد بطولات لديك حتى الآن'), findsOneWidget);
    expect(find.text('ابدأ دورة شعبية'), findsOneWidget);
    expect(find.text('أنشئ دورة جديدة الآن'), findsNothing);

    await tester.tap(find.text('ابدأ دورة شعبية'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('أنشئ دورة جديدة بمجدها'), findsOneWidget);
    expect(find.text('اسم البطولة'), findsOneWidget);
    expect(find.text('الإعداد السريع الجاهز'), findsOneWidget);
    expect(find.text('مجموعات ثم إقصائيات'), findsOneWidget);
    expect(find.text('5 ضد 5'), findsOneWidget);
    expect(find.text('8 فرق'), findsOneWidget);
    expect(find.text('أنشئ البطولة'), findsOneWidget);
    expect(find.text('ملعب البطولة (اختياري)'), findsNothing);

    await tester.tap(find.text('خيارات متقدمة'));
    await tester.pumpAndSettle();

    expect(find.text('ملعب البطولة (اختياري)'), findsOneWidget);
  });

  testWidgets(
    'active tournament card keeps stage identity readable at 360dp and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Get.find<TournamentController>().myOrganizedTournaments.assign(
        Tournament(
          id: 'street-cup-visual',
          organizerId: 'organizer-1',
          name: 'كأس الحارة للأبطال أصحاب النفس الطويل',
          location: 'ملعب النصر',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.fiveVsFive,
          maxTeams: 8,
          activeParticipantCount: 6,
          status: TournamentStatus.groupStage,
          createdAt: DateTime(2026, 7, 18),
        ),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TournamentListScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('كأس الحارة للأبطال أصحاب النفس الطويل'),
        240,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.text('كأس الحارة للأبطال أصحاب النفس الطويل'),
        findsOneWidget,
      );
      expect(find.text('دور المجموعات'), findsOneWidget);
      expect(
        find.text('مجموعات ثم إقصائيات  •  5 ضد 5  •  ملعب النصر'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('كأس الحارة للأبطال.*6 من 8 فريق')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discover failure is not rendered as a false empty tournament list',
    (tester) async {
      await Get.delete<TournamentController>(force: true);
      Get.put<TournamentController>(
        TournamentController(
          authService: authService,
          tournamentRepository: _DiscoverFailureTournamentRepository(firestore),
          teamRepository: TeamRepositoryImpl(firestore: firestore),
        ),
      );
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TournamentExploreScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('تعذر فتح الاستكشاف'),
        300,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.text('تعذر فتح الاستكشاف'), findsOneWidget);
      expect(
        find.textContaining('لا يوجد اتصال مستقر بالإنترنت'),
        findsOneWidget,
      );
      expect(find.text('لا توجد بطولات مفتوحة الآن'), findsNothing);
      expect(find.text('حاول تاني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-07-17 membership denial shows error without a false my-tournaments empty state',
    (tester) async {
      await Get.delete<TournamentController>(force: true);
      final now = DateTime(2026, 7, 17);
      authService.currentPlayer.value = Player(
        id: 'organizer-1',
        name: 'Organizer',
        createdAt: now,
        lastActiveAt: now,
      );
      Get.put<TournamentController>(
        TournamentController(
          authService: authService,
          tournamentRepository: _MyTournamentsFailureRepository(firestore),
          teamRepository: TeamRepositoryImpl(firestore: firestore),
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: TournamentListScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('تعذر تحديث البطولات التي تنظمها حالياً.'),
        findsOneWidget,
      );
      expect(find.text('لا توجد بطولات لديك حتى الآن'), findsNothing);
      expect(find.text('أنشئ دورة جديدة الآن'), findsOneWidget);
      expect(find.text('حاول تاني'), findsOneWidget);
      expect(
        find.text('تعذر تحميل البطولات التي تتابعها حالياً.'),
        findsNothing,
      );
    },
  );

  testWidgets('discover refresh failure keeps cached tournaments visible', (
    tester,
  ) async {
    await Get.delete<TournamentController>(force: true);
    final controller = Get.put<TournamentController>(
      TournamentController(
        authService: authService,
        tournamentRepository: _DiscoverFailureTournamentRepository(firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      ),
    );
    controller.discoverableTournaments.add(
      Tournament(
        id: 'cached-cup',
        organizerId: 'organizer-1',
        name: 'بطولة محفوظة محلياً',
        format: TournamentFormat.groupsThenKnockout,
        teamSize: TournamentTeamSize.fiveVsFive,
        maxTeams: 8,
        status: TournamentStatus.registration,
        createdAt: DateTime(2026, 7, 17),
      ),
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: TournamentExploreScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحديث القائمة'), findsOneWidget);
    expect(find.text('بطولة محفوظة محلياً'), findsOneWidget);
    expect(find.text('لا توجد بطولات مفتوحة الآن'), findsNothing);
  });

  testWidgets(
    'featured completed World Cup appears in the public spotlight for another user',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = TournamentRepositoryImpl(db: firestore);
      await repository.createTournament(
        Tournament(
          id: 'world-cup-2026-simulation',
          organizerId: 'el7reef-official',
          name: 'كأس العالم 2026',
          description: 'محاكاة داخل الحريف تضم المنتخبات والقوائم والنتائج.',
          format: TournamentFormat.groupsThenKnockout,
          teamSize: TournamentTeamSize.elevenVsEleven,
          maxTeams: 48,
          activeParticipantCount: 48,
          isFeatured: true,
          featuredPriority: 0,
          status: TournamentStatus.completed,
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      await tester.pumpWidget(
        const GetMaterialApp(home: TournamentExploreScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('بطولات مميزة'), findsOneWidget);
      expect(find.text('بطولة مميزة'), findsOneWidget);
      expect(find.text('كأس العالم 2026'), findsOneWidget);
      expect(find.text('شاهد البطولة'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('featured-tournament-world-cup-2026-simulation'),
        ),
        findsOneWidget,
      );
      expect(find.text('بطولة رسمية'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-07-17 participating query failure keeps organized tournaments visible',
    (tester) async {
      await Get.delete<TournamentController>(force: true);
      final now = DateTime(2026, 7, 17);
      await TeamRepositoryImpl(firestore: firestore).createTeam(
        Team(
          id: 'team-1',
          name: 'فريق المنظم',
          ownerId: 'organizer-1',
          playerIds: const ['organizer-1'],
          createdAt: now,
        ),
      );
      authService.currentPlayer.value = Player(
        id: 'organizer-1',
        name: 'Organizer',
        createdAt: now,
        lastActiveAt: now,
      );
      Get.put<TournamentController>(
        TournamentController(
          authService: authService,
          tournamentRepository: _ParticipatingFailureTournamentRepository(
            firestore,
          ),
          teamRepository: TeamRepositoryImpl(firestore: firestore),
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: TournamentListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('كأس الحارة المنظم'), findsOneWidget);
      expect(
        find.text('ظهرت بطولاتك المنظمة، لكن تعذر تحديث بطولات فرقك.'),
        findsOneWidget,
      );
      expect(find.text('لا توجد بطولات لديك حتى الآن'), findsNothing);
    },
  );

  testWidgets('create tournament sheet supports 360dp and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      GetMaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const TournamentListScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ دورة شعبية'));
    await tester.pumpAndSettle();

    expect(find.text('أنشئ دورة جديدة بمجدها'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('خيارات متقدمة'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('خيارات متقدمة'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ظهور البطولة'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('ظهور البطولة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permission error keeps the entered form open and explains the failure',
    (tester) async {
      await Get.delete<TournamentController>(force: true);
      Get.put<TournamentController>(
        TournamentController(
          authService: authService,
          tournamentRepository: _PermissionDeniedTournamentRepository(
            firestore,
          ),
          teamRepository: TeamRepositoryImpl(firestore: firestore),
        ),
      );
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const GetMaterialApp(home: TournamentListScreen()),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ابدأ دورة شعبية'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('ابدأ دورة شعبية'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'بطولة اختبار الصلاحيات',
      );
      await tester.tap(find.text('أنشئ البطولة'));
      await tester.pumpAndSettle();

      expect(find.text('أنشئ دورة جديدة بمجدها'), findsOneWidget);
      expect(
        find.text('فشل إنشاء البطولة. لا تملك صلاحية تنفيذ هذه العملية.'),
        findsOneWidget,
      );
      expect(find.text('بطولة اختبار الصلاحيات'), findsOneWidget);
      expect(Get.find<TournamentController>().myOrganizedTournaments, isEmpty);
    },
  );

  testWidgets(
    'creating after an empty load keeps Rx lists mutable and opens dashboard',
    (tester) async {
      final now = DateTime(2026, 7, 17);
      await Get.delete<TournamentController>(force: true);
      authService.currentPlayer.value = Player(
        id: 'organizer-1',
        name: 'Organizer',
        createdAt: now,
        lastActiveAt: now,
      );
      final controller = Get.put<TournamentController>(
        TournamentController(
          authService: authService,
          tournamentRepository: TournamentRepositoryImpl(db: firestore),
          teamRepository: TeamRepositoryImpl(firestore: firestore),
        ),
      );
      while (controller.isLoadingMyTournaments.value) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await controller.loadDiscoverableTournaments();

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          home: const TournamentListScreen(),
          getPages: [
            GetPage(
              name: AppRoutes.organizerDashboard,
              page: () => const Scaffold(body: Text('لوحة تشغيل البطولة')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ابدأ دورة شعبية'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('ابدأ دورة شعبية'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'بطولة بعد تحميل فارغ',
      );
      await tester.tap(find.text('أنشئ البطولة'));
      await tester.pumpAndSettle();

      expect(controller.createTournamentErrorMessage.value, isEmpty);
      expect(controller.myOrganizedTournaments, hasLength(1));
      expect(controller.discoverableTournaments, hasLength(1));
      expect(
        controller.myOrganizedTournaments.single.name,
        'بطولة بعد تحميل فارغ',
      );
      expect(
        controller.discoverableTournaments.single.id,
        controller.myOrganizedTournaments.single.id,
      );
      final tournamentDocs = await firestore
          .collection(FirebasePaths.tournaments)
          .get();
      final membershipDocs = await firestore
          .collection(FirebasePaths.tournamentMemberships)
          .get();
      expect(tournamentDocs.docs, hasLength(1));
      expect(membershipDocs.docs, hasLength(1));
      expect(
        membershipDocs.docs.single.data()['tournamentId'],
        tournamentDocs.docs.single.id,
      );
      expect(find.text('لوحة تشغيل البطولة'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}

class _PermissionDeniedTournamentRepository extends TournamentRepositoryImpl {
  _PermissionDeniedTournamentRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  @override
  Future<void> createTournament(Tournament tournament) async {
    throw const PermissionDeniedException();
  }
}

class _DiscoverFailureTournamentRepository extends TournamentRepositoryImpl {
  _DiscoverFailureTournamentRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  @override
  Future<List<Tournament>> getDiscoverableTournaments({int limit = 20}) {
    throw const NetworkException();
  }
}

class _MyTournamentsFailureRepository extends TournamentRepositoryImpl {
  _MyTournamentsFailureRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  @override
  Future<List<Tournament>> getOrganizerTournaments(String organizerId) {
    throw const PermissionDeniedException();
  }
}

class _ParticipatingFailureTournamentRepository
    extends TournamentRepositoryImpl {
  _ParticipatingFailureTournamentRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  @override
  Future<List<Tournament>> getOrganizerTournaments(String organizerId) async {
    return [
      Tournament(
        id: 'organized-cup',
        organizerId: organizerId,
        name: 'كأس الحارة المنظم',
        format: TournamentFormat.groupsThenKnockout,
        teamSize: TournamentTeamSize.fiveVsFive,
        maxTeams: 8,
        status: TournamentStatus.registration,
        createdAt: DateTime(2026, 7, 17),
      ),
    ];
  }

  @override
  Future<List<Tournament>> getPlayerTournaments(String teamId) {
    throw const NetworkException();
  }
}

class _FakeAuthService extends GetxService implements AuthService {
  @override
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  @override
  final RxBool isLoading = false.obs;

  @override
  final Rx<AuthProfileStatus> profileStatus = AuthProfileStatus.ready.obs;

  @override
  final RxString profileErrorMessage = ''.obs;

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
  Future<Player?> signInWithGoogle() async => currentPlayer.value;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
