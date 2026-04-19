import '../entities/knockout_bracket.dart';

abstract class KnockoutBracketRepository {
  Future<KnockoutBracket?> getBracket(String bracketId);
  Future<void> createBracket(KnockoutBracket bracket);
  Future<void> updateBracket(KnockoutBracket bracket);
}
