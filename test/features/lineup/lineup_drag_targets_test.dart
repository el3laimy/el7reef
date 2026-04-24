import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/features/lineup/widgets/bench_bar.dart';
import 'package:el7reef/features/lineup/widgets/professional_pitch_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const player = LineupPlayer(
    id: 'p1',
    name: 'Player One',
    preferredPosition: 'MID',
    isRegistered: true,
  );

  testWidgets('ProfessionalPitchCard drag target builds without recursion', (
    tester,
  ) async {
    final slots = [
      const FormationSlot(
        id: 'mid-1',
        role: SlotRole.mid,
        lineIndex: 1,
        slotIndex: 0,
        x: 50,
        y: 50,
        playerId: 'p1',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfessionalPitchCard(
            slots: slots,
            playersByKey: {player.key: player},
            formationCode: '1',
            playerCount: 1,
            editorMode: true,
            onPlayerDrop: (slot, droppedPlayer) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DragTarget<LineupPlayer>), findsOneWidget);
  });

  testWidgets('BenchBar drag target builds without recursion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BenchBar(
            players: const [player],
            draggable: true,
            onPlayerDroppedOnBench: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DragTarget<LineupPlayer>), findsOneWidget);
  });
}
