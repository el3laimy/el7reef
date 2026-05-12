part of 'matchday_service.dart';

class _RegisteredSideContext {
  final Match match;
  final Team team;
  final Tournament? tournament;
  final TournamentRegistration? registration;
  final bool canVerify;

  const _RegisteredSideContext({
    required this.match,
    required this.team,
    required this.tournament,
    required this.registration,
    required this.canVerify,
  });
}

class _GuestSideContext {
  final Match match;
  final GuestTeam guestTeam;
  final Tournament? tournament;
  final TournamentRegistration? registration;
  final bool canVerify;

  const _GuestSideContext({
    required this.match,
    required this.guestTeam,
    required this.tournament,
    required this.registration,
    required this.canVerify,
  });
}

class _SnapshotTransactionResult {
  final MatchdayLineupLockOutcome outcome;
  final MatchLineupSnapshot snapshot;

  const _SnapshotTransactionResult({
    required this.outcome,
    required this.snapshot,
  });
}

abstract class _MatchdayServiceBase {
  final FirebaseFirestore firestore;
  final TournamentPermissionService tournamentPermissionService;
  final TeamRosterPolicy teamRosterPolicy;
  final Uuid uuid;

  _MatchdayServiceBase({
    FirebaseFirestore? firestore,
    TournamentPermissionService? tournamentPermissionService,
    TeamRosterPolicy? teamRosterPolicy,
    Uuid? uuid,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       tournamentPermissionService =
           tournamentPermissionService ?? TournamentPermissionService(),
       teamRosterPolicy = teamRosterPolicy ?? const TeamRosterPolicy(),
       uuid = uuid ?? const Uuid();

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      firestore.collection(FirebasePaths.matches);

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      firestore.collection(FirebasePaths.teams);

  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      firestore.collection(FirebasePaths.guestTeams);

  CollectionReference<Map<String, dynamic>> get _playersRef =>
      firestore.collection(FirebasePaths.players);

  CollectionReference<Map<String, dynamic>> get _guestPlayersRef =>
      firestore.collection(FirebasePaths.guestPlayers);

  CollectionReference<Map<String, dynamic>> get _teamMembershipsRef =>
      firestore.collection(FirebasePaths.teamMemberships);

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      firestore.collection(FirebasePaths.tournaments);

  CollectionReference<Map<String, dynamic>> get _registrationsRef =>
      firestore.collection(FirebasePaths.tournamentRegistrations);

  CollectionReference<Map<String, dynamic>> get _checkInsRef =>
      firestore.collection(FirebasePaths.matchCheckIns);

  CollectionReference<Map<String, dynamic>> get _attendancesRef =>
      firestore.collection(FirebasePaths.matchAttendances);

  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      firestore.collection(FirebasePaths.matchLineupSnapshots);

  CollectionReference<Map<String, dynamic>> get _matchSidesRef =>
      firestore.collection(FirebasePaths.matchSides);

  CollectionReference<Map<String, dynamic>> get _matchSidePlayersRef =>
      firestore.collection(FirebasePaths.matchSidePlayers);

  CollectionReference<Map<String, dynamic>> get _substitutionsRef =>
      firestore.collection(FirebasePaths.matchSubstitutions);

  Future<_RegisteredSideContext> _loadRegisteredContext({
    required String matchId,
    required String teamId,
    required String actorId,
    bool requirePreKickoff = true,
  }) async {
    final match = await _requireMatch(matchId);
    if (requirePreKickoff) {
      _ensureMatchAvailableForPreKickoff(match);
    }

    final team = await _requireTeam(teamId);
    final tournament = await _loadTournamentIfNeeded(match.tournamentId);
    final hasOrganizerLevelAccess = _hasOrganizerLevelAccess(
      match: match,
      tournament: tournament,
      actorId: actorId,
    );

    if (!hasOrganizerLevelAccess &&
        !teamRosterPolicy.canManageRoster(team: team, actorId: actorId)) {
      throw Exception('لا تملك صلاحية إدارة check-in أو lineup لهذا الفريق.');
    }

    final registration = await _loadApprovedRegistrationForTeam(
      tournamentId: match.tournamentId,
      teamId: teamId,
    );
    _assertRegisteredTeamBelongsToMatch(
      match: match,
      teamId: teamId,
      hasApprovedTournamentRegistration: registration != null,
    );

    return _RegisteredSideContext(
      match: match,
      team: team,
      tournament: tournament,
      registration: registration,
      canVerify: hasOrganizerLevelAccess,
    );
  }

  Future<_GuestSideContext> _loadGuestContext({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    bool requirePreKickoff = true,
  }) async {
    final match = await _requireMatch(matchId);
    if (requirePreKickoff) {
      _ensureMatchAvailableForPreKickoff(match);
    }

    final guestTeam = await _requireGuestTeam(guestTeamId);
    final tournament = await _loadTournamentIfNeeded(match.tournamentId);
    final hasOrganizerLevelAccess = _hasOrganizerLevelAccess(
      match: match,
      tournament: tournament,
      actorId: actorId,
    );

    if (!hasOrganizerLevelAccess && guestTeam.creatorId != actorId) {
      throw Exception(
        'لا تملك صلاحية إدارة check-in أو lineup لهذا الفريق الضيف.',
      );
    }

    final registration = await _loadApprovedRegistrationForGuestTeam(
      tournamentId: match.tournamentId,
      guestTeamId: guestTeamId,
    );
    _assertGuestTeamBelongsToMatch(
      match: match,
      hasApprovedTournamentRegistration: registration != null,
    );

    return _GuestSideContext(
      match: match,
      guestTeam: guestTeam,
      tournament: tournament,
      registration: registration,
      canVerify: hasOrganizerLevelAccess,
    );
  }

  Future<MatchSide> _requireMatchSide({
    required String matchId,
    required String matchSideId,
    required String sideKey,
  }) async {
    final snapshot = await _matchSidesRef.doc(matchSideId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('طرف المباراة المؤقت غير موجود.');
    }
    final side = MatchSideModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
    if (side.matchId != matchId || _normalizeSideKey(side.sideKey) != sideKey) {
      throw Exception('طرف المباراة لا يخص هذه المباراة.');
    }
    return side;
  }

  Future<List<MatchSidePlayer>> _loadMatchSidePlayers(
    String matchId,
    String sideKey,
  ) async {
    final snapshot = await _matchSidePlayersRef
        .where('matchId', isEqualTo: matchId)
        .get();
    final normalizedSide = _normalizeSideKey(sideKey);
    return snapshot.docs
        .map(
          (doc) =>
              MatchSidePlayerModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .where(
          (player) => _normalizeSideKey(player.sideKey) == normalizedSide,
        )
        .toList(growable: false);
  }

  void _ensureCanManageMatchSideLineup({
    required Match match,
    required MatchSide side,
    required String actorId,
  }) {
    if (match.organizerId == actorId ||
        side.captainUserId == actorId ||
        side.managedByUserIds.contains(actorId)) {
      return;
    }
    throw Exception('لا تملك صلاحية تعديل تشكيلة هذا الطرف.');
  }

  Future<Match> _requireMatch(String matchId) async {
    final snapshot = await _matchesRef.doc(matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('المباراة المطلوبة غير موجودة.');
    }
    return MatchModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Team> _requireTeam(String teamId) async {
    final snapshot = await _teamsRef.doc(teamId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الفريق المسجل المطلوب غير موجود.');
    }
    return TeamModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<GuestTeam> _requireGuestTeam(String guestTeamId) async {
    final snapshot = await _guestTeamsRef.doc(guestTeamId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الفريق الضيف المطلوب غير موجود.');
    }
    return GuestTeamModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Tournament?> _loadTournamentIfNeeded(String? tournamentId) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الدورة المرتبطة بالمباراة غير موجودة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Tournament?> _loadTournamentForTransaction({
    required Transaction transaction,
    required String? tournamentId,
  }) async {
    if (tournamentId == null || tournamentId.isEmpty) {
      return null;
    }
    final snapshot =
        await transaction.get(_tournamentsRef.doc(tournamentId));
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('الدورة المرتبطة بالمباراة غير موجودة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  void _ensureCanUnlockLineup({
    required Match match,
    required Tournament? tournament,
    required String actorId,
  }) {
    if (tournament != null) {
      if (!tournamentPermissionService.canManageTeams(
        tournament,
        actorId,
      )) {
        throw Exception(
          'فقط منظم أو مشرف البطولة يمكنه فك قفل التشكيلة.',
        );
      }
      return;
    }

    if (match.organizerId != actorId) {
      throw Exception('فقط منظم المباراة يمكنه فك قفل التشكيلة.');
    }
  }

  Future<TournamentRegistration?> _loadApprovedRegistrationForTeam({
    required String? tournamentId,
    required String teamId,
  }) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _registrationsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw Exception(
        'الفريق غير مسجل داخل الدورة المرتبطة بهذه المباراة.',
      );
    }
    final registration = TournamentRegistrationModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
    if (registration.status != TournamentRegistrationStatus.approved) {
      throw Exception(
        'لا يمكن تشغيل matchday لفريق لم يتم اعتماد تسجيله بعد.',
      );
    }
    return registration;
  }

  Future<TournamentRegistration?> _loadApprovedRegistrationForGuestTeam({
    required String? tournamentId,
    required String guestTeamId,
  }) async {
    if (tournamentId == null) {
      return null;
    }
    final snapshot = await _registrationsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw Exception(
        'الفريق الضيف غير مسجل داخل الدورة المرتبطة بهذه المباراة.',
      );
    }
    final registration = TournamentRegistrationModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
    if (registration.status != TournamentRegistrationStatus.approved) {
      throw Exception(
        'لا يمكن تشغيل matchday لفريق ضيف لم يتم اعتماد تسجيله بعد.',
      );
    }
    return registration;
  }

  bool _hasOrganizerLevelAccess({
    required Match match,
    required Tournament? tournament,
    required String actorId,
  }) {
    if (tournament == null) {
      return match.organizerId == actorId;
    }
    if (tournament.organizerId == actorId) {
      return true;
    }
    if (!tournament.assistants.any(
      (assistant) => assistant.userId == actorId,
    )) {
      return false;
    }
    return tournamentPermissionService.canManageTeams(tournament, actorId);
  }

  void _assertRegisteredTeamBelongsToMatch({
    required Match match,
    required String teamId,
    required bool hasApprovedTournamentRegistration,
  }) {
    final assignedTeamIds = <String>[
      if (match.teamAId != null) match.teamAId!,
      if (match.teamBId != null) match.teamBId!,
    ];
    if (assignedTeamIds.contains(teamId)) {
      return;
    }
    if (assignedTeamIds.length >= 2 || !hasApprovedTournamentRegistration) {
      throw Exception('هذا الفريق ليس طرفًا صالحًا في المباراة الحالية.');
    }
  }

  void _assertGuestTeamBelongsToMatch({
    required Match match,
    required bool hasApprovedTournamentRegistration,
  }) {
    final assignedTeamIds = <String>[
      if (match.teamAId != null) match.teamAId!,
      if (match.teamBId != null) match.teamBId!,
    ];
    if (assignedTeamIds.length >= 2) {
      throw Exception(
        'المباراة الحالية لا تترك طرفًا متاحًا لفريق ضيف داخل flow الـ matchday.',
      );
    }
    if (match.tournamentId != null && !hasApprovedTournamentRegistration) {
      throw Exception(
        'الفريق الضيف ليس معتمدًا لهذه المباراة داخل الدورة.',
      );
    }
  }

  void _ensureMatchAvailableForPreKickoff(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception(
        'المباراة مجمّدة ولا يمكن تعديل بيانات matchday لها.',
      );
    }

    if (match.status == MatchStatus.live ||
        match.status == MatchStatus.completed ||
        match.status == MatchStatus.pendingReview ||
        match.status == MatchStatus.ratingWindow ||
        match.status == MatchStatus.settled ||
        match.status == MatchStatus.cancelled) {
      throw Exception(
        'لا يمكن تنفيذ check-in أو lineup lock بعد انطلاق المباراة.',
      );
    }
  }

  void _ensureMatchAvailableForSubstitution(Match match) {
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception('المباراة مجمّدة ولا يمكن تعديل بيانات التبديلات.');
    }

    if (match.status == MatchStatus.completed ||
        match.status == MatchStatus.pendingReview ||
        match.status == MatchStatus.ratingWindow ||
        match.status == MatchStatus.settled ||
        match.status == MatchStatus.cancelled) {
      throw Exception('لا يمكن تسجيل تبديلات بعد انتهاء المباراة.');
    }
  }

  Future<List<TeamMembership>> _loadActiveMemberships(
    String teamId,
  ) async {
    final snapshot = await _teamMembershipsRef
        .where('teamId', isEqualTo: teamId)
        .get();
    final memberships = snapshot.docs
        .map(
          (doc) =>
              TeamMembershipModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .where(
          (membership) =>
              membership.status != TeamMembershipStatus.inactive,
        )
        .toList(growable: true);
    memberships.sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
    return memberships;
  }

  Future<Map<String, Player>> _loadPlayersByIds(
    Set<String> playerIds,
  ) async {
    final result = <String, Player>{};
    for (final playerId in playerIds) {
      final snapshot = await _playersRef.doc(playerId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        continue;
      }
      result[playerId] = PlayerModel.fromJson(
        snapshot.data()!,
        snapshot.id,
      ).toEntity();
    }
    return result;
  }

  Future<Map<String, GuestPlayer>> _loadGuestPlayersByIds(
    Iterable<String> guestPlayerIds,
  ) async {
    final result = <String, GuestPlayer>{};
    for (final guestPlayerId in guestPlayerIds) {
      final snapshot = await _guestPlayersRef.doc(guestPlayerId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        continue;
      }
      result[guestPlayerId] = GuestPlayerModel.fromJson(
        snapshot.data()!,
        snapshot.id,
      ).toEntity();
    }
    return result;
  }

  Future<MatchCheckIn?> _getCheckInByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchCheckInModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchCheckIn?> _getCheckInByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _checkInsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchCheckInModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchLineupSnapshot?> _getSnapshotByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchLineupSnapshotModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchLineupSnapshot?> _getSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return MatchLineupSnapshotModel.fromJson(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    ).toEntity();
  }

  Future<MatchCheckIn> _requireCheckedInTeam({
    required String matchId,
    required String teamId,
  }) async {
    final checkIn =
        await _getCheckInByTeamId(matchId: matchId, teamId: teamId);
    if (checkIn == null || !checkIn.isCheckedIn) {
      throw Exception('يجب تنفيذ check-in للفريق أولاً قبل قفل التشكيل.');
    }
    return checkIn;
  }

  Future<MatchCheckIn> _requireCheckedInGuestTeam({
    required String matchId,
    required String guestTeamId,
  }) async {
    final checkIn = await _getCheckInByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    if (checkIn == null || !checkIn.isCheckedIn) {
      throw Exception(
        'يجب تنفيذ check-in للفريق الضيف أولاً قبل قفل التشكيل.',
      );
    }
    return checkIn;
  }

  Future<MatchLineupSnapshot> _requireSnapshotByTeamId({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot =
        await _getSnapshotByTeamId(matchId: matchId, teamId: teamId);
    if (snapshot == null) {
      throw Exception('يجب قفل التشكيل أولاً قبل تسجيل التبديلات.');
    }
    return snapshot;
  }

  Future<MatchLineupSnapshot> _requireSnapshotByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _getSnapshotByGuestTeamId(
      matchId: matchId,
      guestTeamId: guestTeamId,
    );
    if (snapshot == null) {
      throw Exception(
        'يجب قفل تشكيل الفريق الضيف أولاً قبل تسجيل التبديلات.',
      );
    }
    return snapshot;
  }

  Future<List<MatchAttendance>> _getAttendancesForTeam({
    required String matchId,
    required String teamId,
  }) async {
    final snapshot = await _attendancesRef
        .where('matchId', isEqualTo: matchId)
        .where('teamId', isEqualTo: teamId)
        .get();
    final attendances = snapshot.docs
        .map(
          (doc) =>
              MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    attendances.sort(
      (left, right) => left.createdAt.compareTo(right.createdAt),
    );
    return attendances;
  }

  Future<List<MatchAttendance>> _getAttendancesForGuestTeam({
    required String matchId,
    required String guestTeamId,
  }) async {
    final snapshot = await _attendancesRef
        .where('matchId', isEqualTo: matchId)
        .where('guestTeamId', isEqualTo: guestTeamId)
        .get();
    final attendances = snapshot.docs
        .map(
          (doc) =>
              MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    attendances.sort(
      (left, right) => left.createdAt.compareTo(right.createdAt),
    );
    return attendances;
  }

  MatchAttendanceStatus _defaultAttendanceStatusForMembership(
    TeamMembership membership,
  ) {
    return switch (membership.availability) {
      TeamMemberAvailability.available => MatchAttendanceStatus.present,
      TeamMemberAvailability.pending => MatchAttendanceStatus.pending,
      TeamMemberAvailability.unavailable ||
      TeamMemberAvailability.injured =>
        MatchAttendanceStatus.absent,
    };
  }

  String _registeredCheckInId({
    required String matchId,
    required String teamId,
  }) {
    return 'match::$matchId::team::$teamId::checkin';
  }

  String _guestCheckInId({
    required String matchId,
    required String guestTeamId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::checkin';
  }

  String _registeredAttendanceId({
    required String matchId,
    required String teamId,
    required String membershipId,
  }) {
    return 'match::$matchId::team::$teamId::attendance::$membershipId';
  }

  String _guestAttendanceId({
    required String matchId,
    required String guestTeamId,
    required String guestPlayerId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::attendance::$guestPlayerId';
  }

  String _registeredSnapshotId({
    required String matchId,
    required String teamId,
  }) {
    return 'match::$matchId::team::$teamId::lineup';
  }

  String _guestSnapshotId({
    required String matchId,
    required String guestTeamId,
  }) {
    return 'match::$matchId::guest::$guestTeamId::lineup';
  }

  String _matchSideSnapshotId({
    required String matchId,
    required String matchSideId,
  }) {
    return 'match::$matchId::side::$matchSideId::lineup';
  }

  String _normalizeSideKey(String sideKey) {
    final normalized = sideKey.trim().toUpperCase();
    if (normalized != 'A' && normalized != 'B') {
      throw Exception('طرف المباراة غير صحيح.');
    }
    return normalized;
  }

  void _assertAttendanceEligibleForLineup(MatchAttendance attendance) {
    if (attendance.status == MatchAttendanceStatus.present ||
        attendance.status == MatchAttendanceStatus.late) {
      return;
    }
    throw Exception(
      'لا يمكن قفل التشكيل بلاعبين لم يتم تأكيد حضورهم في matchday.',
    );
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
