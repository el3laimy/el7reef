import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:el7reef/core/enums/audit_action.dart';
import 'package:el7reef/core/services/audit_service.dart';
import 'package:el7reef/domain/entities/audit_event.dart';
import 'package:el7reef/domain/repositories/audit_repository.dart';
import 'package:el7reef/features/organizer/controllers/audit_timeline_controller.dart';
import 'package:el7reef/features/organizer/views/audit_timeline_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  tearDown(Get.reset);

  testWidgets('timeline labels old events as unverified', (tester) async {
    final event = AuditEvent(
      id: 'legacy-1',
      entityType: AuditEntityType.match,
      entityId: 'match-1',
      action: AuditAction.matchCreated,
      actorId: 'organizer-1',
      createdAt: DateTime(2026, 7, 29),
    );
    Get.put(
      AuditTimelineController(
        entityId: 'match-1',
        entityType: AuditEntityType.match,
        auditService: AuditService(repository: _TimelineRepository([event])),
      ),
    );

    await tester.pumpWidget(const GetMaterialApp(home: AuditTimelineScreen()));
    await tester.pumpAndSettle();

    expect(find.text('تم إنشاء المباراة'), findsOneWidget);
    expect(find.text('قديم غير موثق'), findsOneWidget);
  });

  testWidgets('timeline does not label trusted events as legacy', (
    tester,
  ) async {
    final event = AuditEvent(
      id: 'trusted-1',
      entityType: AuditEntityType.match,
      entityId: 'match-1',
      action: AuditAction.matchScoreApproved,
      actorId: 'organizer-1',
      source: 'trustedOperation',
      verificationVersion: 1,
      requestId: 'approval-request-1',
      createdAt: DateTime(2026, 7, 29),
    );
    Get.put(
      AuditTimelineController(
        entityId: 'match-1',
        entityType: AuditEntityType.match,
        auditService: AuditService(repository: _TimelineRepository([event])),
      ),
    );

    await tester.pumpWidget(const GetMaterialApp(home: AuditTimelineScreen()));
    await tester.pumpAndSettle();

    expect(find.text('تم اعتماد النتيجة'), findsOneWidget);
    expect(find.text('قديم غير موثق'), findsNothing);
  });
}

class _TimelineRepository implements AuditRepository {
  final List<AuditEvent> events;

  _TimelineRepository(this.events);

  @override
  Future<List<AuditEvent>> getEntityAuditEvents({
    required AuditEntityType entityType,
    required String entityId,
    int limit = 50,
  }) async => events;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
