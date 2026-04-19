/// Route name constants for EL7REEF
abstract class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String playerProfile = '/player/:id';
  static const String teamProfile = '/team/:id';
  static const String createTeam = '/team/create';
  static const String findMatch = '/match/find';
  static const String createMatch = '/match/create';
  static const String matchLobby = '/match/lobby/:id';
  static const String matchDetails = '/match/details/:id';
  static const String rating = '/rating/:matchId';
  static const String mvpVote = '/rating/mvp/:matchId';
  static const String createTournament = '/tournament/create';
  static const String tournamentList = '/tournament/list';
  static const String tournamentDetail = '/tournament/:id';
  static const String tournamentBracket = '/tournament/:id/bracket';
  static const String teamRegistration = '/tournament/:id/register';
  static const String tournamentGuestTeamCreate =
      '/tournament/:id/register/guest-team/create';
  static const String tournamentRegistrationReview =
      '/tournament/:id/register/review/:registrationId';
  static const String organizerDashboard = '/organizer/dashboard/:tournamentId';
  static const String scoreApproval = '/organizer/score/:matchId';
  static const String goldenRating = '/organizer/golden-rating/:matchId';
  static const String fantasyHome = '/fantasy';
  static const String fantasyPickTeam = '/fantasy/pick/:leagueId';
  static const String fantasyTeam = '/fantasy/team/:leagueId';
  static const String fantasyTransfers = '/fantasy/transfers/:leagueId';
  static const String fantasyLeaderboard = '/fantasy/leaderboard/:leagueId';
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';
  // Phase 6 — Social & Identity
  static const String username = '/profile/username';
  static const String qrScanner = '/qr/scan';
  static const String myQrCode = '/profile/qr';
  static const String friends = '/social/friends';
  static const String searchPlayers = '/social/search';
  static const String activityFeed = '/social/feed';
  static const String claimEntry = '/claim';
  static const String inviteEntry = '/invite';
  static const String guestPlayerClaim = '/guest-player/:guestPlayerId/claim';
  static const String guestTeamClaim = '/guest-team/:guestTeamId/claim';
  static const String myTeams = '/teams';
  static const String tournaments = '/tournaments';
  // Phase 7 — Audit & Disputes
  static const String auditTimeline = '/organizer/audit/:entityId';
  static const String disputeViewer = '/organizer/disputes/:matchId';

  static String teamProfileById(String id) => '/team/$id';
  static String tournamentDetailById(String id) => '/tournament/$id';
  static String teamRegistrationForTournament(String tournamentId) =>
      '/tournament/$tournamentId/register';
  static String tournamentGuestTeamCreateForTournament(String tournamentId) =>
      '/tournament/$tournamentId/register/guest-team/create';
  static String tournamentRegistrationReviewForTournament(
    String tournamentId,
    String registrationId,
  ) => '/tournament/$tournamentId/register/review/$registrationId';
  static String organizerDashboardForTournament(String tournamentId) =>
      '/organizer/dashboard/$tournamentId';
  static String scoreApprovalForMatch(String matchId) =>
      '/organizer/score/$matchId';
  static String matchDetailsById(String matchId) => '/match/details/$matchId';
  static String mvpVoteForMatch(String matchId) => '/rating/mvp/$matchId';
  static String fantasyPickTeamForLeague(String leagueId) =>
      '/fantasy/pick/$leagueId';
  static String fantasyTeamForLeague(String leagueId) =>
      '/fantasy/team/$leagueId';
  static String fantasyTransfersForLeague(String leagueId) =>
      '/fantasy/transfers/$leagueId';
  static String fantasyLeaderboardForLeague(String leagueId) =>
      '/fantasy/leaderboard/$leagueId';
  static String auditTimelineForEntity(
    String entityId, {
    String? entityType,
  }) => _withQuery(
        '/organizer/audit/$entityId',
        {'entityType': entityType},
      );
  static String disputeViewerForMatch(String matchId) =>
      '/organizer/disputes/$matchId';

  static String claimEntryWithQuery(Map<String, String?> queryParameters) =>
      _withQuery(claimEntry, queryParameters);

  static String inviteEntryWithQuery(Map<String, String?> queryParameters) =>
      _withQuery(inviteEntry, queryParameters);

  static String guestPlayerClaimById(
    String guestPlayerId, {
    Map<String, String?> queryParameters = const {},
  }) => _withQuery('/guest-player/$guestPlayerId/claim', queryParameters);

  static String guestTeamClaimById(
    String guestTeamId, {
    Map<String, String?> queryParameters = const {},
  }) => _withQuery('/guest-team/$guestTeamId/claim', queryParameters);

  static String _withQuery(
    String path,
    Map<String, String?> queryParameters,
  ) {
    final filtered = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        filtered[entry.key] = value;
      }
    }
    if (filtered.isEmpty) {
      return path;
    }
    return Uri(path: path, queryParameters: filtered).toString();
  }
}
