import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/audit_action.dart';
import 'package:el7reef/core/services/audit_service.dart';
import 'package:el7reef/data/repositories/audit_repository_impl.dart';

void main() {
  group('AuditService', () {
    late FakeFirebaseFirestore firestore;
    late AuditService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = AuditService(
        repository: AuditRepositoryImpl(db: firestore),
      );
    });

    test('records a match event and retrieves it by entity id', () async {
      final now = DateTime(2026, 4, 17, 20);
      final event = await service.recordMatchEvent(
        matchId: 'match-1',
        action: AuditAction.matchScoreApproved,
        actorId: 'organizer-1',
        afterPayload: {'scoreTeamA': 3, 'scoreTeamB': 1},
        now: now,
      );

      expect(event.id, isNotEmpty);
      expect(event.entityType, AuditEntityType.match);
      expect(event.entityId, 'match-1');
      expect(event.action, AuditAction.matchScoreApproved);
      expect(event.actorId, 'organizer-1');
      expect(event.afterPayload?['scoreTeamA'], 3);

      final doc = await firestore
          .collection(FirebasePaths.auditEvents)
          .doc(event.id)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['entityType'], 'match');
      expect(doc.data()?['action'], 'matchScoreApproved');
    });

    test('records a tournament event with metadata', () async {
      final event = await service.recordTournamentEvent(
        tournamentId: 'tournament-1',
        action: AuditAction.tournamentStatusChanged,
        actorId: 'organizer-1',
        metadata: {'from': 'registration', 'to': 'groupStage'},
        now: DateTime(2026, 4, 17, 21),
      );

      expect(event.entityType, AuditEntityType.tournament);
      expect(event.metadata?['from'], 'registration');
    });

    test('records a claim event with before/after diff', () async {
      final event = await service.recordClaimEvent(
        entityType: AuditEntityType.guestPlayer,
        entityId: 'guest-player-1',
        action: AuditAction.guestPlayerClaimed,
        actorId: 'player-1',
        beforePayload: {'claimStatus': 'guest', 'linkedPlayerId': null},
        afterPayload: {'claimStatus': 'claimed', 'linkedPlayerId': 'player-1'},
        now: DateTime(2026, 4, 17, 22),
      );

      expect(event.hasDiff, isTrue);
      expect(event.beforePayload?['claimStatus'], 'guest');
      expect(event.afterPayload?['claimStatus'], 'claimed');
    });

    test('retrieves entity timeline in reverse chronological order', () async {
      final base = DateTime(2026, 4, 17, 20);
      await service.recordMatchEvent(
        matchId: 'match-2',
        action: AuditAction.matchCreated,
        actorId: 'organizer-1',
        now: base,
      );
      await service.recordMatchEvent(
        matchId: 'match-2',
        action: AuditAction.matchScoreSubmitted,
        actorId: 'organizer-1',
        now: base.add(const Duration(hours: 1)),
      );
      await service.recordMatchEvent(
        matchId: 'match-2',
        action: AuditAction.matchScoreApproved,
        actorId: 'organizer-1',
        now: base.add(const Duration(hours: 2)),
      );

      final timeline = await service.getEntityTimeline(
        entityType: AuditEntityType.match,
        entityId: 'match-2',
      );
      expect(timeline, hasLength(3));
      expect(timeline.first.action, AuditAction.matchScoreApproved);
      expect(timeline.last.action, AuditAction.matchCreated);
    });

    test('entity timeline isolates events by entity type and id together', () async {
      final base = DateTime(2026, 4, 18, 10);
      await service.recordMatchEvent(
        matchId: 'shared-id',
        action: AuditAction.matchCreated,
        actorId: 'organizer-1',
        now: base,
      );
      await service.recordTournamentEvent(
        tournamentId: 'shared-id',
        action: AuditAction.tournamentCreated,
        actorId: 'organizer-1',
        now: base.add(const Duration(minutes: 5)),
      );

      final matchTimeline = await service.getEntityTimeline(
        entityType: AuditEntityType.match,
        entityId: 'shared-id',
      );
      final tournamentTimeline = await service.getEntityTimeline(
        entityType: AuditEntityType.tournament,
        entityId: 'shared-id',
      );

      expect(matchTimeline, hasLength(1));
      expect(matchTimeline.single.action, AuditAction.matchCreated);
      expect(tournamentTimeline, hasLength(1));
      expect(tournamentTimeline.single.action, AuditAction.tournamentCreated);
    });

    test('retrieves actor history across different entities', () async {
      final now = DateTime(2026, 4, 17, 20);
      await service.recordMatchEvent(
        matchId: 'match-1',
        action: AuditAction.matchSettled,
        actorId: 'org-1',
        now: now,
      );
      await service.recordTournamentEvent(
        tournamentId: 'tournament-1',
        action: AuditAction.tournamentCreated,
        actorId: 'org-1',
        now: now.add(const Duration(minutes: 10)),
      );

      final history = await service.getActorHistory('org-1');
      expect(history, hasLength(2));
    });

    test('records a dispute event', () async {
      final event = await service.recordDisputeEvent(
        disputeId: 'dispute-1',
        action: AuditAction.disputeOpened,
        actorId: 'player-1',
        metadata: {'matchId': 'match-1', 'reason': 'نتيجة خاطئة'},
        now: DateTime(2026, 4, 17, 23),
      );

      expect(event.entityType, AuditEntityType.dispute);
      expect(event.action, AuditAction.disputeOpened);
      expect(event.metadata?['reason'], 'نتيجة خاطئة');
    });
  });
}
