import 'package:el7reef/app/theme/app_colors.dart';
import 'package:el7reef/app/theme/app_dimensions.dart';
import 'package:el7reef/app/theme/app_text_styles.dart';
import 'package:el7reef/app/theme/app_theme.dart';
import 'package:el7reef/core/widgets/el7reef_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cairo is bundled locally and used by the typography tokens', () async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');

    expect(fontData.lengthInBytes, greaterThan(500000));
    expect(AppTextStyles.bodyMedium.fontFamily, 'Cairo');
    expect(AppTextStyles.bodySmall.fontSize, greaterThanOrEqualTo(12));
    expect(
      AppTextStyles.scoreMedium.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      AppTextStyles.displayLarge.fontVariations,
      contains(const FontVariation('wght', 800)),
    );
  });

  test('Material 3 theme keeps operational surfaces solid and tactile', () {
    final theme = AppTheme.darkTheme;
    final primaryButton = theme.filledButtonTheme.style!;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
    expect(
      primaryButton.minimumSize!.resolve(const <WidgetState>{}),
      const Size(AppDimensions.minTouchTarget, AppDimensions.buttonHeightMd),
    );
    expect(AppDimensions.animFast, inInclusiveRange(150, 250));
    expect(AppDimensions.animNormal, inInclusiveRange(150, 250));
    expect(AppDimensions.animSlow, inInclusiveRange(150, 250));
  });

  test(
    'brand master is a flat path and all identity assets are bundled',
    () async {
      const vectorAssets = <String>[
        'assets/brand/brand_mark.svg',
        'assets/brand/brand_mark_mono_positive.svg',
        'assets/brand/brand_mark_mono_negative.svg',
        'assets/brand/wordmark_ar.svg',
        'assets/brand/lockup_bilingual.svg',
        'assets/brand/play_store_icon_master.svg',
      ];

      for (final path in vectorAssets) {
        expect(await rootBundle.loadString(path), isNotEmpty, reason: path);
      }

      final mark = await rootBundle.loadString(vectorAssets.first);
      expect(mark, contains('<path'));
      expect(mark, isNot(contains('<text')));
      expect(mark, isNot(contains('<filter')));
      expect(mark, isNot(contains('<image')));
      expect(
        (await rootBundle.load(
          'assets/brand/play_store_icon_512.png',
        )).lengthInBytes,
        lessThan(1024 * 1024),
      );
    },
  );

  testWidgets('brand mark widget resolves the SVG asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: El7reefBrandMark(size: 96))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(El7reefBrandMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
