import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_enums.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/group_standing_snapshot_model.dart';
import '../../data/models/knockout_bracket_model.dart';
import '../../data/models/knockout_tie_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_group_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_participant_model.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/knockout_bracket.dart';
import '../../domain/entities/knockout_tie.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group.dart';
import '../../domain/entities/tournament_participant.dart';
import 'group_stage_builder.dart';
import 'knockout_builder.dart';
import 'participant_finalization_policy.dart';
import 'tournament_audit_emitter.dart';
import 'tournament_completion_policy.dart';
import 'tournament_ops_migration_service.dart';
import 'tournament_participant_service.dart';

class TournamentLifecycleService {
  final FirebaseFirestore _firestore;
  final TournamentOpsMigrationService _migrationService;
  final TournamentParticipantService _participantService;
  final ParticipantFinalizationPolicy _participantFinalizationPolicy;
  final GroupStageBuilder _groupStageBuilder;
  final KnockoutBuilder _knockoutBuilder;
  final TournamentCompletionPolicy _completionPolicy;
  final TournamentAuditEmitter _auditEmitter;

  TournamentLifecycleService({
    FirebaseFirestore? firestore,
    TournamentOpsMigrationService? migrationService,
    TournamentParticipantService? participantService,
    ParticipantFinalizationPolicy? participantFinalizationPolicy,
    GroupStageBuilder? groupStageBuilder,
    KnockoutBuilder? knockoutBuilder,
    TournamentCompletionPolicy? completionPolicy,
    TournamentAuditEmitter? auditEmitter,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _migrationService =
           migrationService ??
           TournamentOpsMigrationService(firestore: firestore),
       _participantService =
           participantService ??
           TournamentParticipantService(firestore: firestore),
       _participantFinalizationPolicy =
           participantFinalizationPolicy ??
           const ParticipantFinalizationPolicy(),
       _groupStageBuilder = groupStageBuilder ?? const GroupStageBuilder(),
       _knockoutBuilder = knockoutBuilder ?? const KnockoutBuilder(),
       _completionPolicy =
           completionPolicy ?? const TournamentCompletionPolicy(),
       _auditEmitter =
           auditEmitter ?? TournamentAuditEmitter(firestore: firestore);

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
  CollectionReference<Map<String, dynamic>> get _bracketsRef =>
      _firestore.collection(FirebasePaths.knockoutBrackets);
  CollectionReference<Map<String, dynamic>> get _tiesRef =>
      _firestore.collection(FirebasePaths.knockoutTies);

  Future<List<TournamentParticipant>> finalizeParticipants({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    await _migrationService.backfillTournament(
      tournamentId: tournamentId,
      actorId: actorId,
      now: effectiveNow,
    );
    final tournament = await _loadTournament(tournamentId);
    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final finalized = _participantFinalizationPolicy.finalize(
      tournament: tournament,
      participants: participants,
      now: effectiveNow,
    );
    final batch = _firestore.batch();
    for (final participant in finalized) {
      batch.set(
        _participantsRef.doc(participant.id),
        TournamentParticipantModel.fromEntity(participant).toJson(),
      );
    }
    final updatedTournament = tournament.copyWith(
      participantListFinalizedAt: effectiveNow,
    );
    batch.update(
      _tournamentsRef.doc(tournamentId),
      TournamentModel.fromEntity(updatedTournament).toJson(),
    );
    await batch.commit();
    await _auditEmitter.participantsFinalized(
      tournament: updatedTournament,
      actorId: actorId,
      participantCount: finalized.length,
    );
    return finalized;
  }

  Future<GroupStageBuildResult> startGroupStage({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    await _migrationService.backfillTournament(
      tournamentId: tournamentId,
      actorId: actorId,
      now: effectiveNow,
    );
    final tournament = await _loadTournament(tournamentId);
    if (tournament.currentGroupStageId != null &&
        tournament.currentGroupStageId!.isNotEmpty) {
      final groups = await _loadGroups(
        tournamentId: tournamentId,
        groupStageId: tournament.currentGroupStageId!,
      );
      final standings = await _loadStandings(tournament.currentGroupStageId!);
      final fixtures = await _loadMatches(
        tournamentId: tournamentId,
        stageType: TournamentStageType.groupStage,
        groupStageId: tournament.currentGroupStageId,
      );
      return GroupStageBuildResult(
        groupStageId: tournament.currentGroupStageId!,
        groups: groups,
        fixtures: fixtures,
        standings: standings,
      );
    }

    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    if (tournament.participantListFinalizedAt == null) {
      throw Exception('يجب قفل المشاركين قبل بدء المجموعات.');
    }
    final buildResult = _groupStageBuilder.build(
      tournament: tournament,
      participants: participants,
      now: effectiveNow,
    );
    final batch = _firestore.batch();
    for (final group in buildResult.groups) {
      batch.set(
        _groupsRef.doc(group.id),
        TournamentGroupModel.fromEntity(group).toJson(),
      );
    }
    for (final standing in buildResult.standings) {
      batch.set(
        _standingsRef.doc(standing.id),
        GroupStandingSnapshotModel.fromEntity(standing).toJson(),
      );
    }
    for (final fixture in buildResult.fixtures) {
      batch.set(
        _matchesRef.doc(fixture.id),
        MatchModel.fromEntity(fixture).toJson(),
      );
    }
    final updatedTournament = tournament.copyWith(
      status: TournamentStatus.groupStage,
      currentGroupStageId: buildResult.groupStageId,
    );
    batch.update(
      _tournamentsRef.doc(tournamentId),
      TournamentModel.fromEntity(updatedTournament).toJson(),
    );
    await batch.commit();
    await _auditEmitter.groupStageGenerated(
      tournament: updatedTournament,
      actorId: actorId,
      groupStageId: buildResult.groupStageId,
      groupsCount: buildResult.groups.length,
      fixturesCount: buildResult.fixtures.length,
    );
    return buildResult;
  }

  Future<List<Match>> publishFixtures({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    final fixtures = await _loadMatches(tournamentId: tournamentId);
    final publishedFixtures = fixtures
        .where((fixture) => fixture.fixtureStatus != FixtureStatus.published)
        .map(
          (fixture) => fixture.copyWith(
            fixtureStatus: FixtureStatus.published,
            publishedAt: fixture.publishedAt ?? effectiveNow,
          ),
        )
        .toList(growable: false);
    if (publishedFixtures.isEmpty) {
      return fixtures;
    }

    final batch = _firestore.batch();
    for (final fixture in publishedFixtures) {
      batch.update(
        _matchesRef.doc(fixture.id),
        MatchModel.fromEntity(fixture).toJson(),
      );
    }
    await batch.commit();
    await _auditEmitter.fixturesPublished(
      tournament: tournament,
      actorId: actorId,
      fixturesCount: publishedFixtures.length,
    );
    return await _loadMatches(tournamentId: tournamentId);
  }

  Future<KnockoutBuildResult> startKnockout({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    if (tournament.currentKnockoutBracketId != null &&
        tournament.currentKnockoutBracketId!.isNotEmpty) {
      final bracket = await _loadBracket(tournament.currentKnockoutBracketId!);
      final ties = await _loadTies(bracket.id);
      final matches = await _loadMatches(
        tournamentId: tournamentId,
        stageType: TournamentStageType.knockoutStage,
      );
      return KnockoutBuildResult(
        bracket: bracket,
        ties: ties,
        matches: matches,
      );
    }

    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final groups = tournament.currentGroupStageId == null
        ? const <TournamentGroup>[]
        : await _loadGroups(
            tournamentId: tournamentId,
            groupStageId: tournament.currentGroupStageId!,
          );
    final standings = tournament.currentGroupStageId == null
        ? const <GroupStandingSnapshot>[]
        : await refreshGroupStandings(
            tournamentId: tournamentId,
            now: effectiveNow,
          );
    final buildResult = _knockoutBuilder.build(
      tournament: tournament,
      participants: participants,
      groups: groups,
      standings: standings,
      now: effectiveNow,
    );

    final batch = _firestore.batch();
    batch.set(
      _bracketsRef.doc(buildResult.bracket.id),
      KnockoutBracketModel.fromEntity(buildResult.bracket).toJson(),
    );
    for (final tie in buildResult.ties) {
      batch.set(
        _tiesRef.doc(tie.id),
        KnockoutTieModel.fromEntity(tie).toJson(),
      );
    }
    for (final match in buildResult.matches) {
      batch.set(
        _matchesRef.doc(match.id),
        MatchModel.fromEntity(match).toJson(),
      );
    }
    final updatedTournament = tournament.copyWith(
      status: TournamentStatus.knockoutStage,
      currentKnockoutBracketId: buildResult.bracket.id,
    );
    batch.update(
      _tournamentsRef.doc(tournamentId),
      TournamentModel.fromEntity(updatedTournament).toJson(),
    );
    await batch.commit();
    await _auditEmitter.knockoutGenerated(
      tournament: updatedTournament,
      actorId: actorId,
      bracketId: buildResult.bracket.id,
      tiesCount: buildResult.ties.length,
    );
    return buildResult;
  }

  Future<List<GroupStandingSnapshot>> refreshGroupStandings({
    required String tournamentId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    if (tournament.currentGroupStageId == null ||
        tournament.currentGroupStageId!.isEmpty) {
      return const <GroupStandingSnapshot>[];
    }
    final groups = await _loadGroups(
      tournamentId: tournamentId,
      groupStageId: tournament.currentGroupStageId!,
    );
    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final fixtures = await _loadMatches(
      tournamentId: tournamentId,
      stageType: TournamentStageType.groupStage,
      groupStageId: tournament.currentGroupStageId!,
    );
    final snapshots = groups
        .map(
          (group) => _groupStageBuilder.recalculateSnapshot(
            tournament: tournament,
            group: group,
            participantsById: participantsById,
            matches: fixtures
                .where((match) => match.groupId == group.id)
                .toList(),
            now: effectiveNow,
          ),
        )
        .toList(growable: false);
    final batch = _firestore.batch();
    for (final snapshot in snapshots) {
      batch.set(
        _standingsRef.doc(snapshot.id),
        GroupStandingSnapshotModel.fromEntity(snapshot).toJson(),
      );
    }
    await batch.commit();
    return snapshots;
  }

  Future<KnockoutProgressResult?> refreshKnockoutProgress({
    required String tournamentId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    final bracketId = tournament.currentKnockoutBracketId;
    if (bracketId == null || bracketId.isEmpty) {
      return null;
    }
    final bracket = await _loadBracket(bracketId);
    final ties = await _loadTies(bracketId);
    final matches = await _loadMatches(
      tournamentId: tournamentId,
      stageType: TournamentStageType.knockoutStage,
    );
    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final progress = _knockoutBuilder.synchronizeProgress(
      bracket: bracket,
      ties: ties,
      matches: matches,
      participantsById: participantsById,
      now: effectiveNow,
    );
    final batch = _firestore.batch();
    batch.update(
      _bracketsRef.doc(progress.bracket.id),
      KnockoutBracketModel.fromEntity(progress.bracket).toJson(),
    );
    for (final tie in progress.ties) {
      batch.set(
        _tiesRef.doc(tie.id),
        KnockoutTieModel.fromEntity(tie).toJson(),
      );
    }
    for (final match in progress.matches) {
      batch.set(
        _matchesRef.doc(match.id),
        MatchModel.fromEntity(match).toJson(),
      );
    }
    await batch.commit();
    return progress;
  }

  Future<Tournament> completeTournament({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    await refreshGroupStandings(tournamentId: tournamentId, now: effectiveNow);
    await refreshKnockoutProgress(
      tournamentId: tournamentId,
      now: effectiveNow,
    );
    final tournament = await _loadTournament(tournamentId);
    final bracket = tournament.currentKnockoutBracketId == null
        ? null
        : await _loadBracket(tournament.currentKnockoutBracketId!);
    final standings = tournament.currentGroupStageId == null
        ? const <GroupStandingSnapshot>[]
        : await _loadStandings(tournament.currentGroupStageId!);
    final winnerParticipantId = _completionPolicy.determineWinnerParticipantId(
      tournament: tournament,
      bracket: bracket,
      standings: standings,
    );
    final updatedTournament = tournament.copyWith(
      status: TournamentStatus.completed,
      winnerParticipantId: winnerParticipantId,
    );
    await _tournamentsRef
        .doc(tournamentId)
        .update(TournamentModel.fromEntity(updatedTournament).toJson());
    await _auditEmitter.tournamentCompleted(
      tournament: updatedTournament,
      actorId: actorId,
      winnerParticipantId: winnerParticipantId,
    );
    return updatedTournament;
  }

  Future<Tournament> _loadTournament(String tournamentId) async {
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على البطولة المطلوبة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<List<TournamentGroup>> _loadGroups({
    required String tournamentId,
    required String groupStageId,
  }) async {
    final snapshot = await _groupsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .where('groupStageId', isEqualTo: groupStageId)
        .get();
    final groups = snapshot.docs
        .map(
          (doc) => TournamentGroupModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: true);
    groups.sort((left, right) => left.order.compareTo(right.order));
    return groups;
  }

  Future<List<GroupStandingSnapshot>> _loadStandings(
    String groupStageId,
  ) async {
    final snapshot = await _standingsRef
        .where('groupStageId', isEqualTo: groupStageId)
        .get();
    final standings = snapshot.docs
        .map(
          (doc) => GroupStandingSnapshotModel.fromJson(
            doc.data(),
            doc.id,
          ).toEntity(),
        )
        .toList(growable: true);
    standings.sort((left, right) => left.groupId.compareTo(right.groupId));
    return standings;
  }

  Future<List<Match>> _loadMatches({
    required String tournamentId,
    TournamentStageType? stageType,
    String? groupStageId,
  }) async {
    Query<Map<String, dynamic>> query = _matchesRef.where(
      'tournamentId',
      isEqualTo: tournamentId,
    );
    if (stageType != null) {
      query = query.where('stageType', isEqualTo: stageType.name);
    }
    if (groupStageId != null && groupStageId.isNotEmpty) {
      query = query.where('groupStageId', isEqualTo: groupStageId);
    }
    final snapshot = await query.get();
    final matches = snapshot.docs
        .map((doc) => MatchModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: true);
    matches.sort((left, right) {
      final leftSort = left.scheduledAt ?? left.createdAt;
      final rightSort = right.scheduledAt ?? right.createdAt;
      return leftSort.compareTo(rightSort);
    });
    return matches;
  }

  Future<KnockoutBracket> _loadBracket(String bracketId) async {
    final snapshot = await _bracketsRef.doc(bracketId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على bracket الحالي.');
    }
    return KnockoutBracketModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
  }

  Future<List<KnockoutTie>> _loadTies(String bracketId) async {
    final snapshot = await _tiesRef
        .where('bracketId', isEqualTo: bracketId)
        .get();
    final ties = snapshot.docs
        .map((doc) => KnockoutTieModel.fromJson(doc.data(), doc.id).toEntity())
        .toList(growable: true);
    ties.sort((left, right) {
      if (left.roundIndex != right.roundIndex) {
        return left.roundIndex.compareTo(right.roundIndex);
      }
      return left.slotNumber.compareTo(right.slotNumber);
    });
    return ties;
  }
}
