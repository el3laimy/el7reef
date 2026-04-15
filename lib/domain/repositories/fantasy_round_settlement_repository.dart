import '../entities/fantasy_round_settlement_marker.dart';

abstract class FantasyRoundSettlementRepository {
  Future<FantasyRoundSettlementMarker?> getSettlementMarker({
    required String leagueId,
    required int gameweek,
    required String settlementType,
  });

  Future<void> saveSettlementMarker(FantasyRoundSettlementMarker marker);
}
