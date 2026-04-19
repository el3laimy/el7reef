import '../entities/tournament_group.dart';

abstract class TournamentGroupRepository {
  Future<TournamentGroup?> getGroup(String groupId);
  Future<void> createGroup(TournamentGroup group);
  Future<void> updateGroup(TournamentGroup group);
  Future<List<TournamentGroup>> getTournamentGroups(
    String tournamentId, {
    String? groupStageId,
  });
}
