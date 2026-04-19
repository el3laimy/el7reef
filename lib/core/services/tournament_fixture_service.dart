import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/group_standing_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_group_model.dart';
import '../../data/models/tournament_model.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import 'group_stage_builder.dart';
import 'tournament_audit_emitter.dart';
import 'tournament_participant_service.dart';

class TournamentFixtureService {
  final FirebaseFirestore _firestore;
  final TournamentParticipantService _participantService;
  final GroupStageBuilder _groupStageBuilder;
  final TournamentAuditEmitter _auditEmitter;

  TournamentFixtureService({
    FirebaseFirestore? firestore,
    TournamentParticipantService? participantService,
    GroupStageBuilder? groupStageBuilder,
    TournamentAuditEmitter? auditEmitter,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _participantService =
           participantService ??
           TournamentParticipantService(firestore: firestore),
       _groupStageBuilder = groupStageBuilder ?? const GroupStageBuilder(),
       _auditEmitter =
           auditEmitter ?? TournamentAuditEmitter(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);
  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection(FirebasePaths.tournamentGroups);
  CollectionReference<Map<String, dynamic>> get _standingsRef =>
      _firestore.collection(FirebasePaths.groupStandingSnapshots);
  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);

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
