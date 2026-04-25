import '../../../domain/entities/match.dart';
import '../../../domain/entities/team.dart';

class FriendlyMatchSideView {
  final String sideKey;
  final String displayName;
  final String? officialTeamId;
  final List<String> playerIds;
  final bool canEditName;

  const FriendlyMatchSideView({
    required this.sideKey,
    required this.displayName,
    required this.officialTeamId,
    required this.playerIds,
    this.canEditName = false,
  });

  int get playerCount => playerIds.length;
  bool get isOfficialTeam =>
      officialTeamId != null && officialTeamId!.isNotEmpty;
  bool get isTemporarySide => !isOfficialTeam;
  bool get canOpenOfficialLineup => isOfficialTeam;

  static List<FriendlyMatchSideView> fromMatch({
    required Match match,
    Map<String, Team> teamsById = const {},
  }) {
    return [
      FriendlyMatchSideView(
        sideKey: 'A',
        displayName: _displayNameForSide(
          fallback: 'فريق A',
          teamId: match.teamAId,
          teamsById: teamsById,
        ),
        officialTeamId: _nonEmpty(match.teamAId),
        playerIds: List<String>.unmodifiable(match.teamAPlayerIds),
      ),
      FriendlyMatchSideView(
        sideKey: 'B',
        displayName: _displayNameForSide(
          fallback: 'فريق B',
          teamId: match.teamBId,
          teamsById: teamsById,
        ),
        officialTeamId: _nonEmpty(match.teamBId),
        playerIds: List<String>.unmodifiable(match.teamBPlayerIds),
      ),
    ];
  }

  static String _displayNameForSide({
    required String fallback,
    required String? teamId,
    required Map<String, Team> teamsById,
  }) {
    final normalizedTeamId = _nonEmpty(teamId);
    if (normalizedTeamId == null) return fallback;
    final teamName = teamsById[normalizedTeamId]?.name.trim();
    if (teamName == null || teamName.isEmpty) return fallback;
    return teamName;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
