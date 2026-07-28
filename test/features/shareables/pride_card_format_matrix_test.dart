import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/app/theme/app_media_colors.dart';
import 'package:el7reef/core/lineup/lineup_types.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/models/champion_share_data.dart';
import 'package:el7reef/features/shareables/models/lineup_share_data.dart';
import 'package:el7reef/features/shareables/models/match_result_share_data.dart';
import 'package:el7reef/features/shareables/models/mvp_share_data.dart';
import 'package:el7reef/features/shareables/models/player_share_data.dart';
import 'package:el7reef/features/shareables/models/player_moment_share_data.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/qualification_share_data.dart';
import 'package:el7reef/features/shareables/models/team_share_data.dart';
import 'package:el7reef/features/shareables/models/top_scorers_share_data.dart';
import 'package:el7reef/features/shareables/models/tournament_announcement_share_data.dart';
import 'package:el7reef/features/shareables/widgets/champion_share_card.dart';
import 'package:el7reef/features/shareables/widgets/lineup_share_card.dart';
import 'package:el7reef/features/shareables/widgets/match_result_share_card.dart';
import 'package:el7reef/features/shareables/widgets/mvp_share_card.dart';
import 'package:el7reef/features/shareables/widgets/player_share_card.dart';
import 'package:el7reef/features/shareables/widgets/player_moment_share_card.dart';
import 'package:el7reef/features/shareables/widgets/qualification_share_card.dart';
import 'package:el7reef/features/shareables/widgets/pride_card_shell.dart';
import 'package:el7reef/features/shareables/widgets/team_share_card.dart';
import 'package:el7reef/features/shareables/widgets/top_scorers_share_card.dart';
import 'package:el7reef/features/shareables/widgets/tournament_announcement_share_card.dart';

import 'pride_card_test_font.dart';

void main() {
  setUpAll(loadPrideCardTestFont);

  for (final format in PrideCardFormat.values) {
    testWidgets('all verified Pride cards fit ${format.name}', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final card in _cards(format)) {
        await tester.pumpWidget(
          MaterialApp(
            theme: prideCardTestTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(body: Center(child: card)),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${card.runtimeType} overflowed in ${format.name}',
        );
        expect(find.byType(PrideCardShell), findsOneWidget);
        expect(
          tester.getSize(find.byType(PrideCardShell)),
          Size(format.width, format.height),
          reason:
              '${card.runtimeType} did not preserve the ${format.name} export boundary',
        );
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: '${card.runtimeType} exported glass in ${format.name}',
        );
      }
    });

    testWidgets('accessible Pride previews fit ${format.name}', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final card in _cards(format, exportMode: false)) {
        await tester.pumpWidget(
          MaterialApp(
            theme: prideCardTestTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: format.width,
                    height: format.height,
                    child: card,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${card.runtimeType} preview overflowed in ${format.name}',
        );
        expect(find.byType(PrideCardShell), findsOneWidget);
        expect(
          tester.getSize(find.byType(PrideCardShell)),
          Size(format.width, format.height),
          reason:
              '${card.runtimeType} did not preserve the ${format.name} preview boundary',
        );
      }
    });
  }
}

List<Widget> _cards(PrideCardFormat format, {bool exportMode = true}) {
  return [
    MatchResultShareCard(
      exportMode: exportMode,
      format: format,
      data: const MatchResultShareData(
        matchId: 'match-1',
        title: 'النتيجة الرسمية',
        subtitle: 'نهائي بطولة أبطال شوارع القاهرة الكبرى',
        teamAName: 'نجوم الحارة الشرقية',
        teamAAccent: AppMediaColors.actionPrimary,
        teamBName: 'أسود الميدان الغربية',
        teamBAccent: AppMediaColors.info,
        scoreA: 5,
        scoreB: 4,
        statusLabel: 'معتمدة',
        winnerSide: 'A',
        tournamentName: 'كأس الحواري الكبرى',
        mvpName: 'عبد الرحمن محمد الحريف',
      ),
    ),
    MvpShareCard(
      exportMode: exportMode,
      format: format,
      data: const MvpShareData(
        title: 'نجم المباراة النهائية',
        mvpDisplayName: 'عبد الرحمن محمد أبو زيد الحريف',
        isGuest: true,
        tournamentName: 'كأس الحواري الكبرى',
        scoreLine: 'نجوم الحارة 5 - 4 أسود الميدان',
        sideLabel: 'نجوم الحارة الشرقية',
      ),
    ),
    TopScorersShareCard(
      exportMode: exportMode,
      format: format,
      data: const TopScorersShareData(
        title: 'هدافو البطولة',
        tournamentName: 'كأس الحواري الكبرى',
        scorers: [
          TopScorersShareEntryData(
            rank: 1,
            displayName: 'عبد الرحمن محمد أبو زيد',
            goals: 12,
            isGuest: true,
          ),
          TopScorersShareEntryData(
            rank: 2,
            displayName: 'حسام أحمد الحريف',
            goals: 9,
            isGuest: false,
          ),
          TopScorersShareEntryData(
            rank: 3,
            displayName: 'محمود ناصر',
            goals: 7,
            isGuest: false,
          ),
        ],
      ),
    ),
    ChampionShareCard(
      exportMode: exportMode,
      format: format,
      data: ChampionShareData(
        tournamentName: 'كأس الحواري الكبرى',
        championName: 'نجوم الحارة الشرقية',
        teamKindLabel: 'فريق ضيف',
        initials: 'نح',
        sharePayload: _payload(ShareCardType.champion),
      ),
    ),
    PlayerShareCard(
      exportMode: exportMode,
      format: format,
      data: PlayerShareData(
        displayName: 'عبد الرحمن محمد أبو زيد الحريف',
        initials: 'عر',
        totalGoals: 20,
        totalMvps: 5,
        isGuest: true,
        sharePayload: _payload(ShareCardType.player),
      ),
    ),
    TeamShareCard(
      exportMode: exportMode,
      format: format,
      data: TeamShareData(
        teamName: 'نجوم الحارة الشرقية',
        initials: 'نح',
        teamKindLabel: 'فريق ضيف',
        tournamentName: 'كأس الحواري الكبرى',
        playerCount: 8,
        wins: 6,
        totalMatches: 7,
        sharePayload: _payload(ShareCardType.team),
      ),
    ),
    LineupShareCard(
      exportMode: exportMode,
      format: format,
      data: const LineupShareData(
        matchId: 'match-1',
        lineupOwnerType: LineupShareOwnerType.officialTeam,
        ownerId: 'team-1',
        teamName: 'نجوم الحارة الشرقية',
        teamLabel: 'فريق رسمي',
        initials: 'نح',
        accentColor: AppMediaColors.actionPrimary,
        formationCode: '2-2',
        teamSize: 5,
        lineupTypeLabel: 'فريق رسمي',
        matchLabel: 'نهائي كأس الحواري',
        statusLabel: 'التشكيلة المعتمدة',
        updatedLabel: '2026/07/14',
        pitchPlayers: [
          LineupSharePlayerData(
            id: 'player-1',
            displayName: 'عبد الرحمن',
            initials: 'عر',
            shirtNumber: 10,
            slotId: 'att-1',
            slotRole: SlotRole.att,
            slotX: 50,
            slotY: 45,
            isTemporary: false,
          ),
        ],
        benchPlayers: [
          LineupShareBenchPlayerData(
            id: 'bench-1',
            displayName: 'حسام أحمد',
            initials: 'حأ',
            shirtNumber: 7,
            isTemporary: false,
          ),
        ],
      ),
    ),
    TournamentAnnouncementShareCard(
      exportMode: exportMode,
      format: format,
      data: TournamentInviteShareData(
        tournamentName: 'بطولة أبطال شوارع القاهرة الكبرى الرمضانية',
        teamSizeLabel: '5 ضد 5',
        maxTeams: 8,
        location: 'ملعب الحارة الشرقية الرئيسي',
        startDate: DateTime(2026, 7, 20),
        registrationDeadline: DateTime(2026, 7, 19),
        sharePayload: _payload(ShareCardType.tournamentInvite),
      ),
    ),
    TournamentAnnouncementShareCard(
      exportMode: exportMode,
      format: format,
      data: UpcomingFixtureShareData(
        tournamentName: 'بطولة أبطال شوارع القاهرة الكبرى الرمضانية',
        teamAName: 'نجوم الحارة الشرقية',
        teamBName: 'أسود الميدان الغربية',
        scheduledAt: DateTime(2026, 7, 20, 21, 30),
        stageLabel: 'دور المجموعات · الجولة الثانية',
        location: 'ملعب الحارة الشرقية الرئيسي',
        sharePayload: _payload(ShareCardType.upcomingFixture),
      ),
    ),
    PlayerMomentShareCard(
      exportMode: exportMode,
      format: format,
      data: GoalScorerShareData(
        actor: const ParticipantRef(
          kind: ParticipantRefKind.guestPlayer,
          id: 'guest-player-1',
          displayName: 'عبد الرحمن محمد أبو زيد الحريف',
        ),
        playerName: 'عبد الرحمن محمد أبو زيد الحريف',
        initials: 'عر',
        tournamentName: 'بطولة أبطال شوارع القاهرة الكبرى',
        sideKey: 'A',
        goalsInMatch: 3,
        teamAName: 'نجوم الحارة الشرقية',
        teamBName: 'أسود الميدان الغربية',
        scoreTeamA: 5,
        scoreTeamB: 4,
        sharePayload: _payload(ShareCardType.goalScorer),
      ),
    ),
    PlayerMomentShareCard(
      exportMode: exportMode,
      format: format,
      data: PlayerMilestoneShareData(
        actor: const ParticipantRef(
          kind: ParticipantRefKind.player,
          id: 'player-1',
          displayName: 'عبد الرحمن محمد أبو زيد الحريف',
        ),
        playerName: 'عبد الرحمن محمد أبو زيد الحريف',
        initials: 'عر',
        metric: PlayerMilestoneMetric.goals,
        milestone: 20,
        currentTotal: 24,
        sharePayload: _payload(ShareCardType.playerMilestone),
      ),
    ),
    QualificationShareCard(
      exportMode: exportMode,
      format: format,
      data: QualificationShareData(
        tournamentName: 'بطولة أبطال شوارع القاهرة الكبرى الرمضانية',
        groupName: 'المجموعة الأولى',
        teamName: 'نجوم الحارة الشرقية أصحاب الاسم الطويل',
        teamKindLabel: 'فريق ضيف',
        initials: 'نح',
        rank: 1,
        points: 9,
        goalDifference: 7,
        sharePayload: _payload(ShareCardType.qualification),
      ),
    ),
  ];
}

SharePayload _payload(ShareCardType type) {
  return SharePayload(
    cardType: type,
    entityType: ShareEntityType.tournament,
    entityId: 'entity-1',
    targetUrl: Uri.parse('https://el7reef-app.web.app/tournament/entity-1'),
    campaignSource: '${type.name.toLowerCase()}_card',
  );
}
