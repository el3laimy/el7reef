import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/guest_team_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_participant_model.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_participant.dart';
import '../../domain/entities/tournament_registration.dart';
import 'tournament_audit_emitter.dart';

class TournamentParticipantService {
  final FirebaseFirestore _firestore;
  final TournamentAuditEmitter _auditEmitter;

  TournamentParticipantService({
    FirebaseFirestore? firestore,
    TournamentAuditEmitter? auditEmitter,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auditEmitter =
           auditEmitter ?? TournamentAuditEmitter(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _firestore.collection(FirebasePaths.tournamentParticipants);
  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);
  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection(FirebasePaths.teams);
  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      _firestore.collection(FirebasePaths.guestTeams);

  String participantIdFor({
    required String tournamentId,
    required TournamentParticipantSourceType sourceType,
    required String sourceEntityId,
  }) {
    return 'participant::$tournamentId::${sourceType.name}::$sourceEntityId';
  }

  Future<List<TournamentParticipant>> getTournamentParticipants(
    String tournamentId,
  ) async {
    final snapshot = await _participantsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    final participants = snapshot.docs
        .map(
          (doc) => TournamentParticipantModel.fromJson(
            doc.data(),
            doc.id,
          ).toEntity(),
        )
        .toList(growable: true);
    participants.sort((left, right) {
      final leftSeed = left.seed ?? 1 << 20;
      final rightSeed = right.seed ?? 1 << 20;
      if (leftSeed != rightSeed) {
        return leftSeed.compareTo(rightSeed);
      }
      return left.displayName.compareTo(right.displayName);
    });
    return participants;
  }

  Future<TournamentParticipant?> getParticipantById(
    String participantId,
  ) async {
    final snapshot = await _participantsRef.doc(participantId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return TournamentParticipantModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
  }

  Future<TournamentParticipant> syncApprovedRegistration({
    required TournamentRegistration registration,
    required String actorId,
    DateTime? now,
    bool refreshTournamentSummary = true,
  }) async {
    if (registration.status.name != 'approved') {
      throw Exception('لا يمكن تحويل تسجيل غير معتمد إلى participant.');
    }
    final effectiveNow = now ?? DateTime.now();
    final source = await _loadSourceForRegistration(registration);
    final participantId = participantIdFor(
      tournamentId: registration.tournamentId,
      sourceType: source.sourceType,
      sourceEntityId: source.entityId,
    );
    final existingDoc = await _participantsRef.doc(participantId).get();
    final existing = existingDoc.exists && existingDoc.data() != null
        ? TournamentParticipantModel.fromJson(
            existingDoc.data()!,
            existingDoc.id,
          ).toEntity()
        : null;
    final participant = TournamentParticipant(
      id: participantId,
      tournamentId: registration.tournamentId,
      sourceType: source.sourceType,
      sourceEntityId: source.entityId,
      displayName: source.displayName,
      status: existing?.status ?? TournamentParticipantStatus.approved,
      seed: existing?.seed,
      groupId: existing?.groupId,
      sourceRegistrationId: registration.id,
      replacementForParticipantId: existing?.replacementForParticipantId,
      replacedByParticipantId: existing?.replacedByParticipantId,
      createdAt: existing?.createdAt ?? effectiveNow,
      updatedAt: effectiveNow,
      approvedAt:
          existing?.approvedAt ?? registration.verifiedAt ?? effectiveNow,
      finalizedAt: existing?.finalizedAt,
      withdrawnAt: existing?.withdrawnAt,
      replacedAt: existing?.replacedAt,
    );
    final shouldWrite =
        existing == null ||
        !_hasSameSyncedParticipantState(existing, participant);
    Tournament? tournament;
    if (shouldWrite) {
      await _participantsRef
          .doc(participant.id)
          .set(TournamentParticipantModel.fromEntity(participant).toJson());
    }
    if (existing == null) {
      tournament = await _loadTournament(registration.tournamentId);
      await _auditEmitter.participantAdded(
        tournament: tournament,
        actorId: actorId,
        participantId: participant.id,
        afterPayload: {
          'sourceType': participant.sourceType.name,
          'sourceEntityId': participant.sourceEntityId,
          'displayName': participant.displayName,
        },
      );
    }
    if (refreshTournamentSummary) {
      tournament ??= await _loadTournament(registration.tournamentId);
      await refreshTournamentParticipantSummary(
        tournamentId: registration.tournamentId,
        tournament: tournament,
      );
    }
    if (!shouldWrite) {
      return existing;
    }
    return participant;
  }

  Future<TournamentParticipant> addManualParticipant({
    required String tournamentId,
    required TournamentParticipantSourceType sourceType,
    required String sourceEntityId,
    required String actorId,
    DateTime? now,
    bool refreshTournamentSummary = true,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    _assertCanAddManualParticipant(tournament);
    final source = await _loadSource(
      sourceType: sourceType,
      sourceEntityId: sourceEntityId,
    );
    final participantId = participantIdFor(
      tournamentId: tournamentId,
      sourceType: sourceType,
      sourceEntityId: sourceEntityId,
    );
    final existing = await _participantsRef.doc(participantId).get();
    if (existing.exists && existing.data() != null) {
      return TournamentParticipantModel.fromJson(
        existing.data()!,
        existing.id,
      ).toEntity();
    }
    final participant = TournamentParticipant(
      id: participantId,
      tournamentId: tournamentId,
      sourceType: sourceType,
      sourceEntityId: sourceEntityId,
      displayName: source.displayName,
      createdAt: effectiveNow,
      updatedAt: effectiveNow,
      approvedAt: effectiveNow,
    );
    await _participantsRef
        .doc(participant.id)
        .set(TournamentParticipantModel.fromEntity(participant).toJson());
    await _auditEmitter.participantAdded(
      tournament: tournament,
      actorId: actorId,
      participantId: participant.id,
      afterPayload: {
        'sourceType': sourceType.name,
        'sourceEntityId': sourceEntityId,
        'displayName': participant.displayName,
        'manual': true,
      },
    );
    if (refreshTournamentSummary) {
      await refreshTournamentParticipantSummary(
        tournamentId: tournamentId,
        tournament: tournament,
      );
    }
    return participant;
  }

  Future<void> removeParticipant({
    required String participantId,
    required String actorId,
    bool refreshTournamentSummary = true,
  }) async {
    final participant = await _loadParticipant(participantId);
    if (participant.status == TournamentParticipantStatus.finalized) {
      throw Exception(
        'لا يمكن حذف participant finalized. استخدم withdraw أو replace.',
      );
    }
    await _participantsRef.doc(participantId).delete();
    final tournament = await _loadTournament(participant.tournamentId);
    await _auditEmitter.participantWithdrawn(
      tournament: tournament,
      actorId: actorId,
      participantId: participant.id,
      beforePayload: {'status': participant.status.name},
      afterPayload: {'deleted': true},
    );
    if (refreshTournamentSummary) {
      await refreshTournamentParticipantSummary(
        tournamentId: participant.tournamentId,
        tournament: tournament,
      );
    }
  }

  Future<TournamentParticipant> withdrawParticipant({
    required String participantId,
    required String actorId,
    DateTime? now,
    bool refreshTournamentSummary = true,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final participant = await _loadParticipant(participantId);
    if (participant.status == TournamentParticipantStatus.withdrawn) {
      return participant;
    }
    final updated = participant.copyWith(
      status: TournamentParticipantStatus.withdrawn,
      withdrawnAt: effectiveNow,
      updatedAt: effectiveNow,
    );
    await _participantsRef
        .doc(participantId)
        .update(TournamentParticipantModel.fromEntity(updated).toJson());
    final tournament = await _loadTournament(participant.tournamentId);
    await _auditEmitter.participantWithdrawn(
      tournament: tournament,
      actorId: actorId,
      participantId: updated.id,
      beforePayload: {'status': participant.status.name},
      afterPayload: {'status': updated.status.name},
    );
    if (refreshTournamentSummary) {
      await refreshTournamentParticipantSummary(
        tournamentId: participant.tournamentId,
        tournament: tournament,
      );
    }
    return updated;
  }

  Future<TournamentParticipant> reactivateParticipant({
    required String participantId,
    required String actorId,
    DateTime? now,
    bool refreshTournamentSummary = true,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final participant = await _loadParticipant(participantId);
    final tournament = await _loadTournament(participant.tournamentId);
    _assertCanReactivateParticipant(tournament);
    if (participant.isActive) {
      return participant;
    }

    final reactivatedStatus = tournament.participantListFinalizedAt != null
        ? TournamentParticipantStatus.finalized
        : TournamentParticipantStatus.approved;
    final reactivated = participant.copyWith(
      status: reactivatedStatus,
      replacedByParticipantId: null,
      withdrawnAt: null,
      replacedAt: null,
      updatedAt: effectiveNow,
    );

    final batch = _firestore.batch();
    batch.update(
      _participantsRef.doc(reactivated.id),
      TournamentParticipantModel.fromEntity(reactivated).toJson(),
    );

    TournamentParticipant? withdrawnReplacement;
    if (participant.status == TournamentParticipantStatus.replaced &&
        participant.replacedByParticipantId != null &&
        participant.replacedByParticipantId!.isNotEmpty) {
      final replacement = await getParticipantById(
        participant.replacedByParticipantId!,
      );
      if (replacement != null &&
          replacement.replacementForParticipantId == participant.id &&
          replacement.isActive) {
        withdrawnReplacement = replacement.copyWith(
          status: TournamentParticipantStatus.withdrawn,
          withdrawnAt: effectiveNow,
          updatedAt: effectiveNow,
        );
        batch.update(
          _participantsRef.doc(withdrawnReplacement.id),
          TournamentParticipantModel.fromEntity(withdrawnReplacement).toJson(),
        );
      }
    }

    await batch.commit();
    await _auditEmitter.participantReactivated(
      tournament: tournament,
      actorId: actorId,
      participantId: reactivated.id,
      beforePayload: {
        'status': participant.status.name,
        'replacedByParticipantId': participant.replacedByParticipantId,
      },
      afterPayload: {
        'status': reactivated.status.name,
        'replacementWithdrawnId': withdrawnReplacement?.id,
      },
    );
    if (refreshTournamentSummary) {
      await refreshTournamentParticipantSummary(
        tournamentId: participant.tournamentId,
        tournament: tournament,
      );
    }
    return reactivated;
  }

  Future<TournamentParticipant> replaceParticipant({
    required String participantId,
    required TournamentParticipantSourceType replacementSourceType,
    required String replacementSourceEntityId,
    required String actorId,
    DateTime? now,
    bool refreshTournamentSummary = true,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final current = await _loadParticipant(participantId);
    final tournament = await _loadTournament(current.tournamentId);
    _assertCanReplaceParticipant(tournament);
    if (!current.isActive) {
      throw Exception('لا يمكن استبدال participant غير نشط.');
    }
    final replacement = await _loadSource(
      sourceType: replacementSourceType,
      sourceEntityId: replacementSourceEntityId,
    );
    final replacementId = participantIdFor(
      tournamentId: current.tournamentId,
      sourceType: replacementSourceType,
      sourceEntityId: replacementSourceEntityId,
    );
    if (replacementId == current.id) {
      throw Exception('لا يمكن استبدال participant بنفسه.');
    }
    final replacementSnapshot = await _participantsRef.doc(replacementId).get();
    if (replacementSnapshot.exists && replacementSnapshot.data() != null) {
      throw Exception('البديل المختار موجود بالفعل داخل البطولة.');
    }
    final replacementParticipant = TournamentParticipant(
      id: replacementId,
      tournamentId: current.tournamentId,
      sourceType: replacementSourceType,
      sourceEntityId: replacementSourceEntityId,
      displayName: replacement.displayName,
      status: current.status == TournamentParticipantStatus.finalized
          ? TournamentParticipantStatus.finalized
          : TournamentParticipantStatus.approved,
      seed: current.seed,
      groupId: current.groupId,
      replacementForParticipantId: current.id,
      createdAt: effectiveNow,
      updatedAt: effectiveNow,
      approvedAt: effectiveNow,
      finalizedAt: current.status == TournamentParticipantStatus.finalized
          ? effectiveNow
          : null,
    );
    final replaced = current.copyWith(
      status: TournamentParticipantStatus.replaced,
      replacedByParticipantId: replacementParticipant.id,
      replacedAt: effectiveNow,
      updatedAt: effectiveNow,
    );
    final batch = _firestore.batch();
    batch.set(
      _participantsRef.doc(replacementParticipant.id),
      TournamentParticipantModel.fromEntity(replacementParticipant).toJson(),
    );
    batch.update(
      _participantsRef.doc(replaced.id),
      TournamentParticipantModel.fromEntity(replaced).toJson(),
    );
    await batch.commit();
    await _auditEmitter.participantReplaced(
      tournament: tournament,
      actorId: actorId,
      participantId: replaced.id,
      beforePayload: {
        'status': current.status.name,
        'displayName': current.displayName,
      },
      afterPayload: {
        'status': replaced.status.name,
        'replacedByParticipantId': replacementParticipant.id,
      },
    );
    await _auditEmitter.participantAdded(
      tournament: tournament,
      actorId: actorId,
      participantId: replacementParticipant.id,
      afterPayload: {
        'sourceType': replacementParticipant.sourceType.name,
        'sourceEntityId': replacementParticipant.sourceEntityId,
        'displayName': replacementParticipant.displayName,
        'replacementForParticipantId': current.id,
      },
    );
    if (refreshTournamentSummary) {
      await refreshTournamentParticipantSummary(
        tournamentId: current.tournamentId,
        tournament: tournament,
      );
    }
    return replacementParticipant;
  }

  Future<TournamentParticipant> updateParticipantSeed({
    required String participantId,
    required String actorId,
    int? seed,
    DateTime? now,
  }) async {
    if (seed != null && seed <= 0) {
      throw Exception('الـ seed يجب أن تكون رقمًا موجبًا.');
    }
    final effectiveNow = now ?? DateTime.now();
    final participant = await _loadParticipant(participantId);
    final tournament = await _loadTournament(participant.tournamentId);
    _assertCanEditParticipantSeed(tournament);
    if (!participant.isActive) {
      throw Exception('لا يمكن تعديل seed لمشارك غير نشط.');
    }
    if (participant.seed == seed) {
      return participant;
    }

    final updated = participant.copyWith(seed: seed, updatedAt: effectiveNow);
    await _participantsRef
        .doc(participantId)
        .update(TournamentParticipantModel.fromEntity(updated).toJson());
    await _auditEmitter.participantSeedUpdated(
      tournament: tournament,
      actorId: actorId,
      participantId: updated.id,
      beforePayload: {'seed': participant.seed},
      afterPayload: {'seed': updated.seed},
    );
    return updated;
  }

  Future<int> refreshTournamentParticipantSummary({
    required String tournamentId,
    Tournament? tournament,
  }) async {
    final participants = await getTournamentParticipants(tournamentId);
    final activeCount = participants
        .where(
          (participant) =>
              participant.status == TournamentParticipantStatus.approved ||
              participant.status == TournamentParticipantStatus.finalized,
        )
        .length;
    final currentTournament = tournament ?? await _loadTournament(tournamentId);
    if (currentTournament.activeParticipantCount != null &&
        currentTournament.activeParticipantCount == activeCount) {
      return activeCount;
    }
    await _tournamentsRef.doc(tournamentId).update({
      'activeParticipantCount': activeCount,
    });
    return activeCount;
  }

  bool _hasSameSyncedParticipantState(
    TournamentParticipant existing,
    TournamentParticipant desired,
  ) {
    return existing.tournamentId == desired.tournamentId &&
        existing.sourceType == desired.sourceType &&
        existing.sourceEntityId == desired.sourceEntityId &&
        existing.displayName == desired.displayName &&
        existing.status == desired.status &&
        existing.seed == desired.seed &&
        existing.groupId == desired.groupId &&
        existing.sourceRegistrationId == desired.sourceRegistrationId &&
        existing.replacementForParticipantId ==
            desired.replacementForParticipantId &&
        existing.replacedByParticipantId == desired.replacedByParticipantId &&
        _sameInstant(existing.createdAt, desired.createdAt) &&
        _sameInstant(existing.approvedAt, desired.approvedAt) &&
        _sameInstant(existing.finalizedAt, desired.finalizedAt) &&
        _sameInstant(existing.withdrawnAt, desired.withdrawnAt) &&
        _sameInstant(existing.replacedAt, desired.replacedAt);
  }

  bool _sameInstant(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return left.millisecondsSinceEpoch == right.millisecondsSinceEpoch;
  }

  Future<Tournament> _loadTournament(String tournamentId) async {
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على البطولة المرتبطة بالمشارك.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<TournamentParticipant> _loadParticipant(String participantId) async {
    final participant = await getParticipantById(participantId);
    if (participant == null) {
      throw Exception('المشارك المطلوب غير موجود.');
    }
    return participant;
  }

  Future<_ParticipantSource> _loadSourceForRegistration(
    TournamentRegistration registration,
  ) {
    if (registration.teamId != null && registration.teamId!.isNotEmpty) {
      return _loadSource(
        sourceType: TournamentParticipantSourceType.registeredTeam,
        sourceEntityId: registration.teamId!,
      );
    }
    return _loadSource(
      sourceType: TournamentParticipantSourceType.guestTeam,
      sourceEntityId: registration.guestTeamId!,
    );
  }

  Future<_ParticipantSource> _loadSource({
    required TournamentParticipantSourceType sourceType,
    required String sourceEntityId,
  }) async {
    switch (sourceType) {
      case TournamentParticipantSourceType.registeredTeam:
        final snapshot = await _teamsRef.doc(sourceEntityId).get();
        if (!snapshot.exists || snapshot.data() == null) {
          throw Exception('الفريق المسجل المطلوب غير موجود.');
        }
        final team = TeamModel.fromJson(
          snapshot.data()!,
          snapshot.id,
        ).toEntity();
        return _ParticipantSource(
          entityId: team.id,
          displayName: team.name,
          sourceType: sourceType,
        );
      case TournamentParticipantSourceType.guestTeam:
        final snapshot = await _guestTeamsRef.doc(sourceEntityId).get();
        if (!snapshot.exists || snapshot.data() == null) {
          throw Exception('الفريق الضيف المطلوب غير موجود.');
        }
        final guestTeam = GuestTeamModel.fromJson(
          snapshot.data()!,
          snapshot.id,
        ).toEntity();
        return _ParticipantSource(
          entityId: guestTeam.id,
          displayName: guestTeam.name,
          sourceType: sourceType,
        );
    }
  }

  void _assertCanAddManualParticipant(Tournament tournament) {
    if (tournament.needsManualOpsMigration) {
      throw Exception(
        'هذه البطولة تحتاج manual ops migration قبل تعديل المشاركين.',
      );
    }
    if (tournament.participantListFinalizedAt != null) {
      throw Exception(
        'لا يمكن إضافة participant يدويًا بعد قفل قائمة المشاركين.',
      );
    }
    if (_hasOperationalStageStarted(tournament)) {
      throw Exception(
        'لا يمكن إضافة participant يدويًا بعد بدء تشغيل البطولة.',
      );
    }
  }

  void _assertCanReplaceParticipant(Tournament tournament) {
    if (tournament.needsManualOpsMigration) {
      throw Exception(
        'هذه البطولة تحتاج manual ops migration قبل تعديل المشاركين.',
      );
    }
    if (_hasOperationalStageStarted(tournament)) {
      throw Exception('لا يمكن استبدال participant بعد بدء تشغيل البطولة.');
    }
  }

  void _assertCanReactivateParticipant(Tournament tournament) {
    if (tournament.needsManualOpsMigration) {
      throw Exception(
        'هذه البطولة تحتاج manual ops migration قبل تعديل المشاركين.',
      );
    }
    if (_hasOperationalStageStarted(tournament)) {
      throw Exception('لا يمكن إعادة تفعيل participant بعد بدء تشغيل البطولة.');
    }
  }

  void _assertCanEditParticipantSeed(Tournament tournament) {
    if (tournament.needsManualOpsMigration) {
      throw Exception(
        'هذه البطولة تحتاج manual ops migration قبل تعديل المشاركين.',
      );
    }
    if (_hasOperationalStageStarted(tournament)) {
      throw Exception('لا يمكن تعديل seed بعد بدء تشغيل البطولة.');
    }
  }

  bool _hasOperationalStageStarted(Tournament tournament) {
    return (tournament.currentGroupStageId != null &&
            tournament.currentGroupStageId!.isNotEmpty) ||
        (tournament.currentKnockoutBracketId != null &&
            tournament.currentKnockoutBracketId!.isNotEmpty);
  }
}

class _ParticipantSource {
  final String entityId;
  final String displayName;
  final TournamentParticipantSourceType sourceType;

  const _ParticipantSource({
    required this.entityId,
    required this.displayName,
    required this.sourceType,
  });
}
