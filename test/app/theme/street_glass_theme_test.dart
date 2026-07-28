import 'package:el7reef/app/theme/app_colors.dart';
import 'package:el7reef/app/theme/app_dimensions.dart';
import 'package:el7reef/app/theme/app_glass_theme.dart';
import 'package:el7reef/app/theme/app_media_colors.dart';
import 'package:el7reef/app/theme/app_text_styles.dart';
import 'package:el7reef/app/theme/app_theme.dart';
import 'package:el7reef/core/widgets/el7reef_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + 0.05) / (low + 0.05);
}

double _hueDistance(Color first, Color second) {
  final firstHue = HSLColor.fromColor(first).hue;
  final secondHue = HSLColor.fromColor(second).hue;
  final distance = (firstHue - secondHue).abs();
  return distance > 180 ? 360 - distance : distance;
}

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
    final theme = AppTheme.lightTheme;
    final primaryButton = theme.filledButtonTheme.style!;

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
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

  test('Chalk and Cobalt separates action, social, tactical and pride', () {
    final theme = AppTheme.lightTheme;

    expect(AppColors.actionPrimary, isNot(AppColors.tactical));
    expect(
      _hueDistance(AppColors.socialAccent, AppColors.error),
      greaterThan(10),
    );
    expect(
      _hueDistance(AppColors.achievement, AppColors.warning),
      greaterThan(10),
    );
    expect(AppColors.competitive, isNot(AppColors.socialAccent));
    expect(theme.colorScheme.primary, AppColors.actionPrimary);
    expect(theme.colorScheme.secondary, AppColors.info);
    expect(theme.colorScheme.tertiary, AppColors.tactical);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(AppColors.background, const Color(0xFFEEF2F6));
    expect(AppColors.surface, const Color(0xFFF8FAFC));
    expect(AppColors.actionPrimary, const Color(0xFF315CC6));
    expect(AppColors.socialAccent, const Color(0xFFC84232));
    expect(AppColors.tactical, const Color(0xFF167247));
    expect(AppColors.competitive, const Color(0xFF6746B8));
  });

  test(
    'media palette remains dark and independent from operational colors',
    () {
      expect(AppMediaColors.canvas, const Color(0xFF10140F));
      expect(AppMediaColors.surface, isNot(AppColors.surface));
      expect(AppMediaColors.actionPrimary, isNot(AppColors.actionPrimary));
      expect(AppMediaColors.textPrimary, isNot(AppColors.textPrimary));
    },
  );

  test('daylight glass roles use the approved fixed specifications', () {
    const glass = AppGlassTheme.daylight;

    expect(glass.navigation.fill, const Color(0xC7F8FAFC));
    expect(glass.navigation.blurSigma, 18);
    expect(glass.navigation.radius, 28);
    expect(glass.hero.fill, const Color(0xB3F8FAFC));
    expect(glass.hero.blurSigma, 16);
    expect(glass.hero.radius, 30);
    expect(glass.floatingToolbar.fill, const Color(0xB8F8FAFC));
    expect(glass.floatingToolbar.blurSigma, 12);
    expect(glass.floatingToolbar.radius, 20);
    expect(glass.compactSheet.fill, const Color(0xE8FDFBF6));
    expect(glass.compactSheet.blurSigma, 16);
    expect(glass.compactSheet.radius, 28);
    expect(glass.previewToolbar.fill, const Color(0xBDF8FAFC));
    expect(glass.previewToolbar.blurSigma, 14);
    expect(glass.previewToolbar.radius, 24);
    expect(glass.mediaOverlay.fill, const Color(0x9417202C));
    expect(glass.mediaOverlay.blurSigma, 10);
    expect(glass.mediaOverlay.radius, 20);
    expect(glass.specularWidth, 0.75);
    expect(glass.pressScale, 0.98);
    expect(glass.pressDuration, const Duration(milliseconds: 150));
    expect(glass.selectionDuration, const Duration(milliseconds: 220));
    expect(glass.sheetDuration, const Duration(milliseconds: 250));
    expect(glass.motionCurve, Curves.easeOutQuart);
  });

  test('core palette keeps AA contrast for outdoor reading', () {
    expect(
      _contrastRatio(AppColors.textPrimary, AppColors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.textSecondary, AppColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.textMuted, AppColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.textOnPrimary, AppColors.actionPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('secondary controls stay neutral until interaction', () {
    final theme = AppTheme.lightTheme;
    final outlined = theme.outlinedButtonTheme.style!;

    expect(
      outlined.foregroundColor!.resolve(const <WidgetState>{}),
      AppColors.textPrimary,
    );
    expect(
      outlined.side!.resolve(const <WidgetState>{}),
      const BorderSide(color: AppColors.surfaceBorderStrong),
    );
    expect(
      outlined.side!.resolve(const <WidgetState>{WidgetState.focused}),
      const BorderSide(color: AppColors.actionPrimary, width: 1.5),
    );
    expect(theme.tabBarTheme.labelColor, AppColors.textPrimary);
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
