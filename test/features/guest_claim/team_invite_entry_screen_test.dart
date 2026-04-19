import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/services/share_link_service.dart';
import 'package:el7reef/core/services/team_invite_service.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_membership_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/generated_share_link.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/features/guest_claim/controllers/team_invite_entry_controller.dart';
import 'package:el7reef/features/guest_claim/views/team_invite_entry_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TeamRepositoryImpl teamRepository;
  late TeamMembershipRepositoryImpl membershipRepository;
  late PlayerRepositoryImpl playerRepository;
  late ClaimCodeRepositoryImpl claimCodeRepository;
  late GuestPlayerRepositoryImpl guestPlayerRepository;
  late GuestTeamRepositoryImpl guestTeamRepository;
  late TeamInviteService teamInviteService;
  late ShareLinkService shareLinkService;
  late GeneratedShareLink inviteLink;
  late DateTime now;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();
    teamRepository = TeamRepositoryImpl(firestore: firestore);
    membershipRepository = TeamMembershipRepositoryImpl(firestore: firestore);
    playerRepository = PlayerRepositoryImpl(firestore: firestore);
    claimCodeRepository = ClaimCodeRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    guestTeamRepository = GuestTeamRepositoryImpl(firestore: firestore);
    teamInviteService = TeamInviteService(
      claimCodeRepository: claimCodeRepository,
      teamRepository: teamRepository,
      membershipRepository: membershipRepository,
      playerRepository: playerRepository,
    );
    shareLinkService = ShareLinkService(
      claimCodeRepository: claimCodeRepository,
      guestPlayerRepository: guestPlayerRepository,
      guestTeamRepository: guestTeamRepository,
      teamRepository: teamRepository,
    );
    now = DateTime(2026, 4, 18, 13);

    await playerRepository.createPlayer(
      Player(
        id: 'owner-1',
        name: 'Captain Blue',
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
        id: 'team-1',
        name: 'Blue Sharks',
        ownerId: 'owner-1',
        playerIds: const ['owner-1'],
        createdAt: now,
      ),
    );

    inviteLink = await shareLinkService.createTeamInviteLink(
      teamId: 'team-1',
      actorId: 'owner-1',
    );
  });

  tearDown(Get.reset);

  testWidgets('logged-in player can accept a team invite from the entry screen',
      (WidgetTester tester) async {
    final authSession = _FakeAuthSession(
      currentUserId: 'player-1',
      currentPlayer: Player(
        id: 'player-1',
        name: 'Mahmoud Salem',
        createdAt: now,
        lastActiveAt: now,
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        authSession: authSession,
        teamInviteService: teamInviteService,
        initialRoute: AppRoutes.inviteEntryWithQuery(
          inviteLink.payload.toQueryParameters(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Sharks'), findsOneWidget);

    await tester.tap(find.text('قبول الدعوة'));
    await tester.pumpAndSettle();

    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    }

    final updatedTeam = await teamRepository.getTeam('team-1');
    final updatedPlayer = await playerRepository.getPlayer('player-1');
    final membership = await membershipRepository.getMembership(
      'team-invite::team-1::player-1',
    );

    expect(find.text('team-profile'), findsOneWidget);
    expect(updatedTeam?.playerIds, contains('player-1'));
    expect(updatedPlayer?.teamIds, contains('team-1'));
    expect(membership?.playerId, 'player-1');
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

Widget _buildApp({
  required AuthSession authSession,
  required TeamInviteService teamInviteService,
  required String initialRoute,
}) {
  return GetMaterialApp(
    initialRoute: initialRoute,
    getPages: [
      GetPage(
        name: AppRoutes.inviteEntry,
        page: () => const TeamInviteEntryScreen(),
        binding: BindingsBuilder(() {
          Get.put<TeamInviteEntryController>(
            TeamInviteEntryController(
              authSession: authSession,
              teamInviteService: teamInviteService,
            ),
          );
        }),
      ),
      GetPage(
        name: AppRoutes.teamProfile,
        page: () => const Scaffold(
          body: Center(child: Text('team-profile')),
        ),
      ),
    ],
  );
}
