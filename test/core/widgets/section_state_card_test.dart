import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/widgets/el7reef_glass_surface.dart';
import 'package:el7reef/core/widgets/section_state_card.dart';

void main() {
  testWidgets('error card shows retry action and uses error glass variant', (
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

    final surface = tester.widget<El7reefGlassSurface>(
      find.byType(El7reefGlassSurface),
    );
    expect(surface.variant, El7reefGlassVariant.error);

    await tester.tap(find.text('حاول تاني'));
    expect(retryCount, 1);
  });
}
