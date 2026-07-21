import 'package:el7reef/data/models/match_model.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchModel teamSize', () {
    test('falls back to 5 when teamSize is missing', () {
      final model = MatchModel.fromJson({
        'organizerId': 'organizer-1',
        'createdAt': DateTime(2026, 4, 24).millisecondsSinceEpoch,
      }, 'match-1');

      expect(model.teamSize, 5);
      expect(model.toEntity().teamSize, 5);
    });

    test('normalizes invalid teamSize to 5', () {
      final model = MatchModel.fromJson({
        'organizerId': 'organizer-1',
        'teamSize': 99,
        'createdAt': DateTime(2026, 4, 24).millisecondsSinceEpoch,
      }, 'match-1');

      expect(model.teamSize, 5);
      expect(model.toJson()['teamSize'], 5);
    });

    test('preserves valid teamSize', () {
      final model = MatchModel.fromJson({
        'organizerId': 'organizer-1',
        'teamSize': 9,
        'createdAt': DateTime(2026, 4, 24).millisecondsSinceEpoch,
      }, 'match-1');

      expect(model.teamSize, 9);
      expect(model.toEntity().teamSize, 9);
    });

    test('round-trips prideEventsPending safely', () {
      final model = MatchModel.fromJson({
        'organizerId': 'organizer-1',
        'prideEventsPending': true,
        'createdAt': DateTime(2026, 4, 24).millisecondsSinceEpoch,
      }, 'match-1');

      expect(model.toEntity().prideEventsPending, isTrue);
      expect(model.toJson()['prideEventsPending'], isTrue);
    });

    test('round-trips the optional knockout match role', () {
      final model = MatchModel.fromJson({
        'organizerId': 'organizer-1',
        'knockoutMatchRole': 'thirdPlace',
        'createdAt': DateTime(2026, 7, 18).millisecondsSinceEpoch,
      }, 'match-103');

      expect(model.toEntity().knockoutMatchRole, KnockoutMatchRole.thirdPlace);
      expect(model.toJson()['knockoutMatchRole'], 'thirdPlace');
    });
  });
}
