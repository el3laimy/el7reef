import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/core/widgets/el7reef_solid_surface.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';
import 'package:el7reef/features/profile/models/public_player_profile_data.dart';
import 'package:el7reef/features/shareables/controllers/champion_share_controller.dart';
import 'package:el7reef/features/shareables/controllers/player_share_controller.dart';
import 'package:el7reef/features/shareables/controllers/team_share_controller.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/widgets/champion_share_card.dart';
import 'package:el7reef/features/shareables/widgets/champion_celebration_sheet.dart';
import 'package:el7reef/features/shareables/widgets/player_share_card.dart';
import 'package:el7reef/features/shareables/widgets/post_match_pride_hub_sheet.dart';
import 'package:el7reef/features/shareables/widgets/pride_card_format_picker.dart';
import 'package:el7reef/features/shareables/widgets/team_share_card.dart';

void main() {
  test('builds a guest champion card with a public team target', () {
    final data = const ChampionShareController().build(
      tournament: _tournament(),
      champion: _participant(),
      logoUrl: 'https://example.com/champions.png',
    )!;

    expect(data.championName, 'أبطال الشارع');
    expect(data.teamKindLabel, 'فريق ضيف');
    expect(
      data.sharePayload.targetUrl.toString(),
      'https://el7reef-app.web.app/team/guestTeam/guest-team-1',
    );
    expect(data.sharePayload.analyticsParameters['cardType'], 'champion');
  });

  test('builds player and team cards with safe pride targets', () {
    final player = const PlayerShareController().build(
      profile: PublicPlayerProfileData(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'أحمد الحريف',
        photoUrl: 'https://example.com/player.png',
        totalGoals: 7,
        totalMvps: 2,
      ),
    );
    final team = const TeamShareController().buildGuest(
      team: GuestTeam(
        id: 'guest-team-1',
        name: 'أبطال الشارع',
        normalizedName: 'ابطال الشارع',
        creatorId: 'organizer-1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      tournamentId: 'tournament-1',
      tournamentName: 'كأس الحواري',
    );

    expect(player.sharePayload.targetUrl.path, '/player/player/player-1');
    expect(player.photoUrl, 'https://example.com/player.png');
    expect(team.sharePayload.targetUrl.path, '/team/guestTeam/guest-team-1');
    expect(team.tournamentName, 'كأس الحواري');
    expect(team.playerCount, isNull);
    expect(team.wins, isNull);
    expect(team.totalMatches, isNull);
  });

  testWidgets('renders pride cards and keeps exports free of glass blur', (
    tester,
  ) async {
    final champion = const ChampionShareController().build(
      tournament: _tournament(),
      champion: _participant(),
    )!;
    final player = const PlayerShareController().build(
      profile: const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف موهوب',
        totalGoals: 4,
        totalMvps: 1,
      ),
    );
    final team = const TeamShareController().buildGuest(
      team: GuestTeam(
        id: 'guest-team-1',
        name: 'أبطال الشارع',
        normalizedName: 'ابطال الشارع',
        creatorId: 'organizer-1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 450,
              child: ChampionShareCard(data: champion),
            ),
          ),
        ),
      ),
    );

    expect(find.text('أبطال الشارع'), findsWidgets);
    expect(find.text('لاعبين'), findsNothing);
    expect(find.text('فوز'), findsNothing);
    expect(find.text('مباريات'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 450,
              child: PlayerShareCard(data: player),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ضيف موهوب'), findsOneWidget);
    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 450,
              child: TeamShareCard(data: team),
            ),
          ),
        ),
      ),
    );

    expect(find.text('أبطال الشارع'), findsWidgets);
    expect(find.byType(El7reefSolidSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChampionShareCard(data: champion, exportMode: true),
        ),
      ),
    );

    expect(find.byType(El7reefSolidSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('routes every available post-match pride action', (tester) async {
    var openedResult = 0;
    var openedMvp = 0;
    var openedScorers = 0;
    var returned = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostMatchPrideHubSheet(
            scoreLine: 'الحريف 3 - 2 الخصم',
            hasMvp: true,
            canOpenTopScorers: true,
            onOpenResult: () => openedResult += 1,
            onOpenMvp: () => openedMvp += 1,
            onOpenTopScorers: () => openedScorers += 1,
            onReturnToMatch: () => returned += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('شارك كارت النتيجة'));
    await tester.tap(find.text('شارك كارت نجم المباراة'));
    await tester.tap(find.text('هدافو البطولة'));
    await tester.tap(find.text('العودة للمباراة'));

    expect(openedResult, 1);
    expect(openedMvp, 1);
    expect(openedScorers, 1);
    expect(returned, 1);
  });

  testWidgets('champion celebration keeps a working tournament return', (
    tester,
  ) async {
    var openedTournament = 0;
    final champion = const ChampionShareController().build(
      tournament: _tournament(),
      champion: _participant(),
    )!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChampionCelebrationSheet(
            data: champion,
            onViewTournament: () => openedTournament += 1,
          ),
        ),
      ),
    );

    expect(find.text('البطل اتوّج'), findsOneWidget);
    await tester.tap(find.text('عرض البطولة'));
    expect(openedTournament, 1);
  });

  testWidgets('share format picker returns the story ratio', (tester) async {
    PrideCardFormat? selectedFormat;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedFormat = await showPrideCardFormatPicker(context);
              },
              child: const Text('اختار المقاس'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('اختار المقاس'));
    await tester.pumpAndSettle();
    expect(find.text('منشور 4:5'), findsOneWidget);
    expect(find.text('ستوري 9:16'), findsOneWidget);
    expect(find.text('مربع 1:1'), findsOneWidget);
    expect(find.text('أفقي 16:9'), findsOneWidget);

    await tester.tap(find.text('ستوري 9:16'));
    await tester.pumpAndSettle();
    expect(selectedFormat, PrideCardFormat.story9x16);
  });
}

Tournament _tournament() {
  return Tournament(
    id: 'tournament-1',
    organizerId: 'organizer-1',
    name: 'كأس الحواري',
    format: TournamentFormat.knockoutOnly,
    teamSize: TournamentTeamSize.fiveVsFive,
    maxTeams: 8,
    status: TournamentStatus.completed,
    winnerParticipantId: 'participant-1',
    createdAt: DateTime(2026),
  );
}

TournamentParticipant _participant() {
  return TournamentParticipant(
    id: 'participant-1',
    tournamentId: 'tournament-1',
    sourceType: TournamentParticipantSourceType.guestTeam,
    sourceEntityId: 'guest-team-1',
    displayName: 'أبطال الشارع',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
