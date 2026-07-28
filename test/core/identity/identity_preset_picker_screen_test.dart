import 'package:el7reef/app/theme/app_theme.dart';
import 'package:el7reef/core/identity/identity_preset.dart';
import 'package:el7reef/core/identity/identity_preset_catalog.dart';
import 'package:el7reef/core/identity/identity_preset_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('team picker exposes badges, pennants, preview, and 3 columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const IdentityPresetPickerScreen(
          scope: IdentityPresetScope.team,
          previewTitle: 'نسور الحارة',
        ),
      ),
    );

    expect(find.text('اختيار هوية الفريق'), findsOneWidget);
    expect(find.text('نسور الحارة'), findsOneWidget);
    expect(find.text('شعارات'), findsOneWidget);
    expect(find.text('رايات'), findsOneWidget);

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);

    await tester.tap(find.text('رايات'));
    await tester.pumpAndSettle();
    expect(
      find.text(IdentityPresetCatalog.teamPennants.first.nameAr),
      findsOneWidget,
    );
  });

  testWidgets('selection updates preview and returns the stable reference', (
    tester,
  ) async {
    IdentityPresetSelection? result;
    final preset = IdentityPresetCatalog.teamBadges.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await IdentityPresetPickerScreen.show(
                context,
                scope: IdentityPresetScope.team,
                previewTitle: 'فريق الاختبار',
              );
            },
            child: const Text('افتح'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    final useButtonBefore = tester.widget<FilledButton>(
      find.byKey(const ValueKey('identity-use-action')),
    );
    expect(useButtonBefore.onPressed, isNull);

    await tester.tap(
      find.byKey(ValueKey<String>('identity-preset-${preset.value}')),
    );
    await tester.pump();

    final useButtonAfter = tester.widget<FilledButton>(
      find.byKey(const ValueKey('identity-use-action')),
    );
    expect(useButtonAfter.onPressed, isNotNull);
    expect(find.text(preset.nameAr), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('identity-use-action')));
    await tester.pumpAndSettle();

    expect(result?.isCleared, isFalse);
    expect(result?.reference, preset.value);
  });

  testWidgets('tournament picker has only tournament emblems and can clear', (
    tester,
  ) async {
    IdentityPresetSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await IdentityPresetPickerScreen.show(
                context,
                scope: IdentityPresetScope.tournament,
                initialReference:
                    IdentityPresetCatalog.tournamentEmblems.first.value,
              );
            },
            child: const Text('افتح'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(find.text('اختيار رمز البطولة'), findsOneWidget);
    expect(find.text('شعارات'), findsNothing);
    expect(find.text('رايات'), findsNothing);
    expect(
      find.text(IdentityPresetCatalog.tournamentEmblems.first.nameAr),
      findsWidgets,
    );

    await tester.tap(find.byKey(const ValueKey('identity-clear-action')));
    await tester.pumpAndSettle();

    expect(result?.isCleared, isTrue);
    expect(result?.reference, isNull);
  });
}
