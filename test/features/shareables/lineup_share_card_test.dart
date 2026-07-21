import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/app/theme/app_colors.dart';
import 'package:el7reef/core/lineup/formation_engine.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/core/widgets/el7reef_glass_surface.dart';
import 'package:el7reef/features/shareables/models/lineup_share_data.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/widgets/lineup_share_card.dart';

import 'pride_card_test_font.dart';

void main() {
  setUpAll(loadPrideCardTestFont);
  testWidgets('renders lineup card text and uses pride glass in preview', (
    tester,
  ) async {
    final data = _data();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: LineupShareCard(data: data)),
        ),
      ),
    );

    expect(find.text('التشكيلة الرسمية'), findsOneWidget);
    expect(find.text('الحريف'), findsOneWidget);
    expect(find.text('2-2'), findsOneWidget);
    expect(find.text('حسام'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('نهائي الشارع'), findsOneWidget);
    expect(find.text('اضغط من البداية'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byType(El7reefGlassSurface), findsOneWidget);

    final surface = tester.widget<El7reefGlassSurface>(
      find.byType(El7reefGlassSurface),
    );
    expect(surface.variant, El7reefGlassVariant.pride);
  });

  testWidgets('export mode keeps the lineup image free of live glass blur', (
    tester,
  ) async {
    final data = _data();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: LineupShareCard(data: data, exportMode: true)),
        ),
      ),
    );

    expect(find.text('التشكيلة الرسمية'), findsOneWidget);
    expect(find.byType(El7reefGlassSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      tester.getSize(find.byType(Directionality).last),
      const Size(360, 450),
    );
  });

  testWidgets('story export preserves 9:16 and Arabic RTL', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LineupShareCard(
              data: _data(),
              exportMode: true,
              format: PrideCardFormat.story9x16,
            ),
          ),
        ),
      ),
    );

    final cardDirectionality = tester.widget<Directionality>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Directionality &&
                widget.textDirection == TextDirection.rtl,
          )
          .last,
    );
    expect(cardDirectionality.textDirection, TextDirection.rtl);
    expect(
      tester.getSize(find.byType(Directionality).last),
      const Size(360, 640),
    );
  });

  testWidgets(
    '11-player export keeps every node separated at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final format in PrideCardFormat.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: prideCardTestTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Center(
                  child: LineupShareCard(
                    data: _elevenPlayerData(),
                    exportMode: true,
                    format: format,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: format.name);
        final playerNodes = List.generate(
          11,
          (index) => tester.getRect(
            find.byKey(ValueKey('lineup-share-player-player-$index')),
          ),
        );

        for (var left = 0; left < playerNodes.length; left += 1) {
          for (var right = left + 1; right < playerNodes.length; right += 1) {
            expect(
              playerNodes[left].overlaps(playerNodes[right]),
              isFalse,
              reason: '${format.name}: player-$left overlaps player-$right',
            );
          }
        }
      }
    },
  );
}

LineupShareData _data() {
  return const LineupShareData(
    matchId: 'match-1',
    lineupOwnerType: LineupShareOwnerType.officialTeam,
    ownerId: 'team-1',
    teamName: 'الحريف',
    teamLabel: 'فريق رسمي',
    initials: 'ح',
    accentColor: AppColors.primary,
    formationCode: '2-2',
    formationLabel: '2-2',
    teamSize: 5,
    lineupTypeLabel: 'فريق رسمي',
    matchLabel: 'نهائي الشارع',
    pitchPlayers: [
      LineupSharePlayerData(
        id: 'p1',
        displayName: 'حسام',
        initials: 'حس',
        shirtNumber: 10,
        slotId: 'att-1',
        slotRole: SlotRole.att,
        slotX: 50,
        slotY: 28,
        isTemporary: false,
        positionLabel: 'مهاجم',
        shortName: 'HOSSAM',
      ),
    ],
    tacticalNotes: ['اضغط من البداية'],
  );
}

LineupShareData _elevenPlayerData() {
  final slots = FormationEngine.generateFormationSlots(
    playerCount: 11,
    formationCode: '4-2-3-1',
  );
  return LineupShareData(
    matchId: 'match-11',
    lineupOwnerType: LineupShareOwnerType.officialTeam,
    ownerId: 'team-11',
    teamName: 'نجوم الحارة',
    teamLabel: 'فريق رسمي',
    initials: 'نح',
    accentColor: AppColors.primary,
    formationCode: '4-2-3-1',
    teamSize: 11,
    lineupTypeLabel: 'فريق رسمي',
    matchLabel: 'نهائي البطولة',
    pitchPlayers: [
      for (var index = 0; index < slots.length; index += 1)
        LineupSharePlayerData(
          id: 'player-$index',
          displayName: 'لاعب ${index + 1}',
          initials: 'ل${index + 1}',
          shirtNumber: index + 2,
          slotId: 'slot-$index',
          slotRole: slots[index].role,
          slotX: slots[index].x,
          slotY: slots[index].y,
          isTemporary: false,
        ),
    ],
  );
}
