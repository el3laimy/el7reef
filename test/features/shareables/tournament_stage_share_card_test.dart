import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:el7reef/core/widgets/el7reef_brand_mark.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/tournament_stage_share_data.dart';
import 'package:el7reef/features/shareables/services/pride_share_payload_builder.dart';
import 'package:el7reef/features/shareables/widgets/tournament_stage_share_card.dart';

import 'pride_card_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrideCardTestFont);

  testWidgets(
    'verified group standings fit every social format at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final format in PrideCardFormat.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: prideCardTestTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Center(
                  child: TournamentStageShareCard(
                    data: _groupData(),
                    exportMode: true,
                    format: format,
                    includeGrowthLink: true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('جدول المجموعة أ'), findsOneWidget);
        expect(find.text('ترتيب رسمي'), findsOneWidget);
        final qr = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(qr.semanticsLabel, 'رمز QR لمتابعة البطولة');
        expect(qr.semanticsLabel.contains('https://'), isFalse);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull, reason: format.name);
      }
    },
  );

  testWidgets(
    'road to final keeps the verified champion in every social format',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final format in PrideCardFormat.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: prideCardTestTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Center(
                  child: TournamentStageShareCard(
                    data: _bracketData(),
                    exportMode: true,
                    format: format,
                    includeGrowthLink: true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('طريق النهائي'), findsOneWidget);
        expect(find.text('نجوم الحارة · البطل'), findsOneWidget);
        expect(find.text('2-2 (5-4)'), findsOneWidget);
        expect(find.textContaining('تحليل'), findsNothing);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(tester.takeException(), isNull, reason: format.name);
      }
    },
  );

  testWidgets('growth-link kill switch removes QR from the exported card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prideCardTestTheme(),
        home: Scaffold(
          body: Center(
            child: TournamentStageShareCard(
              data: _groupData(),
              exportMode: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(El7reefBrandMark), findsOneWidget);
  });
}

TournamentStageShareData _groupData() {
  const payloadBuilder = PrideSharePayloadBuilder();
  return TournamentStageShareData(
    kind: TournamentStagePrideKind.groupStandings,
    tournamentName: 'كأس الحارة الرمضاني الكبير',
    title: 'جدول المجموعة أ',
    statusLabel: 'ترتيب رسمي',
    rows: const [
      TournamentStageShareRowData(
        leading: '#1',
        title: 'نجوم الحارة أصحاب الاسم العربي الطويل',
        subtitle: 'لعب 3 · فرق +5',
        trailing: '9',
        emphasized: true,
        earned: true,
      ),
      TournamentStageShareRowData(
        leading: '#2',
        title: 'فرسان البلد',
        subtitle: 'لعب 3 · فرق +2',
        trailing: '6',
        emphasized: true,
        earned: true,
      ),
      TournamentStageShareRowData(
        leading: '#3',
        title: 'شباب الميدان',
        subtitle: 'لعب 3 · فرق -1',
        trailing: '3',
      ),
      TournamentStageShareRowData(
        leading: '#4',
        title: 'أبطال الشارع',
        subtitle: 'لعب 3 · فرق -6',
        trailing: '0',
      ),
    ],
    sharePayload: payloadBuilder.groupStandings(tournamentId: 'cup-1'),
  );
}

TournamentStageShareData _bracketData() {
  const payloadBuilder = PrideSharePayloadBuilder();
  return TournamentStageShareData(
    kind: TournamentStagePrideKind.knockoutBracket,
    tournamentName: 'كأس الحارة الرمضاني الكبير',
    title: 'طريق النهائي',
    statusLabel: 'الإقصائيات جارية',
    rows: const [
      TournamentStageShareRowData(
        leading: '1',
        title: 'نجوم الحارة · البطل',
        subtitle: 'النهائي · نجوم الحارة × فرسان البلد',
        trailing: '2-2 (5-4)',
        emphasized: true,
        earned: true,
      ),
      TournamentStageShareRowData(
        leading: '2',
        title: 'نجوم الحارة × شباب الميدان',
        subtitle: 'نصف النهائي',
      ),
      TournamentStageShareRowData(
        leading: '3',
        title: 'فرسان البلد × أبطال الشارع',
        subtitle: 'نصف النهائي',
      ),
      TournamentStageShareRowData(
        leading: '4',
        title: 'نجوم الحارة × ملوك الساحة',
        subtitle: 'ربع النهائي',
      ),
      TournamentStageShareRowData(
        leading: '5',
        title: 'شباب الميدان · تأهل مباشر',
        subtitle: 'ربع النهائي',
      ),
      TournamentStageShareRowData(
        leading: '6',
        title: 'فرسان البلد × أصدقاء الملعب',
        subtitle: 'ربع النهائي',
      ),
      TournamentStageShareRowData(
        leading: '7',
        title: 'أبطال الشارع × نسور الحارة',
        subtitle: 'ربع النهائي',
      ),
    ],
    sharePayload: payloadBuilder.knockoutBracket(tournamentId: 'cup-1'),
  );
}
