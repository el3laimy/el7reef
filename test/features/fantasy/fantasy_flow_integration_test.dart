import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/core/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/core/services/fantasy_market_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/player_fantasy_value.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/fantasy_create_team_controller.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/fantasy_leaderboard_controller.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/fantasy_team_controller.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/transfer_market_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets(
      'create team -> team page -> transfer -> leaderboard works with fake data',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));

    final firestore = FakeFirebaseFirestore();
    final lifecycleRepository = FantasyLifecycleRepositoryImpl(db: firestore);
    final fantasyRepository = FantasyRepositoryImpl(db: firestore);
    final playerRepository = PlayerRepositoryImpl(firestore: firestore);
    final tournamentRepository = TournamentRepositoryImpl(db: firestore);
    final lifecycleService = FantasyLifecycleService(
      lifecycleRepository: lifecycleRepository,
      tournamentRepository: tournamentRepository,
    );
    final marketService = FantasyMarketService(
      fantasyRepository: fantasyRepository,
      playerRepository: playerRepository,
    );
    final session = _FakeAuthSession(
      userId: 'owner-1',
      player: Player(
        id: 'owner-1',
        name: 'Ahmed',
        position: 'MID',
        createdAt: DateTime(2026, 4, 15, 12),
        lastActiveAt: DateTime(2026, 4, 15, 12),
      ),
    );

    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'owner-1', name: 'Ahmed', position: 'MID', price: 6);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-gk', name: 'GK', position: 'GK', price: 4);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-def', name: 'DEF', position: 'DEF', price: 4.5);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-mid-1', name: 'MID1', position: 'MID', price: 5.5);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-mid-2', name: 'MID2', position: 'MID', price: 5);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-fwd', name: 'FWD', position: 'FWD', price: 6.5);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-bench-1', name: 'Bench1', position: 'DEF', price: 4);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-bench-2', name: 'Bench2', position: 'MID', price: 4);
    await _seedPlayer(playerRepository, fantasyRepository,
        id: 'p-replace', name: 'Replace', position: 'MID', price: 5.5);
    await playerRepository.createPlayer(
      Player(
        id: 'owner-2',
        name: 'Ziad',
        position: 'DEF',
        createdAt: DateTime(2026, 4, 15, 12),
        lastActiveAt: DateTime(2026, 4, 15, 12),
      ),
    );

    await lifecycleRepository.saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 1,
        phase: FantasyLeaguePhase.draft,
        isLocked: false,
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
    );

    final createController = FantasyCreateTeamController(
      leagueId: 'global',
      fantasyRepository: fantasyRepository,
      tournamentRepository: tournamentRepository,
      marketService: marketService,
      lifecycleService: lifecycleService,
      authSession: session,
    );
    await createController.loadDraft();

    final playersById = {
      for (final player in createController.marketPlayers) player.player.id: player,
    };
    final draftOrder = [
      'p-gk',
      'p-def',
      'p-mid-1',
      'p-mid-2',
      'p-fwd',
      'p-bench-1',
      'p-bench-2',
    ];
    for (var i = 0; i < draftOrder.length; i++) {
      createController.assignPlayerToSlot(i, playersById[draftOrder[i]]!);
    }
    createController.teamNameController.text = 'Alpha';

    await createController.saveTeam();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();

    final createdTeam = await fantasyRepository.getFantasyTeam('owner-1');
    expect(createdTeam, isNotNull);
    expect(createdTeam!.teamName, 'Alpha');
    expect(createdTeam.leagueIds, contains('global'));
    expect(createdTeam.freeTransfers, 1);
    expect(createdTeam.freeTransfersGameweek, 1);

    final createdSlots = await fantasyRepository.getTeamSlots(createdTeam.id);
    expect(createdSlots.length, 7);

    final teamController = FantasyTeamController(
      leagueId: 'global',
      fantasyRepository: fantasyRepository,
      marketService: marketService,
      lifecycleService: lifecycleService,
      authSession: session,
    );
    await teamController.loadTeam();

    expect(teamController.team.value?.id, 'owner-1');
    expect(teamController.starters.length, 5);
    expect(teamController.bench.length, 2);
    expect(teamController.lifecycle.value?.phase, FantasyLeaguePhase.draft);

    await lifecycleRepository.saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 3,
        phase: FantasyLeaguePhase.transferWindow,
        isLocked: false,
        updatedAt: DateTime(2026, 4, 16, 12),
      ),
    );

    final transferController = TransferMarketController(
      leagueId: 'global',
      fantasyRepository: fantasyRepository,
      tournamentRepository: tournamentRepository,
      marketService: marketService,
      lifecycleService: lifecycleService,
      authSession: session,
    );
    await transferController.loadData();

    expect(transferController.freeTransfers, 2);
    expect(transferController.team.value?.freeTransfersGameweek, 3);

    final memberToReplace = transferController.squad.firstWhere(
      (member) => member.marketPlayer.player.id == 'p-mid-2',
    );
    final replacement = transferController.marketPlayers.firstWhere(
      (player) => player.player.id == 'p-replace',
    );

    await transferController.replacePlayer(
      member: memberToReplace,
      replacement: replacement,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();

    final transfers = await fantasyRepository.getTeamTransfers('owner-1');
    expect(transfers.length, 1);
    expect(transfers.single.gameweek, 3);
    expect(transfers.single.usedFreeTransfer, isTrue);
    expect(transfers.single.hitApplied, isFalse);
    expect(transfers.single.policyPhase, 'global_transferWindow');

    final updatedTeam = await fantasyRepository.getFantasyTeam('owner-1');
    expect(updatedTeam, isNotNull);
    expect(updatedTeam!.freeTransfers, 1);
    expect(updatedTeam.freeTransfersGameweek, 3);

    final updatedSlots = await fantasyRepository.getTeamSlots('owner-1');
    expect(updatedSlots.any((slot) => slot.playerId == 'p-replace'), isTrue);
    expect(updatedSlots.any((slot) => slot.playerId == 'p-mid-2'), isFalse);

    await fantasyRepository.createFantasyTeam(
      FantasyTeam(
        id: 'owner-2',
        ownerPlayerId: 'owner-2',
        teamName: 'Beta',
        leagueIds: const ['global'],
        totalPoints: 12,
        createdAt: DateTime(2026, 4, 15, 12),
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
      const [],
    );

    final leaderboardController = FantasyLeaderboardController(
      leagueId: 'global',
      fantasyRepository: fantasyRepository,
      playerRepository: playerRepository,
      tournamentRepository: tournamentRepository,
      lifecycleService: lifecycleService,
      authSession: session,
    );
    await leaderboardController.loadLeaderboard();

    expect(leaderboardController.entries.length, 2);
    expect(
      leaderboardController.entries.any(
        (entry) => entry.team.id == 'owner-1' && entry.managerName == 'Ahmed',
      ),
      isTrue,
    );
    expect(leaderboardController.isJoinedLeague, isTrue);
    expect(
      leaderboardController.lifecycle.value?.phase,
      FantasyLeaguePhase.transferWindow,
    );

    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}

Future<void> _seedPlayer(
  PlayerRepositoryImpl playerRepository,
  FantasyRepositoryImpl fantasyRepository, {
  required String id,
  required String name,
  required String position,
  required double price,
}) async {
  final now = DateTime(2026, 4, 15, 12);
  await playerRepository.createPlayer(
    Player(
      id: id,
      name: name,
      position: position,
      createdAt: now,
      lastActiveAt: now,
    ),
  );
  await fantasyRepository.updatePlayerFantasyValue(
    PlayerFantasyValue(
      playerId: id,
      currentPrice: price,
      tier: PlayerTier.bronze,
      totalFantasyPoints: 40,
    ),
  );
}

class _FakeAuthSession implements AuthSession {
  @override
  final String? currentUserId;

  @override
  final Player? currentPlayer;

  const _FakeAuthSession({
    required String userId,
    required Player player,
  })  : currentUserId = userId,
        currentPlayer = player;
}
