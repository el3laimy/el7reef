import '../entities/tournament_assistant_permission.dart';

abstract class TournamentAssistantPermissionRepository {
  Future<TournamentAssistantPermission?> getAssistantPermission(
    String tournamentId,
    String userId,
  );

  Future<List<TournamentAssistantPermission>> listTournamentAssistants(
    String tournamentId,
  );

  Future<void> createAssistantPermission(
    TournamentAssistantPermission permission,
  );

  Future<void> updateAssistantPermissions({
    required String tournamentId,
    required String userId,
    required TournamentAssistantPermissionPreset preset,
    required Map<TournamentAssistantPermissionKey, bool> permissions,
    required DateTime updatedAt,
  });

  Future<void> revokeAssistant({
    required String tournamentId,
    required String userId,
    required DateTime revokedAt,
  });
}
