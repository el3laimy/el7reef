import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';

void main() {
  group('PlayerRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late PlayerRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = PlayerRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 20, 15);
    });

    test('loads players by ids in the requested order', () async {
      await repository.createPlayer(
        Player(
          id: 'player-1',
          name: 'Captain Blue',
          createdAt: now,
          lastActiveAt: now,
        ),
      );
      await repository.createPlayer(
        Player(
          id: 'player-2',
          name: 'Captain Red',
          createdAt: now,
          lastActiveAt: now,
        ),
      );

      final players = await repository.getPlayersByIds([
        'player-2',
        'missing',
        'player-1',
      ]);

      expect(players.map((player) => player.id).toList(), [
        'player-2',
        'player-1',
      ]);
    });
  });
}
