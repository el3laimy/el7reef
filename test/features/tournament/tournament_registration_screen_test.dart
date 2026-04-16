import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_registration_mode.dart';
import 'package:el7reef/core/services/tournament_registration_service.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_registration_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/features/tournament/controllers/tournament_registration_controller.dart';
import 'package:el7reef/features/tournament/controllers/tournament_registration_review_controller.dart';
import 'package:el7reef/features/tournament/views/tournament_registration_review_screen.dart';
import 'package:el7reef/features/tournament/views/tournament_registration_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TournamentRegistrationService registrationService;
  late TournamentRegistrationRepositoryImpl registrationRepository;
  late TournamentRepositoryImpl tournamentRepository;
  late TeamRepositoryImpl teamRepository;
  late GuestTeamRepositoryImpl guestTeamRepository;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();

    Get.put<TournamentRepositoryImpl>(TournamentRepositoryImpl(db: firestore));
    Get.put<TeamRepositoryImpl>(TeamRepositoryImpl(firestore: firestore));
    Get.put<GuestTeamRepositoryImpl>(GuestTeamRepositoryImpl(firestore: firestore));
    Get.put<PlayerRepositoryImpl>(PlayerRepositoryImpl(firestore: firestore));
    Get.put<TournamentRegistrationRepositoryImpl>(
      TournamentRegistrationRepositoryImpl(firestore: firestore),
    );
    Get.put<TournamentRegistrationService>(
      TournamentRegistrationService(firestore: firestore),
    );
    registrationService = Get.find<TournamentRegistrationService>();
    registrationRepository = Get.find<TournamentRegistrationRepositoryImpl>();
    tournamentRepository = Get.find<TournamentRepositoryImpl>();
    teamRepository = Get.find<TeamRepositoryImpl>();
    guestTeamRepository = Get.find<GuestTeamRepositoryImpl>();

    final now = DateTime(2026, 4, 16, 20);
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
        ownerId: 'owner-1',
        playerIds: const ['owner-1'],
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
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-1',
        name: 'Guest Falcons',
        normalizedName: 'guest falcons',
        creatorId: 'guest-owner-1',
        claimStatus: GuestClaimStatus.guest,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await Get.find<PlayerRepositoryImpl>().createPlayer(
      Player(
        id: 'organizer-1',
        name: 'Organizer One',
        createdAt: now,
        lastActiveAt: now,
      ),
    );

    await registrationService.registerGuestTeam(
      tournamentId: 'tournament-1',
      guestTeamId: 'guest-team-1',
      actorId: 'guest-owner-1',
      mode: TournamentRegistrationMode.hybrid,
      now: now.add(const Duration(minutes: 1)),
    );
  });

  tearDown(Get.reset);

  testWidgets('registration hub route boots with organizer actions and pending entries',
      (WidgetTester tester) async {
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'organizer-1',
        currentPlayer: Player(
          id: 'organizer-1',
          name: 'Organizer One',
          createdAt: DateTime(2026, 4, 16, 20),
          lastActiveAt: DateTime(2026, 4, 16, 20),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.teamRegistrationForTournament('tournament-1'),
        authSession: Get.find<AuthSession>(),
        registrationService: registrationService,
        registrationRepository: registrationRepository,
        tournamentRepository: tournamentRepository,
        teamRepository: teamRepository,
        guestTeamRepository: guestTeamRepository,
      ),
    );
    await tester.pumpAndSettle();

    final controller = Get.find<TournamentRegistrationController>();
    expect(find.byType(TournamentRegistrationScreen), findsOneWidget);
    expect(find.text('إنشاء فريق ضيف'), findsOneWidget);
    expect(controller.pendingRegistrations, hasLength(1));
  });

  testWidgets('organizer can approve pending registration from the review screen',
      (WidgetTester tester) async {
    final registration = await registrationRepository.getRegistrationByGuestTeamId(
      tournamentId: 'tournament-1',
      guestTeamId: 'guest-team-1',
    );
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'organizer-1',
        currentPlayer: Player(
          id: 'organizer-1',
          name: 'Organizer One',
          createdAt: DateTime(2026, 4, 16, 20),
          lastActiveAt: DateTime(2026, 4, 16, 20),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.tournamentRegistrationReviewForTournament(
          'tournament-1',
          registration!.id,
        ),
        authSession: Get.find<AuthSession>(),
        registrationService: registrationService,
        registrationRepository: registrationRepository,
        tournamentRepository: tournamentRepository,
        teamRepository: teamRepository,
        guestTeamRepository: guestTeamRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TournamentRegistrationReviewScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'اعتماد التسجيل'));
    await tester.pumpAndSettle();

    expect(find.text('معتمد'), findsWidgets);
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    }
  });
}

class _FakeAuthSession implements AuthSession {
  @override
  final String? currentUserId;

  @override
  final Player? currentPlayer;

  const _FakeAuthSession({
    required this.currentUserId,
    required this.currentPlayer,
  });
}

GetMaterialApp _buildApp({
  required String initialRoute,
  required AuthSession authSession,
  required TournamentRegistrationService registrationService,
  required TournamentRegistrationRepositoryImpl registrationRepository,
  required TournamentRepositoryImpl tournamentRepository,
  required TeamRepositoryImpl teamRepository,
  required GuestTeamRepositoryImpl guestTeamRepository,
}) {
  return GetMaterialApp(
    initialRoute: initialRoute,
    getPages: [
      GetPage(
        name: AppRoutes.teamRegistration,
        page: () => const TournamentRegistrationScreen(),
        binding: BindingsBuilder(() {
          if (!Get.isRegistered<TournamentRegistrationController>()) {
            Get.put<TournamentRegistrationController>(
              TournamentRegistrationController(
                authSession: authSession,
                tournamentRepository: tournamentRepository,
                registrationRepository: registrationRepository,
                teamRepository: teamRepository,
                guestTeamRepository: guestTeamRepository,
                registrationService: registrationService,
              ),
            );
          }
        }),
      ),
      GetPage(
        name: AppRoutes.tournamentRegistrationReview,
        page: () => const TournamentRegistrationReviewScreen(),
        binding: BindingsBuilder(() {
          if (!Get.isRegistered<TournamentRegistrationReviewController>()) {
            Get.put<TournamentRegistrationReviewController>(
              TournamentRegistrationReviewController(
                authSession: authSession,
                registrationRepository: registrationRepository,
                tournamentRepository: tournamentRepository,
                teamRepository: teamRepository,
                guestTeamRepository: guestTeamRepository,
                registrationService: registrationService,
              ),
            );
          }
        }),
      ),
    ],
  );
}
