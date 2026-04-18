import '../entities/dispute.dart';

/// عقد مستودع النزاعات
abstract class DisputeRepository {
  Future<void> createDispute(Dispute dispute);
  Future<Dispute?> getDispute(String disputeId);
  Future<void> updateDispute(Dispute dispute);
  Future<List<Dispute>> getMatchDisputes(String matchId);
  Future<List<Dispute>> getTournamentDisputes(String tournamentId, {int limit = 50});
  Future<List<Dispute>> getPlayerDisputes(String playerId, {int limit = 20});
}
