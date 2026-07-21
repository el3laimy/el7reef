import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/services/activity_feed_service.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';

void main() {
  group('ActivityFeedService', () {
    late FakeFirebaseFirestore firestore;
    late ActivityFeedService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ActivityFeedService(
        playerRepository: PlayerRepositoryImpl(firestore: firestore),
        matchRepository: MatchRepositoryImpl(db: firestore),
        tournamentRepository: TournamentRepositoryImpl(db: firestore),
        teamRepository: TeamRepositoryImpl(firestore: firestore),
      );
    });

    test('builds a recent MVP activity for a friend', () async {
      final now = DateTime.now();

      await firestore.collection(FirebasePaths.players).doc('friend-1').set({
        'name': 'أحمد',
        'createdAt': now
            .subtract(const Duration(days: 60))
            .millisecondsSinceEpoch,
        'lastActiveAt': now.millisecondsSinceEpoch,
      });

      await firestore.collection(FirebasePaths.matches).doc('match-1').set({
        'organizerId': 'org-1',
        'teamAPlayerIds': ['friend-1'],
        'teamBPlayerIds': ['other-1'],
        'status': 'settled',
        'scoreTeamA': 3,
        'scoreTeamB': 1,
        'mvpPlayerId': 'friend-1',
        'createdAt': now
            .subtract(const Duration(hours: 3))
            .millisecondsSinceEpoch,
        'completedAt': now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });

      final currentPlayer = Player(
        id: 'me',
        name: 'Me',
        friendIds: const ['friend-1'],
        createdAt: now.subtract(const Duration(days: 90)),
        lastActiveAt: now,
      );

      final feed = await service.buildFeedForPlayer(currentPlayer);

      expect(feed, isNotEmpty);
      expect(feed.first.actorName, 'أحمد');
      expect(feed.first.iconEmoji, '⭐');
      expect(feed.first.highlightText, '3-1');
    });

    test('builds a tournament activity for a followed organizer', () async {
      final now = DateTime.now();

      await firestore.collection(FirebasePaths.players).doc('org-1').set({
        'name': 'كابتن محمود',
        'role': 'organizer',
        'createdAt': now
            .subtract(const Duration(days: 90))
            .millisecondsSinceEpoch,
        'lastActiveAt': now.millisecondsSinceEpoch,
      });

      await firestore.collection(FirebasePaths.tournaments).doc('tour-1').set({
        'organizerId': 'org-1',
        'name': 'دوري المعادي',
        'format': TournamentFormat.knockoutOnly.name,
        'teamSize': TournamentTeamSize.fiveVsFive.value,
        'maxTeams': 8,
        'status': TournamentStatus.registration.name,
        'createdAt': now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'registeredTeamIds': const <String>[],
        'assistants': const <Map<String, dynamic>>[],
        'groupRoundIds': const <String>[],
        'knockoutRoundIds': const <String>[],
      });
      await firestore
          .collection('tournamentMemberships')
          .doc('org-1_tour-1')
          .set({
            'tournamentId': 'tour-1',
            'userId': 'org-1',
            'role': 'organizer',
            'createdAt': now
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          });

      final currentPlayer = Player(
        id: 'me',
        name: 'Me',
        followingIds: const ['org-1'],
        createdAt: now.subtract(const Duration(days: 90)),
        lastActiveAt: now,
      );

      final feed = await service.buildFeedForPlayer(currentPlayer);

      expect(feed, isNotEmpty);
      expect(feed.first.actorName, 'كابتن محمود');
      expect(feed.first.iconEmoji, '🏆');
      expect(feed.first.highlightText, 'دوري المعادي');
    });
  });
}
