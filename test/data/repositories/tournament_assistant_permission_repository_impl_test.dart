import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/repositories/tournament_assistant_permission_repository_impl.dart';
import 'package:el7reef/domain/entities/tournament_assistant_permission.dart';

void main() {
  group('TournamentAssistantPermissionRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late TournamentAssistantPermissionRepositoryImpl repository;
    late DateTime createdAt;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TournamentAssistantPermissionRepositoryImpl(
        firestore: firestore,
      );
      createdAt = DateTime(2026, 5, 8, 18);
    });

    test('stores, lists, updates, and revokes assistant permissions', () async {
      await repository.createAssistantPermission(
        TournamentAssistantPermission.resultsAssistant(
          tournamentId: 'tournament-1',
          userId: 'assistant-1',
          addedBy: 'organizer-1',
          createdAt: createdAt,
        ),
      );
      await repository.createAssistantPermission(
        TournamentAssistantPermission.scoreApprover(
          tournamentId: 'tournament-1',
          userId: 'assistant-2',
          addedBy: 'organizer-1',
          createdAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );

      final fetched = await repository.getAssistantPermission(
        'tournament-1',
        'assistant-1',
      );
      final listed = await repository.listTournamentAssistants('tournament-1');

      expect(
        fetched?.preset,
        TournamentAssistantPermissionPreset.resultsAssistant,
      );
      expect(listed.map((entry) => entry.userId), [
        'assistant-1',
        'assistant-2',
      ]);

      final updatedAt = createdAt.add(const Duration(hours: 1));
      await repository.updateAssistantPermissions(
        tournamentId: 'tournament-1',
        userId: 'assistant-1',
        preset: TournamentAssistantPermissionPreset.customLimited,
        permissions: const {
          TournamentAssistantPermissionKey.canViewMatchday: true,
          TournamentAssistantPermissionKey.canApproveScore: true,
        },
        updatedAt: updatedAt,
      );

      final updated = await repository.getAssistantPermission(
        'tournament-1',
        'assistant-1',
      );
      expect(
        updated?.preset,
        TournamentAssistantPermissionPreset.customLimited,
      );
      expect(
        updated?.hasPermission(
          TournamentAssistantPermissionKey.canApproveScore,
        ),
        isTrue,
      );
      expect(
        updated?.hasPermission(TournamentAssistantPermissionKey.canSubmitScore),
        isFalse,
      );

      final revokedAt = createdAt.add(const Duration(hours: 2));
      await repository.revokeAssistant(
        tournamentId: 'tournament-1',
        userId: 'assistant-1',
        revokedAt: revokedAt,
      );

      final revoked = await repository.getAssistantPermission(
        'tournament-1',
        'assistant-1',
      );
      final rawDoc = await firestore
          .collection('tournaments')
          .doc('tournament-1')
          .collection('assistants')
          .doc('assistant-1')
          .get();

      expect(revoked?.isActive, isFalse);
      expect(revoked?.revokedAt, revokedAt);
      expect(rawDoc.id, 'assistant-1');
      expect(rawDoc.data()?['userId'], 'assistant-1');
    });
  });
}
