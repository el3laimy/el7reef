import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/core/widgets/el7reef_glass_surface.dart';
import 'package:el7reef/core/widgets/el7reef_solid_surface.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/pride_export.dart';
import 'package:el7reef/features/shareables/services/pride_share_preference_store.dart';
import 'package:el7reef/features/shareables/widgets/pride_share_composer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Android flag exposes video, sound and the four formats', (
    tester,
  ) async {
    _registerVideoFlag(enabled: true);
    PrideShareSelection? chosenSelection;
    await tester.pumpWidget(
      _ComposerLauncher(
        cardType: ShareCardType.matchResult,
        onSelected: (selection) => chosenSelection = selection,
      ),
    );

    await tester.tap(find.text('افتح التجهيز'));
    await tester.pumpAndSettle();
    expect(find.text('صورة'), findsOneWidget);
    expect(find.text('فيديو'), findsOneWidget);
    expect(find.text('بصمة صوت الحريف'), findsNothing);
    expect(find.text('مربع 1:1'), findsOneWidget);
    expect(find.text('منشور 4:5'), findsOneWidget);
    expect(find.text('ستوري 9:16'), findsOneWidget);
    expect(find.text('أفقي 16:9'), findsOneWidget);

    await tester.tap(find.text('فيديو'));
    await tester.pumpAndSettle();
    expect(find.text('بصمة صوت الحريف'), findsOneWidget);
    await tester.tap(find.text('ستوري 9:16'));
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.ensureVisible(
      find.byKey(const ValueKey('pride-share-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('pride-share-confirm')));
    await tester.pumpAndSettle();

    expect(chosenSelection?.mediaType, PrideMediaType.video);
    expect(chosenSelection?.format, PrideCardFormat.story9x16);
    expect(chosenSelection?.includeAudio, isFalse);
  });

  testWidgets('video controls stay hidden outside the approved gate', (
    tester,
  ) async {
    _registerVideoFlag(enabled: false);
    await tester.pumpWidget(
      const _ComposerLauncher(cardType: ShareCardType.matchResult),
    );
    await tester.tap(find.text('افتح التجهيز'));
    await tester.pumpAndSettle();
    expect(find.text('فيديو'), findsNothing);
    expect(find.text('بصمة صوت الحريف'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('pride-share-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('pride-share-confirm')));
    await tester.pumpAndSettle();
    Get.reset();
    _registerVideoFlag(enabled: true);
    await tester.pumpWidget(
      const _ComposerLauncher(cardType: ShareCardType.topScorers),
    );
    await tester.tap(find.text('افتح التجهيز'));
    await tester.pumpAndSettle();

    expect(find.text('فيديو'), findsNothing);
    expect(find.text('بصمة صوت الحريف'), findsNothing);
  });

  testWidgets('long composer is solid with two preview toolbars only', (
    tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {
          FeatureFlagKey.functionalGlassEnabled: true,
          FeatureFlagKey.prideVideoExportEnabled: false,
        },
      ),
    );
    await tester.pumpWidget(
      const _ComposerLauncher(cardType: ShareCardType.matchResult),
    );

    await tester.tap(find.text('افتح التجهيز'));
    await tester.pumpAndSettle();

    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(El7reefGlassSurface), findsNWidgets(2));
    for (final surface in tester.widgetList<El7reefGlassSurface>(
      find.byType(El7reefGlassSurface),
    )) {
      expect(surface.role, El7reefGlassRole.previewToolbar);
    }
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.text('preview-square1x1'),
        matching: find.byType(El7reefGlassSurface),
      ),
      findsNothing,
    );
  });

  testWidgets('preference storage failure does not block sharing', (
    tester,
  ) async {
    _registerVideoFlag(enabled: true);
    PrideShareSelection? chosenSelection;
    final failingStore = PrideSharePreferenceStore(
      preferencesLoader: () => Future.error(Exception('storage unavailable')),
    );
    await tester.pumpWidget(
      _ComposerLauncher(
        cardType: ShareCardType.matchResult,
        preferenceStore: failingStore,
        onSelected: (selection) => chosenSelection = selection,
      ),
    );

    await tester.tap(find.text('افتح التجهيز'));
    await tester.pumpAndSettle();
    expect(find.text('جهّز لحظة الفخر'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('pride-share-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('pride-share-confirm')));
    await tester.pumpAndSettle();

    expect(chosenSelection?.mediaType, PrideMediaType.image);
    expect(find.text('جهّز لحظة الفخر'), findsNothing);
  });
}

void _registerVideoFlag({required bool enabled}) {
  Get.put(
    FeatureFlagService(
      overrides: {FeatureFlagKey.prideVideoExportEnabled: enabled},
    ),
  );
}

class _ComposerLauncher extends StatelessWidget {
  final ShareCardType cardType;
  final PrideSharePreferenceStore? preferenceStore;
  final ValueChanged<PrideShareSelection>? onSelected;

  const _ComposerLauncher({
    required this.cardType,
    this.preferenceStore,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final selection = await showPrideShareComposer(
                context: context,
                cardType: cardType,
                previewBuilder: (format) => ColoredBox(
                  color: Colors.green,
                  child: Center(child: Text('preview-${format.name}')),
                ),
                preferenceStore: preferenceStore,
              );
              if (selection != null) onSelected?.call(selection);
            },
            child: const Text('افتح التجهيز'),
          ),
        ),
      ),
    );
  }
}
