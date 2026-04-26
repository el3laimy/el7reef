import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/team.dart';

class FriendlyMatchSideView {
  final String sideKey;
  final String displayName;
  final String? officialTeamId;
  final List<String> playerIds;
  final List<MatchSidePlayer> temporaryPlayers;
  final bool canEditName;

  const FriendlyMatchSideView({
    required this.sideKey,
    required this.displayName,
    required this.officialTeamId,
    required this.playerIds,
    this.temporaryPlayers = const [],
    this.canEditName = false,
  });

  int get registeredCount => playerIds.length;
  int get temporaryCount => temporaryPlayers.length;
  int get playerCount => registeredCount + temporaryCount;
  bool get isOfficialTeam =>
      officialTeamId != null && officialTeamId!.isNotEmpty;
  bool get isTemporarySide => !isOfficialTeam;
  bool get canOpenOfficialLineup => isOfficialTeam;

  static List<FriendlyMatchSideView> fromMatch({
    required Match match,
    Map<String, Team> teamsById = const {},
    List<MatchSide> sides = const [],
    List<MatchSidePlayer> sidePlayers = const [],
  }) {
    return [
      _sideView(
        match: match,
        sideKey: 'A',
        fallbackName: 'فريق A',
        teamId: match.teamAId,
        playerIds: match.teamAPlayerIds,
        teamsById: teamsById,
        sides: sides,
        sidePlayers: sidePlayers,
      ),
      _sideView(
        match: match,
        sideKey: 'B',
        fallbackName: 'فريق B',
        teamId: match.teamBId,
        playerIds: match.teamBPlayerIds,
        teamsById: teamsById,
        sides: sides,
        sidePlayers: sidePlayers,
      ),
    ];
  }

  static FriendlyMatchSideView _sideView({
    required Match match,
    required String sideKey,
    required String fallbackName,
    required String? teamId,
    required List<String> playerIds,
    required Map<String, Team> teamsById,
    required List<MatchSide> sides,
    required List<MatchSidePlayer> sidePlayers,
  }) {
    final storedSide = _storedSideFor(sides, sideKey);
    final officialTeamId = _nonEmpty(teamId);
    return FriendlyMatchSideView(
      sideKey: sideKey,
      displayName: _displayNameForSide(
        fallback: fallbackName,
        teamId: teamId,
        teamsById: teamsById,
        storedSide: storedSide,
      ),
      officialTeamId: officialTeamId,
      playerIds: List<String>.unmodifiable(playerIds),
      temporaryPlayers: List<MatchSidePlayer>.unmodifiable(
        sidePlayers.where(
          (player) => player.sideKey == sideKey && player.isTemporary,
        ),
      ),
      canEditName: match.tournamentId == null && officialTeamId == null,
    );
  }

  static String _displayNameForSide({
    required String fallback,
    required String? teamId,
    required Map<String, Team> teamsById,
    MatchSide? storedSide,
  }) {
    final normalizedTeamId = _nonEmpty(teamId);
    if (normalizedTeamId != null) {
      final teamName = teamsById[normalizedTeamId]?.name.trim();
      if (teamName != null && teamName.isNotEmpty) return teamName;
    }
    final storedName = storedSide?.displayName.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;
    return fallback;
  }

  static MatchSide? _storedSideFor(List<MatchSide> sides, String sideKey) {
    final normalizedSideKey = sideKey.trim().toUpperCase();
    for (final side in sides) {
      if (side.sideKey.trim().toUpperCase() == normalizedSideKey) return side;
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
