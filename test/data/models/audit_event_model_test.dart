import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/audit_action.dart';
import 'package:el7reef/data/models/audit_event_model.dart';
import 'package:el7reef/domain/entities/audit_event.dart';

void main() {
  test('missing provenance is always treated as legacy unverified', () {
    final event = AuditEventModel.fromJson({
      'entityType': 'match',
      'entityId': 'match-1',
      'action': 'matchCreated',
      'actorId': 'organizer-1',
      'createdAt': 1,
    }, 'legacy-1').toEntity();

    expect(event.provenance, AuditEventProvenance.legacyUnverified);
    expect(event.isTrusted, isFalse);
  });

  test('trusted provenance requires source, version, and request id', () {
    final event = AuditEventModel.fromJson({
      'entityType': 'match',
      'entityId': 'match-1',
      'action': 'matchScoreApproved',
      'actorId': 'organizer-1',
      'source': 'trustedOperation',
      'verificationVersion': 1,
      'requestId': 'approval-request-1',
      'createdAt': 1,
    }, 'trusted-1').toEntity();

    expect(event.provenance, AuditEventProvenance.trustedOperation);
    expect(event.isTrusted, isTrue);
  });

  test('a partial or forged provenance marker remains unverified', () {
    final event = AuditEventModel.fromJson({
      'entityType': 'match',
      'entityId': 'match-1',
      'action': 'matchScoreApproved',
      'actorId': 'organizer-1',
      'source': 'trustedOperation',
      'verificationVersion': 1,
      'createdAt': 1,
    }, 'partial-1').toEntity();

    expect(event.provenance, AuditEventProvenance.legacyUnverified);
  });

  test('trusted safety actions keep their opaque entity types', () {
    final cases = <(String, AuditEntityType, String, AuditAction)>[
      (
        'moderationReport',
        AuditEntityType.moderationReport,
        'profileReported',
        AuditAction.profileReported,
      ),
      (
        'safetyRelationship',
        AuditEntityType.safetyRelationship,
        'playerBlocked',
        AuditAction.playerBlocked,
      ),
      (
        'safetyRelationship',
        AuditEntityType.safetyRelationship,
        'playerUnblocked',
        AuditAction.playerUnblocked,
      ),
    ];

    for (final testCase in cases) {
      final event = AuditEventModel.fromJson({
        'entityType': testCase.$1,
        'entityId': 'opaque-relationship-id',
        'action': testCase.$3,
        'actorId': 'player-1',
        'source': 'trustedOperation',
        'verificationVersion': 1,
        'requestId': 'safety-request-1',
        'createdAt': 1,
      }, 'safety-event').toEntity();

      expect(event.entityType, testCase.$2);
      expect(event.action, testCase.$4);
      expect(event.isTrusted, isTrue);
    }
  });

  test('account deletion audit keeps its pseudonymous lifecycle type', () {
    final event = AuditEventModel.fromJson({
      'entityType': 'accountDeletion',
      'entityId': 'deleted-opaque-id',
      'action': 'accountDeletionCompleted',
      'actorId': 'deleted-opaque-id',
      'source': 'trustedOperation',
      'verificationVersion': 1,
      'requestId': 'deleted-opaque-id:completed:1',
      'createdAt': 1,
    }, 'deletion-event').toEntity();

    expect(event.entityType, AuditEntityType.accountDeletion);
    expect(event.action, AuditAction.accountDeletionCompleted);
    expect(event.isTrusted, isTrue);
  });
}
