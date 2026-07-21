import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/audit_action.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
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

  Future<void> fixtureStarted({
    required Tournament tournament,
    required String actorId,
    required String matchId,
    required DateTime startedAt,
    required int teamAProjectedPlayers,
    required int teamBProjectedPlayers,
  }) {
    return _auditService.recordMatchEvent(
      matchId: matchId,
      action: AuditAction.fixtureStarted,
      actorId: actorId,
      metadata: {
        'tournamentId': tournament.id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'teamAProjectedPlayers': teamAProjectedPlayers,
        'teamBProjectedPlayers': teamBProjectedPlayers,
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
    required KnockoutSeedingMethod seedingMethod,
    required List<String> qualifierParticipantIds,
    required List<String> byeParticipantIds,
  }) {
    return _auditService.recordTournamentEvent(
      tournamentId: tournament.id,
      action: AuditAction.knockoutGenerated,
      actorId: actorId,
      metadata: {
        'bracketId': bracketId,
        'tiesCount': tiesCount,
        'seedingMethod': seedingMethod.name,
        'qualifierParticipantIds': qualifierParticipantIds,
        'byeParticipantIds': byeParticipantIds,
      },
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

  Future<void> guestPlayerCreated({
    required Tournament tournament,
    required String guestTeamId,
    required String actorId,
    required GuestPlayer guestPlayer,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.guestPlayer,
      entityId: guestPlayer.id,
      action: AuditAction.guestPlayerCreated,
      actorId: actorId,
      afterPayload: _guestPlayerPayload(guestPlayer),
      metadata: {'tournamentId': tournament.id, 'guestTeamId': guestTeamId},
    );
  }

  Future<void> guestPlayerUpdated({
    required Tournament tournament,
    required String guestTeamId,
    required String actorId,
    required GuestPlayer before,
    required GuestPlayer after,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.guestPlayer,
      entityId: after.id,
      action: AuditAction.guestPlayerUpdated,
      actorId: actorId,
      beforePayload: _guestPlayerPayload(before),
      afterPayload: _guestPlayerPayload(after),
      metadata: {'tournamentId': tournament.id, 'guestTeamId': guestTeamId},
    );
  }

  Future<void> guestPlayerArchived({
    required Tournament tournament,
    required String guestTeamId,
    required String actorId,
    required GuestPlayer before,
    required GuestPlayer after,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.guestPlayer,
      entityId: after.id,
      action: AuditAction.guestPlayerArchived,
      actorId: actorId,
      beforePayload: _guestPlayerPayload(before),
      afterPayload: _guestPlayerPayload(after),
      metadata: {'tournamentId': tournament.id, 'guestTeamId': guestTeamId},
    );
  }

  Future<void> guestTeamCaptainUpdated({
    required Tournament tournament,
    required String actorId,
    required GuestTeam before,
    required GuestTeam after,
  }) {
    return _auditService.record(
      entityType: AuditEntityType.guestTeam,
      entityId: after.id,
      action: AuditAction.guestTeamCaptainUpdated,
      actorId: actorId,
      beforePayload: _guestTeamPayload(before),
      afterPayload: _guestTeamPayload(after),
      metadata: {'tournamentId': tournament.id},
    );
  }

  Map<String, dynamic> _guestPlayerPayload(GuestPlayer guestPlayer) {
    return {
      'displayName': guestPlayer.displayName,
      'normalizedName': guestPlayer.normalizedName,
      'phoneNumber': guestPlayer.phoneNumber,
      'jerseyNumber': guestPlayer.jerseyNumber,
      'preferredPosition': guestPlayer.preferredPosition,
      'teamId': guestPlayer.teamId,
      'guestTeamId': guestPlayer.guestTeamId,
      'tournamentId': guestPlayer.tournamentId,
      'claimStatus': guestPlayer.claimStatus.name,
      'linkedPlayerId': guestPlayer.linkedPlayerId,
      'notes': guestPlayer.notes,
    };
  }

  Map<String, dynamic> _guestTeamPayload(GuestTeam guestTeam) {
    return {
      'name': guestTeam.name,
      'captainGuestPlayerId': guestTeam.captainGuestPlayerId,
      'linkedTeamId': guestTeam.linkedTeamId,
      'claimStatus': guestTeam.claimStatus.name,
      'tournamentIds': guestTeam.tournamentIds,
    };
  }
}
