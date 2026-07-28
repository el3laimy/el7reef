import 'package:el7reef/core/lineup/formation_engine.dart';
import 'package:el7reef/core/lineup/formation_library.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/core/lineup/lineup_utils.dart';
import 'package:el7reef/core/widgets/el7reef_glass_surface.dart';
import 'package:el7reef/features/lineup/widgets/bench_bar.dart';
import 'package:el7reef/features/lineup/widgets/formation_control_bar.dart';
import 'package:el7reef/features/lineup/widgets/lineup_player_node.dart';
import 'package:el7reef/features/lineup/widgets/lineup_status_panel.dart';
import 'package:el7reef/features/lineup/widgets/professional_pitch_card.dart';
import 'package:el7reef/features/lineup/widgets/squad_player_card.dart';
import 'package:el7reef/features/lineup/widgets/starter_swap_sheet.dart';
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
            onPlayerDrop: (slot, payload) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DragTarget<LineupDragPayload>), findsOneWidget);
    expect(find.byType(El7reefGlassSurface), findsNothing);
  });

  testWidgets('ProfessionalPitchCard marks tap-select move targets clearly', (
    tester,
  ) async {
    const secondPlayer = LineupPlayer(
      id: 'p2',
      name: 'Player Two',
      preferredPosition: 'ATT',
      isRegistered: true,
    );
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
      const FormationSlot(
        id: 'att-1',
        role: SlotRole.att,
        lineIndex: 2,
        slotIndex: 0,
        x: 32,
        y: 30,
        playerId: 'p2',
      ),
      const FormationSlot(
        id: 'def-1',
        role: SlotRole.def,
        lineIndex: 0,
        slotIndex: 0,
        x: 68,
        y: 70,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfessionalPitchCard(
            slots: slots,
            playersByKey: {player.key: player, secondPlayer.key: secondPlayer},
            formationCode: '1-1-1',
            playerCount: 3,
            editorMode: true,
            selectedPlayerKey: player.key,
            onPlayerDrop: (slot, payload) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('انقل هنا'), findsOneWidget);
    expect(find.text('بدّل'), findsOneWidget);
  });

  testWidgets('ProfessionalPitchCard exposes stable full-height touch slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ProfessionalPitchCard(
              slots: const [
                FormationSlot(
                  id: 'mid-1',
                  role: SlotRole.mid,
                  lineIndex: 1,
                  slotIndex: 0,
                  x: 50,
                  y: 54,
                  playerId: 'p1',
                ),
              ],
              playersByKey: {player.key: player},
              formationCode: '1',
              playerCount: 7,
              editorMode: true,
              onPlayerDrop: (_, _) {},
            ),
          ),
        ),
      ),
    );

    final slot = tester.widget<Positioned>(
      find.byKey(const ValueKey('lineup-slot-mid-1')),
    );

    expect(slot.width, greaterThanOrEqualTo(96));
    expect(slot.height, greaterThanOrEqualTo(132));
  });

  testWidgets('all 11v11 formations stay readable on a 320px pitch', (
    tester,
  ) async {
    final squad = List.generate(
      11,
      (index) => LineupPlayer(
        id: 'p$index',
        name: 'لاعب عربي باسم طويل ${index + 1}',
        number: index + 1,
        preferredPosition: index == 0 ? 'GK' : null,
        isRegistered: index.isEven,
      ),
    );
    final players = {for (final player in squad) player.key: player};

    for (final formationCode in getAvailableFormations(11)) {
      final generatedSlots = FormationEngine.generateFormationSlots(
        playerCount: 11,
        formationCode: formationCode,
      );
      final slots = [
        for (var index = 0; index < generatedSlots.length; index++)
          generatedSlots[index].assignPlayer(squad[index]),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: ProfessionalPitchCard(
                  slots: slots,
                  playersByKey: players,
                  formationCode: formationCode,
                  playerCount: 11,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: formationCode);
      expect(find.byType(SquadPlayerCard), findsNWidgets(11));
      expect(
        tester
            .widgetList<SquadPlayerCard>(find.byType(SquadPlayerCard))
            .every((card) => card.size == SquadPlayerCardSize.dense),
        isTrue,
      );

      final cardRects = find
          .byType(SquadPlayerCard)
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList(growable: false);
      for (var index = 0; index < cardRects.length; index++) {
        for (
          var otherIndex = index + 1;
          otherIndex < cardRects.length;
          otherIndex++
        ) {
          expect(
            cardRects[index].overlaps(cardRects[otherIndex]),
            isFalse,
            reason:
                '$formationCode: squad cards $index and $otherIndex overlap.',
          );
        }
      }
    }
  });

  testWidgets(
    'ProfessionalPitchCard swaps two occupied slots by tapping nodes',
    (tester) async {
      const secondPlayer = LineupPlayer(
        id: 'p2',
        name: 'Player Two',
        preferredPosition: 'ATT',
        isRegistered: true,
      );
      var slots = [
        const FormationSlot(
          id: 'mid-1',
          role: SlotRole.mid,
          lineIndex: 1,
          slotIndex: 0,
          x: 50,
          y: 55,
          playerId: 'p1',
        ),
        const FormationSlot(
          id: 'att-1',
          role: SlotRole.att,
          lineIndex: 2,
          slotIndex: 0,
          x: 50,
          y: 32,
          playerId: 'p2',
        ),
      ];
      LineupDragPayload? selectedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ProfessionalPitchCard(
                  slots: slots,
                  playersByKey: {
                    player.key: player,
                    secondPlayer.key: secondPlayer,
                  },
                  formationCode: '1-1',
                  playerCount: 2,
                  editorMode: true,
                  selectedPlayerKey: selectedPayload?.player.key,
                  onPlayerTap: (slot, tappedPlayer) {
                    setState(() {
                      if (selectedPayload == null) {
                        selectedPayload = LineupDragPayload(
                          player: tappedPlayer,
                          sourceSlotId: slot.id,
                        );
                        return;
                      }
                      slots = LineupUtils.movePlayerToSlot(
                        slots: slots,
                        payload: selectedPayload!,
                        targetSlotId: slot.id,
                      );
                      selectedPayload = null;
                    });
                  },
                  onPlayerDrop: (slot, payload) {
                    setState(() {
                      slots = LineupUtils.movePlayerToSlot(
                        slots: slots,
                        payload: payload,
                        targetSlotId: slot.id,
                      );
                      selectedPayload = null;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('lineup-node-mid-1')));
      await tester.pumpAndSettle();

      expect(selectedPayload?.player.key, player.key);

      await tester.tap(find.byKey(const ValueKey('lineup-node-att-1')));
      await tester.pumpAndSettle();

      expect(
        slots.firstWhere((slot) => slot.id == 'mid-1').occupantKey,
        secondPlayer.key,
      );
      expect(
        slots.firstWhere((slot) => slot.id == 'att-1').occupantKey,
        player.key,
      );
      expect(selectedPayload, isNull);
    },
  );

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
    expect(find.byType(DragTarget<LineupDragPayload>), findsOneWidget);
    expect(find.byType(El7reefGlassSurface), findsNothing);
  });

  testWidgets('BenchBar highlights selected bench player', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BenchBar(
            players: const [player],
            selectedPlayerKey: player.key,
            onPlayerTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('مختار'), findsOneWidget);
  });

  testWidgets('guest squad card exposes identity and football semantics', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    const guest = LineupPlayer(
      id: 'guest-1',
      name: 'مصطفى زيكو',
      number: 11,
      preferredPosition: 'ATT',
      isRegistered: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LineupPlayerNode(
              player: guest,
              role: SlotRole.att,
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('ضيف'), findsOneWidget);
    expect(
      find.bySemanticsLabel('مصطفى زيكو، رقم 11، هجوم، لاعب زائر'),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });

  testWidgets('dirty tactics bar keeps one save action on narrow layouts', (
    tester,
  ) async {
    int? selectedPlayerCount;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: FormationControlBar(
                playerCount: 7,
                formationCode: '2-3-1',
                onPlayerCountChanged: (value) => selectedPlayerCount = value,
                onFormationChanged: (_) {},
                onReset: _noop,
                isDirty: true,
                onSave: _noop,
                onCancel: _noop,
                allowPlayerCountChange: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('squad-tactics-save')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'حفظ'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(El7reefGlassSurface), findsOneWidget);
    expect(
      tester.widget<El7reefGlassSurface>(find.byType(El7reefGlassSurface)).role,
      El7reefGlassRole.floatingToolbar,
    );

    final saveRect = tester.getRect(
      find.byKey(const ValueKey('squad-tactics-save')),
    );
    expect(saveRect.left, greaterThanOrEqualTo(0));
    expect(saveRect.right, lessThanOrEqualTo(320));

    await tester.tap(find.byKey(const ValueKey('squad-player-count-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<int> && widget.value == 11,
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedPlayerCount, 11);
  });

  testWidgets('BenchBar exposes tap target for selected pitch player', (
    tester,
  ) async {
    var moved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BenchBar(
            players: const [player],
            selectedPlayerKey: player.key,
            onSelectedPlayerMoveToBench: () => moved = true,
          ),
        ),
      ),
    );

    expect(find.text('انقل المختار للبدلاء'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bench-move-selected-target')));
    await tester.pump();

    expect(moved, isTrue);
  });

  testWidgets('BenchBar exposes quick swap target for selected bench player', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BenchBar(
            players: const [player],
            selectedPlayerKey: player.key,
            onSelectedBenchSwapRequest: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('بدّل المختار مع أساسي'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bench-swap-selected-target')));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('BenchBar selected bench target fits narrow scaled layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: BenchBar(
                players: const [player],
                onAddGuest: () {},
                onSelectedPlayerMoveToBench: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('انقل المختار للبدلاء'), findsOneWidget);
  });

  testWidgets('StarterSwapSheet lists starters and selects target slot', (
    tester,
  ) async {
    FormationSlot? selectedSlot;
    const starter = LineupPlayer(
      id: 'p2',
      name: 'Starter Two',
      preferredPosition: 'DEF',
      isRegistered: true,
    );
    const occupiedSlot = FormationSlot(
      id: 'def-1',
      role: SlotRole.def,
      lineIndex: 0,
      slotIndex: 0,
      x: 50,
      y: 70,
      playerId: 'p2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarterSwapSheet(
            title: 'بدّل مع لاعب أساسي',
            slots: const [occupiedSlot],
            playersByKey: {starter.key: starter},
            onSlotSelected: (slot) => selectedSlot = slot,
          ),
        ),
      ),
    );

    expect(find.text('بدّل مع لاعب أساسي'), findsOneWidget);
    expect(find.text('Starter Two'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('starter-swap-slot-def-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('starter-swap-slot-def-1')));
    await tester.pump();

    expect(selectedSlot?.id, 'def-1');
  });

  testWidgets('LineupStatusPanel surfaces dirty save action near pitch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: LineupStatusPanel(
              formationCode: '2-3-1',
              filledSlots: 6,
              totalSlots: 7,
              benchCount: 2,
              isDirty: true,
              canManageLineup: true,
              selectedPlayerName: 'أمام عاشور',
              onSave: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('خطة 2-3-1'), findsOneWidget);
    expect(
      find.text(
        'اضغط لاعب من الملعب أو البدلاء، ثم اضغط خانة للنقل أو التبديل.',
      ),
      findsOneWidget,
    );
    expect(find.text('جاهزة للحفظ'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'حفظ'), findsOneWidget);
    expect(find.text('6/7 على الملعب'), findsOneWidget);
    expect(find.text('مختار: أمام عاشور'), findsOneWidget);
    expect(find.text('اضغط خانة للنقل أو التبديل'), findsOneWidget);
    expect(find.byType(El7reefGlassSurface), findsNothing);
  });
}

void _noop() {}
