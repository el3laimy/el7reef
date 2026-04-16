import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/services/guest_claim_service.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/entities/generated_share_link.dart';
import 'package:el7reef/features/guest_claim/views/guest_player_claim_screen.dart';
import 'package:el7reef/features/guest_claim/views/guest_team_claim_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ShareLinkService shareLinkService;
  late GeneratedShareLink playerClaimLink;
  late GeneratedShareLink teamClaimLink;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();

    Get.put<TeamRepositoryImpl>(TeamRepositoryImpl(firestore: firestore));
    Get.put<PlayerRepositoryImpl>(PlayerRepositoryImpl(firestore: firestore));
    Get.put<GuestPlayerRepositoryImpl>(
      GuestPlayerRepositoryImpl(firestore: firestore),
    );
    Get.put<GuestTeamRepositoryImpl>(
      GuestTeamRepositoryImpl(firestore: firestore),
    );
    Get.put<ClaimCodeRepositoryImpl>(
      ClaimCodeRepositoryImpl(firestore: firestore),
    );
    Get.put<GuestClaimService>(GuestClaimService(firestore: firestore));

    shareLinkService = ShareLinkService(
      claimCodeRepository: Get.find<ClaimCodeRepositoryImpl>(),
      guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
      guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
      teamRepository: Get.find<TeamRepositoryImpl>(),
    );

    final now = DateTime(2026, 4, 16, 10);
    final playerRepository = Get.find<PlayerRepositoryImpl>();
    final teamRepository = Get.find<TeamRepositoryImpl>();
    final guestPlayerRepository = Get.find<GuestPlayerRepositoryImpl>();
    final guestTeamRepository = Get.find<GuestTeamRepositoryImpl>();

    await playerRepository.createPlayer(
      Player(
        id: 'owner-1',
        name: 'Organizer One',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: 'owner-2',
        name: 'Captain Two',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: 'player-1',
        name: 'Mahmoud Salem',
        createdAt: now,
        lastActiveAt: now,
      ),
    );

    await teamRepository.createTeam(
      Team(
        id: 'team-2',
        name: 'Blue Sharks',
        ownerId: 'owner-2',
        playerIds: const ['owner-2'],
        createdAt: now,
      ),
    );

    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-1',
        displayName: 'Mahmoud Guest',
        normalizedName: 'mahmoud guest',
        teamId: 'team-2',
        createdBy: 'owner-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-1',
        name: 'Guest Falcons',
        normalizedName: 'guest falcons',
        creatorId: 'owner-1',
        tournamentIds: const ['street-cup'],
        createdAt: now,
        updatedAt: now,
      ),
    );

    playerClaimLink = await shareLinkService.createGuestPlayerClaimLink(
      guestPlayerId: 'guest-1',
      actorId: 'owner-1',
    );
    teamClaimLink = await shareLinkService.createGuestTeamClaimLink(
      guestTeamId: 'guest-team-1',
      actorId: 'owner-1',
    );
  });

  tearDown(Get.reset);

  testWidgets('generic claim route redirects to guest player claim screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.claimEntryWithQuery({
          'code': playerClaimLink.claimCode.code,
          'type': 'guestPlayer',
          'targetId': 'guest-1',
          'requiresApproval': '0',
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestPlayerClaimScreen), findsOneWidget);
    expect(find.text('Mahmoud Guest'), findsOneWidget);
    expect(find.text('سجّل الدخول أولاً حتى تستلم مكانك.'), findsOneWidget);
  });

  testWidgets('logged-in player can complete guest player claim from the screen',
      (WidgetTester tester) async {
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'player-1',
        currentPlayer: Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestPlayerClaimById(
          'guest-1',
          queryParameters: {'code': playerClaimLink.claimCode.code},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
    await tester.pumpAndSettle();

    expect(find.text('تم استلام مكانك بنجاح'), findsOneWidget);
    expect(
      find.text(
        'تم ربط بيانات اللاعب الضيف بحسابك الحالي مع الحفاظ على سجلاته السابقة.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('expired guest player claim links are blocked in the UI',
      (WidgetTester tester) async {
    await Get.find<ClaimCodeRepositoryImpl>().updateClaimCode(
      playerClaimLink.claimCode.copyWith(
        expiresAt: DateTime(2000, 1, 1),
        updatedAt: DateTime(2000, 1, 1),
      ),
    );
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'player-1',
        currentPlayer: Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestPlayerClaimById(
          'guest-1',
          queryParameters: {'code': playerClaimLink.claimCode.code},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
    await tester.pumpAndSettle();

    expect(find.text('تعذر إكمال العملية'), findsOneWidget);
    expect(find.text('انتهت صلاحية رابط الاستلام.'), findsOneWidget);
  });

  testWidgets('player claim conflicts are surfaced in the claim screen',
      (WidgetTester tester) async {
    await Get.find<PlayerRepositoryImpl>().createPlayer(
      Player(
        id: 'player-name-dup',
        name: 'Mahmoud Guest',
        createdAt: DateTime(2026, 4, 16, 10),
        lastActiveAt: DateTime(2026, 4, 16, 10),
      ),
    );
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'player-1',
        currentPlayer: Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestPlayerClaimById(
          'guest-1',
          queryParameters: {'code': playerClaimLink.claimCode.code},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
    await tester.pumpAndSettle();

    expect(find.text('يوجد تعارض يحتاج مراجعة'), findsOneWidget);
    expect(
      find.text('يوجد لاعب مسجل آخر يطابق اسم هذا اللاعب الضيف.'),
      findsOneWidget,
    );
  });

  testWidgets('logged-in captain can submit a guest team claim request from the screen',
      (WidgetTester tester) async {
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'owner-2',
        currentPlayer: Player(
          id: 'owner-2',
          name: 'Captain Two',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.claimEntryWithQuery({
          'code': teamClaimLink.claimCode.code,
          'type': 'guestTeam',
          'targetId': 'guest-team-1',
          'requiresApproval': '1',
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestTeamClaimScreen), findsOneWidget);
    expect(find.text('Blue Sharks'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'إرسال طلب الاستلام'));
    await tester.pumpAndSettle();

    expect(find.text('تم إرسال طلب الاستلام'), findsOneWidget);
    expect(
      find.text(
        'تم حفظ طلب الـ claim. سيحتاج الرابط الآن إلى موافقة منشئ الفريق الضيف لإكمال الربط.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('guest team creator can complete a pending approval request from the screen',
      (WidgetTester tester) async {
    await Get.find<GuestClaimService>().claimGuestTeam(
      claimCode: teamClaimLink.claimCode.code,
      teamId: 'team-2',
      actorId: 'owner-2',
      now: DateTime(2026, 4, 16, 11),
    );
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'owner-1',
        currentPlayer: Player(
          id: 'owner-1',
          name: 'Organizer One',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestTeamClaimById(
          'guest-team-1',
          queryParameters: {
            'code': teamClaimLink.claimCode.code,
            'requiresApproval': '1',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestTeamClaimScreen), findsOneWidget);
    expect(find.text('يوجد طلب claim معلق'), findsOneWidget);
    expect(find.textContaining('Blue Sharks'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'موافقة المنظم وإتمام الربط'));
    await tester.pumpAndSettle();

    expect(find.text('تم ربط الفريق بنجاح'), findsOneWidget);
    expect(
      find.text(
        'تم ربط الفريق الضيف بالفريق المسجل مع الحفاظ على تاريخ البطولات الحالي.',
      ),
      findsOneWidget,
    );
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

Widget _buildApp({required String initialRoute}) {
  return GetMaterialApp(
    initialRoute: initialRoute,
    getPages: AppPages.routes,
  );
}
