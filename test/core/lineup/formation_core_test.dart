import 'package:flutter_test/flutter_test.dart';
import 'package:el7reef/core/lineup/formation_engine.dart';
import 'package:el7reef/core/lineup/formation_library.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/core/lineup/lineup_utils.dart';

void main() {
  group('Formation library', () {
    test('normalizes match team size conservatively', () {
      expect(normalizeMatchTeamSize(null), 5);
      expect(normalizeMatchTeamSize(4), 5);
      expect(normalizeMatchTeamSize(12), 5);
      expect(normalizeMatchTeamSize(9), 9);
    });

    for (var count = 5; count <= 11; count += 1) {
      test('supports valid options for $count players', () {
        final defaultFormation = getDefaultFormation(count);
        final options = getAvailableFormations(count);

        expect(options, contains(defaultFormation));
        for (final option in options) {
          expect(isValidFormationForPlayerCount(count, option), isTrue);
          expect(getTotalPlayersForFormation(option), count);
        }
      });
    }
  });

  group('Formation engine', () {
    test('generates goalkeeper and percentage slots', () {
      final slots = FormationEngine.generateFormationSlots(
        playerCount: 7,
        formationCode: '2-3-1',
      );

      expect(slots, hasLength(7));
      expect(slots.first.id, 'gk');
      expect(slots.first.role, SlotRole.gk);
      expect(slots.first.x, 50);
      expect(slots.first.y, 92);
      expect(slots.every((slot) => slot.x >= 0 && slot.x <= 100), isTrue);
      expect(slots.every((slot) => slot.y >= 0 && slot.y <= 100), isTrue);
    });

    test('preserves players and moves overflow to bench', () {
      final oldSlots = FormationEngine.generateFormationSlots(
        playerCount: 7,
        formationCode: '2-3-1',
      );
      final players = List.generate(
        7,
        (index) => LineupPlayer(
          id: 'member-$index',
          name: 'Player $index',
          preferredPosition: index == 0 ? 'GK' : null,
          isRegistered: true,
        ),
      );
      final assigned = LineupUtils.assignPlayersToGeneratedSlots(
        slots: oldSlots,
        starters: players,
      );
      final newSlots = FormationEngine.generateFormationSlots(
        playerCount: 6,
        formationCode: '2-2-1',
      );
      final preserved = LineupUtils.preserveAssignments(
        oldSlots: assigned.slots,
        newSlots: newSlots,
        playersByKey: {for (final player in players) player.key: player},
      );

      expect(preserved.slots, hasLength(6));
      expect(
        preserved.slots.where((slot) => slot.occupantKey != null),
        hasLength(6),
      );
      expect(preserved.movedToBenchKeys, hasLength(1));
      expect(
        preserved.slots.first.occupantKey,
        LineupPlayer.registeredKey('member-0'),
      );
    });
  });
}
