import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_state_card.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../../shareables/controllers/tournament_announcement_share_controller.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../../shareables/widgets/tournament_announcement_share_card.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentFixturesScreen extends StatefulWidget {
  const TournamentFixturesScreen({super.key});

  @override
  State<TournamentFixturesScreen> createState() =>
      _TournamentFixturesScreenState();
}

class _TournamentFixturesScreenState extends State<TournamentFixturesScreen> {
  static const _announcementShareController =
      TournamentAnnouncementShareController();
  static const _captureService = ShareCardCaptureService();

  final controller = Get.find<TournamentOperationsController>();
  TournamentStageType? _stageFilter;
  FixtureStatus? _publicationFilter;
  bool? _scheduledFilter;
  String? _groupFilter;
  DateTime? _scheduledDayFilter;
  bool _needsActionOnly = true;
  bool _showAdvancedFilters = false;

  int get _activeAdvancedFilterCount => <Object?>[
    _stageFilter,
    _publicationFilter,
    _scheduledFilter,
    _groupFilter,
    _scheduledDayFilter,
  ].where((filter) => filter != null).length;

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'مباريات البطولة',
      child: Obx(() {
        if (controller.isLoading.value && controller.fixtures.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (controller.errorMessage.value.isNotEmpty &&
            controller.fixtures.isEmpty) {
          return Center(
            child: El7reefStateCard(
              title: 'تعذر تحميل المباريات',
              message: controller.errorMessage.value,
              icon: Icons.cloud_off_rounded,
              color: AppColors.error,
              action: FilledButton.icon(
                onPressed: controller.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          );
        }
        if (controller.fixtures.isEmpty) {
          return const Center(
            child: El7reefStateCard(
              title: 'لا توجد مباريات بعد',
              message:
                  'ابدأ دور المجموعات أو الإقصائيات لتوليد مباريات البطولة.',
              icon: Icons.sports_soccer_rounded,
              color: AppColors.primary,
            ),
          );
        }
        final visibleFixtures = controller.canManageTournament
            ? controller.fixtures.toList(growable: false)
            : controller.fixtures
                  .where(
                    (fixture) => fixture.fixtureStatus != FixtureStatus.draft,
                  )
                  .toList(growable: false);
        final filteredFixtures =
            visibleFixtures
                .where((fixture) {
                  if (controller.canManageTournament &&
                      _needsActionOnly &&
                      !_fixtureNeedsAction(fixture)) {
                    return false;
                  }
                  if (_stageFilter != null &&
                      fixture.stageType != _stageFilter) {
                    return false;
                  }
                  if (_publicationFilter != null &&
                      fixture.fixtureStatus != _publicationFilter) {
                    return false;
                  }
                  if (_scheduledFilter != null) {
                    final isScheduled = fixture.scheduledAt != null;
                    if (_scheduledFilter != isScheduled) {
                      return false;
                    }
                  }
                  if (_groupFilter != null && fixture.groupId != _groupFilter) {
                    return false;
                  }
                  if (_scheduledDayFilter != null &&
                      !_matchesScheduledDay(
                        fixture.scheduledAt,
                        _scheduledDayFilter!,
                      )) {
                    return false;
                  }
                  return true;
                })
                .toList(growable: false)
              ..sort(_compareFixtures);

        final needsActionCount = visibleFixtures
            .where(_fixtureNeedsAction)
            .length;
        final overview = El7reefSurface(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderColor: AppColors.primary.withValues(alpha: 0.22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.canManageTournament
                          ? 'مركز تشغيل المباريات'
                          : 'جدول المباريات',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  if (controller.canManageTournament)
                    FilterChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('تحتاج إجراء'),
                      selected: _needsActionOnly,
                      onSelected: (selected) =>
                          setState(() => _needsActionOnly = selected),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(
                    child: _FixtureSummaryMetric(
                      label: 'كل المباريات',
                      value: visibleFixtures.length,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Expanded(
                    child: _FixtureSummaryMetric(
                      label: 'نتائج رسمية',
                      value: controller.officialResultsCount,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Expanded(
                    child: _FixtureSummaryMetric(
                      label: 'تحتاج إجراء',
                      value: needsActionCount,
                      color: needsActionCount == 0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'يعرض ${filteredFixtures.length} من ${visibleFixtures.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('advanced-fixtures-filter-toggle'),
                    onPressed: () => setState(
                      () => _showAdvancedFilters = !_showAdvancedFilters,
                    ),
                    icon: Icon(
                      _showAdvancedFilters
                          ? Icons.expand_less_rounded
                          : Icons.tune_rounded,
                    ),
                    label: Text(
                      _showAdvancedFilters ? 'إخفاء الفلاتر' : 'فلاتر متقدمة',
                    ),
                  ),
                ],
              ),
              if (_activeAdvancedFilterCount > 0)
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: Text('مسح ($_activeAdvancedFilterCount)'),
                  onPressed: _clearAdvancedFilters,
                ),
              if (_showAdvancedFilters) ...[
                const Divider(color: AppColors.surfaceBorder),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('كل المراحل'),
                      selected: _stageFilter == null,
                      onSelected: (_) => setState(() => _stageFilter = null),
                    ),
                    ...TournamentStageType.values.map(
                      (stage) => ChoiceChip(
                        label: Text(_stageLabel(stage)),
                        selected: _stageFilter == stage,
                        onSelected: (_) => setState(() {
                          _stageFilter = _stageFilter == stage ? null : stage;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('كل الحالات'),
                      selected: _publicationFilter == null,
                      onSelected: (_) =>
                          setState(() => _publicationFilter = null),
                    ),
                    ...FixtureStatus.values
                        .where(
                          (status) =>
                              controller.canManageTournament ||
                              status != FixtureStatus.draft,
                        )
                        .map(
                          (status) => ChoiceChip(
                            label: Text(_fixtureStatusLabel(status)),
                            selected: _publicationFilter == status,
                            onSelected: (_) => setState(() {
                              _publicationFilter = _publicationFilter == status
                                  ? null
                                  : status;
                            }),
                          ),
                        ),
                    ChoiceChip(
                      label: const Text('مجدولة'),
                      selected: _scheduledFilter == true,
                      onSelected: (_) => setState(() {
                        _scheduledFilter = _scheduledFilter == true
                            ? null
                            : true;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('غير مجدولة'),
                      selected: _scheduledFilter == false,
                      onSelected: (_) => setState(() {
                        _scheduledFilter = _scheduledFilter == false
                            ? null
                            : false;
                      }),
                    ),
                  ],
                ),
                if (controller.groups.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('كل المجموعات'),
                        selected: _groupFilter == null,
                        onSelected: (_) => setState(() => _groupFilter = null),
                      ),
                      ...controller.groups.map(
                        (group) => ChoiceChip(
                          label: Text(group.name),
                          selected: _groupFilter == group.id,
                          onSelected: (_) => setState(() {
                            _groupFilter = _groupFilter == group.id
                                ? null
                                : group.id;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickScheduledDay(context),
                      icon: const Icon(Icons.event),
                      label: Text(
                        _scheduledDayFilter == null
                            ? 'اختر يومًا'
                            : intl.DateFormat(
                                'yyyy/MM/dd',
                              ).format(_scheduledDayFilter!),
                      ),
                    ),
                    if (_scheduledDayFilter != null)
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 18),
                        label: const Text('إزالة اليوم'),
                        onPressed: () =>
                            setState(() => _scheduledDayFilter = null),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );

        return ListView.separated(
          key: const ValueKey('fixtures-results-list'),
          itemCount:
              1 + (filteredFixtures.isEmpty ? 1 : filteredFixtures.length),
          separatorBuilder: (_, index) => SizedBox(
            height: index == 0 ? AppDimensions.md : AppDimensions.sm,
          ),
          itemBuilder: (context, index) {
            if (index == 0) return overview;
            if (filteredFixtures.isEmpty) {
              return const El7reefStateCard(
                title: 'لا توجد مباريات مطابقة',
                message: 'غيّر الفلاتر الحالية لعرض مباريات أخرى.',
                icon: Icons.filter_alt_off_rounded,
                color: AppColors.warning,
              );
            }

            final fixture = filteredFixtures[index - 1];
            final canShareUpcoming =
                FeatureFlags.prideShareCatalogV2Enabled &&
                _isUpcomingFixtureShareEligible(fixture);
            return _FixtureOperationsCard(
              fixture: fixture,
              controller: controller,
              onSchedule:
                  controller.isActing.value ||
                      fixture.isOfficialTournamentResult
                  ? null
                  : () => _showScheduleDialog(context, fixture),
              onShareUpcoming: canShareUpcoming
                  ? () => _shareUpcomingFixture(context, fixture)
                  : null,
            );
          },
        );
      }),
    );
  }

  bool _isUpcomingFixtureShareEligible(Match fixture) {
    final tournament = controller.tournament.value;
    final teamA = _participantForFixtureSide(fixture, isHome: true);
    final teamB = _participantForFixtureSide(fixture, isHome: false);
    if (tournament == null || teamA == null || teamB == null) return false;
    return _announcementShareController.buildUpcomingFixtureIfEligible(
          tournament: tournament,
          fixture: fixture,
          teamA: teamA,
          teamB: teamB,
        ) !=
        null;
  }

  TournamentParticipant? _participantForFixtureSide(
    Match fixture, {
    required bool isHome,
  }) {
    final participantId =
        (isHome ? fixture.teamAParticipantId : fixture.teamBParticipantId)
            ?.trim();
    if (participantId != null && participantId.isNotEmpty) {
      for (final participant in controller.participants) {
        if (participant.id == participantId) return participant;
      }
    }

    final sourceEntityId = (isHome ? fixture.teamAId : fixture.teamBId)?.trim();
    if (sourceEntityId != null && sourceEntityId.isNotEmpty) {
      for (final participant in controller.participants) {
        if (participant.sourceEntityId == sourceEntityId) return participant;
      }
    }
    return null;
  }

  Future<void> _shareUpcomingFixture(
    BuildContext context,
    Match fixture,
  ) async {
    if (!FeatureFlags.prideShareCatalogV2Enabled) return;
    final tournament = controller.tournament.value;
    final teamA = _participantForFixtureSide(fixture, isHome: true);
    final teamB = _participantForFixtureSide(fixture, isHome: false);
    if (tournament == null || teamA == null || teamB == null) {
      Get.snackbar('المشاركة غير متاحة', 'تعذر التحقق من طرفي المباراة.');
      return;
    }
    final fixturePoster = _announcementShareController
        .buildUpcomingFixtureIfEligible(
          tournament: tournament,
          fixture: fixture,
          teamA: teamA,
          teamB: teamB,
        );
    if (fixturePoster == null) {
      Get.snackbar(
        'المشاركة غير متاحة',
        'يجب نشر المباراة وتحديد موعد قادم قبل مشاركة البوستر.',
      );
      return;
    }

    final selection = await showPrideShareComposer(
      context: context,
      cardType: fixturePoster.sharePayload.cardType,
      previewBuilder: (format) => TournamentAnnouncementShareCard(
        data: fixturePoster,
        format: format,
        includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
      ),
    );
    if (selection == null || !context.mounted) return;

    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: TournamentAnnouncementShareCard(
            data: fixturePoster,
            exportMode: true,
            format: selection.format,
            includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
          ),
          exportRequest: PrideExportRequest(
            cardType: fixturePoster.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_upcoming_fixture_${fixture.id}',
            includeAudio: selection.includeAudio,
          ),
          text:
              '${teamA.displayName} ضد ${teamB.displayName} في ${tournament.name}',
          payload: fixturePoster.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'TournamentFixturesScreen.shareUpcomingFixture',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز بوستر المباراة القادمة.');
    }
  }

  Future<void> _showScheduleDialog(BuildContext context, Match fixture) async {
    final initialDate = fixture.scheduledAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: initialDate,
    );
    if (pickedDate == null || !context.mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null || !context.mounted) {
      return;
    }

    final venueController = TextEditingController(text: fixture.venueId ?? '');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('جدولة المباراة'),
          content: TextField(
            controller: venueController,
            decoration: const InputDecoration(
              labelText: 'الملعب',
              hintText: 'مثال: الملعب 1',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      final scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      await controller.scheduleFixture(
        fixtureId: fixture.id,
        scheduledAt: scheduledAt,
        venueId: venueController.text,
      );
    } finally {
      venueController.dispose();
    }
  }

  Future<void> _pickScheduledDay(BuildContext context) async {
    final pickedDay = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: _scheduledDayFilter ?? DateTime.now(),
    );
    if (pickedDay == null) {
      return;
    }
    setState(() => _scheduledDayFilter = pickedDay);
  }

  void _clearAdvancedFilters() {
    setState(() {
      _stageFilter = null;
      _publicationFilter = null;
      _scheduledFilter = null;
      _groupFilter = null;
      _scheduledDayFilter = null;
    });
  }

  int _compareFixtures(Match left, Match right) {
    final leftSchedule = left.scheduledAt;
    final rightSchedule = right.scheduledAt;
    if (leftSchedule != null && rightSchedule != null) {
      return leftSchedule.compareTo(rightSchedule);
    }
    if (leftSchedule != null) {
      return -1;
    }
    if (rightSchedule != null) {
      return 1;
    }
    return left.createdAt.compareTo(right.createdAt);
  }

  bool _matchesScheduledDay(DateTime? scheduledAt, DateTime day) {
    if (scheduledAt == null) {
      return false;
    }
    return scheduledAt.year == day.year &&
        scheduledAt.month == day.month &&
        scheduledAt.day == day.day;
  }

  String _stageLabel(TournamentStageType stage) => _tournamentStageLabel(stage);

  String _fixtureStatusLabel(FixtureStatus status) =>
      _fixtureStatusLabelText(status);
}

class _FixtureOperationsCard extends StatelessWidget {
  final Match fixture;
  final TournamentOperationsController controller;
  final VoidCallback? onSchedule;
  final VoidCallback? onShareUpcoming;

  const _FixtureOperationsCard({
    required this.fixture,
    required this.controller,
    required this.onSchedule,
    required this.onShareUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    final maxRoundIndex = controller.knockoutTies.isEmpty
        ? fixture.roundIndex ?? 0
        : controller.knockoutTies
              .map((tie) => tie.roundIndex)
              .reduce((left, right) => left > right ? left : right);
    final stageDetail = fixture.stageType == TournamentStageType.knockoutStage
        ? fixture.knockoutMatchRole == KnockoutMatchRole.thirdPlace
              ? 'المركز الثالث'
              : _knockoutRoundLabel(
                  fixture.roundIndex ?? 0,
                  maxRoundIndex: maxRoundIndex,
                )
        : controller.groupLabelFor(fixture.groupId);

    final statusColor = _matchStatusColor(fixture);
    final homeName = controller.fixtureTeamLabel(fixture, isHome: true);
    final awayName = controller.fixtureTeamLabel(fixture, isHome: false);

    final scoreAction = _scoreActionForMatch(controller, fixture);
    final primaryAction = scoreAction;
    final primaryActionLabel = _compactScoreActionLabel(fixture);
    final primaryActionSemanticLabel = _scoreActionLabel(fixture);
    final primaryActionIcon = _scoreActionIcon(fixture);
    final hasMoreActions =
        controller.canManageTournament &&
        (onSchedule != null || onShareUpcoming != null);

    return El7reefSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderColor: statusColor.withValues(alpha: 0.26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.xs,
                  children: [
                    El7reefBadge(
                      label: _tournamentStageLabel(fixture.stageType),
                      color: AppColors.primary,
                      icon: Icons.account_tree_rounded,
                    ),
                    El7reefBadge(
                      label: stageDetail,
                      color: AppColors.accent,
                      icon: Icons.flag_rounded,
                    ),
                  ],
                ),
              ),
              El7reefBadge(
                label: _matchStatusLabel(fixture.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: _TeamNameBlock(name: homeName, alignLeft: true),
                ),
                _ScorePill(fixture: fixture),
                Expanded(
                  child: _TeamNameBlock(name: awayName, alignLeft: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.textSecondaryTinted,
              ),
              const SizedBox(width: AppDimensions.xs),
              Expanded(
                child: Text(
                  _formatDateTime(fixture.scheduledAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (fixture.venueId != null && fixture.venueId!.isNotEmpty)
                Flexible(
                  child: Text(
                    ' · ${fixture.venueId!}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            _fixtureHint(fixture),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: controller.canManageTournament
                      ? 'إدارة المباراة'
                      : 'عرض المباراة',
                  child: ExcludeSemantics(
                    child: OutlinedButton.icon(
                      key: ValueKey('fixture-manage-${fixture.id}'),
                      onPressed: () =>
                          Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                      icon: const Icon(Icons.sports_soccer_rounded),
                      label: Text(
                        controller.canManageTournament ? 'إدارة' : 'عرض',
                      ),
                    ),
                  ),
                ),
              ),
              if (primaryAction != null) ...[
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: primaryActionSemanticLabel,
                    child: ExcludeSemantics(
                      child: FilledButton.icon(
                        key: ValueKey('fixture-primary-${fixture.id}'),
                        onPressed: primaryAction,
                        icon: Icon(primaryActionIcon),
                        label: Text(primaryActionLabel),
                      ),
                    ),
                  ),
                ),
              ],
              if (hasMoreActions)
                PopupMenuButton<VoidCallback>(
                  tooltip: 'إجراءات أخرى',
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    if (onShareUpcoming != null)
                      PopupMenuItem(
                        value: onShareUpcoming,
                        child: const _FixtureMenuAction(
                          icon: Icons.ios_share_rounded,
                          label: 'شارك بوستر المباراة',
                        ),
                      ),
                    if (onSchedule != null)
                      PopupMenuItem(
                        value: onSchedule,
                        child: _FixtureMenuAction(
                          icon: Icons.schedule_rounded,
                          label: fixture.scheduledAt == null
                              ? 'جدولة المباراة'
                              : 'تعديل الموعد',
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamNameBlock extends StatelessWidget {
  final String name;
  final bool alignLeft;

  const _TeamNameBlock({required this.name, required this.alignLeft});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: alignLeft ? TextAlign.left : TextAlign.right,
      style: AppTextStyles.titleMedium.copyWith(
        color: AppColors.textPrimaryTinted,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final Match fixture;

  const _ScorePill({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final hasScore = fixture.scoreTeamA != null && fixture.scoreTeamB != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: hasScore ? AppColors.primarySurface : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: hasScore
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.surfaceBorderStrong,
        ),
      ),
      child: Text(
        hasScore ? '${fixture.scoreTeamA} - ${fixture.scoreTeamB}' : 'ضد',
        style: AppTextStyles.titleLarge.copyWith(
          color: hasScore ? AppColors.primary : AppColors.textSecondaryTinted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _ScaffoldListScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FixtureSummaryMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _FixtureSummaryMetric({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryTinted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixtureMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FixtureMenuAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppDimensions.sm),
        Text(label),
      ],
    );
  }
}

String _fixtureStatusLabelText(FixtureStatus status) => switch (status) {
  FixtureStatus.draft => 'مسودة',
  FixtureStatus.published => 'منشورة',
  FixtureStatus.completed => 'مكتملة',
};

VoidCallback? _scoreActionForMatch(
  TournamentOperationsController controller,
  Match match,
) {
  if (controller.isActing.value) {
    return null;
  }
  return switch (match.status) {
    MatchStatus.live => () => Get.toNamed(
      AppRoutes.scoreApprovalForMatch(match.id),
    ),
    MatchStatus.completed || MatchStatus.pendingReview => () => Get.toNamed(
      AppRoutes.scoreApprovalForMatch(match.id),
    ),
    MatchStatus.settled => null,
    _ => null,
  };
}

String _scoreActionLabel(Match match) => switch (match.status) {
  MatchStatus.live => 'سجّل النتيجة',
  MatchStatus.completed => 'راجع النتيجة',
  MatchStatus.pendingReview => 'راجع النتيجة',
  MatchStatus.settled => 'معتمدة',
  _ => 'مراجعة النتيجة',
};

String _compactScoreActionLabel(Match match) => switch (match.status) {
  MatchStatus.live => 'سجّل',
  MatchStatus.completed || MatchStatus.pendingReview => 'راجع',
  MatchStatus.settled => 'معتمدة',
  _ => 'راجع',
};

IconData _scoreActionIcon(Match match) => switch (match.status) {
  MatchStatus.live => Icons.edit_note,
  MatchStatus.completed || MatchStatus.pendingReview => Icons.verified_outlined,
  MatchStatus.settled => Icons.check_circle_outline,
  _ => Icons.rule_folder_outlined,
};

String _tournamentStageLabel(TournamentStageType? stage) => switch (stage) {
  TournamentStageType.groupStage => 'المجموعات',
  TournamentStageType.knockoutStage => 'الإقصاء',
  null => 'غير محدد',
};

String _knockoutRoundLabel(int roundIndex, {required int maxRoundIndex}) {
  final distanceFromFinal = maxRoundIndex - roundIndex;
  return switch (distanceFromFinal) {
    0 => 'النهائي',
    1 => 'نصف النهائي',
    2 => 'ربع النهائي',
    _ => 'دور الـ${1 << (distanceFromFinal + 1)}',
  };
}

String _matchStatusLabel(MatchStatus status) => switch (status) {
  MatchStatus.open => 'مفتوحة',
  MatchStatus.full => 'مكتملة العدد',
  MatchStatus.live => 'جارية',
  MatchStatus.pendingReview => 'بانتظار الاعتماد',
  MatchStatus.completed => 'انتهت',
  MatchStatus.settled => 'معتمدة',
  MatchStatus.ratingWindow => 'نافذة التقييم',
  MatchStatus.frozen => 'مجمّدة',
  MatchStatus.cancelled => 'ملغاة',
};

Color _matchStatusColor(Match fixture) {
  if (fixture.isOfficialTournamentResult ||
      fixture.status == MatchStatus.settled) {
    return AppColors.success;
  }
  return switch (fixture.status) {
    MatchStatus.live => AppColors.primary,
    MatchStatus.pendingReview || MatchStatus.completed => AppColors.warning,
    MatchStatus.cancelled || MatchStatus.frozen => AppColors.error,
    _ => AppColors.accent,
  };
}

String _fixtureHint(Match fixture) {
  if (fixture.isOfficialTournamentResult) {
    return 'النتيجة معتمدة وتؤثر مباشرة على الترتيب أو الإقصاء.';
  }
  if (fixture.status == MatchStatus.live) {
    return 'المباراة جارية الآن. سجّل النتيجة والهدافين والـ MVP بعد الصفارة.';
  }
  if (fixture.fixtureStatus == FixtureStatus.draft) {
    return 'هذه المباراة ما زالت مسودة. انشر الجدول قبل بدء التشغيل.';
  }
  if (fixture.status == MatchStatus.open) {
    return 'افتح إدارة المباراة، سجّل حضور الطرفين، ثم ابدأ.';
  }
  if (fixture.scheduledAt == null) {
    return 'يفضل تحديد الموعد والملعب قبل يوم التشغيل.';
  }
  if (fixture.status == MatchStatus.pendingReview ||
      fixture.status == MatchStatus.completed) {
    return 'راجع النتيجة قبل اعتمادها حتى تظهر في الترتيب وكروت الفخر.';
  }
  return 'المباراة جاهزة للوصول السريع إلى التشغيل أو مراجعة النتيجة.';
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd - HH:mm').format(value);
}

bool _fixtureNeedsAction(Match fixture) {
  if (fixture.isOfficialTournamentResult ||
      fixture.status == MatchStatus.settled ||
      fixture.status == MatchStatus.cancelled) {
    return false;
  }
  return fixture.fixtureStatus == FixtureStatus.draft ||
      fixture.scheduledAt == null ||
      fixture.status == MatchStatus.open ||
      fixture.status == MatchStatus.full ||
      fixture.status == MatchStatus.live ||
      fixture.status == MatchStatus.completed ||
      fixture.status == MatchStatus.pendingReview;
}
