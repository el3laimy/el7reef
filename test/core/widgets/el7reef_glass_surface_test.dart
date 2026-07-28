import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/core/widgets/el7reef_glass_surface.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('functional glass disabled renders a solid sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: El7reefGlassSurface(
            role: El7reefGlassRole.compactSheet,
            child: Text('زجاج'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('functional glass enabled blurs a sheet', (
    WidgetTester tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: El7reefGlassSurface(
            role: El7reefGlassRole.compactSheet,
            child: Text('زجاج'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('disabled animations override functional glass', (
    WidgetTester tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: El7reefGlassSurface(
              role: El7reefGlassRole.compactSheet,
              child: Text('زجاج'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('reduce glass kill switch overrides functional glass', (
    WidgetTester tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {
          FeatureFlagKey.functionalGlassEnabled: true,
          FeatureFlagKey.reduceGlassBlurEnabled: true,
        },
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: El7reefGlassSurface(
            role: El7reefGlassRole.compactSheet,
            child: Text('زجاج'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('high contrast overrides functional glass', (tester) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Scaffold(
            body: El7reefGlassSurface(
              role: El7reefGlassRole.hero,
              child: Text('تباين عالٍ'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('solid scope removes every backdrop filter', (tester) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: El7reefGlassScope(
          quality: El7reefGlassQuality.solid,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                El7reefGlassSurface(
                  role: El7reefGlassRole.hero,
                  child: Text('Hero'),
                ),
                El7reefGlassSurface(
                  role: El7reefGlassRole.floatingToolbar,
                  child: Text('Toolbar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('visible keyboard makes a compact sheet solid', (tester) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 260)),
          child: El7reefGlassSurface(
            role: El7reefGlassRole.compactSheet,
            child: Text('لوحة مفاتيح'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('opening a sheet suspends blur on the covered route', (
    tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.functionalGlassEnabled: true},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => El7reefGlassScope(child: child!),
        home: const _GlassModalHarness(),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('test-navigation-glass')),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('test-navigation-glass')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('test-sheet-glass')),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}

class _GlassModalHarness extends StatelessWidget {
  const _GlassModalHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => const El7reefGlassSurface(
                key: ValueKey('test-sheet-glass'),
                role: El7reefGlassRole.compactSheet,
                child: Text('محتوى'),
              ),
            );
          },
          child: const Text('افتح'),
        ),
      ),
      bottomNavigationBar: const El7reefGlassSurface(
        key: ValueKey('test-navigation-glass'),
        role: El7reefGlassRole.navigation,
        child: Text('تنقل'),
      ),
    );
  }
}
