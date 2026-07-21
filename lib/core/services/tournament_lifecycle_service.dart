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
import 'tournament_lifecycle_planners.dart';
import 'tournament_participant_service.dart';

class TournamentLifecycleService {
  final FirebaseFirestore _firestore;
  final TournamentParticipantService _participantService;
  final ParticipantFinalizationPolicy _participantFinalizationPolicy;
  final GroupStageBuilder _groupStageBuilder;
  final KnockoutBuilder _knockoutBuilder;
  final TournamentStandingsRefreshPlanner _standingsRefreshPlanner;
  final TournamentCompletionPlanner _completionPlanner;
  final TournamentAuditEmitter _auditEmitter;

  TournamentLifecycleService({
    FirebaseFirestore? firestore,
    TournamentParticipantService? participantService,
    ParticipantFinalizationPolicy? participantFinalizationPolicy,
    GroupStageBuilder? groupStageBuilder,
    KnockoutBuilder? knockoutBuilder,
    TournamentCompletionPolicy? completionPolicy,
    TournamentStandingsRefreshPlanner? standingsRefreshPlanner,
    TournamentCompletionPlanner? completionPlanner,
    TournamentAuditEmitter? auditEmitter,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _participantService =
           participantService ??
           TournamentParticipantService(firestore: firestore),
       _participantFinalizationPolicy =
           participantFinalizationPolicy ??
           const ParticipantFinalizationPolicy(),
       _groupStageBuilder = groupStageBuilder ?? const GroupStageBuilder(),
       _knockoutBuilder = knockoutBuilder ?? const KnockoutBuilder(),
       _standingsRefreshPlanner =
           standingsRefreshPlanner ??
           TournamentStandingsRefreshPlanner(
             groupStageBuilder: groupStageBuilder ?? const GroupStageBuilder(),
           ),
       _completionPlanner =
           completionPlanner ??
           TournamentCompletionPlanner(
             completionPolicy:
                 completionPolicy ?? const TournamentCompletionPolicy(),
           ),
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
    final tournament = await _loadTournament(tournamentId);
    _assertTournamentOrganizer(tournament: tournament, actorId: actorId);
    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final alreadyFinalized =
        tournament.participantListFinalizedAt != null &&
        participants
            .where((participant) => participant.isActive)
            .every((participant) => participant.isFinalized);
    if (alreadyFinalized) {
      return participants;
    }
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
      participantListFinalizedAt:
          tournament.participantListFinalizedAt ?? effectiveNow,
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
    final tournament = await _loadTournament(tournamentId);
    _assertTournamentOrganizer(tournament: tournament, actorId: actorId);
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
    _assertTournamentOrganizer(tournament: tournament, actorId: actorId);
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
    final publishedById = {
      for (final fixture in publishedFixtures) fixture.id: fixture,
    };
    return fixtures
        .map((fixture) => publishedById[fixture.id] ?? fixture)
        .toList(growable: false);
  }

  Future<KnockoutBuildResult> startKnockout({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    _assertTournamentOrganizer(tournament: tournament, actorId: actorId);
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

    final groupStageId = tournament.currentGroupStageId;
    final hasGroupStage = groupStageId != null && groupStageId.isNotEmpty;
    if (hasGroupStage) {
      final groupFixtures = await _loadMatches(
        tournamentId: tournamentId,
        stageType: TournamentStageType.groupStage,
        groupStageId: groupStageId,
      );
      if (groupFixtures.isEmpty ||
          !groupFixtures.every(
            (fixture) => fixture.isOfficialTournamentResult,
          )) {
        throw Exception(
          'لا يمكن بدء الإقصائيات قبل اعتماد كل مباريات دور '
          'المجموعات.',
        );
      }
    }

    final participants = await _participantService.getTournamentParticipants(
      tournamentId,
    );
    final groups = !hasGroupStage
        ? const <TournamentGroup>[]
        : await _loadGroups(
            tournamentId: tournamentId,
            groupStageId: groupStageId,
          );
    final standings = !hasGroupStage
        ? const <GroupStandingSnapshot>[]
        : await refreshGroupStandings(
            tournamentId: tournamentId,
            actorId: actorId,
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
      seedingMethod: buildResult.bracket.seedingMethod,
      qualifierParticipantIds: buildResult.bracket.qualifierParticipantIds,
      byeParticipantIds: buildResult.bracket.byeParticipantIds,
    );
    return buildResult;
  }

  Future<List<GroupStandingSnapshot>> refreshGroupStandings({
    required String tournamentId,
    String? actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    _assertTournamentOrganizerIfProvided(
      tournament: tournament,
      actorId: actorId,
    );
    if (tournament.currentGroupStageId == null ||
        tournament.currentGroupStageId!.isEmpty) {
      return const <GroupStandingSnapshot>[];
    }
    final groupsFuture = _loadGroups(
      tournamentId: tournamentId,
      groupStageId: tournament.currentGroupStageId!,
    );
    final participantsFuture = _participantService.getTournamentParticipants(
      tournamentId,
    );
    final fixturesFuture = _loadMatches(
      tournamentId: tournamentId,
      stageType: TournamentStageType.groupStage,
      groupStageId: tournament.currentGroupStageId!,
    );
    final existingSnapshotsFuture = _loadStandings(
      tournament.currentGroupStageId!,
    );

    final groups = await groupsFuture;
    final participants = await participantsFuture;
    final fixtures = await fixturesFuture;
    final existingSnapshots = await existingSnapshotsFuture;
    final plan = _standingsRefreshPlanner.plan(
      tournament: tournament,
      groups: groups,
      participants: participants,
      fixtures: fixtures,
      existingSnapshots: existingSnapshots,
      now: effectiveNow,
    );

    if (plan.changedSnapshots.isEmpty) {
      return plan.snapshots;
    }

    final batch = _firestore.batch();
    for (final snapshot in plan.changedSnapshots) {
      batch.set(
        _standingsRef.doc(snapshot.id),
        GroupStandingSnapshotModel.fromEntity(snapshot).toJson(),
      );
    }
    await batch.commit();
    return plan.snapshots;
  }

  Future<KnockoutProgressResult?> refreshKnockoutProgress({
    required String tournamentId,
    String? actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    _assertTournamentOrganizerIfProvided(
      tournament: tournament,
      actorId: actorId,
    );
    final bracketId = tournament.currentKnockoutBracketId;
    if (bracketId == null || bracketId.isEmpty) {
      return null;
    }
    final bracketFuture = _loadBracket(bracketId);
    final tiesFuture = _loadTies(bracketId);
    final matchesFuture = _loadMatches(
      tournamentId: tournamentId,
      stageType: TournamentStageType.knockoutStage,
    );
    final participantsFuture = _participantService.getTournamentParticipants(
      tournamentId,
    );
    final bracket = await bracketFuture;
    final ties = await tiesFuture;
    final matches = await matchesFuture;
    final participants = await participantsFuture;
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

    final existingTiesById = {for (final tie in ties) tie.id: tie};
    final existingMatchesById = {for (final match in matches) match.id: match};

    var bracketToReturn = bracket;
    KnockoutBracket? bracketToPersist;
    if (!_isEquivalentKnockoutBracket(bracket, progress.bracket)) {
      bracketToPersist = progress.bracket.copyWith(
        createdAt: bracket.createdAt,
        updatedAt: effectiveNow,
      );
      bracketToReturn = bracketToPersist;
    }

    final tiesToReturn = <KnockoutTie>[];
    final changedTies = <KnockoutTie>[];
    for (final tie in progress.ties) {
      final existingTie = existingTiesById[tie.id];
      if (existingTie != null && _isEquivalentKnockoutTie(existingTie, tie)) {
        tiesToReturn.add(existingTie);
        continue;
      }

      final tieToPersist = tie.copyWith(
        createdAt: existingTie?.createdAt ?? tie.createdAt,
        updatedAt: effectiveNow,
      );
      tiesToReturn.add(tieToPersist);
      changedTies.add(tieToPersist);
    }

    final matchesToReturn = <Match>[];
    final changedMatches = <Match>[];
    for (final match in progress.matches) {
      final existingMatch = existingMatchesById[match.id];
      if (existingMatch != null && _isEquivalentMatch(existingMatch, match)) {
        matchesToReturn.add(existingMatch);
        continue;
      }
      matchesToReturn.add(match);
      changedMatches.add(match);
    }

    if (bracketToPersist == null &&
        changedTies.isEmpty &&
        changedMatches.isEmpty) {
      return KnockoutProgressResult(
        bracket: bracketToReturn,
        ties: tiesToReturn,
        matches: matchesToReturn,
      );
    }

    final batch = _firestore.batch();
    if (bracketToPersist != null) {
      batch.update(
        _bracketsRef.doc(bracketToPersist.id),
        KnockoutBracketModel.fromEntity(bracketToPersist).toJson(),
      );
    }
    for (final tie in changedTies) {
      batch.set(
        _tiesRef.doc(tie.id),
        KnockoutTieModel.fromEntity(tie).toJson(),
      );
    }
    for (final match in changedMatches) {
      batch.set(
        _matchesRef.doc(match.id),
        MatchModel.fromEntity(match).toJson(),
      );
    }
    await batch.commit();
    return KnockoutProgressResult(
      bracket: bracketToReturn,
      ties: tiesToReturn,
      matches: matchesToReturn,
    );
  }

  Future<Tournament> completeTournament({
    required String tournamentId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournamentForGuard = await _loadTournament(tournamentId);
    _assertTournamentOrganizer(
      tournament: tournamentForGuard,
      actorId: actorId,
    );
    await refreshGroupStandings(
      tournamentId: tournamentId,
      actorId: actorId,
      now: effectiveNow,
    );
    await refreshKnockoutProgress(
      tournamentId: tournamentId,
      actorId: actorId,
      now: effectiveNow,
    );
    final tournament = await _loadTournament(tournamentId);
    final bracket = tournament.currentKnockoutBracketId == null
        ? null
        : await _loadBracket(tournament.currentKnockoutBracketId!);
    final standings = tournament.currentGroupStageId == null
        ? const <GroupStandingSnapshot>[]
        : await _loadStandings(tournament.currentGroupStageId!);
    final updatedTournament = _completionPlanner.complete(
      tournament: tournament,
      bracket: bracket,
      standings: standings,
    );
    final winnerParticipantId = updatedTournament.winnerParticipantId;
    if (tournament.status == TournamentStatus.completed &&
        tournament.winnerParticipantId == winnerParticipantId) {
      return tournament;
    }
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

  void _assertTournamentOrganizer({
    required Tournament tournament,
    required String actorId,
  }) {
    final normalizedActorId = actorId.trim();
    if (normalizedActorId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }
    if (tournament.organizerId != normalizedActorId) {
      throw Exception('لا تملك صلاحية إدارة هذه البطولة.');
    }
  }

  void _assertTournamentOrganizerIfProvided({
    required Tournament tournament,
    required String? actorId,
  }) {
    if (actorId == null) {
      return;
    }
    _assertTournamentOrganizer(tournament: tournament, actorId: actorId);
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

  bool _isEquivalentKnockoutBracket(
    KnockoutBracket left,
    KnockoutBracket right,
  ) {
    return left.tournamentId == right.tournamentId &&
        left.format == right.format &&
        left.seedingMethod == right.seedingMethod &&
        left.championParticipantId == right.championParticipantId &&
        _stringListsEqual(
          left.qualifierParticipantIds,
          right.qualifierParticipantIds,
        ) &&
        _stringListsEqual(left.byeParticipantIds, right.byeParticipantIds);
  }

  bool _isEquivalentKnockoutTie(KnockoutTie left, KnockoutTie right) {
    return left.tournamentId == right.tournamentId &&
        left.bracketId == right.bracketId &&
        left.roundIndex == right.roundIndex &&
        left.slotNumber == right.slotNumber &&
        left.participantAId == right.participantAId &&
        left.participantBId == right.participantBId &&
        left.winnerParticipantId == right.winnerParticipantId &&
        left.matchId == right.matchId &&
        left.nextTieId == right.nextTieId &&
        left.resolutionType == right.resolutionType;
  }

  bool _isEquivalentMatch(Match left, Match right) {
    return left.organizerId == right.organizerId &&
        left.teamAId == right.teamAId &&
        left.teamBId == right.teamBId &&
        _stringListsEqual(left.teamAPlayerIds, right.teamAPlayerIds) &&
        _stringListsEqual(left.teamBPlayerIds, right.teamBPlayerIds) &&
        left.teamAParticipantId == right.teamAParticipantId &&
        left.teamBParticipantId == right.teamBParticipantId &&
        left.status == right.status &&
        left.scoreTeamA == right.scoreTeamA &&
        left.scoreTeamB == right.scoreTeamB &&
        left.penaltyScoreTeamA == right.penaltyScoreTeamA &&
        left.penaltyScoreTeamB == right.penaltyScoreTeamB &&
        left.knockoutDecision == right.knockoutDecision &&
        left.mvpPlayerId == right.mvpPlayerId &&
        left.location == right.location &&
        left.latitude == right.latitude &&
        left.longitude == right.longitude &&
        left.teamSize == right.teamSize &&
        left.isOrganized == right.isOrganized &&
        left.tournamentId == right.tournamentId &&
        left.isGoldenRating == right.isGoldenRating &&
        left.isAnomaly == right.isAnomaly &&
        left.isFrozen == right.isFrozen &&
        left.stageType == right.stageType &&
        left.groupId == right.groupId &&
        left.groupStageId == right.groupStageId &&
        left.knockoutTieId == right.knockoutTieId &&
        left.roundIndex == right.roundIndex &&
        left.slotNumber == right.slotNumber &&
        left.scheduledAt == right.scheduledAt &&
        left.publishedAt == right.publishedAt &&
        left.venueId == right.venueId &&
        left.fixtureStatus == right.fixtureStatus &&
        left.createdAt == right.createdAt &&
        left.startedAt == right.startedAt &&
        left.completedAt == right.completedAt;
  }

  bool _stringListsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
