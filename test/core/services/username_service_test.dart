import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/username_service.dart';

void main() {
  group('UsernameService', () {
    late FakeFirebaseFirestore firestore;
    late UsernameService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = UsernameService(db: firestore);

      await firestore.collection(FirebasePaths.players).doc('p1').set({
        'name': 'Player One',
        'createdAt': DateTime(2024).millisecondsSinceEpoch,
        'lastActiveAt': DateTime(2024).millisecondsSinceEpoch,
      });
      await firestore.collection(FirebasePaths.players).doc('p2').set({
        'name': 'Player Two',
        'createdAt': DateTime(2024).millisecondsSinceEpoch,
        'lastActiveAt': DateTime(2024).millisecondsSinceEpoch,
      });
    });

    test('claims a username and writes the active lock document', () async {
      final result = await service.setUsername(
        playerId: 'p1',
        newUsername: 'captain_1',
      );

      expect(result, UsernameSetResult.success);

      final player = await firestore
          .collection(FirebasePaths.players)
          .doc('p1')
          .get();
      final lock = await firestore
          .collection(FirebasePaths.reservedUsernames)
          .doc('captain_1')
          .get();

      expect(player.data()?['username'], 'captain_1');
      expect(lock.data()?['status'], 'active');
      expect(lock.data()?['ownerId'], 'p1');
    });

    test('prevents another player from claiming an active username', () async {
      await service.setUsername(
        playerId: 'p1',
        newUsername: 'captain_1',
      );

      final result = await service.setUsername(
        playerId: 'p2',
        newUsername: 'captain_1',
      );

      expect(result, UsernameSetResult.taken);
    });

    test('reserves the previous username when the player changes it', () async {
      await service.setUsername(
        playerId: 'p1',
        newUsername: 'captain_1',
      );

      final result = await service.setUsername(
        playerId: 'p1',
        newUsername: 'captain_2',
        oldUsername: 'captain_1',
      );

      expect(result, UsernameSetResult.success);

      final oldLock = await firestore
          .collection(FirebasePaths.reservedUsernames)
          .doc('captain_1')
          .get();
      final newLock = await firestore
          .collection(FirebasePaths.reservedUsernames)
          .doc('captain_2')
          .get();

      expect(oldLock.data()?['status'], 'reserved');
      expect(newLock.data()?['status'], 'active');
    });
  });
}
