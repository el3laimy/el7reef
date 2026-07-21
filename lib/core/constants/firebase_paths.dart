/// مسارات مجموعات Firebase Firestore
abstract class FirebasePaths {
  static const String players = 'players';
  static const String guestPlayers = 'guestPlayers';
  static const String teams = 'teams';
  static const String guestTeams = 'guestTeams';
  static const String teamMemberships = 'teamMemberships';
  static const String teamFormationTemplates = 'teamFormationTemplates';
  static const String teamRosterSnapshots = 'teamRosterSnapshots';
  static const String matches = 'matches';
  static const String matchEvents = 'matchEvents';
  static const String matchSides = 'matchSides';
  static const String matchSidePlayers = 'matchSidePlayers';
  static const String matchCheckIns = 'matchCheckIns';
  static const String matchAttendances = 'matchAttendances';
  static const String matchLineupSnapshots = 'matchLineupSnapshots';
  static const String matchSubstitutions = 'matchSubstitutions';
  static const String tournaments = 'tournaments';
  static const String tournamentMemberships = 'tournamentMemberships';
  static const String tournamentRegistrations = 'tournamentRegistrations';
  static const String tournamentParticipants = 'tournamentParticipants';
  static const String publicTournamentRosterEntries =
      'publicTournamentRosterEntries';
  static const String tournamentGroups = 'tournamentGroups';
  static const String groupStandingSnapshots = 'groupStandingSnapshots';
  static const String knockoutBrackets = 'knockoutBrackets';
  static const String knockoutTies = 'knockoutTies';
  static const String claimCodes = 'claimCodes';
  static const String ratingEvents = 'ratingEvents';
  static const String encounterLogs = 'encounterLogs';
  static const String organizerActions = 'organizerActions';
  static const String achievements = 'achievements';
  static const String fantasyLeagues = 'fantasyLeagues';
  static const String fantasyTeams = 'fantasyTeams';
  static const String notifications = 'notifications';
  // Phase 6 — Social
  static const String reservedUsernames = 'reservedUsernames';
  static const String friendships = 'friendships';
  static const String friendRequests = 'friendRequests';
  static const String matchInvitations = 'matchInvitations';
  static const String playerStats = 'player_stats';
  static const String challenges = 'challenges';
  static const String userVotes = 'userVotes'; // Fan voting
  static const String fanVotingSessions = 'fanVotingSessions';
  static const String fantasySlots = 'fantasySlots';
  static const String transferRecords = 'transferRecords';
  static const String playerFantasyValues = 'playerFantasyValues';
  static const String fantasyRoundSettlements = 'fantasyRoundSettlements';
  // Phase 7 — Audit & Disputes
  static const String auditEvents = 'auditEvents';
  static const String disputes = 'disputes';
  static const String analyticsEvents = 'analyticsEvents';
}
