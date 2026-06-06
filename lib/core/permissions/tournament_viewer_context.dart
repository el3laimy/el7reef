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
  final bool participates;
  final bool follows;
  final bool teamCaptain;
  final bool hasRegistrationRequest;
  final TournamentAssistantPermission? assistantPermission;

  const TournamentViewerContext({
    required this.userId,
    required this.tournamentId,
    required this.role,
    this.participates = false,
    this.follows = false,
    this.teamCaptain = false,
    this.hasRegistrationRequest = false,
    this.assistantPermission,
  });

  factory TournamentViewerContext.fromTournament({
    required Tournament tournament,
    required String? userId,
    TournamentAssistantPermission? assistantPermission,
    bool isParticipant = false,
    bool isFollower = false,
    bool isTeamCaptain = false,
    bool hasRegistrationRequest = false,
  }) {
    final actorId = userId?.trim();
    if (actorId != null && actorId.isNotEmpty) {
      if (tournament.organizerId == actorId) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.organizer,
          assistantPermission: assistantPermission,
        );
      }
      if (assistantPermission?.userId == actorId &&
          assistantPermission?.tournamentId == tournament.id &&
          assistantPermission?.isActive == true) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.assistant,
          participates: isParticipant,
          follows: isFollower,
          teamCaptain: isTeamCaptain,
          hasRegistrationRequest: hasRegistrationRequest,
          assistantPermission: assistantPermission,
        );
      }
      if (isParticipant || isTeamCaptain) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.participant,
          participates: true,
          follows: isFollower,
          teamCaptain: isTeamCaptain,
          hasRegistrationRequest: hasRegistrationRequest,
          assistantPermission: assistantPermission,
        );
      }
      if (isFollower) {
        return TournamentViewerContext(
          userId: actorId,
          tournamentId: tournament.id,
          role: TournamentViewerRole.follower,
          follows: true,
          hasRegistrationRequest: hasRegistrationRequest,
          assistantPermission: assistantPermission,
        );
      }
    }
    return TournamentViewerContext(
      userId: actorId,
      tournamentId: tournament.id,
      role: TournamentViewerRole.viewer,
      hasRegistrationRequest: hasRegistrationRequest,
      assistantPermission: assistantPermission,
    );
  }

  bool get isOrganizer => role == TournamentViewerRole.organizer;
  bool get isAssistant => role == TournamentViewerRole.assistant;
  bool get isParticipant => role == TournamentViewerRole.participant;
  bool get isFollower => role == TournamentViewerRole.follower;
  bool get isTeamCaptain => teamCaptain;
  bool get canViewAdminDashboard => isOrganizer;
  bool get canManageTournament => isOrganizer;
  bool get canManageRegistrations => isOrganizer;
  bool get canPublishFixtures => isOrganizer;
  bool get canSubmitResults =>
      isOrganizer ||
      _hasAssistantPermission(
        TournamentAssistantPermissionKey.canSubmitScore,
      ) ||
      _hasAssistantPermission(
        TournamentAssistantPermissionKey.canRecordGoalsAndMvp,
      );
  bool get canManageAssistants => isOrganizer;
  bool get canFollowTournament =>
      userId != null && !isOrganizer && !isParticipant;

  bool _hasAssistantPermission(TournamentAssistantPermissionKey permission) {
    return isAssistant &&
        assistantPermission != null &&
        assistantPermission!.hasPermission(permission);
  }
}
