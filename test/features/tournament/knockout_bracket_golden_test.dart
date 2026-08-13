import 'package:el7reef/app/theme/app_theme.dart';
import 'package:el7reef/app/theme/app_colors.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/domain/entities/knockout_tie.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/features/tournament/widgets/knockout_bracket_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadArabicGoldenFont);

  testWidgets('round view stays readable at 360dp and 200 percent text', (
    tester,
  ) async {
    await _expectBracketGolden(
      tester,
      size: const Size(360, 800),
      viewMode: KnockoutBracketViewMode.round,
      goldenPath: 'goldens/knockout_round_360_text_200.png',
    );
  });

  testWidgets('full tree stays readable at 600dp and 200 percent text', (
    tester,
  ) async {
    await _expectBracketGolden(
      tester,
      size: const Size(600, 900),
      viewMode: KnockoutBracketViewMode.fullTree,
      goldenPath: 'goldens/knockout_full_tree_600_text_200.png',
    );
  });
}

Future<void> _expectBracketGolden(
  WidgetTester tester, {
  required Size size,
  required KnockoutBracketViewMode viewMode,
  required String goldenPath,
}) async {
  final goldenKey = GlobalKey();
  final scenario = _goldenBracketScenario();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final bracket = KnockoutBracketView(
    ties: scenario.ties,
    matchesById: scenario.matchesById,
    participantLabel: (participantId) =>
        scenario.participantLabels[participantId] ?? 'لم يتحدد',
    hideUnpublishedParticipants: false,
    viewMode: viewMode,
    expandFullTree: viewMode == KnockoutBracketViewMode.fullTree,
    headerData: const KnockoutBracketHeaderData(teamCount: 4, byeCount: 1),
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: const TextScaler.linear(2),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RepaintBoundary(
              key: goldenKey,
              child: ColoredBox(
                color: AppColors.background,
                child: SizedBox.fromSize(
                  size: size,
                  child: viewMode == KnockoutBracketViewMode.round
                      ? SingleChildScrollView(child: bracket)
                      : bracket,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(find.byKey(goldenKey), matchesGoldenFile(goldenPath));
}

Future<void> _loadArabicGoldenFont() async {
  final cairoLoader = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([cairoLoader.load(), iconLoader.load()]);
}

_GoldenBracketScenario _goldenBracketScenario() {
  final now = DateTime.utc(2026, 8, 1);
  final semiA = KnockoutTie(
    id: 'semi-a',
    tournamentId: 'golden-tournament',
    bracketId: 'golden-bracket',
    roundIndex: 0,
    slotNumber: 0,
    participantAId: 'team-a',
    winnerParticipantId: 'team-a',
    nextTieId: 'final',
    resolutionType: KnockoutTieResolution.bye,
    createdAt: now,
    updatedAt: now,
  );
  final semiB = KnockoutTie(
    id: 'semi-b',
    tournamentId: 'golden-tournament',
    bracketId: 'golden-bracket',
    roundIndex: 0,
    slotNumber: 1,
    participantAId: 'team-b',
    participantBId: 'team-c',
    winnerParticipantId: 'team-b',
    matchId: 'semi-b-match',
    nextTieId: 'final',
    resolutionType: KnockoutTieResolution.penalties,
    createdAt: now,
    updatedAt: now,
  );
  final finalTie = KnockoutTie(
    id: 'final',
    tournamentId: 'golden-tournament',
    bracketId: 'golden-bracket',
    roundIndex: 1,
    slotNumber: 0,
    participantAId: 'team-a',
    participantBId: 'team-b',
    matchId: 'final-match',
    createdAt: now,
    updatedAt: now,
  );
  final penaltyMatch = Match(
    id: 'semi-b-match',
    organizerId: 'organizer',
    teamAParticipantId: 'team-b',
    teamBParticipantId: 'team-c',
    status: MatchStatus.settled,
    scoreTeamA: 2,
    scoreTeamB: 2,
    penaltyScoreTeamA: 5,
    penaltyScoreTeamB: 4,
    knockoutDecision: KnockoutDecision.teamA,
    stageType: TournamentStageType.knockoutStage,
    knockoutTieId: 'semi-b',
    fixtureStatus: FixtureStatus.completed,
    createdAt: now,
  );
  return _GoldenBracketScenario(
    ties: [semiA, semiB, finalTie],
    matchesById: {'semi-b-match': penaltyMatch},
    participantLabels: const {
      'team-a': 'نجوم الحارة الشرقية',
      'team-b': 'فرسان الملعب الشعبي',
      'team-c': 'نسور شارع البطولة',
    },
  );
}

class _GoldenBracketScenario {
  final List<KnockoutTie> ties;
  final Map<String, Match> matchesById;
  final Map<String, String> participantLabels;

  const _GoldenBracketScenario({
    required this.ties,
    required this.matchesById,
    required this.participantLabels,
  });
}
