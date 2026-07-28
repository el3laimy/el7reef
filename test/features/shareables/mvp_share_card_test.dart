import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/core/widgets/el7reef_solid_surface.dart';
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
      )!;

      expect(data.title, 'نجم المباراة');
      expect(data.mvpDisplayName, 'Ali MVP');
      expect(data.isGuest, isFalse);
      expect(data.tournamentName, 'Street Cup');
      expect(data.scoreLine, 'الحريف 3 - 2 الخصم');
      expect(data.sideLabel, 'الحريف');
      expect(data.brandLabel, 'الحريف');
    });

    test('marks guest MVP without inventing a missing tournament name', () {
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
      )!;

      expect(data.mvpDisplayName, 'ضيف المباراة');
      expect(data.isGuest, isTrue);
      expect(data.tournamentName, isNull);
      expect(data.sideLabel, 'الخصم');
    });

    test('rejects legacy MVP data when the player name is missing', () {
      final data = const MvpShareController().buildFallback(
        match: _match(mvpPlayerId: 'legacy-mvp'),
        mvpPlayerId: 'legacy-mvp',
        displayName: '   ',
        tournamentName: null,
      );

      expect(data, isNull);
    });

    test('builds legacy MVP data only from a confirmed display name', () {
      final data = const MvpShareController().buildFallback(
        match: _match(mvpPlayerId: 'legacy-mvp'),
        mvpPlayerId: 'legacy-mvp',
        displayName: 'محمد الحريف',
      )!;

      expect(data.mvpDisplayName, 'محمد الحريف');
      expect(data.tournamentName, isNull);
      expect(data.isGuest, isFalse);
      expect(data.scoreLine, isNull);
    });

    test('rejects a fallback actor that does not match the settled MVP', () {
      final data = const MvpShareController().buildFallback(
        match: _match(mvpPlayerId: 'player-1'),
        mvpPlayerId: 'player-1',
        displayName: 'محمد الحريف',
        actor: const ParticipantRef(
          kind: ParticipantRefKind.player,
          id: 'player-2',
          displayName: 'لاعب آخر',
        ),
      );

      expect(data, isNull);
    });

    test('rejects MVP sharing before official tournament settlement', () {
      final event = MatchEvent(
        id: 'mvp-match-1',
        matchId: 'match-1',
        eventType: MatchEventType.mvp,
        sideKey: 'A',
        actor: const ParticipantRef(
          kind: ParticipantRefKind.player,
          id: 'player-1',
          displayName: 'علي',
        ),
        createdBy: 'organizer-1',
        createdAt: DateTime(2026),
      );

      expect(
        const MvpShareController().buildFromEvent(
          match: _match(status: MatchStatus.completed),
          event: event,
        ),
        isNull,
      );
      expect(
        const MvpShareController().buildFromEvent(
          match: _match(tournamentId: null),
          event: event,
        ),
        isNull,
      );
      expect(
        const MvpShareController().buildFromEvent(
          match: _match(),
          event: event.copyWith(tournamentId: 'another-tournament'),
        ),
        isNull,
      );
      expect(
        const MvpShareController().buildFromEvent(
          match: _match(),
          event: event.copyWith(
            actor: const ParticipantRef(
              kind: ParticipantRefKind.player,
              id: '   ',
              displayName: 'علي',
            ),
          ),
        ),
        isNull,
      );
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

    expect(find.text('نجم المباراة'), findsNWidgets(2));
    expect(find.text('ضيف المباراة'), findsOneWidget);
    expect(find.text('Street Cup'), findsOneWidget);
    expect(find.text('الحريف 3 - 2 الخصم'), findsOneWidget);
    expect(find.text('الخصم'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('الحريف'), findsWidgets);
    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('export mode keeps the share image free of live glass blur', (
    tester,
  ) async {
    const data = MvpShareData(
      title: 'نجم المباراة',
      mvpDisplayName: 'Ali MVP',
      isGuest: false,
      tournamentName: 'Street Cup',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MvpShareCard(data: data, exportMode: true)),
        ),
      ),
    );

    expect(find.text('Ali MVP'), findsOneWidget);
    expect(find.byType(El7reefSolidSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}

Match _match({
  String? mvpPlayerId,
  MatchStatus status = MatchStatus.settled,
  String? tournamentId = 'tournament-1',
}) {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    teamAId: 'team-a',
    teamBId: 'team-b',
    status: status,
    scoreTeamA: 3,
    scoreTeamB: 2,
    mvpPlayerId: mvpPlayerId,
    tournamentId: tournamentId,
    createdAt: DateTime(2026),
  );
}
