import 'package:el7reef/app/theme/app_media_colors.dart';
import 'package:el7reef/core/identity/identity_preset_catalog.dart';
import 'package:el7reef/core/identity/identity_preset_mark.dart';
import 'package:el7reef/core/identity/identity_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a known preset with the code-native mark', (
    tester,
  ) async {
    final preset = IdentityPresetCatalog.teamBadges.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: IdentityVisual(
            source: preset.value,
            size: 96,
            semanticLabel: 'شعار الاختبار',
          ),
        ),
      ),
    );

    expect(find.byType(IdentityPresetMark), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('identity-mark-${preset.value}')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('شعار الاختبار'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('identity-visual-fallback')),
      findsNothing,
    );
  });

  testWidgets('uses fallback for empty and unknown preset references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: <Widget>[
            IdentityVisual(),
            IdentityVisual(source: 'preset://v1/team_badge/not_in_catalog'),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('identity-visual-fallback')),
      findsNWidgets(2),
    );
    expect(find.byType(IdentityPresetMark), findsNothing);
  });

  testWidgets('supports a caller-provided fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IdentityVisual(
          source: 'not-a-url',
          fallbackBuilder: (_) => const ColoredBox(
            key: ValueKey<String>('custom-fallback'),
            color: Colors.red,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('custom-fallback')), findsOneWidget);
  });

  testWidgets('dark media fallback stays independent from the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const IdentityVisual(
          appearance: IdentityVisualAppearance.onDarkMedia,
        ),
      ),
    );

    final fallback = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('identity-visual-fallback')),
    );
    expect((fallback.decoration as BoxDecoration).color, AppMediaColors.raised);
  });
}
