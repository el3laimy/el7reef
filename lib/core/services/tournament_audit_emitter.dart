import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/audit_action.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/tournament.dart';
import 'audit_service.dart';

class TournamentAuditEmitter {
  final AuditService _auditService;

  TournamentAuditEmitter({
    AuditService? auditService,
    FirebaseFirestore? firestore,
  }) : _auditService =
           auditService ??
           AuditService(repository: AuditRepositoryImpl(db: firestore));

  Future<void> participantAdded({
    required Tournament tournament,
    required String actorId,
    required String participantId,
    required Map<String, dynamic> afterPayload,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.tournamentParticipant,
      entityId: participantId,
      action: AuditAction.participantAdded,
      actorId: actorId,
      afterPayload: afterPayload,
      metadata: {'tournamentId': tournament.id},
    );
  }

  Future<void> participantReplaced({
    required Tournament tournament,
    required String actorId,
    required String participantId,
    required Map<String, dynamic> beforePayload,
    required Map<String, dynamic> afterPayload,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.tournamentParticipant,
      entityId: participantId,
      action: AuditAction.participantReplaced,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: {'tournamentId': tournament.id},
    );
  }

  Future<void> participantWithdrawn({
    required Tournament tournament,
    required String actorId,
    required String participantId,
    required Map<String, dynamic> beforePayload,
    required Map<String, dynamic> afterPayload,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.tournamentParticipant,
      entityId: participantId,
      action: AuditAction.participantWithdrawn,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: {'tournamentId': tournament.id},
    );
  }

  Future<void> participantReactivated({
    required Tournament tournament,
    required String actorId,
    required String participantId,
    required Map<String, dynamic> beforePayload,
    required Map<String, dynamic> afterPayload,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.tournamentParticipant,
      entityId: participantId,
      action: AuditAction.participantReactivated,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: {'tournamentId': tournament.id},
    );
  }

  Future<void> participantSeedUpdated({
    required Tournament tournament,
    required String actorId,
    required String participantId,
    required Map<String, dynamic> beforePayload,
    required Map<String, dynamic> afterPayload,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.tournamentParticipant,
      entityId: participantId,
      action: AuditAction.participantSeedUpdated,
      actorId: actorId,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      metadata: {'tournamentId': tournament.id},
    );
  }

  Future<void> participantsFinalized({
    required Tournament tournament,
    required String actorId,
    required int participantCount,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.participantsFinalized,
      actorId: actorId,
      metadata: {'participantCount': participantCount},
    );
  }

  Future<void> groupStageGenerated({
    required Tournament tournament,
    required String actorId,
    required String groupStageId,
    required int groupsCount,
    required int fixturesCount,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.groupStageGenerated,
      actorId: actorId,
      metadata: {
        'groupStageId': groupStageId,
        'groupsCount': groupsCount,
        'fixturesCount': fixturesCount,
      },
    );
  }

  Future<void> groupStageRegenerated({
    required Tournament tournament,
    required String actorId,
    required String groupStageId,
    required int groupsCount,
    required int fixturesCount,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.groupStageRegenerated,
      actorId: actorId,
      metadata: {
        'groupStageId': groupStageId,
        'groupsCount': groupsCount,
        'fixturesCount': fixturesCount,
      },
    );
  }

  Future<void> fixtureScheduled({
    required Tournament tournament,
    required String actorId,
    required String matchId,
    required DateTime scheduledAt,
    required String? venueId,
  }) {
    return _auditService.recordMatchEvent(
      matchId: matchId,
      action: AuditAction.fixtureScheduled,
      actorId: actorId,
      metadata: {
        'tournamentId': tournament.id,
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
        'venueId': venueId,
      },
    );
  }

  Future<void> fixturesPublished({
    required Tournament tournament,
    required String actorId,
    required int fixturesCount,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.fixturesPublished,
      actorId: actorId,
      metadata: {'fixturesCount': fixturesCount},
    );
  }

  Future<void> knockoutGenerated({
    required Tournament tournament,
    required String actorId,
    required String bracketId,
    required int tiesCount,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.knockoutGenerated,
      actorId: actorId,
      metadata: {'bracketId': bracketId, 'tiesCount': tiesCount},
    );
  }

  Future<void> tournamentCompleted({
    required Tournament tournament,
    required String actorId,
    required String? winnerParticipantId,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.tournamentCompleted,
      actorId: actorId,
      metadata: {'winnerParticipantId': winnerParticipantId},
    );
  }
}
