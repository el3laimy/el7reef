import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/data/repositories/friend_repository_impl.dart';

void main() {
  group('FriendRepositoryImpl.blockUser', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('delegates block creation to the trusted callable only', () async {
      final cloudOps = _RecordingCloudSensitiveOps(blocked: true);
      final repository = FriendRepositoryImpl(
        firestore: firestore,
        cloudSensitiveOps: cloudOps,
      );

      await repository.blockUser('target-1');

      expect(cloudOps.requestedBlockedIds, ['target-1']);
      expect(await _allDocuments(firestore, 'players'), isEmpty);
      expect(await _allDocuments(firestore, 'friendships'), isEmpty);
    });

    test('surfaces callable failure without a local write fallback', () async {
      final cloudOps = _RecordingCloudSensitiveOps(blocked: false);
      final repository = FriendRepositoryImpl(
        firestore: firestore,
        cloudSensitiveOps: cloudOps,
      );

      await expectLater(
        repository.blockUser('target-1'),
        throwsA(isA<StateError>()),
      );

      expect(await _allDocuments(firestore, 'players'), isEmpty);
      expect(await _allDocuments(firestore, 'friendships'), isEmpty);
    });

    test(
      'delegates unblock state changes to the trusted callable only',
      () async {
        final cloudOps = _RecordingCloudSensitiveOps(
          blocked: true,
          unblocked: true,
        );
        final repository = FriendRepositoryImpl(
          firestore: firestore,
          cloudSensitiveOps: cloudOps,
        );

        await repository.unblockUser('target-1');

        expect(cloudOps.requestedUnblockedIds, ['target-1']);
        expect(await _allDocuments(firestore, 'players'), isEmpty);
        expect(await _allDocuments(firestore, 'friendships'), isEmpty);
      },
    );

    test('does not fall back to client writes when unblock fails', () async {
      final cloudOps = _RecordingCloudSensitiveOps(
        blocked: true,
        unblocked: false,
      );
      final repository = FriendRepositoryImpl(
        firestore: firestore,
        cloudSensitiveOps: cloudOps,
      );

      await expectLater(
        repository.unblockUser('target-1'),
        throwsA(isA<StateError>()),
      );

      expect(await _allDocuments(firestore, 'players'), isEmpty);
      expect(await _allDocuments(firestore, 'friendships'), isEmpty);
    });
  });
}

Future<List<Object?>> _allDocuments(
  FakeFirebaseFirestore firestore,
  String collectionPath,
) async {
  final snapshot = await firestore.collection(collectionPath).get();
  return snapshot.docs.map((document) => document.data()).toList();
}

class _RecordingCloudSensitiveOps extends CloudSensitiveOpsService {
  final bool blocked;
  final bool unblocked;
  final List<String> requestedBlockedIds = [];
  final List<String> requestedUnblockedIds = [];

  _RecordingCloudSensitiveOps({required this.blocked, this.unblocked = true});

  @override
  Future<bool> blockUser(String blockedId) async {
    requestedBlockedIds.add(blockedId);
    return blocked;
  }

  @override
  Future<bool> unblockUser(String blockedId) async {
    requestedUnblockedIds.add(blockedId);
    return unblocked;
  }
}
