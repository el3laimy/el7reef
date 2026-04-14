import '../../../../domain/entities/player.dart';
import '../../../../domain/entities/player_fantasy_value.dart';

class FantasyMarketPlayer {
  final Player player;
  final PlayerFantasyValue value;

  const FantasyMarketPlayer({
    required this.player,
    required this.value,
  });

  String get displayName => player.username?.isNotEmpty == true
      ? '@${player.username}'
      : player.name;

  String get positionCode => player.position ?? 'MID';
}
