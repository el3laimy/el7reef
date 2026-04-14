import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';

void main() {
  group('FantasyRepositoryImpl', () {
    test('getLeagueLeaderboard filters teams by leagueIds and sorts by points',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FantasyRepositoryImpl(db: firestore);
      final now = DateTime.now();

      await repository.createFantasyTeam(
        FantasyTeam(
          id: 'team-a',
          ownerPlayerId: 'p1',
          teamName: 'A',
          leagueIds: const ['global', 'league-1'],
          totalPoints: 120,
          createdAt: now,
          updatedAt: now,
        ),
        const [],
      );

      await repository.createFantasyTeam(
        FantasyTeam(
          id: 'team-b',
          ownerPlayerId: 'p2',
          teamName: 'B',
          leagueIds: const ['league-1'],
          totalPoints: 180,
          createdAt: now,
          updatedAt: now,
        ),
        const [],
      );

      await repository.createFantasyTeam(
        FantasyTeam(
          id: 'team-c',
          ownerPlayerId: 'p3',
          teamName: 'C',
          leagueIds: const ['league-2'],
          totalPoints: 220,
          createdAt: now,
          updatedAt: now,
        ),
        const [],
      );

      final leaderboard = await repository.getLeagueLeaderboard('league-1');

      expect(leaderboard.map((team) => team.id), ['team-b', 'team-a']);
    });
  });
}
