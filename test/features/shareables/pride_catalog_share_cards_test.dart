import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/models/player_moment_share_data.dart';
import 'package:el7reef/features/shareables/widgets/player_moment_share_card.dart';

import 'pride_card_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrideCardTestFont);

  testWidgets('guest goal card renders its growth QR without glass', (
    tester,
  ) async {
    final payload =
        SharePayload(
          cardType: ShareCardType.goalScorer,
          entityType: ShareEntityType.guestPlayer,
          entityId: 'guest-1',
          tournamentId: 'tournament-1',
          matchId: 'match-1',
          targetUrl: Uri.parse(
            'https://el7reef-app.web.app/player/guestPlayer/guest-1',
          ),
          campaignSource: 'goal_scorer_card',
        ).withClaimUrl(
          Uri.parse(
            'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1',
          ),
        );
    final data = GoalScorerShareData(
      actor: const ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'أحمد الهداف',
      ),
      playerName: 'أحمد الهداف',
      initials: 'أه',
      sideKey: 'A',
      goalsInMatch: 3,
      teamAName: 'نجوم الحارة',
      teamBName: 'فرسان الميدان',
      scoreTeamA: 4,
      scoreTeamB: 2,
      sharePayload: payload,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: prideCardTestTheme(),
        home: Scaffold(
          body: PlayerMomentShareCard(
            data: data,
            exportMode: true,
            includeGrowthLink: true,
          ),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('أه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('growth kill switch keeps a verified mark and removes QR', (
    tester,
  ) async {
    final data = GoalScorerShareData(
      actor: const ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'أحمد الهداف',
      ),
      playerName: 'أحمد الهداف',
      initials: 'أه',
      sideKey: 'A',
      goalsInMatch: 1,
      scoreTeamA: 1,
      scoreTeamB: 0,
      sharePayload: SharePayload(
        cardType: ShareCardType.goalScorer,
        entityType: ShareEntityType.player,
        entityId: 'player-1',
        matchId: 'match-1',
        targetUrl: Uri.parse(
          'https://el7reef-app.web.app/player/player/player-1',
        ),
        campaignSource: 'goal_scorer_card',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: prideCardTestTheme(),
        home: Scaffold(
          body: PlayerMomentShareCard(data: data, exportMode: true),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('بطاقة موثقة من بيانات الحريف الحقيقية'), findsNothing);
    expect(find.textContaining('الأهداف موثقة'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
