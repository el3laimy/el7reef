import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_assistant_permission.dart';

enum TournamentViewerRole {
  organizer,
  assistant,
  participant,
  follower,
  viewer,
}

class TournamentViewerContext {
  final String? userId;
  final String tournamentId;
  final TournamentViewerRole role;

  const TournamentViewerContext({
    required this.userId,
    required this.tournamentId,
    required this.role,
  });

  factory TournamentViewerContext.fromTournament({
    required Tournament tournament,
    required String? userId,
    TournamentAssistantPermission? assistantPermission,
  }) {
    final actorId = userId?.trim();
    if (actorId != null && actorId.isNotEmpty) {
      if (tournament.organizerId == actorId) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.organizer,
        );
      }
      if (assistantPermission?.userId == actorId &&
          assistantPermission?.tournamentId == tournament.id &&
          assistantPermission?.isActive == true) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.assistant,
        );
      }
    }
    return TournamentViewerContext(
      userId: actorId,
      tournamentId: tournament.id,
      role: TournamentViewerRole.viewer,
    );
  }

  bool get isOrganizer => role == TournamentViewerRole.organizer;
  bool get isAssistant => role == TournamentViewerRole.assistant;
  bool get canViewAdminDashboard => isOrganizer;
  bool get canManageTournament => isOrganizer;
  bool get canManageRegistrations => isOrganizer;
  bool get canPublishFixtures => isOrganizer;
  bool get canSubmitResults => isOrganizer || isAssistant;
  bool get canManageAssistants => isOrganizer;
}
