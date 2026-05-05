import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/shareables/controllers/mvp_share_controller.dart';
import 'package:el7reef/features/shareables/models/mvp_share_data.dart';
import 'package:el7reef/features/shareables/widgets/mvp_share_card.dart';

void main() {
  group('MvpShareController', () {
    test('maps MVP MatchEvent to display data', () {
      final data = const MvpShareController().buildFromEvent(
        match: _match(),
        event: MatchEvent(
          id: 'mvp-match-1',
          matchId: 'match-1',
          tournamentId: 'tournament-1',
          eventType: MatchEventType.mvp,
          sideKey: 'A',
          actor: ParticipantRef(
            kind: ParticipantRefKind.player,
            id: 'player-1',
            displayName: 'Ali MVP',
          ),
          createdBy: 'organizer-1',
          createdAt: DateTime(2026),
        ),
        tournamentName: 'Street Cup',
        teamALabel: 'الحريف',
        teamBLabel: 'الخصم',
      );

      expect(data.title, 'نجم المباراة');
      expect(data.mvpDisplayName, 'Ali MVP');
      expect(data.isGuest, isFalse);
      expect(data.tournamentName, 'Street Cup');
      expect(data.scoreLine, 'الحريف 3 - 2 الخصم');
      expect(data.sideLabel, 'الحريف');
      expect(data.brandLabel, 'الحريف');
    });

    test(
      'marks guest MVP and safely falls back for missing tournament name',
      () {
        final data = const MvpShareController().buildFromEvent(
          match: _match(),
          event: MatchEvent(
            id: 'mvp-match-1',
            matchId: 'match-1',
            eventType: MatchEventType.mvp,
            sideKey: 'B',
            actor: ParticipantRef(
              kind: ParticipantRefKind.guestPlayer,
              id: 'guest-1',
              displayName: 'ضيف المباراة',
              linkedPlayerId: 'linked-player-1',
            ),
            createdBy: 'organizer-1',
            createdAt: DateTime(2026),
          ),
          tournamentName: '   ',
          teamALabel: 'الحريف',
          teamBLabel: 'الخصم',
        );

        expect(data.mvpDisplayName, 'ضيف المباراة');
        expect(data.isGuest, isTrue);
        expect(data.tournamentName, 'بطولة الحريف');
        expect(data.sideLabel, 'الخصم');
      },
    );

    test('builds safe fallback data from Match.mvpPlayerId', () {
      final data = const MvpShareController().buildFallback(
        match: _match(mvpPlayerId: 'legacy-mvp'),
        mvpPlayerId: 'legacy-mvp',
        displayName: '   ',
        tournamentName: null,
      );

      expect(data.mvpDisplayName, 'نجم المباراة');
      expect(data.tournamentName, 'بطولة الحريف');
      expect(data.isGuest, isFalse);
    });
  });

  testWidgets('renders title, MVP name, score, branding, and guest badge', (
    tester,
  ) async {
    const data = MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: 'ضيف المباراة',
      isGuest: true,
      tournamentName: 'Street Cup',
      scoreLine: 'الحريف 3 - 2 الخصم',
      sideLabel: 'الخصم',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MvpShareCard(data: data)),
        ),
      ),
    );

    expect(find.text('نجم المباراة'), findsOneWidget);
    expect(find.text('ضيف المباراة'), findsOneWidget);
    expect(find.text('Street Cup'), findsOneWidget);
    expect(find.text('الحريف 3 - 2 الخصم'), findsOneWidget);
    expect(find.text('الخصم'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('الحريف'), findsWidgets);
  });
}

Match _match({String? mvpPlayerId}) {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    teamAId: 'team-a',
    teamBId: 'team-b',
    status: MatchStatus.completed,
    scoreTeamA: 3,
    scoreTeamB: 2,
    mvpPlayerId: mvpPlayerId,
    tournamentId: 'tournament-1',
    createdAt: DateTime(2026),
  );
}
