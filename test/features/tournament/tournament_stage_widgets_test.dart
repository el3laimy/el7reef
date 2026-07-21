import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/domain/entities/group_standing_snapshot.dart';
import 'package:el7reef/domain/entities/knockout_tie.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/tournament_group.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';
import 'package:el7reef/features/tournament/widgets/knockout_bracket_view.dart';
import 'package:el7reef/features/tournament/widgets/tournament_group_stage_overview.dart';
import 'package:el7reef/features/tournament/widgets/tournament_standings_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('knockout round labels describe the real bracket size', () {
    expect(knockoutRoundLabel(0, maxRoundIndex: 4), 'دور الـ32');
    expect(knockoutRoundLabel(1, maxRoundIndex: 4), 'دور الـ16');
    expect(knockoutRoundLabel(2, maxRoundIndex: 4), 'ربع النهائي');
    expect(knockoutRoundLabel(3, maxRoundIndex: 4), 'نصف النهائي');
    expect(knockoutRoundLabel(4, maxRoundIndex: 4), 'النهائي');
  });

  testWidgets(
    'standings expose compact expandable stats at 360 and every column at 600',
    (tester) async {
      final entries = _standingEntries();

      await _pumpAtSize(
        tester,
        size: const Size(360, 800),
        child: TournamentStandingsTable(
          entries: entries,
          qualifierParticipantIds: const {'team-a', 'team-b'},
          qualificationIsOfficial: false,
        ),
      );

      expect(find.text('داخل مراكز التأهل'), findsNWidgets(2));
      expect(find.text('فاز'), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(TournamentStandingsTable)),
        ),
        TextDirection.rtl,
      );

      await tester.tap(find.text('نجوم الحارة'));
      await tester.pumpAndSettle();
      expect(find.text('فاز'), findsOne);
      expect(find.text('تعادل'), findsOne);
      expect(find.text('خسر'), findsOne);

      await _pumpAtSize(
        tester,
        size: const Size(600, 900),
        child: TournamentStandingsTable(
          entries: entries,
          qualifierParticipantIds: const {'team-a', 'team-b'},
          qualificationIsOfficial: true,
        ),
      );

      for (final header in <String>[
        'لعب',
        'فاز',
        'تعادل',
        'خسر',
        'له',
        'عليه',
        'فرق',
        'نقاط',
      ]) {
        expect(find.text(header), findsOne);
      }
      expect(find.text('متأهل'), findsNWidgets(2));
      expect(find.text(' رسميًا'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'legacy odd and even groups reconstruct every fixture into valid rounds',
    () {
      for (final teamCount in const [3, 4]) {
        final participantIds = <String>[
          for (var index = 0; index < teamCount; index++) 'team-$index',
        ];
        final fixtures = <Match>[
          for (var home = 0; home < teamCount; home++)
            for (var away = home + 1; away < teamCount; away++)
              _groupFixture(
                'match-$home-$away',
                participantIds[home],
                participantIds[away],
              ),
        ];

        final rounds = deriveGroupFixtureRounds(
          participantIds: participantIds,
          fixtures: fixtures,
        );

        expect(rounds, hasLength(teamCount.isOdd ? teamCount : teamCount - 1));
        expect(
          rounds.map((round) => round.fixtures.length),
          everyElement(teamCount ~/ 2),
        );
        for (final round in rounds) {
          final roundParticipantIds = <String>{};
          for (final fixture in round.fixtures) {
            expect(
              roundParticipantIds.add(fixture.teamAParticipantId!),
              isTrue,
            );
            expect(
              roundParticipantIds.add(fixture.teamBParticipantId!),
              isTrue,
            );
          }
        }
        expect(
          rounds.expand((round) => round.fixtures).map((fixture) => fixture.id),
          containsAll(fixtures.map((fixture) => fixture.id)),
        );
      }
    },
  );

  testWidgets('group overview stays RTL and responsive at 360 and 600', (
    tester,
  ) async {
    final scenario = _groupStageScenario();

    for (final size in const [Size(360, 1000), Size(600, 1000)]) {
      await _pumpAtSize(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: TournamentGroupStageOverview(
            groups: [scenario.group],
            participantsByGroupId: {scenario.group.id: scenario.participants},
            standings: [scenario.standings],
            visibleFixtures: scenario.fixtures,
            allFixtures: scenario.fixtures,
            fixtureTeamLabel: (fixture, {required isHome}) {
              final participantId = isHome
                  ? fixture.teamAParticipantId
                  : fixture.teamBParticipantId;
              return scenario.participantLabels[participantId] ?? 'لم يتحدد';
            },
          ),
        ),
      );

      expect(find.text('1 من 3 نتيجة معتمدة'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byType(TournamentGroupStageOverview)),
        ),
        TextDirection.rtl,
      );
      expect(
        find.byKey(
          ValueKey(
            size.width == 360
                ? 'standings-table-compact'
                : 'standings-table-wide',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'qualification share appears only after every group result is official',
    (tester) async {
      final scenario = _groupStageScenario();
      var shareCalls = 0;

      Widget overview(List<Match> fixtures) => SingleChildScrollView(
        child: TournamentGroupStageOverview(
          groups: [scenario.group],
          participantsByGroupId: {scenario.group.id: scenario.participants},
          standings: [scenario.standings],
          visibleFixtures: fixtures,
          allFixtures: fixtures,
          fixtureTeamLabel: (fixture, {required isHome}) {
            final participantId = isHome
                ? fixture.teamAParticipantId
                : fixture.teamBParticipantId;
            return scenario.participantLabels[participantId] ?? 'لم يتحدد';
          },
          onShareQualification: (group, entries, qualifiers, isOfficial) {
            expect(group.id, scenario.group.id);
            expect(entries, isNotEmpty);
            expect(qualifiers, contains('team-a'));
            expect(isOfficial, isTrue);
            shareCalls += 1;
          },
        ),
      );

      await _pumpAtSize(
        tester,
        size: const Size(360, 1000),
        child: overview(scenario.fixtures),
      );
      expect(
        find.byKey(const ValueKey('share-qualified-team-card')),
        findsNothing,
      );

      final officialFixtures = scenario.fixtures
          .map(
            (fixture) => fixture.copyWith(
              status: MatchStatus.settled,
              scoreTeamA: fixture.scoreTeamA ?? 0,
              scoreTeamB: fixture.scoreTeamB ?? 0,
            ),
          )
          .toList(growable: false);
      await _pumpAtSize(
        tester,
        size: const Size(360, 1000),
        child: overview(officialFixtures),
      );

      expect(
        find.byKey(const ValueKey('share-qualified-team-card')),
        findsNothing,
      );

      final completeOfficialFixtures = <Match>[
        ...officialFixtures,
        _groupFixture(
          'match-b-c',
          'team-b',
          'team-c',
        ).copyWith(status: MatchStatus.settled, scoreTeamA: 1, scoreTeamB: 1),
      ];
      await _pumpAtSize(
        tester,
        size: const Size(360, 1000),
        child: overview(completeOfficialFixtures),
      );

      expect(
        find.byKey(const ValueKey('share-qualified-team-card')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('share-qualified-team-card')));
      expect(shareCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact standings remain readable at 200 percent text scale', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      size: const Size(360, 900),
      textScaler: const TextScaler.linear(2),
      child: SingleChildScrollView(
        child: TournamentStandingsTable(
          entries: _standingEntries(),
          qualifierParticipantIds: const {'team-a', 'team-b'},
          qualificationIsOfficial: false,
        ),
      ),
    );

    await tester.tap(find.text('نجوم الحارة'));
    await tester.pumpAndSettle();

    expect(find.text('داخل مراكز التأهل'), findsNWidgets(2));
    expect(find.text('فاز'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile bracket opens the first pending round and keeps one page scroll',
    (tester) async {
      final bracket = _bracketScenario();

      await _pumpAtSize(
        tester,
        size: const Size(360, 900),
        child: SingleChildScrollView(
          child: KnockoutBracketView(
            ties: bracket.ties,
            matchesById: bracket.matchesById,
            participantLabel: (participantId) =>
                bracket.participantLabels[participantId] ?? 'لم يتحدد',
            hideUnpublishedParticipants: true,
          ),
        ),
      );

      expect(find.byType(KnockoutRoundPager), findsOne);
      expect(find.byType(PageView), findsNothing);
      expect(
        find.byKey(const ValueKey('bracket-journey-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bracket-round-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bracket-round-chip-1')),
        findsOneWidget,
      );
      expect(find.text('المحطة الأخيرة: الفائز يرفع الكأس'), findsOneWidget);
      expect(find.text('المسار الحاسم نحو الكأس'), findsWidgets);
      expect(find.byType(KnockoutMatchNode), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('bracket-round-chip-0')));
      await tester.pumpAndSettle();

      expect(find.text('تأهل مباشر'), findsWidgets);
      expect(find.text('بركلات الترجيح'), findsOne);
      expect(find.text('كل فرعين يلتقيان في النهائي'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('knockout-path-branch-نصف النهائي-0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('bracket-next-round')));
      await tester.pumpAndSettle();

      expect(find.text('المحطة الأخيرة: الفائز يرفع الكأس'), findsOneWidget);

      await tester.tap(find.text('الشجرة كاملة'));
      await tester.pumpAndSettle();

      expect(find.byType(KnockoutFullTree), findsOne);
      expect(find.byType(InteractiveViewer), findsOne);
      expect(find.byType(KnockoutMatchNode), findsNWidgets(3));
      expect(find.byKey(const ValueKey('knockout-tie-final')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bracket-champion-anchor')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bracket-focus-trophy')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bracket-focus-current')),
        findsOneWidget,
      );
      expect(find.text('الحالي'), findsOneWidget);
      expect(find.text('كامل'), findsOneWidget);
      expect(find.text('الكأس'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bracket-focus-trophy')));
      await tester.pumpAndSettle();

      final treeRect = tester.getRect(
        find.byKey(const ValueKey('knockout-interactive-tree')),
      );
      final trophyRect = tester.getRect(
        find.byKey(const ValueKey('bracket-champion-anchor')),
      );
      final finalRect = tester.getRect(
        find.byKey(const ValueKey('knockout-tie-final')),
      );
      expect(treeRect.overlaps(trophyRect), isTrue);
      expect(treeRect.overlaps(finalRect), isTrue);
      expect(find.text('الطرف الأول لم يُنشر'), findsOne);
      expect(find.text('الطرف الثاني لم يُنشر'), findsOne);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-07-19 large bracket trophy focus keeps the final and cup visible',
    (tester) async {
      // Regression: a 32-team tree focused on an empty connector because its
      // scene coordinates were scaled once by FittedBox and again by the
      // InteractiveViewer transformation.
      await _pumpAtSize(
        tester,
        size: const Size(360, 1000),
        child: SingleChildScrollView(
          child: KnockoutBracketView(
            ties: _largeBracketTies(),
            matchesById: const {},
            participantLabel: (participantId) => participantId ?? 'لم يتحدد',
            hideUnpublishedParticipants: false,
          ),
        ),
      );

      final selectorRect = tester.getRect(
        find.byKey(const ValueKey('bracket-round-selector')),
      );
      final selectedRoundRect = tester.getRect(
        find.byKey(const ValueKey('bracket-round-chip-4')),
      );
      expect(selectorRect.overlaps(selectedRoundRect), isTrue);

      await tester.tap(find.text('الشجرة كاملة'));
      await tester.pumpAndSettle();

      final initialTreeRect = tester.getRect(
        find.byKey(const ValueKey('knockout-interactive-tree')),
      );
      final currentTieRect = tester.getRect(
        find.byKey(const ValueKey('knockout-tie-r4-s0')),
      );
      expect(initialTreeRect.overlaps(currentTieRect), isTrue);

      await tester.tap(find.byKey(const ValueKey('bracket-focus-trophy')));
      await tester.pumpAndSettle();

      final treeRect = tester.getRect(
        find.byKey(const ValueKey('knockout-interactive-tree')),
      );
      final trophyRect = tester.getRect(
        find.byKey(const ValueKey('bracket-champion-anchor')),
      );
      final finalRect = tester.getRect(
        find.byKey(const ValueKey('knockout-tie-r4-s0')),
      );
      expect(treeRect.overlaps(trophyRect), isTrue);
      expect(treeRect.overlaps(finalRect), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bracket stays navigable at 200 percent text scale', (
    tester,
  ) async {
    final bracket = _bracketScenario();
    await _pumpAtSize(
      tester,
      size: const Size(360, 1000),
      textScaler: const TextScaler.linear(2),
      child: SingleChildScrollView(
        child: KnockoutBracketView(
          ties: bracket.ties,
          matchesById: bracket.matchesById,
          participantLabel: (participantId) =>
              bracket.participantLabels[participantId] ?? 'لم يتحدد',
          hideUnpublishedParticipants: true,
        ),
      ),
    );

    expect(find.byType(KnockoutRoundPager), findsOne);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('الشجرة كاملة'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed bracket exposes the earned champion path and trophy destination',
    (tester) async {
      final bracket = _bracketScenario();
      final completedTies = bracket.ties
          .map(
            (tie) => tie.id == 'final'
                ? tie.copyWith(
                    winnerParticipantId: 'team-a',
                    resolutionType: KnockoutTieResolution.regularTime,
                  )
                : tie,
          )
          .toList(growable: false);

      await _pumpAtSize(
        tester,
        size: const Size(600, 1000),
        child: SingleChildScrollView(
          child: KnockoutBracketView(
            ties: completedTies,
            matchesById: bracket.matchesById,
            participantLabel: (participantId) =>
                bracket.participantLabels[participantId] ?? 'لم يتحدد',
            hideUnpublishedParticipants: true,
          ),
        ),
      );

      expect(find.text('خُتم طريق البطولة'), findsOneWidget);
      expect(find.text('نجوم الحارة'), findsWidgets);

      await tester.tap(find.text('الشجرة كاملة'));
      await tester.pumpAndSettle();

      expect(find.text('مسار البطل'), findsOneWidget);
      expect(find.bySemanticsLabel('بطل البطولة، نجوم الحارة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bracket exposes concise linear TalkBack labels for BYE and penalties',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final bracket = _bracketScenario();

      await _pumpAtSize(
        tester,
        size: const Size(600, 1000),
        child: SingleChildScrollView(
          child: KnockoutBracketView(
            ties: bracket.ties,
            matchesById: bracket.matchesById,
            participantLabel: (participantId) =>
                bracket.participantLabels[participantId] ?? 'لم يتحدد',
            hideUnpublishedParticipants: true,
          ),
        ),
      );

      expect(
        Directionality.of(tester.element(find.byType(KnockoutBracketView))),
        TextDirection.rtl,
      );
      await tester.tap(find.byKey(const ValueKey('bracket-previous-round')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('نصف النهائي، نجوم الحارة، تأهل مباشر'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'نصف النهائي، الفرسان ضد النسور، 2 - 2، '
          'حُسمت بركلات الترجيح 5 - 4',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('الشجرة كاملة'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.bySemanticsLabel('نصف النهائي، نجوم الحارة، تأهل مباشر'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semanticsHandle.dispose();
    },
  );
}

Future<void> _pumpAtSize(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: appChild!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SizedBox.expand(child: child)),
      ),
    ),
  );
  await tester.pump();
}

List<GroupStandingEntry> _standingEntries() {
  return const [
    GroupStandingEntry(
      participantId: 'team-a',
      displayName: 'نجوم الحارة',
      played: 3,
      wins: 2,
      draws: 1,
      goalsFor: 8,
      goalsAgainst: 3,
      rank: 1,
    ),
    GroupStandingEntry(
      participantId: 'team-b',
      displayName: 'أسود الملعب الشعبي',
      played: 3,
      wins: 2,
      losses: 1,
      goalsFor: 6,
      goalsAgainst: 4,
      rank: 2,
    ),
    GroupStandingEntry(
      participantId: 'team-c',
      displayName: 'الفرسان',
      played: 3,
      wins: 1,
      losses: 2,
      goalsFor: 4,
      goalsAgainst: 7,
      rank: 3,
    ),
  ];
}

Match _groupFixture(String id, String homeId, String awayId) {
  return Match(
    id: id,
    organizerId: 'organizer',
    teamAParticipantId: homeId,
    teamBParticipantId: awayId,
    stageType: TournamentStageType.groupStage,
    groupId: 'group-a',
    roundIndex: 1,
    createdAt: DateTime.utc(2026, 7, 14),
  );
}

_BracketScenario _bracketScenario() {
  final now = DateTime.utc(2026, 7, 14);
  final semiA = KnockoutTie(
    id: 'semi-a',
    tournamentId: 'tournament',
    bracketId: 'bracket',
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
    tournamentId: 'tournament',
    bracketId: 'bracket',
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
    tournamentId: 'tournament',
    bracketId: 'bracket',
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
  return _BracketScenario(
    ties: [semiA, semiB, finalTie],
    matchesById: {'semi-b-match': penaltyMatch},
    participantLabels: const {
      'team-a': 'نجوم الحارة',
      'team-b': 'الفرسان',
      'team-c': 'النسور',
    },
  );
}

List<KnockoutTie> _largeBracketTies() {
  final now = DateTime.utc(2026, 7, 19);
  final ties = <KnockoutTie>[];
  for (var round = 0; round < 5; round++) {
    final tieCount = 16 >> round;
    for (var slot = 0; slot < tieCount; slot++) {
      final id = 'r$round-s$slot';
      final isFinal = round == 4;
      ties.add(
        KnockoutTie(
          id: id,
          tournamentId: 'large-tournament',
          bracketId: 'large-bracket',
          roundIndex: round,
          slotNumber: slot,
          participantAId: 'team-$round-$slot-a',
          participantBId: 'team-$round-$slot-b',
          winnerParticipantId: isFinal ? null : 'team-$round-$slot-a',
          nextTieId: isFinal ? null : 'r${round + 1}-s${slot ~/ 2}',
          resolutionType: isFinal
              ? KnockoutTieResolution.pending
              : KnockoutTieResolution.regularTime,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
  return ties;
}

_GroupStageScenario _groupStageScenario() {
  final now = DateTime.utc(2026, 7, 14);
  const participantLabels = {
    'team-a': 'نجوم الحارة الشعبية',
    'team-b': 'أسود الملعب',
    'team-c': 'الفرسان',
  };
  final participants = participantLabels.entries
      .map(
        (entry) => TournamentParticipant(
          id: entry.key,
          tournamentId: 'tournament',
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: entry.key,
          displayName: entry.value,
          groupId: 'group-a',
          createdAt: now,
          updatedAt: now,
        ),
      )
      .toList(growable: false);
  final settledFixture = _groupFixture(
    'match-a-b',
    'team-a',
    'team-b',
  ).copyWith(status: MatchStatus.settled, scoreTeamA: 2, scoreTeamB: 1);
  final openFixture = _groupFixture('match-a-c', 'team-a', 'team-c');

  return _GroupStageScenario(
    group: TournamentGroup(
      id: 'group-a',
      tournamentId: 'tournament',
      groupStageId: 'group-stage',
      name: 'المجموعة الأولى',
      order: 0,
      participantIds: participantLabels.keys.toList(growable: false),
      qualifierParticipantIds: const ['team-a', 'team-b'],
      createdAt: now,
      updatedAt: now,
    ),
    participants: participants,
    standings: GroupStandingSnapshot(
      id: 'standings-a',
      tournamentId: 'tournament',
      groupStageId: 'group-stage',
      groupId: 'group-a',
      entries: _standingEntries(),
      qualifierParticipantIds: const ['team-a', 'team-b'],
      createdAt: now,
      updatedAt: now,
    ),
    fixtures: [settledFixture, openFixture],
    participantLabels: participantLabels,
  );
}

class _BracketScenario {
  final List<KnockoutTie> ties;
  final Map<String, Match> matchesById;
  final Map<String, String> participantLabels;

  const _BracketScenario({
    required this.ties,
    required this.matchesById,
    required this.participantLabels,
  });
}

class _GroupStageScenario {
  final TournamentGroup group;
  final List<TournamentParticipant> participants;
  final GroupStandingSnapshot standings;
  final List<Match> fixtures;
  final Map<String, String> participantLabels;

  const _GroupStageScenario({
    required this.group,
    required this.participants,
    required this.standings,
    required this.fixtures,
    required this.participantLabels,
  });
}
