import '../../../../domain/entities/fantasy_slot.dart';
import 'fantasy_market_player.dart';

class FantasySquadMember {
  final FantasySlot slot;
  final FantasyMarketPlayer marketPlayer;

  const FantasySquadMember({
    required this.slot,
    required this.marketPlayer,
  });

  bool get isCaptain => slot.role == FantasyPlayerRole.captain;
  bool get isViceCaptain => slot.role == FantasyPlayerRole.viceCaptain;
}
