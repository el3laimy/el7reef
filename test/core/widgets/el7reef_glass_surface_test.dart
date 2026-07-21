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
            variant: El7reefGlassVariant.sheet,
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
            variant: El7reefGlassVariant.sheet,
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
              variant: El7reefGlassVariant.sheet,
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
            variant: El7reefGlassVariant.sheet,
            child: Text('زجاج'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
