import 'formation_library.dart';
import 'lineup_types.dart';

class FormationEngine {
  const FormationEngine._();

  static List<FormationSlot> generateFormationSlots({
    required int playerCount,
    required String formationCode,
  }) {
    final effectiveCount = clampSupportedPlayerCount(playerCount);
    final effectiveFormation =
        isValidFormationForPlayerCount(effectiveCount, formationCode)
        ? formationCode
        : getDefaultFormation(effectiveCount);
    final lines = parseFormationCode(effectiveFormation);
    final slots = <FormationSlot>[
      const FormationSlot(
        id: 'gk',
        role: SlotRole.gk,
        lineIndex: -1,
        slotIndex: 0,
        x: 50,
        y: 92,
      ),
    ];

    const defensiveY = 74.0;
    const attackingY = 24.0;
    final numberOfLines = lines.length;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      final count = lines[lineIndex];
      final y = numberOfLines == 1
          ? 50.0
          : defensiveY -
                lineIndex * ((defensiveY - attackingY) / (numberOfLines - 1));
      final xs = getXPositions(count);

      for (var slotIndex = 0; slotIndex < xs.length; slotIndex += 1) {
        slots.add(
          FormationSlot(
            id: 'line-$lineIndex-slot-$slotIndex',
            role: getRoleFromLine(lineIndex, numberOfLines),
            lineIndex: lineIndex,
            slotIndex: slotIndex,
            x: xs[slotIndex],
            y: y,
          ),
        );
      }
    }

    return slots;
  }

  static List<double> getXPositions(int count) {
    return switch (count) {
      1 => const [50],
      2 => const [35, 65],
      3 => const [22, 50, 78],
      4 => const [14, 38, 62, 86],
      5 => const [10, 30, 50, 70, 90],
      _ => List<double>.generate(
        count,
        (index) => ((index + 1) * 100) / (count + 1),
      ),
    };
  }

  static SlotRole getRoleFromLine(int lineIndex, int numberOfLines) {
    if (lineIndex == 0) {
      return SlotRole.def;
    }
    if (lineIndex == numberOfLines - 1) {
      return SlotRole.att;
    }
    return SlotRole.mid;
  }
}
