import '../entities/knockout_tie.dart';

abstract class KnockoutTieRepository {
  Future<KnockoutTie?> getTie(String tieId);
  Future<void> createTie(KnockoutTie tie);
  Future<void> updateTie(KnockoutTie tie);
  Future<List<KnockoutTie>> getBracketTies(String bracketId);
}
