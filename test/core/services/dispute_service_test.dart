import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/dispute_enums.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/services/audit_service.dart';
import 'package:el7reef/core/services/dispute_service.dart';
import 'package:el7reef/data/repositories/audit_repository_impl.dart';
import 'package:el7reef/data/repositories/dispute_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';

void main() {
  group('DisputeService', () {
    late FakeFirebaseFirestore firestore;
    late DisputeService service;
    late MatchRepositoryImpl matchRepository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      matchRepository = MatchRepositoryImpl(db: firestore);
      service = DisputeService(
        disputeRepository: DisputeRepositoryImpl(db: firestore),
        matchRepository: matchRepository,
        auditService: AuditService(
          repository: AuditRepositoryImpl(db: firestore),
        ),
      );
    });

    Future<void> _seedMatch(String matchId, {MatchStatus status = MatchStatus.completed}) async {
      await matchRepository.createMatch(
        Match(
          id: matchId,
          organizerId: 'organizer-1',
          status: status,
          scoreTeamA: 3,
          scoreTeamB: 1,
          createdAt: DateTime(2026, 4, 17, 18),
        ),
      );
    }

    test('opens a score dispute and auto-freezes the match', () async {
      await _seedMatch('match-1');
      final now = DateTime(2026, 4, 17, 20);

      final result = await service.openDispute(
        matchId: 'match-1',
        type: DisputeType.scoreDispute,
        raisedBy: 'player-1',
        description: 'النتيجة الحقيقية كانت 2-1',
        now: now,
      );

      expect(result.dispute.status, DisputeStatus.open);
      expect(result.dispute.matchId, 'match-1');
      expect(result.matchFrozen, isTrue);

      // التحقق من تجميد المباراة
      final matchDoc = await firestore
          .collection(FirebasePaths.matches)
          .doc('match-1')
          .get();
      expect(matchDoc.data()?['isFrozen'], isTrue);
      expect(matchDoc.data()?['status'], MatchStatus.frozen.name);

      // التحقق من وجود audit events
      final auditDocs = await firestore
          .collection(FirebasePaths.auditEvents)
          .get();
      expect(auditDocs.docs.length, greaterThanOrEqualTo(2)); // dispute opened + match frozen
    });

    test('opens a lineup dispute without freezing the match', () async {
      await _seedMatch('match-2');
      final now = DateTime(2026, 4, 17, 20);

      final result = await service.openDispute(
        matchId: 'match-2',
        type: DisputeType.lineupDispute,
        raisedBy: 'player-2',
        description: 'لاعب غير مسجل شارك',
        now: now,
      );

      expect(result.matchFrozen, isFalse);
      expect(result.dispute.type, DisputeType.lineupDispute);
    });

    test('rejects opening a duplicate dispute of the same type', () async {
      await _seedMatch('match-3');
      final now = DateTime(2026, 4, 17, 20);

      await service.openDispute(
        matchId: 'match-3',
        type: DisputeType.scoreDispute,
        raisedBy: 'player-1',
        description: 'أول نزاع',
        now: now,
      );

      expect(
        () => service.openDispute(
          matchId: 'match-3',
          type: DisputeType.scoreDispute,
          raisedBy: 'player-2',
          description: 'نزاع ثاني',
          now: now.add(const Duration(minutes: 5)),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('نزاع مفتوح بالفعل'),
        )),
      );
    });

    test('resolves a dispute and unfreezes the match', () async {
      await _seedMatch('match-4');
      final now = DateTime(2026, 4, 17, 20);

      final opened = await service.openDispute(
        matchId: 'match-4',
        type: DisputeType.scoreDispute,
        raisedBy: 'player-1',
        description: 'نتيجة خاطئة',
        now: now,
      );

      final resolved = await service.resolveDispute(
        disputeId: opened.dispute.id,
        resolvedBy: 'organizer-1',
        resolutionNote: 'تم تصحيح النتيجة إلى 2-1',
        now: now.add(const Duration(hours: 2)),
      );

      expect(resolved.status, DisputeStatus.resolved);
      expect(resolved.resolvedBy, 'organizer-1');
      expect(resolved.resolutionNote, 'تم تصحيح النتيجة إلى 2-1');

      // التحقق من رفع التجميد
      final matchDoc = await firestore
          .collection(FirebasePaths.matches)
          .doc('match-4')
          .get();
      expect(matchDoc.data()?['isFrozen'], isFalse);
    });

    test('rejects a dispute and unfreezes the match', () async {
      await _seedMatch('match-5');
      final now = DateTime(2026, 4, 17, 20);

      final opened = await service.openDispute(
        matchId: 'match-5',
        type: DisputeType.scoreDispute,
        raisedBy: 'player-1',
        description: 'اعتراض',
        now: now,
      );

      final rejected = await service.rejectDispute(
        disputeId: opened.dispute.id,
        rejectedBy: 'organizer-1',
        rejectionNote: 'النتيجة المسجلة صحيحة',
        now: now.add(const Duration(hours: 1)),
      );

      expect(rejected.status, DisputeStatus.rejected);
    });

    test('cannot resolve an already-closed dispute', () async {
      await _seedMatch('match-6');
      final now = DateTime(2026, 4, 17, 20);

      final opened = await service.openDispute(
        matchId: 'match-6',
        type: DisputeType.mvpDispute,
        raisedBy: 'player-1',
        description: 'اعتراض على MVP',
        now: now,
      );

      await service.resolveDispute(
        disputeId: opened.dispute.id,
        resolvedBy: 'organizer-1',
        resolutionNote: 'تمت المراجعة',
        now: now.add(const Duration(hours: 1)),
      );

      expect(
        () => service.resolveDispute(
          disputeId: opened.dispute.id,
          resolvedBy: 'organizer-1',
          resolutionNote: 'محاولة ثانية',
          now: now.add(const Duration(hours: 2)),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('مغلق بالفعل'),
        )),
      );
    });

    test('expires overdue disputes automatically', () async {
      await _seedMatch('match-7');
      final now = DateTime(2026, 4, 17, 20);

      await service.openDispute(
        matchId: 'match-7',
        type: DisputeType.ratingDispute,
        raisedBy: 'player-1',
        description: 'تقييم غير عادل',
        deadlineDuration: const Duration(hours: 2),
        now: now,
      );

      // قبل انتهاء المهلة — لا شيء يتغير
      final beforeExpiry = await service.expireOverdueDisputes(
        matchId: 'match-7',
        now: now.add(const Duration(hours: 1)),
      );
      expect(beforeExpiry, isEmpty);

      // بعد انتهاء المهلة
      final afterExpiry = await service.expireOverdueDisputes(
        matchId: 'match-7',
        now: now.add(const Duration(hours: 3)),
      );
      expect(afterExpiry, hasLength(1));
      expect(afterExpiry.first.status, DisputeStatus.expired);
    });

    test('retrieves all match disputes', () async {
      await _seedMatch('match-8');
      final now = DateTime(2026, 4, 17, 20);

      await service.openDispute(
        matchId: 'match-8',
        type: DisputeType.scoreDispute,
        raisedBy: 'player-1',
        description: 'نتيجة خاطئة',
        now: now,
      );
      await service.openDispute(
        matchId: 'match-8',
        type: DisputeType.lineupDispute,
        raisedBy: 'player-2',
        description: 'تشكيلة غير صحيحة',
        now: now.add(const Duration(minutes: 5)),
      );

      final disputes = await service.getMatchDisputes('match-8');
      expect(disputes, hasLength(2));
    });
  });
}
