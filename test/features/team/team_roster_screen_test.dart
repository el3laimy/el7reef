import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/core/services/team_formation_service.dart';
import 'package:el7reef/core/services/team_roster_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_formation_template_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/team_roster_snapshot_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/features/team/controllers/team_roster_controller.dart';
import 'package:el7reef/features/team/views/team_roster_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AuthSession authSession;
  late TeamRepositoryImpl teamRepository;
  late PlayerRepositoryImpl playerRepository;
  late GuestPlayerRepositoryImpl guestPlayerRepository;
  late TeamRosterService teamRosterService;
  late TeamFormationService teamFormationService;
  late ShareLinkService shareLinkService;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();

    teamRepository = TeamRepositoryImpl(firestore: firestore);
    playerRepository = PlayerRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);

    Get.put<TeamRepositoryImpl>(teamRepository);
    Get.put<PlayerRepositoryImpl>(playerRepository);
    Get.put<GuestPlayerRepositoryImpl>(guestPlayerRepository);
    Get.put<GuestTeamRepositoryImpl>(
      GuestTeamRepositoryImpl(firestore: firestore),
    );
    Get.put<ClaimCodeRepositoryImpl>(
      ClaimCodeRepositoryImpl(firestore: firestore),
    );
    Get.put<TeamMembershipRepositoryImpl>(
      TeamMembershipRepositoryImpl(firestore: firestore),
    );
    Get.put<TeamFormationTemplateRepositoryImpl>(
      TeamFormationTemplateRepositoryImpl(firestore: firestore),
    );
    Get.put<TeamRosterSnapshotRepositoryImpl>(
      TeamRosterSnapshotRepositoryImpl(firestore: firestore),
    );
    teamRosterService = TeamRosterService(
      teamRepository: teamRepository,
      membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
      guestPlayerRepository: guestPlayerRepository,
    );
    Get.put<TeamRosterService>(teamRosterService);
    teamFormationService = TeamFormationService(
      teamRepository: teamRepository,
      membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
      playerRepository: playerRepository,
      guestPlayerRepository: guestPlayerRepository,
      templateRepository: Get.find<TeamFormationTemplateRepositoryImpl>(),
      snapshotRepository: Get.find<TeamRosterSnapshotRepositoryImpl>(),
    );
    Get.put<TeamFormationService>(teamFormationService);
    shareLinkService = ShareLinkService(
      claimCodeRepository: Get.find<ClaimCodeRepositoryImpl>(),
      teamRepository: teamRepository,
      guestPlayerRepository: guestPlayerRepository,
      guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
    );
    Get.put<ShareLinkService>(shareLinkService);
    authSession = _FakeAuthSession(
      currentUserId: 'owner-1',
      currentPlayer: Player(
        id: 'owner-1',
        name: 'Owner One',
        createdAt: DateTime(2026, 4, 16, 10),
        lastActiveAt: DateTime(2026, 4, 16, 10),
      ),
    );
    Get.put<AuthSession>(authSession);

    final now = DateTime(2026, 4, 16, 12);

    await teamRepository.createTeam(
      Team(
        id: 'team-1',
        name: 'Street Kings',
        ownerId: 'owner-1',
        playerIds: const ['owner-1'],
        createdAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: 'player-2',
        name: 'Ahmed Salem',
        username: 'ahmed',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-1',
        displayName: 'Mahmoud Ali',
        normalizedName: 'mahmoud ali',
        teamId: 'team-1',
        preferredPosition: 'MID',
        createdBy: 'owner-1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await teamRosterService.addRegisteredPlayer(
      teamId: 'team-1',
      actorId: 'owner-1',
      playerId: 'player-2',
    );
    await teamRosterService.addGuestPlayer(
      teamId: 'team-1',
      actorId: 'owner-1',
      guestPlayerId: 'guest-1',
    );
  });

  tearDown(Get.reset);

  testWidgets('team profile route boots into roster screen with guest distinction',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: shareLinkService,
      ),
    );
    await tester.pumpAndSettle();

    final controller = Get.find<TeamRosterController>();

    expect(find.byType(TeamRosterScreen), findsOneWidget);
    expect(find.text('Street Kings'), findsOneWidget);
    expect(
      controller.rosterMembers.any((entry) => entry.displayName == 'Ahmed Salem'),
      isTrue,
    );
    expect(
      controller.rosterMembers.any((entry) => entry.displayName == 'Mahmoud Ali'),
      isTrue,
    );
    expect(
      controller.rosterMembers.any((entry) => entry.isGuest),
      isTrue,
    );
    expect(
      controller.rosterMembers.any((entry) => !entry.isGuest),
      isTrue,
    );
    expect(find.text('إضافة لاعب'), findsOneWidget);
    expect(find.text('حفظ كقالب'), findsOneWidget);
    expect(find.text('إنشاء نسخة'), findsOneWidget);
  });

  testWidgets('guest add sheet shows Arabic validation when name is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: shareLinkService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة ضيف'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة اللاعب'));
    await tester.pumpAndSettle();

    expect(find.text('اسم اللاعب مطلوب'), findsOneWidget);
  });

  testWidgets('manager can save a formation template from team roster screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: shareLinkService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ كقالب'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'تشكيلة الدوري');
    await tester.tap(find.text('حفظ القالب'));
    await tester.pumpAndSettle();

    expect(find.text('تشكيلة الدوري'), findsOneWidget);
  });

  testWidgets('manager can create a ready snapshot from team roster screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: shareLinkService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنشاء نسخة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'قبل المباراة');
    await tester.tap(find.text('إنشاء النسخة'));
    await tester.pumpAndSettle();

    expect(find.text('قبل المباراة'), findsOneWidget);
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

GetMaterialApp _buildTestApp({
  required AuthSession authSession,
  required TeamRepositoryImpl teamRepository,
  required TeamRosterService teamRosterService,
  required TeamFormationService teamFormationService,
  required PlayerRepositoryImpl playerRepository,
  required GuestPlayerRepositoryImpl guestPlayerRepository,
  required ShareLinkService shareLinkService,
}) {
  return GetMaterialApp(
    initialRoute: AppRoutes.teamProfileById('team-1'),
    getPages: [
      GetPage(
        name: AppRoutes.teamProfile,
        page: () => const TeamRosterScreen(),
        binding: BindingsBuilder(() {
          if (!Get.isRegistered<TeamRosterController>()) {
            Get.put<TeamRosterController>(
              TeamRosterController(
                authSession: authSession,
                teamRepository: teamRepository,
                teamRosterService: teamRosterService,
                teamFormationService: teamFormationService,
                playerRepository: playerRepository,
                guestPlayerRepository: guestPlayerRepository,
                shareLinkService: shareLinkService,
              ),
            );
          }
        }),
      ),
    ],
  );
}
