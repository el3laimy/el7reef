import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/claim_code_status.dart';
import 'package:el7reef/core/enums/claim_payload_scope.dart';
import 'package:el7reef/core/enums/claim_target_type.dart';
import 'package:el7reef/data/repositories/claim_code_repository_impl.dart';
import 'package:el7reef/domain/entities/claim_code.dart';

void main() {
  group('ClaimCodeRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late ClaimCodeRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ClaimCodeRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 15, 12);
    });

    test('creates claim codes and fetches active target links', () async {
      final claimCode = ClaimCode(
        code: 'PLAYERCODE1',
        targetType: ClaimTargetType.guestPlayer,
        targetId: 'guest-player-1',
        scope: ClaimPayloadScope.team,
        teamId: 'team-1',
        createdBy: 'owner-1',
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
      );

      await repository.createClaimCode(claimCode);

      final loaded = await repository.getClaimCode('PLAYERCODE1');
      final active = await repository.getActiveClaimCodeForTarget(
        targetType: ClaimTargetType.guestPlayer,
        targetId: 'guest-player-1',
      );

      expect(loaded?.code, 'PLAYERCODE1');
      expect(active?.teamId, 'team-1');
      expect(active?.status, ClaimCodeStatus.active);
    });

    test('updates claim code status and stops returning expired entries', () async {
      final claimCode = ClaimCode(
        code: 'TEAMCODE001',
        targetType: ClaimTargetType.guestTeam,
        targetId: 'guest-team-1',
        scope: ClaimPayloadScope.tournament,
        tournamentId: 'tournament-1',
        createdBy: 'organizer-1',
        createdAt: now,
        updatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
      );

      await repository.createClaimCode(claimCode);
      await repository.updateClaimCode(
        claimCode.copyWith(
          status: ClaimCodeStatus.expired,
          updatedAt: now.add(const Duration(hours: 2)),
        ),
      );

      final active = await repository.getActiveClaimCodeForTarget(
        targetType: ClaimTargetType.guestTeam,
        targetId: 'guest-team-1',
        tournamentId: 'tournament-1',
      );
      final loaded = await repository.getClaimCode('TEAMCODE001');

      expect(active, isNull);
      expect(loaded?.status, ClaimCodeStatus.expired);
    });
  });
}
