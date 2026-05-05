import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/tournament_top_scorers_resolver.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/features/shareables/controllers/top_scorers_share_controller.dart';
import 'package:el7reef/features/shareables/models/top_scorers_share_data.dart';
import 'package:el7reef/features/shareables/widgets/top_scorers_share_card.dart';

void main() {
  group('TopScorersShareController', () {
    test('maps tournament name and top five scorers', () {
      final scorers = [
        for (var index = 1; index <= 6; index += 1)
          TournamentTopScorerEntry(
            actor: ParticipantRef(
              kind: index == 2
                  ? ParticipantRefKind.guestPlayer
                  : ParticipantRefKind.player,
              id: 'scorer-$index',
              displayName: 'Scorer $index',
            ),
            goals: index,
          ),
      ];

      final data = const TopScorersShareController().build(
        tournamentName: 'Street Cup',
        scorers: scorers,
      );

      expect(data.title, 'هدافو البطولة');
      expect(data.tournamentName, 'Street Cup');
      expect(data.scorers, hasLength(5));
      expect(data.scorers.map((entry) => entry.rank), [1, 2, 3, 4, 5]);
      expect(data.scorers[1].isGuest, isTrue);
      expect(
        data.scorers.any((entry) => entry.displayName == 'Scorer 6'),
        isFalse,
      );
    });

    test('uses Arabic goal labels', () {
      const oneGoal = TopScorersShareEntryData(
        rank: 1,
        displayName: 'Ali',
        goals: 1,
        isGuest: false,
      );
      const twoGoals = TopScorersShareEntryData(
        rank: 2,
        displayName: 'Bassem',
        goals: 2,
        isGuest: true,
      );

      expect(oneGoal.goalLabel, '1 هدف');
      expect(twoGoals.goalLabel, '2 أهداف');
    });

    test('uses fallback names for empty tournament and scorer names', () {
      final data = const TopScorersShareController().build(
        tournamentName: '   ',
        scorers: const [
          TournamentTopScorerEntry(
            actor: ParticipantRef(
              kind: ParticipantRefKind.player,
              id: 'player-1',
              displayName: '   ',
            ),
            goals: 1,
          ),
        ],
      );

      expect(data.tournamentName, 'بطولة الحريف');
      expect(data.scorers.single.displayName, 'لاعب');
    });
  });

  testWidgets('renders tournament, scorers, guest badge, and brand', (
    tester,
  ) async {
    const data = TopScorersShareData(
      title: 'هدافو البطولة',
      tournamentName: 'Street Cup',
      scorers: [
        TopScorersShareEntryData(
          rank: 1,
          displayName: 'Ali',
          goals: 1,
          isGuest: false,
        ),
        TopScorersShareEntryData(
          rank: 2,
          displayName: 'ضيف هداف',
          goals: 3,
          isGuest: true,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: TopScorersShareCard(data: data)),
        ),
      ),
    );

    expect(find.text('هدافو البطولة'), findsOneWidget);
    expect(find.text('Street Cup'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('1 هدف'), findsOneWidget);
    expect(find.text('ضيف هداف'), findsOneWidget);
    expect(find.text('3 أهداف'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('الحريف'), findsOneWidget);
  });
}
