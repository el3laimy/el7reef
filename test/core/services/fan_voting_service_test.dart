import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/services/fan_voting_service.dart';

void main() {
  group('FanVotingService', () {
    late FakeFirebaseFirestore firestore;
    late FanVotingService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = FanVotingService(firestore: firestore);

      await firestore.collection(FirebasePaths.matches).doc('m1').set({
        'organizerId': 'org',
        'teamAPlayerIds': ['player_a'],
        'teamBPlayerIds': ['player_b'],
        'status': 'completed',
        'createdAt': DateTime(2024).millisecondsSinceEpoch,
      });

      await firestore.collection(FirebasePaths.players).doc('voter').set({
        'name': 'Eligible Fan',
        'createdAt': DateTime(2024)
            .subtract(const Duration(days: 10))
            .millisecondsSinceEpoch,
        'lastActiveAt': DateTime(2024).millisecondsSinceEpoch,
      });
    });

    test('openSession does not overwrite an existing voting session', () async {
      await firestore.collection(FirebasePaths.fanVotingSessions).doc('m1').set({
        'matchId': 'm1',
        'opensAt': DateTime(2024).millisecondsSinceEpoch,
        'closesAt': DateTime(2024)
            .add(const Duration(minutes: 90))
            .millisecondsSinceEpoch,
        'totalVotes': 3,
        'playerVotes': {'player_a': 3},
        'winnerPlayerId': 'player_a',
      });

      await service.openSession('m1');

      final session = await firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc('m1')
          .get();

      expect(session.data()?['totalVotes'], 3);
      expect(session.data()?['winnerPlayerId'], 'player_a');
    });

    test('voteForPlayer stores one vote and increments counters atomically',
        () async {
      await service.openSession('m1');

      await service.voteForPlayer(
        matchId: 'm1',
        userId: 'voter',
        targetPlayerId: 'player_a',
      );

      final session = await firestore
          .collection(FirebasePaths.fanVotingSessions)
          .doc('m1')
          .get();
      final vote = await firestore
          .collection(FirebasePaths.userVotes)
          .doc('m1_voter')
          .get();

      expect(vote.exists, isTrue);
      expect(session.data()?['totalVotes'], 1);
      expect(session.data()?['playerVotes']['player_a'], 1);
    });
  });
}
