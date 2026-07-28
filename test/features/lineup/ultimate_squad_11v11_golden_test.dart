import 'package:el7reef/app/theme/app_theme.dart';
import 'package:el7reef/core/lineup/formation_engine.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/features/lineup/widgets/professional_pitch_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await _loadArabicGoldenFont();
  });

  testWidgets('11v11 dense squad keeps five-player lines readable', (
    tester,
  ) async {
    final goldenKey = GlobalKey();
    final players = List.generate(
      11,
      (index) => LineupPlayer(
        id: 'player-$index',
        name: [
          'مصطفى شوبير',
          'محمد هاني',
          'رامي ربيعة',
          'أحمد رمضان',
          'يحيى عطية الله',
          'مروان عطية',
          'إمام عاشور',
          'أكرم توفيق',
          'حسين الشحات',
          'وسام أبو علي',
          'طاهر محمد',
        ][index],
        number: index + 1,
        isRegistered: index.isEven,
      ),
    );
    final generatedSlots = FormationEngine.generateFormationSlots(
      playerCount: 11,
      formationCode: '3-5-2',
    );
    final slots = [
      for (var index = 0; index < generatedSlots.length; index++)
        generatedSlots[index].assignPlayer(players[index]),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFF070A08),
          body: Center(
            child: RepaintBoundary(
              key: goldenKey,
              child: SizedBox(
                width: 320,
                child: ProfessionalPitchCard(
                  slots: slots,
                  playersByKey: {
                    for (final player in players) player.key: player,
                  },
                  formationCode: '3-5-2',
                  playerCount: 11,
                  teamName: 'نجوم الشارع',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/ultimate_squad_11v11_320.png'),
    );
  });
}

Future<void> _loadArabicGoldenFont() async {
  final loader = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  await loader.load();
}
