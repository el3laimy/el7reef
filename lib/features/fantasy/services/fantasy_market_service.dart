import '../../../data/repositories/fantasy_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/player_fantasy_value.dart';
import '../../../domain/repositories/fantasy_repository.dart';
import '../../../domain/repositories/player_repository.dart';
import '../../../features/fantasy/presentation/models/fantasy_market_player.dart';

class FantasyMarketService {
  final FantasyRepository _fantasyRepository;
  final PlayerRepository _playerRepository;

  FantasyMarketService({
    FantasyRepository? fantasyRepository,
    PlayerRepository? playerRepository,
  })  : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
        _playerRepository = playerRepository ?? PlayerRepositoryImpl();

  Future<List<FantasyMarketPlayer>> getMarketPlayers({
    int limit = 80,
  }) async {
    final storedValues = await _fantasyRepository.getMarketValues(limit: limit);
    if (storedValues.isNotEmpty) {
      final result = await Future.wait(
        storedValues.map((value) async {
          final player = await _playerRepository.getPlayer(value.playerId);
          if (player == null) {
            return null;
          }
          return FantasyMarketPlayer(player: player, value: value);
        }),
      );

      return result.whereType<FantasyMarketPlayer>().toList();
    }

    final fallbackPlayers = await _playerRepository.getLeaderboard(limit: limit);
    return fallbackPlayers
        .where((player) => player.position != null && player.position!.isNotEmpty)
        .map(
          (player) => FantasyMarketPlayer(
            player: player,
            value: _deriveValueFromPlayer(player),
          ),
        )
        .toList();
  }

  PlayerFantasyValue _deriveValueFromPlayer(Player player) {
    final totalFantasyPoints = (player.rating / 10).round() + (player.mvpCount * 4);
    final price = (4 + (player.rating / 250)).clamp(4.0, 12.0);
    final tier = totalFantasyPoints >= 200
        ? PlayerTier.gold
        : totalFantasyPoints >= 150
            ? PlayerTier.silver
            : PlayerTier.bronze;

    return PlayerFantasyValue(
      playerId: player.id,
      currentPrice: double.parse(price.toStringAsFixed(1)),
      ownershipPct: 0,
      netPriceChangeWeek: 0,
      tier: tier,
      totalFantasyPoints: totalFantasyPoints,
    );
  }
}
