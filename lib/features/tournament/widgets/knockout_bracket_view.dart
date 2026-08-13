import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/knockout_tie.dart';
import '../../../domain/entities/match.dart';

enum KnockoutBracketViewMode { round, fullTree }

class KnockoutBracketHeaderData {
  final int teamCount;
  final int byeCount;
  final VoidCallback? onShare;

  const KnockoutBracketHeaderData({
    required this.teamCount,
    required this.byeCount,
    this.onShare,
  });
}

class KnockoutBracketView extends StatefulWidget {
  static const double fullTreeBreakpoint = 720;

  final List<KnockoutTie> ties;
  final Map<String, Match> matchesById;
  final String Function(String? participantId) participantLabel;
  final bool hideUnpublishedParticipants;
  final ValueChanged<Match>? onOpenMatch;
  final bool Function(Match match)? canReviewMatch;
  final ValueChanged<Match>? onReviewMatch;
  final KnockoutBracketHeaderData? headerData;
  final KnockoutBracketViewMode? viewMode;
  final ValueChanged<KnockoutBracketViewMode>? onViewModeChanged;
  final bool expandFullTree;

  const KnockoutBracketView({
    super.key,
    required this.ties,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
    this.canReviewMatch,
    this.onReviewMatch,
    this.headerData,
    this.viewMode,
    this.onViewModeChanged,
    this.expandFullTree = false,
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
        final mode = widget.viewMode ?? _selectedMode ?? defaultMode;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
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
                  headerData: widget.headerData,
                  onShowFullTree: () {
                    _requestMode(KnockoutBracketViewMode.fullTree);
                  },
                )
              : KnockoutFullTree(
                  key: const ValueKey('bracket-full-tree'),
                  tiesByRound: tiesByRound,
                  matchesById: widget.matchesById,
                  participantLabel: widget.participantLabel,
                  hideUnpublishedParticipants:
                      widget.hideUnpublishedParticipants,
                  onOpenMatch: widget.onOpenMatch,
                  expandToFill: widget.expandFullTree,
                  onShowRounds: () {
                    _requestMode(KnockoutBracketViewMode.round);
                  },
                ),
        );
      },
    );
  }

  void _requestMode(KnockoutBracketViewMode mode) {
    final onModeChanged = widget.onViewModeChanged;
    if (onModeChanged != null) {
      onModeChanged(mode);
      return;
    }
    setState(() => _selectedMode = mode);
  }
}

class _BracketJourneyHeader extends StatelessWidget {
  final Map<int, List<KnockoutTie>> tiesByRound;
  final String Function(String? participantId) participantLabel;
  final KnockoutBracketHeaderData? headerData;
  final VoidCallback onShowFullTree;

  const _BracketJourneyHeader({
    required this.tiesByRound,
    required this.participantLabel,
    required this.headerData,
    required this.onShowFullTree,
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
    final activeRound = hasChampion
        ? rounds.last
        : rounds.firstWhere(
            (round) => tiesByRound[round]!.any(
              (tie) => tie.winnerParticipantId?.isEmpty ?? true,
            ),
            orElse: () => rounds.last,
          );
    final activeRoundLabel = knockoutRoundLabel(
      activeRound,
      maxRoundIndex: rounds.last,
    );
    final details = <String>[
      if (headerData != null) '${headerData!.teamCount} فريق',
      '$resolvedCount/${ties.length} حُسمت',
      if (headerData?.byeCount case final byeCount? when byeCount > 0)
        '$byeCount تأهل مباشر',
    ].join('  •  ');

    return Column(
      key: const ValueKey('bracket-journey-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: hasChampion
              ? 'اكتملت الأدوار الإقصائية، البطل ${participantLabel(championId)}'
              : 'تقدم الأدوار الإقصائية، $resolvedCount من ${ties.length} مواجهات حُسمت، الدور الجاري $activeRoundLabel',
          child: ExcludeSemantics(
            child: Row(
              key: const ValueKey('bracket-screen-summary-bar'),
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasChampion
                        ? AppColors.achievementSurface
                        : AppColors.competitiveSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(
                    hasChampion
                        ? Icons.emoji_events_rounded
                        : Icons.route_rounded,
                    color: hasChampion
                        ? AppColors.achievement
                        : AppColors.competitive,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasChampion ? 'خُتم طريق البطولة' : 'الطريق إلى الكأس',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: hasChampion
                              ? AppColors.achievement
                              : AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        hasChampion
                            ? participantLabel(championId)
                            : 'الدور الجاري: $activeRoundLabel',
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
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.xs),
        _buildDetailsAndActions(context, details),
      ],
    );
  }

  Widget _buildDetailsAndActions(BuildContext context, String details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needsStackedLayout =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final detailsText = Text(
          details,
          maxLines: needsStackedLayout ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryTinted,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        final mapButton = _buildMapButton();
        final shareButton = headerData?.onShare == null
            ? null
            : _buildShareButton(headerData!.onShare!);
        if (needsStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              detailsText,
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  if (shareButton != null) ...[
                    shareButton,
                    const SizedBox(width: AppDimensions.xs),
                  ],
                  Expanded(child: mapButton),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: detailsText),
            if (shareButton != null) ...[
              shareButton,
              const SizedBox(width: AppDimensions.xs),
            ],
            mapButton,
          ],
        );
      },
    );
  }

  Widget _buildShareButton(VoidCallback onShare) {
    return Semantics(
      button: true,
      label: 'شارك طريق النهائي',
      onTap: onShare,
      child: ExcludeSemantics(
        child: IconButton(
          key: const ValueKey('share-knockout-road'),
          tooltip: 'شارك طريق النهائي',
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_rounded),
          color: AppColors.socialAccent,
        ),
      ),
    );
  }

  Widget _buildMapButton() {
    return Semantics(
      button: true,
      label: 'افتح خريطة الشجرة الكاملة',
      onTap: onShowFullTree,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('bracket-view-mode'),
          child: OutlinedButton.icon(
            key: const ValueKey('bracket-open-full-tree'),
            onPressed: onShowFullTree,
            icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
            label: const Text('الخريطة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.competitive,
              side: BorderSide(
                color: AppColors.competitive.withValues(alpha: 0.46),
              ),
              minimumSize: const Size(0, AppDimensions.minTouchTarget),
            ),
          ),
        ),
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
  final KnockoutBracketHeaderData? headerData;
  final VoidCallback onShowFullTree;

  const KnockoutRoundPager({
    super.key,
    required this.tiesByRound,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
    this.canReviewMatch,
    this.onReviewMatch,
    required this.headerData,
    required this.onShowFullTree,
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
    final roundIsComplete = resolvedInRound == selectedRoundTies.length;
    final featuredTie = _featuredTie(selectedRoundTies);
    final remainingTies = selectedRoundTies
        .where((tie) => tie.id != featuredTie.id)
        .toList(growable: false);
    final nextRoundLabel = _page == rounds.length - 1
        ? null
        : knockoutRoundLabel(rounds[_page + 1], maxRoundIndex: finalRound);
    final roundLabel = knockoutRoundLabel(
      selectedRound,
      maxRoundIndex: finalRound,
    );
    final hasChampion =
        selectedRound == finalRound &&
        selectedRoundTies.first.winnerParticipantId?.isNotEmpty == true;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'الأدوار الإقصائية، عرض جولة واحدة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          El7reefGlassSurface(
            role: El7reefGlassRole.floatingToolbar,
            tone: El7reefGlassTone.competitive,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              children: [
                _BracketJourneyHeader(
                  tiesByRound: widget.tiesByRound,
                  participantLabel: widget.participantLabel,
                  headerData: widget.headerData,
                  onShowFullTree: widget.onShowFullTree,
                ),
                const SizedBox(height: AppDimensions.sm),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: AppDimensions.sm),
                _BracketRoundSelector(
                  rounds: rounds,
                  selectedPage: _page,
                  tiesByRound: widget.tiesByRound,
                  onSelected: _setPage,
                ),
                const SizedBox(height: AppDimensions.xs),
                _RoundCompletionMeter(
                  resolved: resolvedInRound,
                  total: selectedRoundTies.length,
                  completed: roundIsComplete,
                ),
              ],
            ),
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
                key: ValueKey('knockout-round-matches-$selectedRound'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundSectionLabel(
                    icon: hasChampion
                        ? Icons.emoji_events_rounded
                        : Icons.play_circle_fill_rounded,
                    color: hasChampion
                        ? AppColors.achievement
                        : AppColors.competitive,
                    title: hasChampion
                        ? 'مواجهة البطل'
                        : roundIsComplete
                        ? 'اكتمل $roundLabel'
                        : featuredTie.isReady
                        ? 'المواجهة الجاهزة الآن'
                        : 'المواجهة التالية',
                    subtitle: hasChampion
                        ? 'الكأس حُسم ببيانات النهائي'
                        : roundIsComplete && nextRoundLabel != null
                        ? 'المتأهلون وصلوا إلى $nextRoundLabel'
                        : nextRoundLabel == null
                        ? 'الفائز يرفع الكأس'
                        : 'الفائز يتقدم إلى $nextRoundLabel',
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  KeyedSubtree(
                    key: ValueKey('bracket-featured-match-${featuredTie.id}'),
                    child: _buildMatchCard(
                      tie: featuredTie,
                      roundLabel: roundLabel,
                      displayLabel: selectedRound == finalRound
                          ? 'المواجهة الحاسمة'
                          : 'مواجهة ${featuredTie.slotNumber + 1}',
                      emphasized: !roundIsComplete,
                      champion: hasChampion,
                      semanticsOrder: 0,
                    ),
                  ),
                  if (remainingTies.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.lg),
                    _RoundSectionLabel(
                      icon: Icons.format_list_numbered_rtl_rounded,
                      color: roundIsComplete
                          ? AppColors.tactical
                          : AppColors.textSecondaryTinted,
                      title: 'بقية مواجهات الدور',
                      subtitle:
                          '${remainingTies.length} مواجهات مرتبة حسب مسار الشجرة',
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Column(
                      key: const ValueKey('bracket-round-match-list'),
                      children: [
                        for (
                          var index = 0;
                          index < remainingTies.length;
                          index++
                        ) ...[
                          _buildMatchCard(
                            tie: remainingTies[index],
                            roundLabel: roundLabel,
                            displayLabel:
                                'مواجهة ${remainingTies[index].slotNumber + 1}',
                            emphasized: false,
                            champion: false,
                            semanticsOrder: (index + 1).toDouble(),
                          ),
                          if (index < remainingTies.length - 1)
                            const SizedBox(height: AppDimensions.sm),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  KnockoutTie _featuredTie(List<KnockoutTie> ties) {
    for (final tie in ties) {
      if (tie.winnerParticipantId == null && tie.isReady) return tie;
    }
    for (final tie in ties) {
      if (tie.winnerParticipantId == null) return tie;
    }
    return ties.last;
  }

  Widget _buildMatchCard({
    required KnockoutTie tie,
    required String roundLabel,
    required String displayLabel,
    required bool emphasized,
    required bool champion,
    required double semanticsOrder,
  }) {
    final match = tie.matchId == null ? null : widget.matchesById[tie.matchId!];
    final canReview =
        match != null &&
        widget.onReviewMatch != null &&
        (widget.canReviewMatch?.call(match) ?? false);
    return Semantics(
      sortKey: OrdinalSortKey(semanticsOrder),
      child: KnockoutMatchNode(
        tie: tie,
        match: match,
        roundLabel: roundLabel,
        displayLabel: displayLabel,
        participantLabel: widget.participantLabel,
        hideParticipants:
            widget.hideUnpublishedParticipants &&
            tie.matchId != null &&
            match == null,
        showActions: true,
        isPathEmphasized: emphasized,
        isChampionPath: champion,
        openActionLabel: widget.canReviewMatch == null
            ? 'عرض المباراة'
            : 'إدارة المباراة',
        onOpen: match == null || widget.onOpenMatch == null
            ? null
            : () => widget.onOpenMatch!(match),
        onReview: canReview ? () => widget.onReviewMatch!(match) : null,
      ),
    );
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
        ? AppColors.tactical
        : AppColors.textSecondaryTinted;
    return Semantics(
      selected: selected,
      button: true,
      label: completed ? '$roundLabel، اكتمل' : roundLabel,
      child: Material(
        color: selected ? AppColors.competitive : AppColors.surface,
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
                    ? AppColors.competitive
                    : completed
                    ? AppColors.tactical.withValues(alpha: 0.48)
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

class _RoundCompletionMeter extends StatelessWidget {
  final int resolved;
  final int total;
  final bool completed;

  const _RoundCompletionMeter({
    required this.resolved,
    required this.total,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (resolved / total).clamp(0.0, 1.0);
    final color = completed ? AppColors.tactical : AppColors.competitive;
    return Semantics(
      label: 'تقدم الدور، $resolved من $total مواجهات حُسمت',
      child: ExcludeSemantics(
        child: Container(
          height: 6,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutQuart,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundSectionLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _RoundSectionLabel({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
  final bool expandToFill;
  final VoidCallback onShowRounds;

  const KnockoutFullTree({
    super.key,
    required this.tiesByRound,
    required this.matchesById,
    required this.participantLabel,
    required this.hideUnpublishedParticipants,
    this.onOpenMatch,
    this.expandToFill = false,
    required this.onShowRounds,
  });

  @override
  State<KnockoutFullTree> createState() => _KnockoutFullTreeState();
}

class _KnockoutFullTreeState extends State<KnockoutFullTree> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _championAnchorKey = GlobalKey();
  String? _selectedTieId;
  Size? _initializedCanvasSize;
  Size? _initializedViewportSize;
  Rect? _initializedCurrentFocusRect;

  @override
  void didUpdateWidget(covariant KnockoutFullTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedTieId = _selectedTieId;
    if (selectedTieId != null && !_containsTie(selectedTieId)) {
      _selectedTieId = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rounds = widget.tiesByRound.keys.toList()..sort();
    if (MediaQuery.accessibleNavigationOf(context)) {
      return _buildAccessibleTree(rounds);
    }
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
    final emphasizedPathTieIds = _pathToCup(_selectedTieId ?? activeTie.id);
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
      emphasizedPathTieIds: emphasizedPathTieIds,
    );
    final finalRound = rounds.last;
    final mapIntroduction = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'خريطة عامة: اسحب للتنقل وقرّب بإصبعين. التشغيل اليومي أوضح في عرض الجولات.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryTinted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.xs),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.xs,
          children: [
            const _BracketLegendDot(
              color: AppColors.tactical,
              label: 'مسار متأهل',
            ),
            if (championId?.isNotEmpty ?? false)
              const _BracketLegendDot(
                color: AppColors.achievement,
                label: 'مسار البطل',
              ),
          ],
        ),
      ],
    );

    Widget buildTreeCanvas({double? height}) {
      return Container(
        key: const ValueKey('knockout-interactive-tree'),
        height: height,
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
                                emphasizedPathTieIds: emphasizedPathTieIds,
                                selectedTieId: _selectedTieId,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: AppDimensions.sm,
                  start: AppDimensions.sm,
                  end: AppDimensions.sm,
                  child: El7reefGlassSurface(
                    key: const ValueKey('bracket-map-toolbar'),
                    role: El7reefGlassRole.floatingToolbar,
                    tone: El7reefGlassTone.competitive,
                    padding: const EdgeInsets.all(AppDimensions.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TreeControlButton(
                            key: const ValueKey('bracket-back-to-rounds'),
                            tooltip: 'العودة إلى عرض الجولات',
                            icon: Icons.view_carousel_rounded,
                            label: 'الجولات',
                            color: AppColors.competitive,
                            onPressed: widget.onShowRounds,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Expanded(
                          child: _TreeControlButton(
                            key: const ValueKey('bracket-focus-current'),
                            tooltip: 'الانتقال إلى المواجهة الحالية',
                            icon: Icons.my_location_rounded,
                            label: 'الحالي',
                            color: AppColors.competitive,
                            onPressed: () => _focusCurrent(geometry),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Expanded(
                          child: _TreeControlButton(
                            key: const ValueKey('bracket-reset-view'),
                            tooltip: 'نظرة عامة للشجرة كلها',
                            icon: Icons.fit_screen_rounded,
                            label: 'نظرة عامة',
                            onPressed: () => _resetView(geometry),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.xs),
                        Expanded(
                          child: _TreeControlButton(
                            key: const ValueKey('bracket-focus-trophy'),
                            tooltip: 'الانتقال إلى النهائي والكأس',
                            icon: Icons.emoji_events_rounded,
                            label: 'الكأس',
                            color: championId?.isNotEmpty ?? false
                                ? AppColors.achievement
                                : AppColors.competitive,
                            onPressed: () => _focusTrophy(geometry),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'الشجرة الإقصائية كاملة من اليمين إلى اليسار',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canFillAvailableHeight =
              widget.expandToFill && constraints.maxHeight.isFinite;
          if (canFillAvailableHeight) {
            return SizedBox(
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mapIntroduction,
                  const SizedBox(height: AppDimensions.sm),
                  Expanded(child: buildTreeCanvas()),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mapIntroduction,
              const SizedBox(height: AppDimensions.sm),
              buildTreeCanvas(
                height: math.min(560.0, math.max(380.0, canvasHeight)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessibleTree(List<int> rounds) {
    final finalRound = rounds.last;
    final activeTie = _activeTie(rounds);
    final emphasizedPathTieIds = _pathToCup(_selectedTieId ?? activeTie.id);
    final finalTie = widget.tiesByRound[finalRound]!.first;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.md),
        child: Text(
          'عرض خطي للأدوار الإقصائية. انتقل بين المواجهات حسب الدور حتى الكأس.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryTinted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
    var semanticsOrder = 0.0;
    for (final round in rounds) {
      final roundLabel = knockoutRoundLabel(round, maxRoundIndex: finalRound);
      children.add(
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.sm,
              bottom: AppDimensions.xs,
            ),
            child: Text(
              roundLabel,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.competitive,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
      for (final tie in widget.tiesByRound[round]!) {
        final match = tie.matchId == null
            ? null
            : widget.matchesById[tie.matchId!];
        final hideParticipants =
            widget.hideUnpublishedParticipants &&
            tie.matchId != null &&
            match == null;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: Semantics(
              key: ValueKey('knockout-semantics-${tie.id}'),
              sortKey: OrdinalSortKey(semanticsOrder++),
              selected: _selectedTieId == tie.id,
              child: KnockoutMatchNode(
                tie: tie,
                match: match,
                roundLabel: roundLabel,
                participantLabel: widget.participantLabel,
                hideParticipants: hideParticipants,
                isChampionPath:
                    finalTie.winnerParticipantId?.isNotEmpty == true &&
                    tie.winnerParticipantId == finalTie.winnerParticipantId,
                isPathEmphasized: emphasizedPathTieIds.contains(tie.id),
                isSelected: _selectedTieId == tie.id,
                showActions: false,
                onOpen: () => _showTieSheet(
                  tie: tie,
                  match: match,
                  roundLabel: roundLabel,
                ),
              ),
            ),
          ),
        );
      }
    }
    children.add(
      SizedBox(
        height: 144,
        child: _BracketChampionAnchor(
          championLabel: finalTie.winnerParticipantId?.isNotEmpty == true
              ? widget.participantLabel(finalTie.winnerParticipantId)
              : null,
        ),
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'المسار الخطي للأدوار الإقصائية',
      child: ListView(
        key: const ValueKey('bracket-accessible-linear-tree'),
        primary: false,
        shrinkWrap: !widget.expandToFill,
        physics: widget.expandToFill
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.sm),
        children: children,
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
        _initializedViewportSize == geometry.viewportSize &&
        _initializedCurrentFocusRect == geometry.currentFocusRect) {
      return;
    }
    _initializedCanvasSize = geometry.canvasSize;
    _initializedViewportSize = geometry.viewportSize;
    _initializedCurrentFocusRect = geometry.currentFocusRect;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _initializedCanvasSize != geometry.canvasSize ||
          _initializedViewportSize != geometry.viewportSize ||
          _initializedCurrentFocusRect != geometry.currentFocusRect) {
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
    required Set<String> emphasizedPathTieIds,
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
            isActivePath: emphasizedPathTieIds.contains(tie.id),
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
        isActivePath: emphasizedPathTieIds.contains(finalTie.id),
      ),
    );
    return connectors;
  }

  Set<String> _pathToCup(String startingTieId) {
    final tiesById = <String, KnockoutTie>{
      for (final tie in widget.tiesByRound.values.expand((ties) => ties))
        tie.id: tie,
    };
    final path = <String>{};
    String? tieId = startingTieId;
    while (tieId != null && tiesById.containsKey(tieId) && path.add(tieId)) {
      tieId = tiesById[tieId]!.nextTieId;
    }
    return path;
  }

  Widget _positionedNode(
    ({
      _BracketNodeLayout layout,
      KnockoutTie tie,
      String roundLabel,
      double semanticsOrder,
      String? championId,
      Set<String> emphasizedPathTieIds,
      String? selectedTieId,
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
        key: ValueKey('knockout-semantics-${tie.id}'),
        sortKey: OrdinalSortKey(node.semanticsOrder),
        selected: node.selectedTieId == tie.id,
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
          isPathEmphasized: node.emphasizedPathTieIds.contains(tie.id),
          isSelected: node.selectedTieId == tie.id,
          showActions: false,
          openActionLabel: 'افتح المباراة',
          onOpen: () => _showTieSheet(
            tie: tie,
            match: match,
            roundLabel: node.roundLabel,
          ),
        ),
      ),
    );
  }

  Future<void> _showTieSheet({
    required KnockoutTie tie,
    required Match? match,
    required String roundLabel,
  }) async {
    if (!mounted) return;
    setState(() => _selectedTieId = tie.id);
    final presentation = _tieSheetPresentation(
      tie: tie,
      match: match,
      roundLabel: roundLabel,
    );
    final openMatch = widget.onOpenMatch;

    final shouldOpenMatch = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: AppDimensions.animSlow),
        reverseDuration: Duration(milliseconds: AppDimensions.animNormal),
      ),
      builder: (sheetContext) => _KnockoutTieSheet(
        presentation: presentation,
        onOpenMatch: match == null || openMatch == null
            ? null
            : () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (shouldOpenMatch != true ||
        !mounted ||
        match == null ||
        openMatch == null) {
      return;
    }
    openMatch(match);
  }

  bool _containsTie(String tieId) {
    return widget.tiesByRound.values.any(
      (ties) => ties.any((tie) => tie.id == tieId),
    );
  }

  _KnockoutTieSheetPresentation _tieSheetPresentation({
    required KnockoutTie tie,
    required Match? match,
    required String roundLabel,
  }) {
    final isBye = _isBye(tie);
    final hideParticipants =
        widget.hideUnpublishedParticipants &&
        tie.matchId != null &&
        match == null;

    String participantName(String? participantId, String hiddenLabel) {
      if (hideParticipants) return hiddenLabel;
      if (participantId == null || participantId.isEmpty) {
        return isBye ? 'تأهل مباشر' : 'الفائز من مباراة سابقة';
      }
      return widget.participantLabel(participantId);
    }

    final homeLabel = participantName(
      tie.participantAId,
      'الطرف الأول لم يُنشر',
    );
    final awayLabel = participantName(
      tie.participantBId,
      'الطرف الثاني لم يُنشر',
    );
    return (
      tie: tie,
      match: match,
      roundLabel: roundLabel,
      homeLabel: homeLabel,
      awayLabel: awayLabel,
      hideParticipants: hideParticipants,
    );
  }
}

typedef _KnockoutTieSheetPresentation = ({
  KnockoutTie tie,
  Match? match,
  String roundLabel,
  String homeLabel,
  String awayLabel,
  bool hideParticipants,
});

class _KnockoutTieSheet extends StatelessWidget {
  final _KnockoutTieSheetPresentation presentation;
  final VoidCallback? onOpenMatch;

  const _KnockoutTieSheet({
    required this.presentation,
    required this.onOpenMatch,
  });

  @override
  Widget build(BuildContext context) {
    final tie = presentation.tie;
    final match = presentation.match;
    final status = _tieStatus(
      tie,
      match,
      hideParticipants: presentation.hideParticipants,
    );
    final penaltyScore = match == null ? null : _penaltyScore(match);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _buildSheetSurface(context, status, penaltyScore),
    );
  }

  Widget _buildSheetSurface(
    BuildContext context,
    _TieStatusPresentation status,
    String? penaltyScore,
  ) {
    return El7reefGlassSurface(
      key: ValueKey('bracket-tie-sheet-${presentation.tie.id}'),
      role: El7reefGlassRole.compactSheet,
      tone: El7reefGlassTone.competitive,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.md,
        bottom: MediaQuery.paddingOf(context).bottom + AppDimensions.lg,
      ),
      child: _buildSheetContent(status, penaltyScore),
    );
  }

  Widget _buildSheetContent(
    _TieStatusPresentation status,
    String? penaltyScore,
  ) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label:
            'تفاصيل ${presentation.roundLabel}، '
            '${presentation.homeLabel} ضد ${presentation.awayLabel}',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppDimensions.md),
              _buildHeader(status),
              const SizedBox(height: AppDimensions.md),
              _buildTeams(),
              if (penaltyScore != null) ...[
                const SizedBox(height: AppDimensions.sm),
                _buildPenaltyRow(penaltyScore),
              ],
              if (onOpenMatch != null) ...[
                const SizedBox(height: AppDimensions.lg),
                _buildOpenMatchButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.surfaceBorderStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(_TieStatusPresentation status) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(
          presentation.roundLabel,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimaryTinted,
            fontWeight: FontWeight.w900,
          ),
        );
        final icon = Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.competitive.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            color: AppColors.competitive,
          ),
        );
        final useStackedHeader =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        if (useStackedHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _KnockoutStatusBadge(status: status),
              ),
            ],
          );
        }
        return Row(
          children: [
            icon,
            const SizedBox(width: AppDimensions.sm),
            Expanded(child: title),
            _KnockoutStatusBadge(status: status),
          ],
        );
      },
    );
  }

  Widget _buildTeams() {
    final tie = presentation.tie;
    return Column(
      children: [
        _KnockoutTeamLine(
          label: presentation.homeLabel,
          score: presentation.match?.scoreTeamA,
          isWinner:
              tie.participantAId?.isNotEmpty == true &&
              tie.participantAId == tie.winnerParticipantId,
        ),
        const SizedBox(height: AppDimensions.xs),
        _KnockoutTeamLine(
          label: presentation.awayLabel,
          score: presentation.match?.scoreTeamB,
          isWinner:
              tie.participantBId?.isNotEmpty == true &&
              tie.participantBId == tie.winnerParticipantId,
        ),
      ],
    );
  }

  Widget _buildPenaltyRow(String penaltyScore) {
    return Row(
      children: [
        const Icon(
          Icons.sports_soccer_rounded,
          color: AppColors.tactical,
          size: AppDimensions.iconSm,
        ),
        const SizedBox(width: AppDimensions.xs),
        Expanded(
          child: Text(
            'ركلات الترجيح',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.tactical,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Text(
          penaltyScore,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.tactical,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenMatchButton() {
    return FilledButton.icon(
      key: const ValueKey('bracket-sheet-open-match'),
      onPressed: onOpenMatch,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppDimensions.buttonHeightLg),
        backgroundColor: AppColors.actionPrimary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('افتح المباراة'),
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
      key: const ValueKey('bracket-champion-semantics'),
      sortKey: const OrdinalSortKey(100000),
      container: true,
      label: hasChampion ? 'بطل البطولة، $championLabel' : 'وجهة الشجرة، الكأس',
      child: Container(
        key: const ValueKey('bracket-champion-anchor'),
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: hasChampion ? AppColors.achievementSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: hasChampion
                ? AppColors.achievement.withValues(alpha: 0.78)
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
                    ? AppColors.achievement
                    : AppColors.textSecondaryTinted,
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                hasChampion ? 'البطل' : 'نحو الكأس',
                style: AppTextStyles.labelLarge.copyWith(
                  color: hasChampion
                      ? AppColors.achievement
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
    this.color = AppColors.actionPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.textScalerOf(context).scale(1) <= 1.4;
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xs),
          backgroundColor: AppColors.surface.withValues(alpha: 0.94),
          foregroundColor: color,
          side: const BorderSide(color: AppColors.surfaceBorderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
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
  final bool isPathEmphasized;
  final bool isSelected;
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
    this.isPathEmphasized = false,
    this.isSelected = false,
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
    final isResolved = tie.winnerParticipantId?.isNotEmpty ?? false;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: opensFromCard,
      label: semanticLabel,
      hint: opensFromCard
          ? isSelected
                ? 'المواجهة المحددة، اضغط لعرض التفاصيل'
                : isPathEmphasized
                ? 'ضمن الطريق المحدد إلى الكأس، اضغط لعرض التفاصيل'
                : 'اضغط لعرض التفاصيل'
          : null,
      child: Material(
        color: isChampionPath
            ? AppColors.achievement.withValues(alpha: 0.06)
            : isPathEmphasized
            ? AppColors.competitiveSurface
            : isResolved
            ? AppColors.tactical.withValues(alpha: 0.04)
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
                    ? AppColors.achievement.withValues(alpha: 0.72)
                    : isSelected
                    ? AppColors.actionPrimary
                    : isPathEmphasized
                    ? AppColors.competitive.withValues(alpha: 0.82)
                    : isResolved
                    ? AppColors.tactical.withValues(alpha: 0.44)
                    : AppColors.surfaceBorderStrong,
                width: isSelected
                    ? 3
                    : isChampionPath || isPathEmphasized
                    ? 2
                    : 1,
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
                            ? AppColors.achievement
                            : AppColors.tactical,
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
                            ? AppColors.achievement
                            : AppColors.tactical,
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
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                penaltyScore,
                                textDirection: TextDirection.ltr,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.info,
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
    this.winnerColor = AppColors.tactical,
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
          ExcludeSemantics(
            child: _TeamInitialsBadge(
              label: label,
              color: isWinner ? winnerColor : AppColors.competitive,
              compact: compact,
            ),
          ),
          const SizedBox(width: AppDimensions.xs),
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

class _TeamInitialsBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _TeamInitialsBadge({
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 24.0 : 28.0;
    final initials = _teamInitials(label);
    final isPlaceholder = _isBracketPlaceholderLabel(label);
    final badgeColor = isPlaceholder ? AppColors.textSecondaryTinted : color;
    return Container(
      key: ValueKey('team-initials-$initials'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: badgeColor.withValues(alpha: 0.32)),
      ),
      child: isPlaceholder
          ? Icon(
              Icons.shield_outlined,
              size: compact ? 14 : 16,
              color: badgeColor,
            )
          : Text(
              initials,
              maxLines: 1,
              style: AppTextStyles.labelSmall.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w900,
              ),
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
              ? AppColors.achievement.withValues(alpha: 0.92)
              : connector.isActivePath
              ? AppColors.competitive.withValues(alpha: 0.92)
              : connector.isResolved
              ? AppColors.tactical.withValues(alpha: 0.64)
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
      color: AppColors.tactical,
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
      color: AppColors.competitive,
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

String _teamInitials(String label) {
  String withoutArabicArticle(String word) {
    final characters = word.characters;
    if (characters.length > 2 && characters.take(2).toString() == 'ال') {
      return characters.skip(2).toString();
    }
    return word;
  }

  final words = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '؟';
  final firstWord = withoutArabicArticle(words.first);
  if (words.length == 1) {
    return firstWord.characters.take(2).toString().toUpperCase();
  }
  final secondWord = withoutArabicArticle(words[1]);
  return '${firstWord.characters.first}${secondWord.characters.first}'
      .toUpperCase();
}

bool _isBracketPlaceholderLabel(String label) {
  return label == 'تأهل مباشر' ||
      label == 'الفائز من مباراة سابقة' ||
      label.endsWith('لم يُنشر');
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
