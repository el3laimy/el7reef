import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/features/shareables/models/mvp_share_data.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/widgets/mvp_share_card.dart';

void main() {
  setUpAll(_loadArabicGoldenFont);

  for (final format in PrideCardFormat.values) {
    testWidgets(
      'long Arabic MVP identity fits ${format.name} at 200 percent text',
      (tester) async {
        final goldenKey = GlobalKey();
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'PrideArabicGolden'),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: goldenKey,
                    child: MvpShareCard(
                      data: const MvpShareData(
                        title: 'نجم المباراة النهائية الكبرى',
                        mvpDisplayName: 'عبد الرحمن محمد أبو زيد الحريف الهداف',
                        isGuest: true,
                        tournamentName:
                            'بطولة أبطال شوارع القاهرة الكبرى الرمضانية',
                        scoreLine: 'فريق نجوم الحارة ١٢ - ١١ أسود الميدان',
                        sideLabel: 'فريق نجوم الحارة الشرقية',
                      ),
                      exportMode: true,
                      format: format,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byKey(goldenKey)),
          Size(format.width, format.height),
        );

        await expectLater(
          find.byKey(goldenKey),
          matchesGoldenFile('goldens/mvp_long_arabic_${format.name}.png'),
        );
      },
    );
  }
}

Future<void> _loadArabicGoldenFont() async {
  final fontFile = File('assets/fonts/Cairo-Variable.ttf');
  final loader = FontLoader('PrideArabicGolden');
  loader.addFont(
    fontFile.readAsBytes().then(
      (bytes) =>
          bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
    ),
  );
  await loader.load();
}
