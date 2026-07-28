import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/enums/claim_payload_scope.dart';
import 'package:el7reef/core/enums/claim_target_type.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
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
import 'package:el7reef/domain/entities/claim_code.dart';
import 'package:el7reef/domain/entities/generated_share_link.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/domain/repositories/claim_code_repository.dart';
import 'package:el7reef/domain/repositories/guest_player_repository.dart';
import 'package:el7reef/domain/repositories/guest_team_repository.dart';
import 'package:el7reef/domain/repositories/team_repository.dart';
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

  testWidgets(
    'team profile route boots into roster screen with guest distinction',
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
        controller.rosterMembers.any(
          (entry) => entry.displayName == 'Ahmed Salem',
        ),
        isTrue,
      );
      expect(
        controller.rosterMembers.any(
          (entry) => entry.displayName == 'Mahmoud Ali',
        ),
        isTrue,
      );
      expect(controller.rosterMembers.any((entry) => entry.isGuest), isTrue);
      expect(controller.rosterMembers.any((entry) => !entry.isGuest), isTrue);
      expect(find.text('إضافة لاعب'), findsOneWidget);
      expect(find.text('حفظ كقالب'), findsOneWidget);
      expect(find.text('إنشاء نسخة'), findsOneWidget);
    },
  );

  testWidgets('guest add sheet shows Arabic validation when name is empty', (
    WidgetTester tester,
  ) async {
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

  testWidgets('manager can save a formation template from team roster screen', (
    WidgetTester tester,
  ) async {
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

  testWidgets('manager can create a ready snapshot from team roster screen', (
    WidgetTester tester,
  ) async {
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

  testWidgets('manager save lineup preserves visual slot assignments', (
    WidgetTester tester,
  ) async {
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
    final player = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Mahmoud Ali',
    );
    final targetSlot = controller.visualSlots.first;

    controller.assignPlayerToVisualSlot(player, targetSlot);
    await controller.saveVisualLineup();
    await tester.pumpAndSettle();

    final state = await teamFormationService.getCurrentLineupState('team-1');
    final savedGuestEntry = state!.entries.firstWhere(
      (entry) => entry.guestPlayerId == 'guest-1',
    );
    final restoredSlot = controller.visualSlots.firstWhere(
      (slot) => slot.id == targetSlot.id,
    );

    expect(savedGuestEntry.slotId, targetSlot.id);
    expect(restoredSlot.occupantKey, player.key);
    expect(controller.isLineupDirty.value, isFalse);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('manager changes lineup size to 11 and saves it visibly', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.text('خطة الفريق'));
    await tester.pumpAndSettle();

    expect(
      find.text('اضغط لاعبًا ثم اختر خانة للنقل أو التبديل.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('squad-player-count-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<int> && widget.value == 11,
      ),
    );
    await tester.pumpAndSettle();

    final controller = Get.find<TeamRosterController>();

    expect(controller.visualPlayerCount.value, 11);
    expect(controller.visualFormationCode.value, '4-2-3-1');
    expect(controller.visualSlots, hasLength(11));
    expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'حفظ'), findsOneWidget);
    expect(find.byKey(const ValueKey('squad-tactics-save')), findsOneWidget);
    expect(find.text('11v11'), findsOneWidget);

    final screenWidth = tester.view.physicalSize.width;
    final saveRect = tester.getRect(
      find.byKey(const ValueKey('squad-tactics-save')),
    );
    expect(saveRect.left, greaterThanOrEqualTo(0));
    expect(saveRect.right, lessThanOrEqualTo(screenWidth));

    await tester.tap(find.byKey(const ValueKey('squad-tactics-save')));
    await tester.pumpAndSettle();

    final state = await teamFormationService.getCurrentLineupState('team-1');
    expect(state?.formationLabel, '4-2-3-1');
    expect(controller.visualPlayerCount.value, 11);
    expect(controller.isLineupDirty.value, isFalse);
    expect(find.byKey(const ValueKey('squad-tactics-saved')), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('resizing 7 to 5 to 11 never loses active roster players', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 7, 13, 17);
    for (var index = 2; index <= 7; index += 1) {
      final guestId = 'resize-guest-$index';
      await guestPlayerRepository.createGuestPlayer(
        GuestPlayer(
          id: guestId,
          displayName: 'Resize Guest $index',
          normalizedName: 'resize guest $index',
          teamId: 'team-1',
          createdBy: 'owner-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await teamRosterService.addGuestPlayer(
        teamId: 'team-1',
        actorId: 'owner-1',
        guestPlayerId: guestId,
      );
    }

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
    final activePlayerKeys = controller.allVisualPlayers
        .map((player) => player.key)
        .toSet();
    expect(activePlayerKeys, hasLength(8));

    final initialPlayers = controller.allVisualPlayers.take(7).toList();
    for (var index = 0; index < initialPlayers.length; index += 1) {
      controller.assignPlayerToVisualSlot(
        initialPlayers[index],
        controller.visualSlots[index],
      );
    }
    expect(controller.visualSlots.where((slot) => !slot.isEmpty), hasLength(7));
    expect(controller.visualBench, hasLength(1));

    controller.changeVisualPlayerCount(5);
    expect(controller.visualSlots.where((slot) => !slot.isEmpty), hasLength(5));
    expect(controller.visualBench, hasLength(3));
    expect(_visibleVisualPlayerKeys(controller), activePlayerKeys);

    await controller.saveVisualLineup();
    await tester.pumpAndSettle();
    expect(controller.visualPlayerCount.value, 5);
    expect(controller.visualBench, hasLength(3));
    expect(_visibleVisualPlayerKeys(controller), activePlayerKeys);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();

    controller.changeVisualPlayerCount(11);
    expect(controller.visualSlots.where((slot) => !slot.isEmpty), hasLength(8));
    expect(controller.visualBench, isEmpty);
    expect(_visibleVisualPlayerKeys(controller), activePlayerKeys);

    await controller.saveVisualLineup();
    await tester.pumpAndSettle();
    expect(controller.visualPlayerCount.value, 11);
    expect(controller.visualSlots.where((slot) => !slot.isEmpty), hasLength(8));
    expect(_visibleVisualPlayerKeys(controller), activePlayerKeys);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('formation tab places a tapped bench player on first pitch tap', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.text('خطة الفريق'));
    await tester.pumpAndSettle();

    final controller = Get.find<TeamRosterController>();
    final guest = controller.allVisualPlayers.firstWhere(
      (candidate) => candidate.name == 'Mahmoud Ali',
    );
    final targetSlot = controller.visualSlots.first;
    final benchPlayerFinder = find.byKey(ValueKey('bench-player-${guest.key}'));
    final targetSlotFinder = find.byKey(
      ValueKey('lineup-slot-${targetSlot.id}'),
    );
    final formationScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('team-roster-formation-list-view')),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      benchPlayerFinder,
      500,
      scrollable: formationScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(benchPlayerFinder);
    await tester.pumpAndSettle();

    expect(find.text('مختار'), findsOneWidget);
    expect(controller.selectedVisualPlayerName, 'Mahmoud Ali');

    await tester.scrollUntilVisible(
      find.text('مختار: Mahmoud Ali'),
      -500,
      scrollable: formationScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('مختار: Mahmoud Ali'), findsOneWidget);
    expect(find.text('اختر خانة للنقل أو التبديل'), findsOneWidget);

    await tester.scrollUntilVisible(
      targetSlotFinder,
      -500,
      scrollable: formationScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(targetSlotFinder);
    await tester.pumpAndSettle();

    expect(
      controller.visualSlots.any((slot) => slot.occupantKey == guest.key),
      isTrue,
    );
    expect(controller.selectedVisualPlayerKey, isNull);
    expect(find.text('مختار'), findsNothing);
    expect(find.text('مختار: Mahmoud Ali'), findsNothing);
  });

  testWidgets('dragging a bench player removes the bench card before saving', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 2800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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

    await tester.tap(find.text('خطة الفريق'));
    await tester.pumpAndSettle();

    final controller = Get.find<TeamRosterController>();
    final player = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Mahmoud Ali',
    );
    final targetSlot = controller.visualSlots.first;
    final benchCard = find.byKey(ValueKey('bench-player-${player.key}'));
    final pitchTarget = find.byKey(ValueKey('lineup-slot-${targetSlot.id}'));
    expect(benchCard, findsOneWidget);
    expect(pitchTarget, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(benchCard));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(pitchTarget));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    final pitchKeys = controller.visualSlots
        .map((slot) => slot.occupantKey)
        .whereType<String>()
        .toSet();
    final benchKeys = controller.visualBench
        .map((candidate) => candidate.key)
        .toSet();
    final activeKeys = controller.allVisualPlayers
        .map((candidate) => candidate.key)
        .toSet();

    expect(pitchKeys, contains(player.key));
    expect(benchKeys, isNot(contains(player.key)));
    expect(pitchKeys.intersection(benchKeys), isEmpty);
    expect(pitchKeys.length + benchKeys.length, activeKeys.length);
    expect(find.byKey(ValueKey('bench-player-${player.key}')), findsNothing);
    expect(controller.isLineupDirty.value, isTrue);
  });

  testWidgets('lineup tap-select mode swaps occupied slots without dragging', (
    WidgetTester tester,
  ) async {
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
    final registered = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Ahmed Salem',
    );
    final guest = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Mahmoud Ali',
    );
    final firstSlot = controller.visualSlots[0];
    final secondSlot = controller.visualSlots[1];

    controller.assignPlayerToVisualSlot(registered, firstSlot);
    controller.assignPlayerToVisualSlot(guest, secondSlot);
    controller.selectVisualPlayer(registered, sourceSlotId: firstSlot.id);

    final moved = controller.moveSelectedVisualPlayerToSlot(secondSlot);

    expect(moved, isTrue);
    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == secondSlot.id)
          .occupantKey,
      registered.key,
    );
    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == firstSlot.id)
          .occupantKey,
      guest.key,
    );
    expect(controller.selectedVisualPlayerKey, isNull);
    expect(controller.isLineupDirty.value, isTrue);
  });

  testWidgets('lineup bench action removes starter and returns him to bench', (
    WidgetTester tester,
  ) async {
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
    final player = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Ahmed Salem',
    );
    final targetSlot = controller.visualSlots.first;

    controller.assignPlayerToVisualSlot(player, targetSlot);
    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == targetSlot.id)
          .occupantKey,
      player.key,
    );
    expect(
      controller.visualBench.map((candidate) => candidate.key),
      isNot(contains(player.key)),
    );

    controller.movePlayerToVisualBench(player);

    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == targetSlot.id)
          .occupantKey,
      isNull,
    );
    expect(
      controller.visualBench.map((candidate) => candidate.key),
      contains(player.key),
    );
    expect(controller.selectedVisualPlayerKey, isNull);
    expect(controller.isLineupDirty.value, isTrue);
  });

  testWidgets('lineup tap-select mode moves pitch player to bench target', (
    WidgetTester tester,
  ) async {
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
    final player = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Ahmed Salem',
    );
    final targetSlot = controller.visualSlots.first;

    controller.assignPlayerToVisualSlot(player, targetSlot);
    controller.selectVisualPlayer(player, sourceSlotId: targetSlot.id);

    expect(controller.selectedVisualPlayerCanMoveToBench, isTrue);

    final moved = controller.moveSelectedVisualPlayerToBench();

    expect(moved, isTrue);
    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == targetSlot.id)
          .occupantKey,
      isNull,
    );
    expect(
      controller.visualBench.map((candidate) => candidate.key),
      contains(player.key),
    );
    expect(controller.selectedVisualPlayerKey, isNull);
    expect(controller.isLineupDirty.value, isTrue);
  });

  testWidgets('lineup tap-select mode replaces starter with bench player', (
    WidgetTester tester,
  ) async {
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
    final starter = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Ahmed Salem',
    );
    final benchPlayer = controller.visualBench.firstWhere(
      (candidate) => candidate.name == 'Mahmoud Ali',
    );
    final targetSlot = controller.visualSlots.first;

    controller.assignPlayerToVisualSlot(starter, targetSlot);
    controller.selectVisualPlayer(benchPlayer);

    expect(controller.selectedVisualPlayerKey, benchPlayer.key);

    final moved = controller.moveSelectedVisualPlayerToSlot(targetSlot);

    expect(moved, isTrue);
    expect(
      controller.visualSlots
          .firstWhere((slot) => slot.id == targetSlot.id)
          .occupantKey,
      benchPlayer.key,
    );
    expect(
      controller.visualBench.map((player) => player.key),
      contains(starter.key),
    );
    expect(controller.selectedVisualPlayerKey, isNull);
    expect(controller.isLineupDirty.value, isTrue);
  });

  testWidgets('manager can share a guest player claim link', (
    WidgetTester tester,
  ) async {
    final fakeShareLinkService = _RecordingShareLinkService(
      claimCodeRepository: ClaimCodeRepositoryImpl(firestore: firestore),
      teamRepository: teamRepository,
      guestPlayerRepository: guestPlayerRepository,
      guestTeamRepository: GuestTeamRepositoryImpl(firestore: firestore),
    );
    final sharedTexts = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: fakeShareLinkService,
        shareText: (text) async => sharedTexts.add(text),
      ),
    );
    await tester.pumpAndSettle();

    final rosterScrollable = find.descendant(
      of: find.byKey(const ValueKey('team-roster-list-view')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
      500,
      scrollable: rosterScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('مشاركة رابط الاستلام'), findsOneWidget);

    await tester.tap(find.text('مشاركة رابط الاستلام'));
    await tester.pumpAndSettle();

    expect(fakeShareLinkService.guestPlayerClaimCalls, 1);
    expect(fakeShareLinkService.lastGuestPlayerId, 'guest-1');
    expect(fakeShareLinkService.lastActorId, 'owner-1');
    expect(sharedTexts, hasLength(1));
    expect(sharedTexts.single, contains('استلم مكانك كلاعب داخل EL7REEF'));
    expect(find.textContaining('CLAIM-CODE-1'), findsNothing);
  });

  testWidgets(
    'claimed guest player shows linked info without active resend action',
    (WidgetTester tester) async {
      final guest = await guestPlayerRepository.getGuestPlayer('guest-1');
      await guestPlayerRepository.updateGuestPlayer(
        guest!.copyWith(
          claimStatus: GuestClaimStatus.claimed,
          linkedPlayerId: 'player-claimed',
        ),
      );

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

      final rosterScrollable = find.descendant(
        of: find.byKey(const ValueKey('team-roster-list-view')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
        500,
        scrollable: rosterScrollable,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('تم ربط هذا الضيف بالفعل ببروفايل لاعب مسجل.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('مشاركة رابط الاستلام'), findsNothing);
    },
  );

  testWidgets('unauthorized viewer does not see guest claim resend action', (
    WidgetTester tester,
  ) async {
    final viewerSession = _FakeAuthSession(
      currentUserId: 'viewer-1',
      currentPlayer: Player(
        id: 'viewer-1',
        name: 'Viewer One',
        createdAt: DateTime(2026, 4, 16, 10),
        lastActiveAt: DateTime(2026, 4, 16, 10),
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        authSession: viewerSession,
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
    expect(controller.canManageRoster, isFalse);
    expect(
      controller.rosterMembers.any(
        (entry) => entry.displayName == 'Mahmoud Ali',
      ),
      isTrue,
    );
    expect(find.text('مشاركة رابط الاستلام'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('guest claim link generation failure shows safe Arabic error', (
    WidgetTester tester,
  ) async {
    final fakeShareLinkService = _RecordingShareLinkService(
      shouldThrow: true,
      claimCodeRepository: ClaimCodeRepositoryImpl(firestore: firestore),
      teamRepository: teamRepository,
      guestPlayerRepository: guestPlayerRepository,
      guestTeamRepository: GuestTeamRepositoryImpl(firestore: firestore),
    );

    await tester.pumpWidget(
      _buildTestApp(
        authSession: authSession,
        teamRepository: teamRepository,
        teamRosterService: teamRosterService,
        teamFormationService: teamFormationService,
        playerRepository: playerRepository,
        guestPlayerRepository: guestPlayerRepository,
        shareLinkService: fakeShareLinkService,
        shareText: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    final rosterScrollable = find.descendant(
      of: find.byKey(const ValueKey('team-roster-list-view')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
      500,
      scrollable: rosterScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('team-roster-member-actions-guest-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاركة رابط الاستلام'));
    await tester.pumpAndSettle();

    expect(fakeShareLinkService.guestPlayerClaimCalls, 1);
    expect(
      find.text(
        'تعذر إنشاء رابط الاستلام الآن. تأكد من الصلاحيات وحاول مرة أخرى.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('raw claim failure'), findsNothing);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}

Set<String> _visibleVisualPlayerKeys(TeamRosterController controller) {
  return {
    ...controller.visualSlots
        .map((slot) => slot.occupantKey)
        .whereType<String>(),
    ...controller.visualBench.map((player) => player.key),
  };
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
  TeamRosterShareText? shareText,
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
                shareText: shareText,
              ),
            );
          }
        }),
      ),
    ],
  );
}

class _RecordingShareLinkService extends ShareLinkService {
  final bool shouldThrow;

  int guestPlayerClaimCalls = 0;
  String? lastGuestPlayerId;
  String? lastActorId;

  _RecordingShareLinkService({
    this.shouldThrow = false,
    required ClaimCodeRepository claimCodeRepository,
    required TeamRepository teamRepository,
    required GuestPlayerRepository guestPlayerRepository,
    required GuestTeamRepository guestTeamRepository,
  }) : super(
         claimCodeRepository: claimCodeRepository,
         teamRepository: teamRepository,
         guestPlayerRepository: guestPlayerRepository,
         guestTeamRepository: guestTeamRepository,
       );

  @override
  Future<GeneratedShareLink> createGuestPlayerClaimLink({
    required String guestPlayerId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = false,
  }) async {
    guestPlayerClaimCalls += 1;
    lastGuestPlayerId = guestPlayerId;
    lastActorId = actorId;
    if (shouldThrow) {
      throw StateError('raw claim failure');
    }

    final now = DateTime(2026, 4, 16, 13);
    final claimCode = ClaimCode(
      code: 'CLAIM-CODE-1',
      targetType: ClaimTargetType.guestPlayer,
      targetId: guestPlayerId,
      scope: ClaimPayloadScope.team,
      teamId: 'team-1',
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(ttl),
      requiresApproval: requiresApproval,
    );
    final payload = claimCode.toPayload();
    final webUri = Uri(
      scheme: 'https',
      host: ShareLinkService.webHost,
      path: '/claim',
      queryParameters: payload.toQueryParameters(),
    );

    return GeneratedShareLink(
      claimCode: claimCode,
      payload: payload,
      appUri: Uri(
        scheme: ShareLinkService.appScheme,
        host: 'claim',
        queryParameters: payload.toQueryParameters(),
      ),
      webUri: webUri,
      qrData: webUri.toString(),
      shareText: 'استلم مكانك كلاعب داخل EL7REEF\n${webUri.toString()}',
      whatsappText: 'استلم مكانك كلاعب داخل EL7REEF\n${webUri.toString()}',
    );
  }
}
