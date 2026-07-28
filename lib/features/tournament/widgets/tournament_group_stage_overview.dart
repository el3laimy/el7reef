import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament_group.dart';
import '../../../domain/entities/tournament_participant.dart';
import 'tournament_stage_components.dart';
import 'tournament_standings_table.dart';

typedef FixtureTeamLabelBuilder =
    String Function(Match fixture, {required bool isHome});
typedef GroupStandingsShareCallback =
    void Function(
      TournamentGroup group,
      List<GroupStandingEntry> entries,
      Set<String> qualifierParticipantIds,
      bool qualificationIsOfficial,
    );
typedef GroupQualificationShareCallback = GroupStandingsShareCallback;

class TournamentGroupStageOverview extends StatefulWidget {
  final List<TournamentGroup> groups;
  final Map<String, List<TournamentParticipant>> participantsByGroupId;
  final List<GroupStandingSnapshot> standings;
  final List<Match> visibleFixtures;
  final List<Match> allFixtures;
  final FixtureTeamLabelBuilder fixtureTeamLabel;
  final ValueChanged<Match>? onFixtureTap;
  final GroupStandingsShareCallback? onShareStandings;
  final GroupQualificationShareCallback? onShareQualification;

  const TournamentGroupStageOverview({
    super.key,
    required this.groups,
    required this.participantsByGroupId,
    required this.standings,
    required this.visibleFixtures,
    required this.allFixtures,
    required this.fixtureTeamLabel,
    this.onFixtureTap,
    this.onShareStandings,
    this.onShareQualification,
  });

  @override
  State<TournamentGroupStageOverview> createState() =>
      _TournamentGroupStageOverviewState();
}

class _TournamentGroupStageOverviewState
    extends State<TournamentGroupStageOverview> {
  String? _selectedGroupId;
  int _selectedRoundNumber = 1;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groups.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant TournamentGroupStageOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.groups.any((group) => group.id == _selectedGroupId)) {
      _selectedGroupId = widget.groups.firstOrNull?.id;
      _selectedRoundNumber = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = widget.groups
        .where((group) => group.id == _selectedGroupId)
        .firstOrNull;
    if (selectedGroup == null) {
      return const SizedBox.shrink();
    }

    final participants =
        widget.participantsByGroupId[selectedGroup.id] ??
        const <TournamentParticipant>[];
    final snapshot = widget.standings
        .where((standing) => standing.groupId == selectedGroup.id)
        .firstOrNull;
    final visibleGroupFixtures = widget.visibleFixtures
        .where((fixture) => fixture.groupId == selectedGroup.id)
        .toList(growable: false);
    final allGroupFixtures = widget.allFixtures
        .where((fixture) => fixture.groupId == selectedGroup.id)
        .toList(growable: false);
    final groupParticipantIds = _canonicalGroupParticipantIds(
      selectedGroup,
      participants,
    );
    final expectedFixturePairs = _circleRoundByPair(
      groupParticipantIds,
    ).keys.toSet();
    final fixturePairs = _groupFixturePairs(
      fixtures: allGroupFixtures,
      participants: participants,
      allowedParticipantIds: groupParticipantIds.toSet(),
    );
    final expectedFixtureCount = expectedFixturePairs.length;
    final fixtureScheduleIsComplete =
        expectedFixtureCount > 0 &&
        allGroupFixtures.length == expectedFixtureCount &&
        fixturePairs != null &&
        fixturePairs.length == expectedFixtureCount &&
        fixturePairs.containsAll(expectedFixturePairs);
    final rounds = deriveGroupFixtureRounds(
      participantIds: groupParticipantIds,
      fixtures: visibleGroupFixtures,
    );
    final hasSelectedRound = rounds
        .where((round) => round.number == _selectedRoundNumber)
        .isNotEmpty;
    final effectiveRoundNumber = rounds.isNotEmpty && !hasSelectedRound
        ? rounds.first.number
        : _selectedRoundNumber;

    final officialFixtures = allGroupFixtures
        .where((fixture) => fixture.isOfficialTournamentResult)
        .length;
    final qualificationIsOfficial =
        fixtureScheduleIsComplete && officialFixtures == expectedFixtureCount;
    final progressTarget = expectedFixtureCount > 0
        ? expectedFixtureCount
        : allGroupFixtures.length;
    final approvalProgress = progressTarget == 0
        ? 0.0
        : (officialFixtures / progressTarget).clamp(0.0, 1.0);
    final qualifiers =
        snapshot?.qualifierParticipantIds.toSet() ??
        selectedGroup.qualifierParticipantIds.toSet();
    final entries = _standingEntries(snapshot, participants);
    final currentRound = rounds
        .where((round) => round.number == effectiveRoundNumber)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        El7reefGlassSurface(
          role: El7reefGlassRole.floatingToolbar,
          tone: El7reefGlassTone.action,
          padding: const EdgeInsets.all(AppDimensions.xs),
          child: TournamentGroupSelector(
            items: widget.groups
                .map(
                  (group) => TournamentGroupSelectorItem(
                    id: group.id,
                    label: group.name,
                    trailingCount:
                        widget.participantsByGroupId[group.id]?.length ?? 0,
                  ),
                )
                .toList(growable: false),
            selectedId: selectedGroup.id,
            onSelected: (groupId) {
              setState(() {
                _selectedGroupId = groupId;
                _selectedRoundNumber = 1;
              });
            },
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        El7reefGlassSurface(
          role: El7reefGlassRole.hero,
          tone: El7reefGlassTone.action,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TournamentStageSectionHeading(
                title: selectedGroup.name,
                subtitle:
                    '${participants.length} فرق، ${allGroupFixtures.length} مباريات',
                trailing: El7reefBadge(
                  label: qualificationIsOfficial
                      ? 'الترتيب رسمي'
                      : 'الترتيب مؤقت',
                  color: qualificationIsOfficial
                      ? AppColors.success
                      : AppColors.primary,
                  icon: qualificationIsOfficial
                      ? Icons.verified_rounded
                      : Icons.schedule_rounded,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      allGroupFixtures.isEmpty
                          ? 'لم تبدأ مباريات المجموعة بعد'
                          : '$officialFixtures من $progressTarget نتيجة معتمدة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                  ),
                  Text(
                    allGroupFixtures.isEmpty
                        ? '0%'
                        : '${(approvalProgress * 100).round()}%',
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: qualificationIsOfficial
                          ? AppColors.success
                          : AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Semantics(
                label:
                    'تقدم اعتماد النتائج، $officialFixtures من $progressTarget',
                child: LinearProgressIndicator(
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  value: allGroupFixtures.isEmpty ? 0 : approvalProgress,
                  color: qualificationIsOfficial
                      ? AppColors.success
                      : AppColors.primary,
                  backgroundColor: AppColors.surfaceSunken,
                ),
              ),
              if (entries.isNotEmpty &&
                  (widget.onShareStandings != null ||
                      (qualificationIsOfficial &&
                          qualifiers.isNotEmpty &&
                          widget.onShareQualification != null))) ...[
                const SizedBox(height: AppDimensions.md),
                if (widget.onShareStandings != null)
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeightMd,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onShareStandings!(
                        selectedGroup,
                        entries,
                        qualifiers,
                        qualificationIsOfficial,
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('شارك جدول المجموعة'),
                    ),
                  ),
                if (qualificationIsOfficial &&
                    qualifiers.isNotEmpty &&
                    widget.onShareQualification != null) ...[
                  if (widget.onShareStandings != null)
                    const SizedBox(height: AppDimensions.sm),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeightMd,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('share-qualified-team-card'),
                      onPressed: () => widget.onShareQualification!(
                        selectedGroup,
                        entries,
                        qualifiers,
                        qualificationIsOfficial,
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('شارك بطاقة متأهل'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        El7reefSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TournamentStageSectionHeading(
                title: 'مباريات المجموعة',
                subtitle: rounds.isEmpty
                    ? 'لا توجد مباريات منشورة لهذه المجموعة.'
                    : 'تابع المواجهات والنتائج جولة بجولة.',
              ),
              if (rounds.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  height: AppDimensions.buttonHeightMd,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rounds.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppDimensions.sm),
                    itemBuilder: (context, index) {
                      final round = rounds[index];
                      return ChoiceChip(
                        key: ValueKey('group-round-${round.number}'),
                        label: Text('الجولة ${round.number}'),
                        selected: round.number == effectiveRoundNumber,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceSunken,
                        side: BorderSide(
                          color: round.number == effectiveRoundNumber
                              ? AppColors.primary
                              : AppColors.surfaceBorderStrong,
                        ),
                        labelStyle: AppTextStyles.labelLarge.copyWith(
                          color: round.number == effectiveRoundNumber
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedRoundNumber = round.number),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                if (currentRound != null)
                  ...currentRound.fixtures.map(
                    (fixture) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                      child: _GroupFixtureRow(
                        fixture: fixture,
                        homeLabel: widget.fixtureTeamLabel(
                          fixture,
                          isHome: true,
                        ),
                        awayLabel: widget.fixtureTeamLabel(
                          fixture,
                          isHome: false,
                        ),
                        onTap: widget.onFixtureTap == null
                            ? null
                            : () => widget.onFixtureTap!(fixture),
                      ),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: AppDimensions.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    allGroupFixtures.isEmpty
                        ? 'سيظهر جدول الجولات هنا بعد إنشاء المباريات.'
                        : 'لم تُنشر مباريات هذه المجموعة للجمهور بعد.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        El7reefSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TournamentStageSectionHeading(
                title: 'جدول ${selectedGroup.name}',
                subtitle: qualificationIsOfficial
                    ? 'اكتملت مباريات المجموعة، مراكز التأهل معتمدة.'
                    : 'المراكز تتغير مع كل نتيجة معتمدة.',
              ),
              const SizedBox(height: AppDimensions.md),
              TournamentStandingsTable(
                entries: entries,
                qualifierParticipantIds: qualifiers,
                qualificationIsOfficial: qualificationIsOfficial,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TournamentFixtureRound {
  final int number;
  final List<Match> fixtures;

  const TournamentFixtureRound({required this.number, required this.fixtures});
}

List<TournamentFixtureRound> deriveGroupFixtureRounds({
  required List<String> participantIds,
  required List<Match> fixtures,
}) {
  if (fixtures.isEmpty) {
    return const <TournamentFixtureRound>[];
  }

  final orderedParticipantIds = <String>[];
  for (final participantId in participantIds) {
    if (participantId.isNotEmpty &&
        !orderedParticipantIds.contains(participantId)) {
      orderedParticipantIds.add(participantId);
    }
  }
  for (final fixture in fixtures) {
    for (final participantId in <String?>[
      _fixtureParticipantId(fixture, isHome: true),
      _fixtureParticipantId(fixture, isHome: false),
    ]) {
      if (participantId != null &&
          participantId.isNotEmpty &&
          !orderedParticipantIds.contains(participantId)) {
        orderedParticipantIds.add(participantId);
      }
    }
  }

  final expectedRoundByPair = _circleRoundByPair(orderedParticipantIds);
  final rounds = <int, List<Match>>{};
  final unmatched = <Match>[];
  for (final fixture in fixtures) {
    final homeId = _fixtureParticipantId(fixture, isHome: true);
    final awayId = _fixtureParticipantId(fixture, isHome: false);
    final roundNumber = homeId == null || awayId == null
        ? null
        : expectedRoundByPair[_pairKey(homeId, awayId)];
    if (roundNumber == null) {
      unmatched.add(fixture);
    } else {
      rounds.putIfAbsent(roundNumber, () => <Match>[]).add(fixture);
    }
  }

  for (final fixture in unmatched) {
    var roundNumber = 1;
    while (!_canAddFixtureToRound(fixture, rounds[roundNumber] ?? const [])) {
      roundNumber++;
    }
    rounds.putIfAbsent(roundNumber, () => <Match>[]).add(fixture);
  }

  final sortedRoundNumbers = rounds.keys.toList()..sort();
  return sortedRoundNumbers
      .map((roundNumber) {
        final roundFixtures = rounds[roundNumber]!..sort(_compareFixtures);
        return TournamentFixtureRound(
          number: roundNumber,
          fixtures: List<Match>.unmodifiable(roundFixtures),
        );
      })
      .toList(growable: false);
}

List<String> _canonicalGroupParticipantIds(
  TournamentGroup group,
  List<TournamentParticipant> participants,
) {
  final canonicalById = _canonicalParticipantIdMap(participants);
  final declaredIds = group.participantIds.isEmpty
      ? participants.map((participant) => participant.id)
      : group.participantIds;
  final canonicalIds = <String>[];
  for (final rawId in declaredIds) {
    final normalizedId = rawId.trim();
    final canonicalId = canonicalById[normalizedId] ?? normalizedId;
    if (canonicalId.isNotEmpty && !canonicalIds.contains(canonicalId)) {
      canonicalIds.add(canonicalId);
    }
  }
  return canonicalIds;
}

Set<String>? _groupFixturePairs({
  required List<Match> fixtures,
  required List<TournamentParticipant> participants,
  required Set<String> allowedParticipantIds,
}) {
  final canonicalById = _canonicalParticipantIdMap(participants);
  final pairs = <String>{};
  for (final fixture in fixtures) {
    final homeId = _canonicalFixtureSide(fixture, true, canonicalById);
    final awayId = _canonicalFixtureSide(fixture, false, canonicalById);
    if (homeId == null ||
        awayId == null ||
        homeId == awayId ||
        !allowedParticipantIds.contains(homeId) ||
        !allowedParticipantIds.contains(awayId) ||
        !pairs.add(_pairKey(homeId, awayId))) {
      return null;
    }
  }
  return pairs;
}

Map<String, String> _canonicalParticipantIdMap(
  List<TournamentParticipant> participants,
) {
  return <String, String>{
    for (final participant in participants) ...{
      participant.id.trim(): participant.id.trim(),
      participant.sourceEntityId.trim(): participant.id.trim(),
    },
  }..removeWhere((key, value) => key.isEmpty || value.isEmpty);
}

String? _canonicalFixtureSide(
  Match fixture,
  bool isHome,
  Map<String, String> canonicalById,
) {
  final rawId = _fixtureParticipantId(fixture, isHome: isHome)?.trim();
  if (rawId == null || rawId.isEmpty) return null;
  return canonicalById[rawId] ?? rawId;
}

Map<String, int> _circleRoundByPair(List<String> participantIds) {
  if (participantIds.length < 2) {
    return const <String, int>{};
  }
  final rotation = <String?>[...participantIds];
  if (rotation.length.isOdd) {
    rotation.add(null);
  }
  final roundByPair = <String, int>{};
  for (var round = 0; round < rotation.length - 1; round++) {
    for (var pair = 0; pair < rotation.length ~/ 2; pair++) {
      final first = rotation[pair];
      final second = rotation[rotation.length - 1 - pair];
      if (first != null && second != null) {
        roundByPair[_pairKey(first, second)] = round + 1;
      }
    }
    final last = rotation.removeLast();
    rotation.insert(1, last);
  }
  return roundByPair;
}

bool _canAddFixtureToRound(Match fixture, List<Match> roundFixtures) {
  final fixtureIds = <String?>{
    _fixtureParticipantId(fixture, isHome: true),
    _fixtureParticipantId(fixture, isHome: false),
  }..remove(null);
  for (final roundFixture in roundFixtures) {
    final roundFixtureIds = <String?>{
      _fixtureParticipantId(roundFixture, isHome: true),
      _fixtureParticipantId(roundFixture, isHome: false),
    }..remove(null);
    if (fixtureIds.intersection(roundFixtureIds).isNotEmpty) {
      return false;
    }
  }
  return true;
}

String? _fixtureParticipantId(Match fixture, {required bool isHome}) {
  final participantId = isHome
      ? fixture.teamAParticipantId
      : fixture.teamBParticipantId;
  if (participantId != null && participantId.isNotEmpty) {
    return participantId;
  }
  final fallbackId = isHome ? fixture.teamAId : fixture.teamBId;
  return fallbackId == null || fallbackId.isEmpty ? null : fallbackId;
}

String _pairKey(String first, String second) {
  return first.compareTo(second) <= 0 ? '$first::$second' : '$second::$first';
}

int _compareFixtures(Match left, Match right) {
  final slotComparison = (left.slotNumber ?? 1 << 20).compareTo(
    right.slotNumber ?? 1 << 20,
  );
  if (slotComparison != 0) {
    return slotComparison;
  }
  return (left.scheduledAt ?? left.createdAt).compareTo(
    right.scheduledAt ?? right.createdAt,
  );
}

List<GroupStandingEntry> _standingEntries(
  GroupStandingSnapshot? snapshot,
  List<TournamentParticipant> participants,
) {
  if (snapshot != null && snapshot.entries.isNotEmpty) {
    return snapshot.entries.toList(growable: false)
      ..sort((left, right) => left.rank.compareTo(right.rank));
  }
  final sortedParticipants = participants.toList(growable: false)
    ..sort((left, right) {
      final seedComparison = (left.seed ?? 1 << 20).compareTo(
        right.seed ?? 1 << 20,
      );
      if (seedComparison != 0) {
        return seedComparison;
      }
      return left.displayName.compareTo(right.displayName);
    });
  return <GroupStandingEntry>[
    for (var index = 0; index < sortedParticipants.length; index++)
      GroupStandingEntry(
        participantId: sortedParticipants[index].id,
        displayName: sortedParticipants[index].displayName,
        rank: index + 1,
      ),
  ];
}

class _GroupFixtureRow extends StatelessWidget {
  final Match fixture;
  final String homeLabel;
  final String awayLabel;
  final VoidCallback? onTap;

  const _GroupFixtureRow({
    required this.fixture,
    required this.homeLabel,
    required this.awayLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scoreLabel = _scoreLabel(fixture);
    final statusLabel = fixture.isOfficialTournamentResult
        ? 'نتيجة معتمدة'
        : switch (fixture.fixtureStatus) {
            FixtureStatus.draft => 'مسودة',
            FixtureStatus.published => 'معلنة',
            FixtureStatus.completed => 'بانتظار الاعتماد',
          };
    return Semantics(
      button: onTap != null,
      label: '$homeLabel ضد $awayLabel، $scoreLabel، $statusLabel',
      hint: onTap == null ? null : 'اضغط لعرض المباراة',
      child: Material(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(AppDimensions.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$homeLabel ضد $awayLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textSecondaryTinted,
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Icon(
                      fixture.isOfficialTournamentResult
                          ? Icons.verified_rounded
                          : Icons.schedule_rounded,
                      size: AppDimensions.iconSm,
                      color: fixture.isOfficialTournamentResult
                          ? AppColors.success
                          : AppColors.textSecondaryTinted,
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Expanded(
                      child: Text(
                        '$statusLabel، ${_formatDateTime(fixture.scheduledAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryTinted,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                        vertical: AppDimensions.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                        border: Border.all(
                          color: AppColors.surfaceBorderStrong,
                        ),
                      ),
                      child: Text(
                        scoreLabel,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: fixture.isOfficialTournamentResult
                              ? AppColors.primary
                              : AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _scoreLabel(Match match) {
  if (match.scoreTeamA == null || match.scoreTeamB == null) {
    return '—';
  }
  return '${match.scoreTeamA} - ${match.scoreTeamB}';
}

String _formatDateTime(DateTime? scheduledAt) {
  if (scheduledAt == null) {
    return 'الموعد غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd، HH:mm').format(scheduledAt);
}
