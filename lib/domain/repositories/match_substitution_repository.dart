import '../entities/match_substitution.dart';

abstract class MatchSubstitutionRepository {
  Future<MatchSubstitution?> getSubstitution(String substitutionId);
  Future<void> createSubstitution(MatchSubstitution substitution);
  Future<List<MatchSubstitution>> getMatchSubstitutions(String matchId);
  Future<List<MatchSubstitution>> getTeamSubstitutions({
    required String matchId,
    String? teamId,
    String? guestTeamId,
  });
}
