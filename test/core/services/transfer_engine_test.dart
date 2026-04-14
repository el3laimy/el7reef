import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/transfer_engine.dart';
import 'package:el7reef/domain/entities/fantasy_slot.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';
import 'package:el7reef/domain/entities/player_fantasy_value.dart';
import 'package:el7reef/domain/entities/transfer_record.dart';
import 'package:el7reef/domain/repositories/fantasy_repository.dart';

void main() {
  group('TransferEngine', () {
    test('uses a free transfer before applying any points hit', () async {
      final repository = _FakeFantasyRepository();
      final engine = TransferEngine(repository);

      await engine.executeTransfer(
        currentTeam: _buildTeam(
          budget: 10,
          freeTransfers: 1,
          totalTransfers: 2,
          totalPoints: 50,
        ),
        slotToReplace: _buildSlot(playerId: 'player-out'),
        playerOutValue: _buildValue('player-out', price: 7),
        playerInValue: _buildValue('player-in', price: 8.5),
        fullTeamValues: [
          _buildValue('player-out', price: 7),
          _buildValue('player-2', price: 6),
        ],
        currentGameweek: 3,
      );

      expect(repository.updatedTeam, isNotNull);
      expect(repository.updatedTeam!.budget, 8.5);
      expect(repository.updatedTeam!.freeTransfers, 0);
      expect(repository.updatedTeam!.totalTransfers, 3);
      expect(repository.updatedTeam!.totalPoints, 50);
      expect(repository.record, isNotNull);
      expect(repository.record!.cost, 0);
      expect(repository.record!.gameweek, 3);
      expect(repository.updatedSlots.single.playerId, 'player-in');
      expect(repository.updatedSlots.single.pointsEarned, 0);
    });

    test('applies a -4 hit when no free transfers remain', () async {
      final repository = _FakeFantasyRepository();
      final engine = TransferEngine(repository);

      await engine.executeTransfer(
        currentTeam: _buildTeam(
          budget: 9,
          freeTransfers: 0,
          totalPoints: 50,
        ),
        slotToReplace: _buildSlot(playerId: 'player-out'),
        playerOutValue: _buildValue('player-out', price: 6),
        playerInValue: _buildValue('player-in', price: 8),
        fullTeamValues: [
          _buildValue('player-out', price: 6),
          _buildValue('player-2', price: 5),
        ],
        currentGameweek: 4,
      );

      expect(repository.updatedTeam, isNotNull);
      expect(repository.updatedTeam!.freeTransfers, 0);
      expect(repository.updatedTeam!.totalPoints, 46);
      expect(repository.record!.cost, -4);
    });

    test('treats wildcard variants as free extra transfers', () async {
      final repository = _FakeFantasyRepository();
      final engine = TransferEngine(repository);

      await engine.executeTransfer(
        currentTeam: _buildTeam(
          budget: 11,
          freeTransfers: 0,
          totalPoints: 72,
          activeChips: const ['Wildcard (Knockout)'],
        ),
        slotToReplace: _buildSlot(playerId: 'player-out'),
        playerOutValue: _buildValue('player-out', price: 7.5),
        playerInValue: _buildValue('player-in', price: 9.5),
        fullTeamValues: [
          _buildValue('player-out', price: 7.5),
          _buildValue('player-2', price: 5),
        ],
        currentGameweek: 5,
      );

      expect(repository.updatedTeam, isNotNull);
      expect(repository.updatedTeam!.totalPoints, 72);
      expect(repository.record!.cost, 0);
      expect(repository.updatedTeam!.freeTransfers, 0);
    });
  });
}

FantasyTeam _buildTeam({
  required double budget,
  required int freeTransfers,
  int totalTransfers = 0,
  int totalPoints = 0,
  List<String> activeChips = const [],
}) {
  final now = DateTime(2026, 4, 14);
  return FantasyTeam(
    id: 'team-1',
    ownerPlayerId: 'owner-1',
    teamName: 'Team One',
    budget: budget,
    freeTransfers: freeTransfers,
    totalTransfers: totalTransfers,
    totalPoints: totalPoints,
    activeChips: activeChips,
    createdAt: now,
    updatedAt: now,
  );
}

FantasySlot _buildSlot({required String playerId}) {
  return FantasySlot(
    id: 'slot-1',
    fantasyTeamId: 'team-1',
    playerId: playerId,
    isStartingXI: true,
  );
}

PlayerFantasyValue _buildValue(String playerId, {required double price}) {
  return PlayerFantasyValue(
    playerId: playerId,
    currentPrice: price,
    tier: PlayerTier.bronze,
  );
}

class _FakeFantasyRepository implements FantasyRepository {
  FantasyTeam? updatedTeam;
  TransferRecord? record;
  List<FantasySlot> updatedSlots = const [];

  @override
  Future<void> processTransfer(
    FantasyTeam team,
    TransferRecord transferRecord,
    List<FantasySlot> slots,
  ) async {
    updatedTeam = team;
    record = transferRecord;
    updatedSlots = List<FantasySlot>.from(slots);
  }

  @override
  Future<void> createFantasyTeam(
    FantasyTeam team,
    List<FantasySlot> slots,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<FantasyTeam?> getFantasyTeam(String ownerPlayerId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FantasyTeam>> getLeagueLeaderboard(
    String leagueId, {
    int limit = 50,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PlayerFantasyValue?> getPlayerFantasyValue(String playerId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<PlayerFantasyValue>> getMarketValues({int limit = 100}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FantasySlot>> getTeamSlots(String fantasyTeamId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<TransferRecord>> getTeamTransfers(String fantasyTeamId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateFantasySlot(FantasySlot slot) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateFantasyTeam(FantasyTeam team) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlayerFantasyValue(PlayerFantasyValue value) async {
    throw UnimplementedError();
  }
}
