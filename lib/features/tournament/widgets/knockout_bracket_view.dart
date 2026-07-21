import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/knockout_tie.dart';
import '../../../domain/entities/match.dart';

enum KnockoutBracketViewMode { round, fullTree }

class KnockoutBracketView extends StatefulWidget {
  static const double fullTreeBreakpoint = 720;

  final List<KnockoutTie> ties;
  final Map<String, Match> matchesById;
  final String Function(String? participantId) participantLabel;
  final bool hideUnpublishedParticipants;
  final ValueChanged<Match>? onOpenMatch;
  final bool Function(Match match)? canReviewMatch;
  final ValueChanged<Match>? onReviewMatch;

  const KnockoutBracketView({
    super.key,
    required this.ties,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
    this.canReviewMatch,
    this.onReviewMatch,
  });

  @override
  State<KnockoutBracketView> createState() => _KnockoutBracketViewState();
}

class _KnockoutBracketViewState extends State<KnockoutBracketView> {
  KnockoutBracketViewMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final tiesByRound = groupKnockoutTiesByRound(widget.ties);
    final rounds = tiesByRound.keys.toList()..sort();
    if (rounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultMode =
            constraints.maxWidth >= KnockoutBracketView.fullTreeBreakpoint
            ? KnockoutBracketViewMode.fullTree
            : KnockoutBracketViewMode.round;
        final mode = _selectedMode ?? defaultMode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BracketJourneyHeader(
              tiesByRound: tiesByRound,
              participantLabel: widget.participantLabel,
            ),
            const SizedBox(height: AppDimensions.md),
            Semantics(
              container: true,
              label: 'طريقة عرض الأدوار الإقصائية',
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<KnockoutBracketViewMode>(
                  key: const ValueKey('bracket-view-mode'),
                  segments: const [
                    ButtonSegment(
                      value: KnockoutBracketViewMode.round,
                      label: Text('الجولات'),
                      icon: Icon(Icons.view_carousel_rounded),
                    ),
                    ButtonSegment(
                      value: KnockoutBracketViewMode.fullTree,
                      label: Text('الشجرة كاملة'),
                      icon: Icon(Icons.account_tree_rounded),
                    ),
                  ],
                  selected: <KnockoutBracketViewMode>{mode},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      return states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      return states.contains(WidgetState.selected)
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimaryTinted;
                    }),
                    side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                      return BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? AppColors.primary
                            : AppColors.surfaceBorderStrong,
                      );
                    }),
                    textStyle: WidgetStatePropertyAll<TextStyle>(
                      AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onSelectionChanged: (selection) {
                    setState(() => _selectedMode = selection.first);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeOutQuart,
              child: mode == KnockoutBracketViewMode.round
                  ? KnockoutRoundPager(
                      key: const ValueKey('bracket-round-pager'),
                      tiesByRound: tiesByRound,
                      matchesById: widget.matchesById,
                      participantLabel: widget.participantLabel,
                      hideUnpublishedParticipants:
                          widget.hideUnpublishedParticipants,
                      onOpenMatch: widget.onOpenMatch,
                      canReviewMatch: widget.canReviewMatch,
                      onReviewMatch: widget.onReviewMatch,
                    )
                  : KnockoutFullTree(
                      key: const ValueKey('bracket-full-tree'),
                      tiesByRound: tiesByRound,
                      matchesById: widget.matchesById,
                      participantLabel: widget.participantLabel,
                      hideUnpublishedParticipants:
                          widget.hideUnpublishedParticipants,
                      onOpenMatch: widget.onOpenMatch,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BracketJourneyHeader extends StatelessWidget {
  final Map<int, List<KnockoutTie>> tiesByRound;
  final String Function(String? participantId) participantLabel;

  const _BracketJourneyHeader({
    required this.tiesByRound,
    required this.participantLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = tiesByRound.keys.toList()..sort();
    final ties = tiesByRound.values.expand((round) => round).toList();
    final resolvedCount = ties
        .where((tie) => tie.winnerParticipantId?.isNotEmpty ?? false)
        .length;
    final finalTie = tiesByRound[rounds.last]!.first;
    final championId = finalTie.winnerParticipantId;
    final hasChampion = championId?.isNotEmpty ?? false;

    return Semantics(
      container: true,
      label: hasChampion
          ? 'اكتملت الأدوار الإقصائية، البطل ${participantLabel(championId)}'
          : 'تقدم الأدوار الإقصائية، $resolvedCount من ${ties.length} مواجهات حُسمت',
      child: Container(
        key: const ValueKey('bracket-journey-header'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: hasChampion
                ? AppColors.secondary.withValues(alpha: 0.44)
                : AppColors.surfaceBorderStrong,
          ),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasChampion
                          ? AppColors.secondary.withValues(alpha: 0.14)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                    child: Icon(
                      hasChampion
                          ? Icons.emoji_events_rounded
                          : Icons.route_rounded,
                      color: hasChampion
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasChampion
                              ? 'خُتم طريق البطولة'
                              : 'الطريق إلى الكأس',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: hasChampion
                                ? AppColors.secondary
                                : AppColors.textPrimaryTinted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          hasChampion
                              ? participantLabel(championId)
                              : '$resolvedCount من ${ties.length} مواجهات حُسمت',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryTinted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${rounds.length}',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: hasChampion
                          ? AppColors.secondary
                          : AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    'أدوار',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              _BracketProgressRail(
                rounds: rounds,
                tiesByRound: tiesByRound,
                hasChampion: hasChampion,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BracketProgressRail extends StatelessWidget {
  final List<int> rounds;
  final Map<int, List<KnockoutTie>> tiesByRound;
  final bool hasChampion;

  const _BracketProgressRail({
    required this.rounds,
    required this.tiesByRound,
    required this.hasChampion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < rounds.length; index++) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: 2,
                color: _roundResolved(index - 1)
                    ? AppColors.primary.withValues(alpha: 0.72)
                    : AppColors.surfaceBorderStrong,
              ),
            ),
          _ProgressStop(
            label: knockoutRoundLabel(
              rounds[index],
              maxRoundIndex: rounds.last,
            ),
            isResolved: _roundResolved(index),
            isFinal: index == rounds.length - 1,
            hasChampion: hasChampion,
          ),
        ],
      ],
    );
  }

  bool _roundResolved(int index) {
    return tiesByRound[rounds[index]]!.every(
      (tie) => tie.winnerParticipantId?.isNotEmpty ?? false,
    );
  }
}

class _ProgressStop extends StatelessWidget {
  final String label;
  final bool isResolved;
  final bool isFinal;
  final bool hasChampion;

  const _ProgressStop({
    required this.label,
    required this.isResolved,
    required this.isFinal,
    required this.hasChampion,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFinal && hasChampion
        ? AppColors.secondary
        : isResolved
        ? AppColors.primary
        : AppColors.textSecondaryTinted;
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isFinal ? 30 : 24,
            height: isFinal ? 30 : 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isResolved ? 0.18 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isResolved ? 2 : 1),
            ),
            child: Icon(
              isFinal
                  ? Icons.emoji_events_rounded
                  : Icons.sports_soccer_rounded,
              size: isFinal ? 17 : 13,
              color: color,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: isResolved ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Map<int, List<KnockoutTie>> groupKnockoutTiesByRound(List<KnockoutTie> ties) {
  final tiesByRound = <int, List<KnockoutTie>>{};
  for (final tie in ties) {
    tiesByRound.putIfAbsent(tie.roundIndex, () => <KnockoutTie>[]).add(tie);
  }
  for (final roundTies in tiesByRound.values) {
    roundTies.sort((left, right) {
      final slotComparison = left.slotNumber.compareTo(right.slotNumber);
      return slotComparison != 0 ? slotComparison : left.id.compareTo(right.id);
    });
  }
  return tiesByRound;
}

class KnockoutRoundPager extends StatefulWidget {
  final Map<int, List<KnockoutTie>> tiesByRound;
  final Map<String, Match> matchesById;
  final String Function(String? participantId) participantLabel;
  final bool hideUnpublishedParticipants;
  final ValueChanged<Match>? onOpenMatch;
  final bool Function(Match match)? canReviewMatch;
  final ValueChanged<Match>? onReviewMatch;

  const KnockoutRoundPager({
    super.key,
    required this.tiesByRound,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
    this.canReviewMatch,
    this.onReviewMatch,
  });

  @override
  State<KnockoutRoundPager> createState() => _KnockoutRoundPagerState();
}

class _KnockoutRoundPagerState extends State<KnockoutRoundPager> {
  late int _page;

  List<int> get _rounds => widget.tiesByRound.keys.toList()..sort();

  @override
  void initState() {
    super.initState();
    _page = _recommendedPage(_rounds);
  }

  @override
  void didUpdateWidget(covariant KnockoutRoundPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = math.max(0, _rounds.length - 1);
    if (_page > lastPage) {
      _page = lastPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rounds = _rounds;
    final finalRound = rounds.last;
    final selectedRound = rounds[_page.clamp(0, rounds.length - 1)];
    final selectedRoundTies = widget.tiesByRound[selectedRound]!;
    final resolvedInRound = selectedRoundTies
        .where((tie) => tie.winnerParticipantId?.isNotEmpty ?? false)
        .length;
    final nextRoundLabel = _page == rounds.length - 1
        ? null
        : knockoutRoundLabel(rounds[_page + 1], maxRoundIndex: finalRound);
    final branchConfig = (
      matchesById: widget.matchesById,
      roundLabel: knockoutRoundLabel(selectedRound, maxRoundIndex: finalRound),
      destinationLabel: nextRoundLabel,
      participantLabel: widget.participantLabel,
      hideUnpublishedParticipants: widget.hideUnpublishedParticipants,
      onOpenMatch: widget.onOpenMatch,
      canReviewMatch: widget.canReviewMatch,
      onReviewMatch: widget.onReviewMatch,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'الأدوار الإقصائية، عرض جولة واحدة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('bracket-previous-round'),
                tooltip: 'الجولة السابقة',
                onPressed: _page == 0 ? null : () => _goToPage(_page - 1),
                style: _roundNavigationButtonStyle,
                icon: const Icon(Icons.east_rounded),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      knockoutRoundLabel(
                        selectedRound,
                        maxRoundIndex: finalRound,
                      ),
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textPrimaryTinted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${selectedRoundTies.length} مواجهات، $resolvedInRound حُسمت',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              IconButton.filledTonal(
                key: const ValueKey('bracket-next-round'),
                tooltip: 'الجولة التالية',
                onPressed: _page == rounds.length - 1
                    ? null
                    : () => _goToPage(_page + 1),
                style: _roundNavigationButtonStyle,
                icon: const Icon(Icons.west_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _BracketRoundSelector(
            rounds: rounds,
            selectedPage: _page,
            tiesByRound: widget.tiesByRound,
            onSelected: _setPage,
          ),
          const SizedBox(height: AppDimensions.sm),
          _RoundDestinationStrip(
            isFinal: nextRoundLabel == null,
            label: nextRoundLabel == null
                ? 'المحطة الأخيرة: الفائز يرفع الكأس'
                : 'كل فرعين يلتقيان في $nextRoundLabel',
          ),
          const SizedBox(height: AppDimensions.sm),
          GestureDetector(
            key: ValueKey('knockout-round-content-$selectedRound'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -240 && _page < rounds.length - 1) {
                _setPage(_page + 1);
              } else if (velocity > 240 && _page > 0) {
                _setPage(_page - 1);
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeOutQuart,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.035, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey('knockout-round-branches-$selectedRound'),
                children: [
                  for (
                    var branchStart = 0;
                    branchStart < selectedRoundTies.length;
                    branchStart += 2
                  ) ...[
                    _KnockoutPathBranch(
                      branchIndex: branchStart ~/ 2,
                      ties: selectedRoundTies
                          .skip(branchStart)
                          .take(2)
                          .toList(growable: false),
                      config: branchConfig,
                    ),
                    if (branchStart + 2 < selectedRoundTies.length)
                      const SizedBox(height: AppDimensions.md),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    _setPage(page);
  }

  void _setPage(int page) {
    final nextPage = page.clamp(0, _rounds.length - 1);
    if (nextPage == _page) return;
    setState(() => _page = nextPage);
  }

  int _recommendedPage(List<int> rounds) {
    for (var index = 0; index < rounds.length; index++) {
      final ties = widget.tiesByRound[rounds[index]]!;
      if (ties.any((tie) => tie.winnerParticipantId?.isEmpty ?? true)) {
        return index;
      }
    }
    return math.max(0, rounds.length - 1);
  }

  ButtonStyle get _roundNavigationButtonStyle => IconButton.styleFrom(
    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
    foregroundColor: AppColors.primary,
    disabledBackgroundColor: AppColors.surfaceSunken,
    disabledForegroundColor: AppColors.textSecondaryTinted.withValues(
      alpha: 0.56,
    ),
    side: const BorderSide(color: AppColors.surfaceBorderStrong),
  );
}

class _BracketRoundSelector extends StatefulWidget {
  final List<int> rounds;
  final int selectedPage;
  final Map<int, List<KnockoutTie>> tiesByRound;
  final ValueChanged<int> onSelected;

  const _BracketRoundSelector({
    required this.rounds,
    required this.selectedPage,
    required this.tiesByRound,
    required this.onSelected,
  });

  @override
  State<_BracketRoundSelector> createState() => _BracketRoundSelectorState();
}

class _BracketRoundSelectorState extends State<_BracketRoundSelector> {
  final Map<int, GlobalKey> _roundKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scheduleSelectedRoundReveal(animate: false);
  }

  @override
  void didUpdateWidget(covariant _BracketRoundSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPage != widget.selectedPage ||
        !listEquals(oldWidget.rounds, widget.rounds)) {
      _scheduleSelectedRoundReveal(animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalRound = widget.rounds.last;
    return Semantics(
      container: true,
      label: 'اختيار دور الإقصائيات',
      child: SingleChildScrollView(
        key: const ValueKey('bracket-round-selector'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < widget.rounds.length; index++) ...[
              _BracketRoundChip(
                key: _roundKeys.putIfAbsent(
                  widget.rounds[index],
                  GlobalKey.new,
                ),
                roundLabel: knockoutRoundLabel(
                  widget.rounds[index],
                  maxRoundIndex: finalRound,
                ),
                selected: index == widget.selectedPage,
                completed: widget.tiesByRound[widget.rounds[index]]!.every(
                  (tie) => tie.winnerParticipantId?.isNotEmpty ?? false,
                ),
                onTap: () => widget.onSelected(index),
                roundIndex: widget.rounds[index],
              ),
              if (index < widget.rounds.length - 1)
                const SizedBox(width: AppDimensions.sm),
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleSelectedRoundReveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.rounds.isEmpty) return;
      final selectedIndex = widget.selectedPage.clamp(
        0,
        widget.rounds.length - 1,
      );
      final selectedContext =
          _roundKeys[widget.rounds[selectedIndex]]?.currentContext;
      if (selectedContext == null) return;
      Scrollable.ensureVisible(
        selectedContext,
        alignment: 0.5,
        duration: animate
            ? const Duration(milliseconds: AppDimensions.animNormal)
            : Duration.zero,
        curve: Curves.easeOutQuart,
      );
    });
  }
}

class _BracketRoundChip extends StatelessWidget {
  final String roundLabel;
  final bool selected;
  final bool completed;
  final VoidCallback onTap;
  final int roundIndex;

  const _BracketRoundChip({
    super.key,
    required this.roundLabel,
    required this.selected,
    required this.completed,
    required this.onTap,
    required this.roundIndex,
  });

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? AppColors.textOnPrimary
        : completed
        ? AppColors.primary
        : AppColors.textSecondaryTinted;
    return Semantics(
      selected: selected,
      button: true,
      label: completed ? '$roundLabel، اكتمل' : roundLabel,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: InkWell(
          key: ValueKey('bracket-round-chip-$roundIndex'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : completed
                    ? AppColors.primary.withValues(alpha: 0.48)
                    : AppColors.surfaceBorderStrong,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.sports_soccer_rounded,
                  size: AppDimensions.iconSm,
                  color: contentColor,
                ),
                const SizedBox(width: AppDimensions.xs),
                Text(
                  roundLabel,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: contentColor,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundDestinationStrip extends StatelessWidget {
  final bool isFinal;
  final String label;

  const _RoundDestinationStrip({required this.isFinal, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isFinal ? AppColors.secondary : AppColors.primary;
    return Container(
      key: const ValueKey('bracket-round-destination'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            isFinal ? Icons.emoji_events_rounded : Icons.route_rounded,
            color: color,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimaryTinted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _KnockoutPathBranchConfig = ({
  Map<String, Match> matchesById,
  String roundLabel,
  String? destinationLabel,
  String Function(String? participantId) participantLabel,
  bool hideUnpublishedParticipants,
  ValueChanged<Match>? onOpenMatch,
  bool Function(Match match)? canReviewMatch,
  ValueChanged<Match>? onReviewMatch,
});

class _KnockoutPathBranch extends StatelessWidget {
  final int branchIndex;
  final List<KnockoutTie> ties;
  final _KnockoutPathBranchConfig config;

  const _KnockoutPathBranch({
    required this.branchIndex,
    required this.ties,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = config.destinationLabel == null;
    final destinationColor = isFinal ? AppColors.secondary : AppColors.primary;
    final resolved = ties
        .map((tie) => tie.winnerParticipantId?.isNotEmpty ?? false)
        .toList(growable: false);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: isFinal
          ? 'المسار الحاسم نحو الكأس'
          : 'المسار ${branchIndex + 1} نحو ${config.destinationLabel}',
      child: Padding(
        key: ValueKey('knockout-path-branch-${config.roundLabel}-$branchIndex'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.xs,
          vertical: AppDimensions.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: destinationColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFinal ? Icons.emoji_events_rounded : Icons.route_rounded,
                    color: destinationColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    isFinal
                        ? 'المسار الحاسم نحو الكأس'
                        : 'المسار ${branchIndex + 1} إلى ${config.destinationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: destinationColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Stack(
              children: [
                if (ties.length > 1)
                  Positioned(
                    left: 0,
                    top: 24,
                    bottom: 24,
                    width: 28,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _BranchConnectorPainter(resolved: resolved),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(left: ties.length > 1 ? 32 : 0),
                  child: Column(
                    children: [
                      for (var index = 0; index < ties.length; index++) ...[
                        _buildTie(ties[index], index),
                        if (index < ties.length - 1)
                          const SizedBox(height: AppDimensions.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTie(KnockoutTie tie, int index) {
    final match = tie.matchId == null ? null : config.matchesById[tie.matchId!];
    final canReview =
        match != null &&
        config.onReviewMatch != null &&
        (config.canReviewMatch?.call(match) ?? false);
    return Semantics(
      sortKey: OrdinalSortKey(index.toDouble()),
      child: KnockoutMatchNode(
        tie: tie,
        match: match,
        roundLabel: config.roundLabel,
        displayLabel: ties.length == 1
            ? 'المواجهة الحاسمة'
            : 'مواجهة ${tie.slotNumber + 1}',
        participantLabel: config.participantLabel,
        hideParticipants:
            config.hideUnpublishedParticipants &&
            tie.matchId != null &&
            match == null,
        showActions: true,
        openActionLabel: config.canReviewMatch == null
            ? 'عرض المباراة'
            : 'إدارة المباراة',
        onOpen: match == null || config.onOpenMatch == null
            ? null
            : () => config.onOpenMatch!(match),
        onReview: canReview ? () => config.onReviewMatch!(match) : null,
      ),
    );
  }
}

class _BranchConnectorPainter extends CustomPainter {
  final List<bool> resolved;

  const _BranchConnectorPainter({required this.resolved});

  @override
  void paint(Canvas canvas, Size size) {
    final joinX = size.width * 0.52;
    final middleY = size.height / 2;
    final firstY = size.height * 0.25;
    final secondY = size.height * 0.75;
    final pendingPaint = Paint()
      ..color = AppColors.surfaceBorderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final resolvedPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    void drawLeg(double y, bool isResolved) {
      final paint = isResolved ? resolvedPaint : pendingPaint;
      canvas.drawLine(Offset(size.width, y), Offset(joinX, y), paint);
      canvas.drawCircle(Offset(size.width - 1, y), 3, paint);
    }

    drawLeg(firstY, resolved.isNotEmpty && resolved.first);
    drawLeg(secondY, resolved.length > 1 && resolved[1]);
    final branchPaint = resolved.every((value) => value)
        ? resolvedPaint
        : pendingPaint;
    canvas.drawLine(Offset(joinX, firstY), Offset(joinX, secondY), branchPaint);
    canvas.drawLine(Offset(joinX, middleY), Offset(0, middleY), branchPaint);
    canvas.drawCircle(Offset(1, middleY), 3.5, branchPaint);
  }

  @override
  bool shouldRepaint(covariant _BranchConnectorPainter oldDelegate) {
    return !listEquals(oldDelegate.resolved, resolved);
  }
}

class KnockoutFullTree extends StatefulWidget {
  static const double _nodeWidth = 210;
  static const double _baseNodeHeight = 176;
  static const double _horizontalGap = 64;
  static const double _verticalGap = 24;
  static const double _championWidth = 132;
  static const double _championGap = 54;

  final Map<int, List<KnockoutTie>> tiesByRound;
  final Map<String, Match> matchesById;
  final String Function(String? participantId) participantLabel;
  final bool hideUnpublishedParticipants;
  final ValueChanged<Match>? onOpenMatch;

  const KnockoutFullTree({
    super.key,
    required this.tiesByRound,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
  });

  @override
  State<KnockoutFullTree> createState() => _KnockoutFullTreeState();
}

class _KnockoutFullTreeState extends State<KnockoutFullTree> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _championAnchorKey = GlobalKey();
  Size? _initializedCanvasSize;
  Size? _initializedViewportSize;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rounds = widget.tiesByRound.keys.toList()..sort();
    final firstRoundCount = widget.tiesByRound[rounds.first]!.length;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final nodeHeight =
        KnockoutFullTree._baseNodeHeight + ((textScale - 1) * 122);
    final canvasHeight = math.max(
      380.0,
      (firstRoundCount * (nodeHeight + KnockoutFullTree._verticalGap)) -
          KnockoutFullTree._verticalGap,
    );
    final canvasWidth =
        (rounds.length * KnockoutFullTree._nodeWidth) +
        ((rounds.length - 1) * KnockoutFullTree._horizontalGap) +
        KnockoutFullTree._championWidth +
        KnockoutFullTree._championGap;
    final layouts = _buildLayouts(
      rounds: rounds,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      nodeHeight: nodeHeight,
    );
    final finalTie = widget.tiesByRound[rounds.last]!.first;
    final championId = finalTie.winnerParticipantId;
    final championHeight = 144 + ((textScale - 1) * 60);
    final championRect = Rect.fromLTWH(
      0,
      (canvasHeight - championHeight) / 2,
      KnockoutFullTree._championWidth,
      championHeight,
    );
    final activeTie = _activeTie(rounds);
    final currentFocusRect = _currentFocusRect(
      tie: activeTie,
      layouts: layouts,
      championRect: championRect,
    );
    final connectors = _buildConnectors(
      rounds: rounds,
      layouts: layouts,
      championId: championId,
      championRect: championRect,
      activeTieId: activeTie.id,
    );
    final viewportHeight = math.min(560.0, math.max(380.0, canvasHeight));
    final finalRound = rounds.last;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'الشجرة الإقصائية كاملة من اليمين إلى اليسار',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسحب للتنقل وقرّب بإصبعين. الخط المضيء يوضح طريق المتأهلين نحو الكأس.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            children: [
              const _BracketLegendDot(
                color: AppColors.primary,
                label: 'مسار متأهل',
              ),
              if (championId?.isNotEmpty ?? false)
                const _BracketLegendDot(
                  color: AppColors.secondary,
                  label: 'مسار البطل',
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Container(
            key: const ValueKey('knockout-interactive-tree'),
            height: viewportHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.surfaceBorderStrong),
            ),
            child: LayoutBuilder(
              builder: (context, viewportConstraints) {
                final viewportSize = Size(
                  viewportConstraints.maxWidth,
                  viewportConstraints.maxHeight,
                );
                final canvasSize = Size(canvasWidth, canvasHeight);
                final focusRect = championRect.expandToInclude(
                  layouts[finalTie.id]!.rect,
                );
                final geometry = (
                  canvasSize: canvasSize,
                  viewportSize: viewportSize,
                  focusRect: focusRect,
                  currentFocusRect: currentFocusRect,
                );
                final fitScale = _fitScale(
                  canvasSize: canvasSize,
                  viewportSize: viewportSize,
                );
                _scheduleInitialView(geometry);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        constrained: false,
                        minScale: math.max(0.04, fitScale * 0.75),
                        maxScale: 4,
                        boundaryMargin: EdgeInsets.all(
                          math.max(viewportSize.width, viewportSize.height),
                        ),
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: CustomPaint(
                                    painter: _BracketConnectorPainter(
                                      connectors: connectors,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fromRect(
                                rect: championRect,
                                child: _BracketChampionAnchor(
                                  key: _championAnchorKey,
                                  championLabel: championId?.isNotEmpty ?? false
                                      ? widget.participantLabel(championId)
                                      : null,
                                ),
                              ),
                              for (
                                var roundPosition = 0;
                                roundPosition < rounds.length;
                                roundPosition++
                              )
                                for (
                                  var tiePosition = 0;
                                  tiePosition <
                                      widget
                                          .tiesByRound[rounds[roundPosition]]!
                                          .length;
                                  tiePosition++
                                )
                                  _positionedNode((
                                    layout:
                                        layouts[widget
                                            .tiesByRound[rounds[roundPosition]]![tiePosition]
                                            .id]!,
                                    tie: widget
                                        .tiesByRound[rounds[roundPosition]]![tiePosition],
                                    roundLabel: knockoutRoundLabel(
                                      rounds[roundPosition],
                                      maxRoundIndex: finalRound,
                                    ),
                                    semanticsOrder:
                                        (roundPosition * 100 + tiePosition)
                                            .toDouble(),
                                    championId: championId,
                                    activeTieId: activeTie.id,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: AppDimensions.sm,
                      end: AppDimensions.sm,
                      child: Row(
                        children: [
                          _TreeControlButton(
                            key: const ValueKey('bracket-focus-current'),
                            tooltip: 'الانتقال إلى المواجهة الحالية',
                            icon: Icons.my_location_rounded,
                            label: 'الحالي',
                            onPressed: () => _focusCurrent(geometry),
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          _TreeControlButton(
                            key: const ValueKey('bracket-reset-view'),
                            tooltip: 'عرض الشجرة كاملة',
                            icon: Icons.fit_screen_rounded,
                            label: 'كامل',
                            onPressed: () => _resetView(geometry),
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          _TreeControlButton(
                            key: const ValueKey('bracket-focus-trophy'),
                            tooltip: 'الانتقال إلى النهائي والكأس',
                            icon: Icons.emoji_events_rounded,
                            label: 'الكأس',
                            color: championId?.isNotEmpty ?? false
                                ? AppColors.secondary
                                : AppColors.primary,
                            onPressed: () => _focusTrophy(geometry),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleInitialView(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    if (_initializedCanvasSize == geometry.canvasSize &&
        _initializedViewportSize == geometry.viewportSize) {
      return;
    }
    _initializedCanvasSize = geometry.canvasSize;
    _initializedViewportSize = geometry.viewportSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _initializedCanvasSize != geometry.canvasSize ||
          _initializedViewportSize != geometry.viewportSize) {
        return;
      }
      _focusCurrent(geometry);
    });
  }

  void _resetView(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    final scale = _fitScale(
      canvasSize: geometry.canvasSize,
      viewportSize: geometry.viewportSize,
    );
    _transformationController.value = _matrixForSceneRect(
      sceneRect: Offset.zero & geometry.canvasSize,
      viewportSize: geometry.viewportSize,
      scale: scale,
    );
  }

  void _focusCurrent(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    _transformationController.value = _matrixForSceneRect(
      sceneRect: geometry.currentFocusRect,
      viewportSize: geometry.viewportSize,
      scale: _currentFocusScale(geometry),
    );
  }

  void _focusTrophy(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    _transformationController.value = _matrixForSceneRect(
      sceneRect: geometry.focusRect,
      viewportSize: geometry.viewportSize,
      scale: _trophyFocusScale(geometry),
    );
    _revealChampionAnchor();
  }

  double _trophyFocusScale(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    const safePadding = AppDimensions.md * 2;
    final widthScale =
        math.max(1.0, geometry.viewportSize.width - safePadding) /
        geometry.focusRect.width;
    final heightScale =
        math.max(1.0, geometry.viewportSize.height - safePadding) /
        geometry.focusRect.height;
    final fitScale = _fitScale(
      canvasSize: geometry.canvasSize,
      viewportSize: geometry.viewportSize,
    );
    return math.min(widthScale, heightScale).clamp(fitScale, 1.35).toDouble();
  }

  double _currentFocusScale(
    ({
      Size canvasSize,
      Size viewportSize,
      Rect focusRect,
      Rect currentFocusRect,
    })
    geometry,
  ) {
    const safePadding = AppDimensions.md * 2;
    final widthScale =
        math.max(1.0, geometry.viewportSize.width - safePadding) /
        geometry.currentFocusRect.width;
    final heightScale =
        math.max(1.0, geometry.viewportSize.height - safePadding) /
        geometry.currentFocusRect.height;
    final fitScale = _fitScale(
      canvasSize: geometry.canvasSize,
      viewportSize: geometry.viewportSize,
    );
    return math.min(widthScale, heightScale).clamp(fitScale, 1.2).toDouble();
  }

  void _revealChampionAnchor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchorContext = _championAnchorKey.currentContext;
      if (!mounted || anchorContext == null) return;
      Scrollable.ensureVisible(
        anchorContext,
        alignment: 0.58,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuart,
      );
    });
  }

  double _fitScale({required Size canvasSize, required Size viewportSize}) {
    return math.min(
      viewportSize.width / canvasSize.width,
      viewportSize.height / canvasSize.height,
    );
  }

  Matrix4 _matrixForSceneRect({
    required Rect sceneRect,
    required Size viewportSize,
    required double scale,
  }) {
    final viewportCenter = viewportSize.center(Offset.zero);
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, viewportCenter.dx - (sceneRect.center.dx * scale))
      ..setEntry(1, 3, viewportCenter.dy - (sceneRect.center.dy * scale));
  }

  Map<String, _BracketNodeLayout> _buildLayouts({
    required List<int> rounds,
    required double canvasWidth,
    required double canvasHeight,
    required double nodeHeight,
  }) {
    final layouts = <String, _BracketNodeLayout>{};
    for (
      var roundPosition = 0;
      roundPosition < rounds.length;
      roundPosition++
    ) {
      final roundTies = widget.tiesByRound[rounds[roundPosition]]!;
      final segmentHeight = canvasHeight / roundTies.length;
      final x =
          canvasWidth -
          KnockoutFullTree._nodeWidth -
          (roundPosition *
              (KnockoutFullTree._nodeWidth + KnockoutFullTree._horizontalGap));
      for (var tiePosition = 0; tiePosition < roundTies.length; tiePosition++) {
        final y = (segmentHeight * (tiePosition + 0.5)) - (nodeHeight / 2);
        final tie = roundTies[tiePosition];
        layouts[tie.id] = _BracketNodeLayout(
          rect: Rect.fromLTWH(x, y, KnockoutFullTree._nodeWidth, nodeHeight),
        );
      }
    }
    return layouts;
  }

  KnockoutTie _activeTie(List<int> rounds) {
    for (final round in rounds) {
      final ties = widget.tiesByRound[round]!;
      for (final tie in ties) {
        if (tie.winnerParticipantId == null && tie.isReady) {
          return tie;
        }
      }
    }
    for (final round in rounds) {
      final unresolvedTie = widget.tiesByRound[round]!.where(
        (tie) => tie.winnerParticipantId == null,
      );
      if (unresolvedTie.isNotEmpty) {
        return unresolvedTie.first;
      }
    }
    return widget.tiesByRound[rounds.last]!.first;
  }

  Rect _currentFocusRect({
    required KnockoutTie tie,
    required Map<String, _BracketNodeLayout> layouts,
    required Rect championRect,
  }) {
    final tieRect = layouts[tie.id]!.rect;
    if (tie.nextTieId != null && layouts[tie.nextTieId] != null) {
      return tieRect.expandToInclude(layouts[tie.nextTieId]!.rect);
    }
    final finalRoundIndex = widget.tiesByRound.keys.reduce(
      (left, right) => left > right ? left : right,
    );
    final isFinalTie = tie.roundIndex == finalRoundIndex;
    return isFinalTie ? tieRect.expandToInclude(championRect) : tieRect;
  }

  List<_BracketConnector> _buildConnectors({
    required List<int> rounds,
    required Map<String, _BracketNodeLayout> layouts,
    required String? championId,
    required Rect championRect,
    required String activeTieId,
  }) {
    final connectors = <_BracketConnector>[];
    for (
      var roundPosition = 0;
      roundPosition < rounds.length - 1;
      roundPosition++
    ) {
      final roundTies = widget.tiesByRound[rounds[roundPosition]]!;
      final nextRoundTies = widget.tiesByRound[rounds[roundPosition + 1]]!;
      for (var tiePosition = 0; tiePosition < roundTies.length; tiePosition++) {
        final tie = roundTies[tiePosition];
        final source = layouts[tie.id]!;
        final fallbackTargetIndex = math.min(
          tiePosition ~/ 2,
          nextRoundTies.length - 1,
        );
        final target = tie.nextTieId == null
            ? layouts[nextRoundTies[fallbackTargetIndex].id]!
            : layouts[tie.nextTieId!] ??
                  layouts[nextRoundTies[fallbackTargetIndex].id]!;
        connectors.add(
          _BracketConnector(
            start: Offset(source.rect.left, source.rect.center.dy),
            end: Offset(target.rect.right, target.rect.center.dy),
            isResolved: tie.winnerParticipantId != null,
            isChampionPath:
                championId?.isNotEmpty == true &&
                tie.winnerParticipantId == championId,
            isActivePath:
                tie.id == activeTieId && tie.winnerParticipantId == null,
          ),
        );
      }
    }
    final finalTie = widget.tiesByRound[rounds.last]!.first;
    final finalLayout = layouts[finalTie.id]!;
    connectors.add(
      _BracketConnector(
        start: Offset(finalLayout.rect.left, finalLayout.rect.center.dy),
        end: Offset(championRect.right, championRect.center.dy),
        isResolved: finalTie.winnerParticipantId?.isNotEmpty ?? false,
        isChampionPath: finalTie.winnerParticipantId?.isNotEmpty ?? false,
        isActivePath:
            finalTie.id == activeTieId && finalTie.winnerParticipantId == null,
      ),
    );
    return connectors;
  }

  Widget _positionedNode(
    ({
      _BracketNodeLayout layout,
      KnockoutTie tie,
      String roundLabel,
      double semanticsOrder,
      String? championId,
      String activeTieId,
    })
    node,
  ) {
    final tie = node.tie;
    final match = tie.matchId == null ? null : widget.matchesById[tie.matchId!];
    return Positioned(
      left: node.layout.rect.left,
      top: node.layout.rect.top,
      width: node.layout.rect.width,
      height: node.layout.rect.height,
      child: Semantics(
        sortKey: OrdinalSortKey(node.semanticsOrder),
        child: KnockoutMatchNode(
          tie: tie,
          match: match,
          roundLabel: node.roundLabel,
          participantLabel: widget.participantLabel,
          hideParticipants:
              widget.hideUnpublishedParticipants &&
              tie.matchId != null &&
              match == null,
          compact: true,
          isChampionPath:
              node.championId?.isNotEmpty == true &&
              tie.winnerParticipantId == node.championId,
          isCurrentFocus:
              tie.id == node.activeTieId && tie.winnerParticipantId == null,
          showActions: false,
          openActionLabel: 'عرض المباراة',
          onOpen: match == null || widget.onOpenMatch == null
              ? null
              : () => widget.onOpenMatch!(match),
        ),
      ),
    );
  }
}

class _BracketLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _BracketLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimensions.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryTinted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BracketChampionAnchor extends StatelessWidget {
  final String? championLabel;

  const _BracketChampionAnchor({super.key, this.championLabel});

  @override
  Widget build(BuildContext context) {
    final hasChampion = championLabel?.isNotEmpty ?? false;
    return Semantics(
      container: true,
      label: hasChampion ? 'بطل البطولة، $championLabel' : 'وجهة الشجرة، الكأس',
      child: Container(
        key: const ValueKey('bracket-champion-anchor'),
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: hasChampion
              ? AppColors.secondary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: hasChampion
                ? AppColors.secondary.withValues(alpha: 0.78)
                : AppColors.surfaceBorderStrong,
            width: hasChampion ? 2 : 1,
          ),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasChampion
                    ? Icons.emoji_events_rounded
                    : Icons.emoji_events_outlined,
                size: 38,
                color: hasChampion
                    ? AppColors.secondary
                    : AppColors.textSecondaryTinted,
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                hasChampion ? 'البطل' : 'نحو الكأس',
                style: AppTextStyles.labelLarge.copyWith(
                  color: hasChampion
                      ? AppColors.secondary
                      : AppColors.textSecondaryTinted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (hasChampion) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  championLabel!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimaryTinted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TreeControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TreeControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppDimensions.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
          backgroundColor: AppColors.surface.withValues(alpha: 0.94),
          foregroundColor: color,
          side: const BorderSide(color: AppColors.surfaceBorderStrong),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class KnockoutMatchNode extends StatelessWidget {
  final KnockoutTie tie;
  final Match? match;
  final String roundLabel;
  final String? displayLabel;
  final String Function(String? participantId) participantLabel;
  final bool hideParticipants;
  final bool showActions;
  final bool compact;
  final bool isChampionPath;
  final bool isCurrentFocus;
  final String openActionLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onReview;

  const KnockoutMatchNode({
    super.key,
    required this.tie,
    required this.match,
    required this.roundLabel,
    this.displayLabel,
    required this.participantLabel,
    required this.hideParticipants,
    this.showActions = false,
    this.compact = false,
    this.isChampionPath = false,
    this.isCurrentFocus = false,
    this.openActionLabel = 'عرض المباراة',
    this.onOpen,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isBye = _isBye(tie);
    final homeLabel = hideParticipants
        ? 'الطرف الأول لم يُنشر'
        : _participantName(tie.participantAId, isBye: isBye);
    final awayLabel = hideParticipants
        ? 'الطرف الثاني لم يُنشر'
        : _participantName(tie.participantBId, isBye: isBye);
    final status = _tieStatus(tie, match, hideParticipants: hideParticipants);
    final penaltyScore = match == null ? null : _penaltyScore(match!);
    final semanticLabel = _knockoutSemanticLabel((
      tie: tie,
      match: match,
      roundLabel: roundLabel,
      homeLabel: homeLabel,
      awayLabel: awayLabel,
      statusLabel: status.label,
    ));
    final opensFromCard = onOpen != null && !showActions;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: opensFromCard,
      label: semanticLabel,
      hint: opensFromCard ? 'اضغط لعرض المباراة' : null,
      child: Material(
        color: isChampionPath
            ? AppColors.secondary.withValues(alpha: 0.06)
            : isCurrentFocus
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: opensFromCard ? onOpen : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            key: ValueKey('knockout-tie-${tie.id}'),
            padding: EdgeInsets.all(
              compact ? AppDimensions.xs : AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isChampionPath
                    ? AppColors.secondary.withValues(alpha: 0.72)
                    : isCurrentFocus
                    ? AppColors.primary.withValues(alpha: 0.82)
                    : AppColors.surfaceBorderStrong,
                width: isChampionPath || isCurrentFocus ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: showActions ? MainAxisSize.min : MainAxisSize.max,
              children: [
                ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayLabel ?? roundLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondaryTinted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 2,
                            child: _KnockoutStatusBadge(status: status),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      _KnockoutTeamLine(
                        label: homeLabel,
                        score: match?.scoreTeamA,
                        isWinner:
                            tie.participantAId != null &&
                            tie.participantAId == tie.winnerParticipantId,
                        winnerColor: isChampionPath
                            ? AppColors.secondary
                            : AppColors.primary,
                        compact: compact,
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      _KnockoutTeamLine(
                        label: awayLabel,
                        score: match?.scoreTeamB,
                        isWinner:
                            tie.participantBId != null &&
                            tie.participantBId == tie.winnerParticipantId,
                        winnerColor: isChampionPath
                            ? AppColors.secondary
                            : AppColors.primary,
                        compact: compact,
                      ),
                      if (!compact && match?.scheduledAt != null) ...[
                        const SizedBox(height: AppDimensions.xs),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _compactDate(match!.scheduledAt!),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryTinted,
                            ),
                          ),
                        ),
                      ],
                      if (penaltyScore != null) ...[
                        const SizedBox(height: AppDimensions.xs),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Wrap(
                            spacing: AppDimensions.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'ركلات الترجيح',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                penaltyScore,
                                textDirection: TextDirection.ltr,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showActions && (onOpen != null || onReview != null)) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      if (onOpen != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppDimensions.buttonHeightMd,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm,
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            label: Text(openActionLabel),
                          ),
                        ),
                      if (onOpen != null && onReview != null)
                        const SizedBox(width: AppDimensions.sm),
                      if (onReview != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onReview,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppDimensions.buttonHeightMd,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm,
                              ),
                            ),
                            icon: const Icon(
                              Icons.fact_check_rounded,
                              size: 18,
                            ),
                            label: const Text('النتيجة'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _participantName(String? participantId, {required bool isBye}) {
    if (participantId == null || participantId.isEmpty) {
      return isBye ? 'تأهل مباشر' : 'الفائز من مباراة سابقة';
    }
    return participantLabel(participantId);
  }
}

class _KnockoutTeamLine extends StatelessWidget {
  final String label;
  final int? score;
  final bool isWinner;
  final Color winnerColor;
  final bool compact;

  const _KnockoutTeamLine({
    required this.label,
    required this.score,
    required this.isWinner,
    this.winnerColor = AppColors.primary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 32 : 36),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      decoration: BoxDecoration(
        color: isWinner
            ? winnerColor.withValues(alpha: 0.10)
            : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        children: [
          if (isWinner) ...[
            Icon(
              Icons.check_circle_rounded,
              color: winnerColor,
              size: compact ? 14 : AppDimensions.iconSm,
            ),
            const SizedBox(width: AppDimensions.xs),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleMedium.copyWith(
                color: isWinner ? winnerColor : AppColors.textPrimaryTinted,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (score != null)
            Text(
              '$score',
              textDirection: TextDirection.ltr,
              style: AppTextStyles.titleLarge.copyWith(
                color: isWinner ? winnerColor : AppColors.textPrimaryTinted,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _KnockoutStatusBadge extends StatelessWidget {
  final _TieStatusPresentation status;

  const _KnockoutStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: status.color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: AppDimensions.iconSm, color: status.color),
          const SizedBox(width: AppDimensions.xs),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketNodeLayout {
  final Rect rect;

  const _BracketNodeLayout({required this.rect});
}

class _BracketConnector {
  final Offset start;
  final Offset end;
  final bool isResolved;
  final bool isChampionPath;
  final bool isActivePath;

  const _BracketConnector({
    required this.start,
    required this.end,
    required this.isResolved,
    this.isChampionPath = false,
    this.isActivePath = false,
  });
}

class _BracketConnectorPainter extends CustomPainter {
  final List<_BracketConnector> connectors;

  const _BracketConnectorPainter({required this.connectors});

  @override
  void paint(Canvas canvas, Size size) {
    for (final connector in connectors) {
      final midpointX = (connector.start.dx + connector.end.dx) / 2;
      final path = Path()
        ..moveTo(connector.start.dx, connector.start.dy)
        ..lineTo(midpointX, connector.start.dy)
        ..lineTo(midpointX, connector.end.dy)
        ..lineTo(connector.end.dx, connector.end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = connector.isChampionPath
              ? 3.4
              : connector.isActivePath
              ? 2.8
              : connector.isResolved
              ? 2.2
              : 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = connector.isChampionPath
              ? AppColors.secondary.withValues(alpha: 0.92)
              : connector.isActivePath
              ? AppColors.primary.withValues(alpha: 0.92)
              : connector.isResolved
              ? AppColors.primary.withValues(alpha: 0.64)
              : AppColors.surfaceBorderStrong,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.connectors != connectors;
  }
}

class _TieStatusPresentation {
  final String label;
  final Color color;
  final IconData icon;

  const _TieStatusPresentation({
    required this.label,
    required this.color,
    required this.icon,
  });
}

_TieStatusPresentation _tieStatus(
  KnockoutTie tie,
  Match? match, {
  required bool hideParticipants,
}) {
  if (_isBye(tie)) {
    return const _TieStatusPresentation(
      label: 'تأهل مباشر',
      color: AppColors.primary,
      icon: Icons.fast_forward_rounded,
    );
  }
  if (tie.resolutionType == KnockoutTieResolution.penalties) {
    return const _TieStatusPresentation(
      label: 'بركلات الترجيح',
      color: AppColors.success,
      icon: Icons.sports_soccer_rounded,
    );
  }
  if (tie.winnerParticipantId != null) {
    return const _TieStatusPresentation(
      label: 'حُسمت',
      color: AppColors.success,
      icon: Icons.verified_rounded,
    );
  }
  if (hideParticipants) {
    return const _TieStatusPresentation(
      label: 'لم تُنشر',
      color: AppColors.textSecondaryTinted,
      icon: Icons.visibility_off_rounded,
    );
  }
  if (match != null &&
      (match.status == MatchStatus.completed ||
          match.status == MatchStatus.pendingReview)) {
    return const _TieStatusPresentation(
      label: 'بانتظار الاعتماد',
      color: AppColors.warning,
      icon: Icons.fact_check_rounded,
    );
  }
  if (tie.isReady) {
    return const _TieStatusPresentation(
      label: 'جاهزة',
      color: AppColors.info,
      icon: Icons.sports_soccer_rounded,
    );
  }
  return const _TieStatusPresentation(
    label: 'بانتظار المتأهلين',
    color: AppColors.textSecondaryTinted,
    icon: Icons.hourglass_bottom_rounded,
  );
}

bool _isBye(KnockoutTie tie) {
  if (tie.resolutionType == KnockoutTieResolution.bye) {
    return true;
  }
  final hasA = tie.participantAId != null && tie.participantAId!.isNotEmpty;
  final hasB = tie.participantBId != null && tie.participantBId!.isNotEmpty;
  final onlyParticipant = hasA == hasB
      ? null
      : (hasA ? tie.participantAId : tie.participantBId);
  return onlyParticipant != null &&
      tie.matchId == null &&
      tie.winnerParticipantId == onlyParticipant;
}

String knockoutRoundLabel(int roundIndex, {required int maxRoundIndex}) {
  final distanceFromFinal = maxRoundIndex - roundIndex;
  return switch (distanceFromFinal) {
    0 => 'النهائي',
    1 => 'نصف النهائي',
    2 => 'ربع النهائي',
    _ => 'دور الـ${1 << (distanceFromFinal + 1)}',
  };
}

String _scoreLabel(Match match) {
  if (match.scoreTeamA == null || match.scoreTeamB == null) {
    return 'النتيجة لم تُسجل';
  }
  return '${match.scoreTeamA} - ${match.scoreTeamB}';
}

String? _penaltyScore(Match match) {
  if (match.penaltyScoreTeamA == null || match.penaltyScoreTeamB == null) {
    return null;
  }
  return '${match.penaltyScoreTeamA} - ${match.penaltyScoreTeamB}';
}

typedef _KnockoutSemanticsContent = ({
  KnockoutTie tie,
  Match? match,
  String roundLabel,
  String homeLabel,
  String awayLabel,
  String statusLabel,
});

String _knockoutSemanticLabel(_KnockoutSemanticsContent content) {
  if (_isBye(content.tie)) {
    return _byeSemanticLabel(content);
  }

  final versusLabel =
      '${content.roundLabel}، ${content.homeLabel} ضد ${content.awayLabel}';
  final match = content.match;
  if (match == null) {
    return '$versusLabel، ${content.statusLabel}';
  }
  final penaltyScore = _penaltyScore(match);
  if (penaltyScore != null) {
    return '$versusLabel، ${_scoreLabel(match)}، '
        'حُسمت بركلات الترجيح $penaltyScore';
  }
  return '$versusLabel، ${_scoreLabel(match)}، ${content.statusLabel}';
}

String _byeSemanticLabel(_KnockoutSemanticsContent content) {
  final qualifiedParticipantId =
      content.tie.winnerParticipantId ??
      content.tie.participantAId ??
      content.tie.participantBId;
  final qualifiedLabel = qualifiedParticipantId == content.tie.participantBId
      ? content.awayLabel
      : content.homeLabel;
  return '${content.roundLabel}، $qualifiedLabel، تأهل مباشر';
}

String _compactDate(DateTime scheduledAt) {
  final hour = scheduledAt.hour.toString().padLeft(2, '0');
  final minute = scheduledAt.minute.toString().padLeft(2, '0');
  return '${scheduledAt.day}/${scheduledAt.month}، $hour:$minute';
}
