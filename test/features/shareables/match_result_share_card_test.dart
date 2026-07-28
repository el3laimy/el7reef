import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/app/theme/app_media_colors.dart';
import 'package:el7reef/core/identity/identity_preset_mark.dart';
import 'package:el7reef/core/widgets/el7reef_solid_surface.dart';
import 'package:el7reef/features/shareables/models/match_result_share_data.dart';
import 'package:el7reef/features/shareables/widgets/match_result_share_card.dart';

void main() {
  testWidgets('renders result card text on a solid preview surface', (
    tester,
  ) async {
    final data = _data();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MatchResultShareCard(data: data)),
        ),
      ),
    );

    expect(find.text('نتيجة المباراة'), findsOneWidget);
    expect(find.text('Street Cup'), findsOneWidget);
    expect(find.text('الحريف'), findsOneWidget);
    expect(find.text('الخصم'), findsOneWidget);
    expect(find.text('3 - 2'), findsOneWidget);
    expect(find.textContaining('Ali MVP'), findsOneWidget);
    expect(find.textContaining('الهدافون: أحمد ×2، باسم'), findsOneWidget);
    expect(find.byType(IdentityPresetMark), findsNWidgets(2));
    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('export mode keeps the result image free of live glass blur', (
    tester,
  ) async {
    final data = _data();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MatchResultShareCard(data: data, exportMode: true),
          ),
        ),
      ),
    );

    expect(find.text('3 - 2'), findsOneWidget);
    expect(find.byType(El7reefSolidSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}

MatchResultShareData _data() {
  return MatchResultShareData(
    matchId: 'match-1',
    title: 'نتيجة المباراة',
    subtitle: 'ملعب الحريف',
    teamAName: 'الحريف',
    teamALogoUrl: 'preset://v1/team_badge/falcon_wing',
    teamAAccent: AppMediaColors.actionPrimary,
    teamBName: 'الخصم',
    teamBLogoUrl: 'preset://v1/team_pennant/diagonal_dash',
    teamBAccent: AppMediaColors.error,
    scoreA: 3,
    scoreB: 2,
    statusLabel: 'نهاية المباراة',
    winnerSide: 'A',
    tournamentName: 'Street Cup',
    mvpName: 'Ali MVP',
    scorers: const [
      MatchResultScorerData(displayName: 'أحمد', sideKey: 'A', goals: 2),
      MatchResultScorerData(displayName: 'باسم', sideKey: 'B', goals: 1),
    ],
    playedAt: DateTime(2026, 7, 5),
  );
}
