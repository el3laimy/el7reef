import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/features/fantasy/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/features/fantasy/services/fantasy_market_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_slot.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/player_fantasy_value.dart';
import 'package:el7reef/domain/entities/transfer_record.dart';
import 'package:el7reef/domain/entities/player_match_stats.dart';
import 'package:el7reef/domain/repositories/player_repository.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/fantasy_create_team_controller.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/transfer_market_controller.dart';
import 'package:el7reef/features/fantasy/presentation/models/fantasy_market_player.dart';
import 'package:el7reef/features/fantasy/presentation/models/fantasy_squad_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('locked draft save does not create a fantasy team', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));

    final firestore = FakeFirebaseFirestore();
    final repository = _RecordingFantasyRepository(firestore);
    final lifecycleRepository = FantasyLifecycleRepositoryImpl(firestore: firestore);
    final lifecycleService = FantasyLifecycleService(
      lifecycleRepository: lifecycleRepository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
    );
    await lifecycleRepository.saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 2,
        phase: FantasyLeaguePhase.locked,
        isLocked: true,
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
    );
    final controller = FantasyCreateTeamController(
      leagueId: 'global',
      fantasyRepository: repository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
      marketService: FantasyMarketService(
        fantasyRepository: repository,
        playerRepository: _FakePlayerRepository(),
      ),
      lifecycleService: lifecycleService,
    );

    controller.lifecycle.value = await lifecycleService.resolveLifecycle(
      'global',
    );
    controller.teamNameController.text = 'Locked Team';
    controller.slots.assignAll([
      FantasyDraftSlot(
        key: 'starter_0',
        requiredPosition: 'MID',
        label: 'أساسي 1',
        isStarting: true,
        benchPriority: 0,
        selectedPlayer: _marketPlayer(
          id: 'player-1',
          position: 'MID',
          price: 6,
        ),
      ),
    ]);

    await controller.saveTeam();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(repository.createFantasyTeamCalled, isFalse);
  });

  testWidgets('locked transfer does not process any player swap', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));

    final firestore = FakeFirebaseFirestore();
    final repository = _RecordingFantasyRepository(firestore);
    final lifecycleRepository = FantasyLifecycleRepositoryImpl(firestore: firestore);
    final lifecycleService = FantasyLifecycleService(
      lifecycleRepository: lifecycleRepository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
    );
    await lifecycleRepository.saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 2,
        phase: FantasyLeaguePhase.locked,
        isLocked: true,
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
    );
    final controller = TransferMarketController(
      leagueId: 'global',
      fantasyRepository: repository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
      marketService: FantasyMarketService(
        fantasyRepository: repository,
        playerRepository: _FakePlayerRepository(),
      ),
      lifecycleService: lifecycleService,
    );

    controller.lifecycle.value = await lifecycleService.resolveLifecycle(
      'global',
    );
    controller.team.value = _team(
      budget: 2,
      freeTransfers: 1,
      freeTransfersGameweek: 2,
    );

    final outgoing = _marketPlayer(id: 'player-out', position: 'MID', price: 4);
    final incoming = _marketPlayer(id: 'player-in', position: 'MID', price: 5);
    controller.squad.assignAll([
      FantasySquadMember(
        slot: const FantasySlot(
          id: 'slot-1',
          fantasyTeamId: 'team-1',
          playerId: 'player-out',
          isStartingXI: true,
        ),
        marketPlayer: outgoing,
      ),
    ]);

    await controller.replacePlayer(
      member: controller.squad.single,
      replacement: incoming,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(repository.processTransferCalled, isFalse);
  });

  testWidgets('transfer window allows processing a player swap', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));

    final firestore = FakeFirebaseFirestore();
    final repository = _RecordingFantasyRepository(firestore);
    final lifecycleRepository = FantasyLifecycleRepositoryImpl(firestore: firestore);
    final lifecycleService = FantasyLifecycleService(
      lifecycleRepository: lifecycleRepository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
    );
    await lifecycleRepository.saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 3,
        phase: FantasyLeaguePhase.transferWindow,
        isLocked: false,
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
    );
    final controller = TransferMarketController(
      leagueId: 'global',
      fantasyRepository: repository,
      tournamentRepository: TournamentRepositoryImpl(db: firestore),
      marketService: FantasyMarketService(
        fantasyRepository: repository,
        playerRepository: _FakePlayerRepository(),
      ),
      lifecycleService: lifecycleService,
    );

    controller.lifecycle.value = await lifecycleService.resolveLifecycle(
      'global',
    );
    controller.team.value = _team(
      budget: 2,
      freeTransfers: 1,
      freeTransfersGameweek: 3,
    );

    final outgoing = _marketPlayer(id: 'player-out', position: 'MID', price: 4);
    final incoming = _marketPlayer(id: 'player-in', position: 'MID', price: 5);
    controller.squad.assignAll([
      FantasySquadMember(
        slot: const FantasySlot(
          id: 'slot-1',
          fantasyTeamId: 'team-1',
          playerId: 'player-out',
          isStartingXI: true,
        ),
        marketPlayer: outgoing,
      ),
    ]);

    await controller.replacePlayer(
      member: controller.squad.single,
      replacement: incoming,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(repository.processTransferCalled, isTrue);
    expect(repository.lastProcessedRecord, isNotNull);
    expect(repository.lastProcessedRecord!.gameweek, 3);
    expect(repository.lastProcessedSlots.single.playerId, 'player-in');
  });
}

FantasyTeam _team({
  required double budget,
  required int freeTransfers,
  int freeTransfersGameweek = 1,
}) {
  final now = DateTime(2026, 4, 15, 12);
  return FantasyTeam(
    id: 'team-1',
    ownerPlayerId: 'owner-1',
    teamName: 'My Team',
    budget: budget,
    freeTransfers: freeTransfers,
    freeTransfersGameweek: freeTransfersGameweek,
    createdAt: now,
    updatedAt: now,
  );
}

FantasyMarketPlayer _marketPlayer({
  required String id,
  required String position,
  required double price,
}) {
  final now = DateTime(2026, 4, 15, 12);
  return FantasyMarketPlayer(
    player: Player(
      id: id,
      name: id,
      position: position,
      createdAt: now,
      lastActiveAt: now,
    ),
    value: PlayerFantasyValue(
      playerId: id,
      currentPrice: price,
      tier: PlayerTier.bronze,
    ),
  );
}

class _RecordingFantasyRepository extends FantasyRepositoryImpl {
  bool createFantasyTeamCalled = false;
  bool processTransferCalled = false;
  TransferRecord? lastProcessedRecord;
  List<FantasySlot> lastProcessedSlots = const [];

  _RecordingFantasyRepository(FakeFirebaseFirestore firestore)
    : super(db: firestore);

  @override
  Future<void> createFantasyTeam(
    FantasyTeam team,
    List<FantasySlot> slots,
  ) async {
    createFantasyTeamCalled = true;
  }

  @override
  Future<void> processTransfer(
    FantasyTeam team,
    TransferRecord record,
    List<FantasySlot> updatedSlots,
  ) async {
    processTransferCalled = true;
    lastProcessedRecord = record;
    lastProcessedSlots = List<FantasySlot>.from(updatedSlots);
  }
}

class _FakePlayerRepository implements PlayerRepository {
  @override
  Future<void> createPlayer(Player player) async {}

  @override
  Future<Player?> getPlayer(String playerId) async => null;

  @override
  Future<List<Player>> getPlayersByIds(List<String> playerIds) async =>
      const [];

  @override
  Future<List<Player>> getLeaderboard({int limit = 50}) async => const [];

  @override
  Future<List<Player>> searchPlayers(String query) async => const [];

  @override
  Future<void> updateMatchStats({
    required String playerId,
    required bool isWin,
    required bool isDraw,
    required bool isMvp,
    PlayerMatchStats? detailedStats,
  }) async {}

  @override
  Future<void> updatePlayer(Player player) async {}

  @override
  Future<void> updateRating(String playerId, int newRating) async {}
}
