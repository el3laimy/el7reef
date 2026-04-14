import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/player_trust_level.dart';
import 'package:el7reef/core/services/rating_engine.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/player.dart';

void main() {
  group('RatingEngine', () {
    final activePlayer = Player(
      id: 'p1',
      name: 'Player One',
      trustLevel: PlayerTrustLevel.active,
      createdAt: DateTime(2024),
      lastActiveAt: DateTime(2024),
    );

    final veteranPlayer = Player(
      id: 'p2',
      name: 'Player Two',
      trustLevel: PlayerTrustLevel.veteran,
      createdAt: DateTime(2024),
      lastActiveAt: DateTime(2024),
    );

    final baseMatch = Match(
      id: 'm1',
      organizerId: 'org',
      createdAt: DateTime(2024),
    );

    test('calculates a normal win delta for an active player', () {
      final delta = RatingEngine.calculateMatchDelta(
        player: activePlayer,
        match: baseMatch,
        isWinner: true,
        isDraw: false,
        isMvp: false,
        difficultyMultiplier: 1.0,
        recentEncounterCount: 0,
      );

      expect(delta.isBlocked, isFalse);
      expect(delta.delta, 25);
    });

    test('applies veteran trust and golden multiplier together', () {
      final delta = RatingEngine.calculateMatchDelta(
        player: veteranPlayer,
        match: baseMatch.copyWith(isGoldenRating: true),
        isWinner: true,
        isDraw: false,
        isMvp: false,
        difficultyMultiplier: 1.0,
        recentEncounterCount: 0,
      );

      expect(delta.isBlocked, isFalse);
      expect(delta.delta, 60);
    });

    test('grants double-award bonus when organizer and fans pick same MVP', () {
      final delta = RatingEngine.calculateMatchDelta(
        player: activePlayer,
        match: baseMatch,
        isWinner: true,
        isDraw: false,
        isMvp: true,
        difficultyMultiplier: 1.0,
        recentEncounterCount: 0,
        isFanMvp: true,
      );

      expect(delta.isBlocked, isFalse);
      expect(delta.delta, 85);
    });

    test('blocks anomalous matches entirely', () {
      final delta = RatingEngine.calculateMatchDelta(
        player: activePlayer,
        match: baseMatch.copyWith(isAnomaly: true),
        isWinner: true,
        isDraw: false,
        isMvp: false,
        difficultyMultiplier: 1.0,
        recentEncounterCount: 0,
      );

      expect(delta.isBlocked, isTrue);
      expect(delta.delta, 0);
    });
  });
}
