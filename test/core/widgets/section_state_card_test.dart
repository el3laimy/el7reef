import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/app/theme/app_glass_theme.dart';
import 'package:el7reef/core/widgets/el7reef_solid_surface.dart';
import 'package:el7reef/core/widgets/section_state_card.dart';

void main() {
  testWidgets('error card shows retry action on a solid error surface', (
    tester,
  ) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SectionStateCard.error(
              message: 'تعذر تحميل المتابعات',
              onAction: () {
                retryCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('تعذر تحميل المتابعات'), findsOneWidget);
    expect(find.text('حاول تاني'), findsOneWidget);

    final surface = tester.widget<El7reefSolidSurface>(
      find.byType(El7reefSolidSurface),
    );
    expect(surface.tone, El7reefGlassTone.error);

    await tester.tap(find.text('حاول تاني'));
    expect(retryCount, 1);
  });
}
