import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/team.dart';

void main() {
  group('TeamRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late TeamRepositoryImpl repository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = TeamRepositoryImpl(firestore: firestore);
      now = DateTime(2026, 4, 20, 12);
    });

    test('loads teams by ids in the requested order', () async {
      await repository.createTeam(
        Team(
          id: 'team-1',
          name: 'Blue Sharks',
          ownerId: 'owner-1',
          playerIds: const ['owner-1'],
          createdAt: now,
        ),
      );
      await repository.createTeam(
        Team(
          id: 'team-2',
          name: 'Red Wolves',
          ownerId: 'owner-2',
          playerIds: const ['owner-2'],
          createdAt: now,
        ),
      );

      final teams = await repository.getTeamsByIds([
        'team-2',
        'missing',
        'team-1',
      ]);

      expect(teams.map((team) => team.id).toList(), ['team-2', 'team-1']);
    });
  });
}
