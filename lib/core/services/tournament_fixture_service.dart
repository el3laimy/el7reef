import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/group_standing_snapshot_model.dart';
import '../../data/models/match_check_in_model.dart';
import '../../data/models/match_lineup_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_group_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_participant_model.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_check_in.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/entities/tournament_participant.dart';
import 'group_stage_builder.dart';
import 'tournament_audit_emitter.dart';
import 'tournament_participant_service.dart';
import 'tournament_permission_service.dart';

class TournamentFixtureService {
  final FirebaseFirestore _firestore;
  final TournamentParticipantService _participantService;
  final GroupStageBuilder _groupStageBuilder;
  final TournamentAuditEmitter _auditEmitter;
  final TournamentPermissionService _permissionService;

  TournamentFixtureService({
    FirebaseFirestore? firestore,
    TournamentParticipantService? participantService,
    GroupStageBuilder? groupStageBuilder,
    TournamentAuditEmitter? auditEmitter,
    TournamentPermissionService? permissionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _participantService =
           participantService ??
           TournamentParticipantService(firestore: firestore),
       _groupStageBuilder = groupStageBuilder ?? const GroupStageBuilder(),
       _auditEmitter =
           auditEmitter ?? TournamentAuditEmitter(firestore: firestore),
       _permissionService = permissionService ?? TournamentPermissionService();

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);
  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _firestore.collection(FirebasePaths.tournamentParticipants);
  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection(FirebasePaths.tournamentGroups);
  CollectionReference<Map<String, dynamic>> get _standingsRef =>
      _firestore.collection(FirebasePaths.groupStandingSnapshots);
  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);
  CollectionReference<Map<String, dynamic>> get _checkInsRef =>
      _firestore.collection(FirebasePaths.matchCheckIns);
  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);

  Future<Match> scheduleFixture({
    required String matchId,
    required String actorId,
    required DateTime scheduledAt,
    String? venueId,
  }) async {
    final match = await _loadMatch(matchId);
    final tournamentId = match.tournamentId;
    if (tournamentId == null || tournamentId.isEmpty) {
      throw Exception('لا يمكن جدولة مباراة ليست جزءًا من بطولة.');
    }
    if (match.isOfficialTournamentResult) {
      throw Exception('لا يمكن جدولة fixture بعد اعتماد نتيجتها.');
    }

    final tournament = await _loadTournament(tournamentId);
    final normalizedVenueId = _normalizeVenueId(venueId);
    final scheduleUnchanged =
        match.scheduledAt == scheduledAt && match.venueId == normalizedVenueId;
    if (scheduleUnchanged) {
      return match;
    }
    final updatedMatch = match.copyWith(
      scheduledAt: scheduledAt,
      venueId: normalizedVenueId,
    );

    await _matchesRef
        .doc(matchId)
        .update(MatchModel.fromEntity(updatedMatch).toJson());
    await _auditEmitter.fixtureScheduled(
      tournament: tournament,
      actorId: actorId,
      matchId: updatedMatch.id,
      scheduledAt: scheduledAt,
      venueId: normalizedVenueId,
    );
    return updatedMatch;
  }

  Future<Match> startMatch({
    required String matchId,
    required String actorId,
    DateTime? now,
  }) async {
    if (actorId.trim().isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }
    final effectiveNow = now ?? DateTime.now();
    final match = await _loadMatch(matchId);
    final tournamentId = match.tournamentId;
    if (tournamentId == null || tournamentId.isEmpty) {
      throw Exception('لا يمكن بدء مباراة ليست جزءًا من بطولة.');
    }
    final tournament = await _loadTournament(tournamentId);
    if (!_permissionService.canManageTeams(tournament, actorId)) {
      throw Exception('لا تملك صلاحية بدء مباريات هذه البطولة.');
    }
    if (match.isFrozen || match.status == MatchStatus.frozen) {
      throw Exception('لا يمكن بدء مباراة مجمدة.');
    }
    if (match.isOfficialTournamentResult ||
        match.status == MatchStatus.completed ||
        match.status == MatchStatus.pendingReview ||
        match.status == MatchStatus.ratingWindow ||
        match.status == MatchStatus.settled) {
      throw Exception('لا يمكن بدء مباراة تملك نتيجة بالفعل.');
    }
    if (match.status == MatchStatus.live) {
      return match;
    }
    if (match.status != MatchStatus.open) {
      throw Exception('لا يمكن بدء المباراة بحالتها الحالية.');
    }
    if (match.fixtureStatus != FixtureStatus.published) {
      throw Exception('يجب نشر fixture قبل بدء المباراة.');
    }

    final homeSide = await _loadStartSide(
      match: match,
      participantId: match.teamAParticipantId,
      sideLabel: 'الفريق الأول',
    );
    final awaySide = await _loadStartSide(
      match: match,
      participantId: match.teamBParticipantId,
      sideLabel: 'الفريق الثاني',
    );

    final updatedMatch = match.copyWith(
      status: MatchStatus.live,
      startedAt: match.startedAt ?? effectiveNow,
      teamAPlayerIds: homeSide.projectedRegisteredPlayerIds,
      teamBPlayerIds: awaySide.projectedRegisteredPlayerIds,
    );

    await _matchesRef
        .doc(matchId)
        .update(MatchModel.fromEntity(updatedMatch).toJson());
    await _auditEmitter.fixtureStarted(
      tournament: tournament,
      actorId: actorId,
      matchId: updatedMatch.id,
      startedAt: updatedMatch.startedAt ?? effectiveNow,
      teamAProjectedPlayers: homeSide.projectedRegisteredPlayerIds.length,
      teamBProjectedPlayers: awaySide.projectedRegisteredPlayerIds.length,
    );
    return updatedMatch;
  }

  Future<GroupStageBuildResult> regenerateGroupStage({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    final groupStageId = tournament.currentGroupStageId;
    if (tournament.needsManualOpsMigration) {
      throw Exception(
        'هذه البطولة تحتاج manual ops migration قبل إعادة توليد المجموعات.',
      );
    }
    if (groupStageId == null || groupStageId.isEmpty) {
      throw Exception('لا توجد مرحلة مجموعات حالية لإعادة توليدها.');
    }
    if (tournament.participantListFinalizedAt == null) {
      throw Exception('يجب قفل قائمة المشاركين قبل إعادة توليد المجموعات.');
    }
    if (tournament.currentKnockoutBracketId != null &&
        tournament.currentKnockoutBracketId!.isNotEmpty) {
      throw Exception('لا يمكن إعادة توليد المجموعات بعد بدء الإقصاء.');
    }

    final fixtures = await _loadGroupFixtures(
      tournamentId: tournamentId,
      groupStageId: groupStageId,
    );
    _assertCanRegenerateGroupStage(fixtures);

    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final buildResult = _groupStageBuilder.build(
      tournament: tournament,
      participants: participants,
      now: effectiveNow,
    );
    final existingGroups = await _loadGroups(groupStageId);
    final existingStandings = await _loadStandings(groupStageId);

    final batch = _firestore.batch();
    for (final group in existingGroups) {
      batch.delete(_groupsRef.doc(group.id));
    }
    for (final snapshot in existingStandings) {
      batch.delete(_standingsRef.doc(snapshot.id));
    }
    for (final fixture in fixtures) {
      batch.delete(_matchesRef.doc(fixture.id));
    }
    for (final group in buildResult.groups) {
      batch.set(
        _groupsRef.doc(group.id),
        TournamentGroupModel.fromEntity(group).toJson(),
      );
    }
    for (final snapshot in buildResult.standings) {
      batch.set(
        _standingsRef.doc(snapshot.id),
        GroupStandingSnapshotModel.fromEntity(snapshot).toJson(),
      );
    }
    for (final fixture in buildResult.fixtures) {
      batch.set(
        _matchesRef.doc(fixture.id),
        MatchModel.fromEntity(fixture).toJson(),
      );
    }
    await batch.commit();

    await _auditEmitter.groupStageRegenerated(
      tournament: tournament,
      actorId: actorId,
      groupStageId: buildResult.groupStageId,
      groupsCount: buildResult.groups.length,
      fixturesCount: buildResult.fixtures.length,
    );
    return buildResult;
  }

  void _assertCanRegenerateGroupStage(List<Match> fixtures) {
    if (fixtures.any(
      (fixture) => fixture.fixtureStatus == FixtureStatus.published,
    )) {
      throw Exception('لا يمكن إعادة توليد المجموعات بعد نشر fixtures.');
    }

    if (fixtures.any(
      (fixture) =>
          fixture.isOfficialTournamentResult ||
          fixture.scoreTeamA != null ||
          fixture.scoreTeamB != null ||
          fixture.status == MatchStatus.completed ||
          fixture.status == MatchStatus.pendingReview,
    )) {
      throw Exception(
        'لا يمكن إعادة توليد المجموعات بعد إدخال أو اعتماد أي نتيجة.',
      );
    }
  }

  Future<Tournament> _loadTournament(String tournamentId) async {
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على البطولة المطلوبة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<Match> _loadMatch(String matchId) async {
    final snapshot = await _matchesRef.doc(matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على fixture المطلوبة.');
    }
    return MatchModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<_FixtureStartSide> _loadStartSide({
    required Match match,
    required String? participantId,
    required String sideLabel,
  }) async {
    if (participantId == null || participantId.isEmpty) {
      throw Exception('تعذر تحديد $sideLabel داخل هذه الـ fixture.');
    }
    final participant = await _loadParticipant(participantId);
    final displayLabel = participant.displayName;
    final sourceEntityId = participant.sourceEntityId;

    final checkIn =
        participant.sourceType == TournamentParticipantSourceType.registeredTeam
        ? await _getCheckInByTeamId(matchId: match.id, teamId: sourceEntityId)
        : await _getCheckInByGuestTeamId(
            matchId: match.id,
            guestTeamId: sourceEntityId,
          );
    if (checkIn == null || !checkIn.isCheckedIn) {
      throw Exception('يجب تنفيذ check-in لـ $displayLabel قبل بدء المباراة.');
    }

    final snapshot =
        participant.sourceType == TournamentParticipantSourceType.registeredTeam
        ? await _getSnapshotByTeamId(matchId: match.id, teamId: sourceEntityId)
        : await _getSnapshotByGuestTeamId(
            matchId: match.id,
            guestTeamId: sourceEntityId,
          );
    if (snapshot == null) {
      throw Exception('يجب قفل التشكيل لـ $displayLabel قبل بدء المباراة.');
    }

    final projectedRegisteredPlayerIds = _projectRegisteredPlayerIds(snapshot);
    if (participant.sourceType ==
            TournamentParticipantSourceType.registeredTeam &&
        projectedRegisteredPlayerIds.isEmpty) {
      throw Exception(
        'تعذر تكوين roster فعلية لـ $displayLabel من التشكيل المقفول.',
      );
    }

    return _FixtureStartSide(
      participant: participant,
      checkIn: checkIn,
      snapshot: snapshot,
      projectedRegisteredPlayerIds: projectedRegisteredPlayerIds,
    );
  }

  Future<TournamentParticipant> _loadParticipant(String participantId) async {
    final snapshot = await _participantsRef.doc(participantId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على participant المطلوبة.');
    }
    return TournamentParticipantModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
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

  List<String> _projectRegisteredPlayerIds(MatchLineupSnapshot snapshot) {
    final projected = <String>[];
    for (final entry in <dynamic>[...snapshot.starters, ...snapshot.bench]) {
      final playerId = entry.playerId as String?;
      if (playerId == null || projected.contains(playerId)) {
        continue;
      }
      projected.add(playerId);
    }
    return projected;
  }

  Future<List<TournamentGroup>> _loadGroups(String groupStageId) async {
    final snapshot = await _groupsRef
        .where('groupStageId', isEqualTo: groupStageId)
        .get();
    return snapshot.docs
        .map(
          (doc) => TournamentGroupModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: false);
  }

  Future<List<GroupStandingSnapshot>> _loadStandings(
    String groupStageId,
  ) async {
    final snapshot = await _standingsRef
        .where('groupStageId', isEqualTo: groupStageId)
        .get();
    return snapshot.docs
        .map(
          (doc) => GroupStandingSnapshotModel.fromJson(
            doc.data(),
            doc.id,
          ).toEntity(),
        )
        .toList(growable: false);
  }

  Future<List<Match>> _loadGroupFixtures({
    required String tournamentId,
    required String groupStageId,
  }) async {
    final snapshot = await _matchesRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('stageType', isEqualTo: TournamentStageType.groupStage.name)
        .where('groupStageId', isEqualTo: groupStageId)
        .get();
    return snapshot.docs
        .map((doc) => MatchModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: false);
  }

  String? _normalizeVenueId(String? venueId) {
    final trimmed = venueId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _FixtureStartSide {
  final TournamentParticipant participant;
  final MatchCheckIn checkIn;
  final MatchLineupSnapshot snapshot;
  final List<String> projectedRegisteredPlayerIds;

  const _FixtureStartSide({
    required this.participant,
    required this.checkIn,
    required this.snapshot,
    required this.projectedRegisteredPlayerIds,
  });
}
