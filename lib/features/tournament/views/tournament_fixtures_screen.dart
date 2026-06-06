import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_state_card.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/match.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentFixturesScreen extends StatefulWidget {
  const TournamentFixturesScreen({super.key});

  @override
  State<TournamentFixturesScreen> createState() =>
      _TournamentFixturesScreenState();
}

class _TournamentFixturesScreenState extends State<TournamentFixturesScreen> {
  final controller = Get.find<TournamentOperationsController>();
  TournamentStageType? _stageFilter;
  FixtureStatus? _publicationFilter;
  bool? _scheduledFilter;
  String? _groupFilter;
  DateTime? _scheduledDayFilter;

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'مباريات البطولة',
      child: Obx(() {
        if (controller.fixtures.isEmpty) {
          return const Center(
            child: El7reefStateCard(
              title: 'لا توجد مباريات بعد',
              message: 'ابدأ دور المجموعات أو الإقصائيات لتوليد مباريات البطولة.',
              icon: Icons.sports_soccer_rounded,
              color: AppColors.primary,
            ),
          );
        }
        final visibleFixtures = controller.canManageTournament
            ? controller.fixtures.toList(growable: false)
            : controller.fixtures
                .where((fixture) => fixture.fixtureStatus != FixtureStatus.draft)
                .toList(growable: false);
        final filteredFixtures =
            visibleFixtures
                .where((fixture) {
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

        return ListView(
          children: [
            El7reefSurface(
              elevated: true,
              borderColor: AppColors.primary.withValues(alpha: 0.22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لوحة المباريات', style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    controller.canManageTournament
                        ? 'تابع جدول البطولة، ابدأ المباريات، وسجّل النتائج أول بأول.'
                        : 'شاهد جدول البطولة والنتائج المنشورة بدون أدوات إدارة.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [
                      _MetricChip(
                        label: 'الكل',
                        value: visibleFixtures.length.toString(),
                      ),
                      if (controller.canManageTournament)
                        _MetricChip(
                          label: 'مسودة',
                          value: controller.draftFixturesCount.toString(),
                        ),
                      _MetricChip(
                        label: 'منشورة',
                        value: visibleFixtures
                            .where(
                              (fixture) =>
                                  fixture.fixtureStatus == FixtureStatus.published,
                            )
                            .length
                            .toString(),
                      ),
                      _MetricChip(
                        label: 'مجدولة',
                        value: visibleFixtures
                            .where((fixture) => fixture.scheduledAt != null)
                            .length
                            .toString(),
                      ),
                      _MetricChip(
                        label: 'نتائج رسمية',
                        value: controller.officialResultsCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Text('الفلاتر', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                     'يعرض ${filteredFixtures.length} من ${visibleFixtures.length} مباراة',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
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
                            _stageFilter = _stageFilter == stage
                                ? null
                                : stage;
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
                          label: const Text('إزالة فلتر اليوم'),
                          onPressed: () =>
                              setState(() => _scheduledDayFilter = null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            if (filteredFixtures.isEmpty)
              const El7reefStateCard(
                title: 'لا توجد مباريات مطابقة',
                message: 'غيّر الفلاتر الحالية لعرض مباريات أخرى.',
                icon: Icons.filter_alt_off_rounded,
                color: AppColors.warning,
              )
            else
              ...filteredFixtures.map(
                (fixture) => _FixtureOperationsCard(
                  fixture: fixture,
                  controller: controller,
                  onStartMatch:
                      controller.isActing.value ||
                          !controller.canStartFixture(fixture)
                      ? null
                      : () => controller.startFixture(fixture.id),
                  onSchedule:
                      controller.isActing.value ||
                          fixture.isOfficialTournamentResult
                      ? null
                      : () => _showScheduleDialog(context, fixture),
                ),
              ),
          ],
        );
      }),
    );
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
  final VoidCallback? onStartMatch;
  final VoidCallback? onSchedule;

  const _FixtureOperationsCard({
    required this.fixture,
    required this.controller,
    required this.onStartMatch,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final maxRoundIndex = controller.knockoutTies.isEmpty
        ? fixture.roundIndex ?? 0
        : controller.knockoutTies
              .map((tie) => tie.roundIndex)
              .reduce((left, right) => left > right ? left : right);
    final stageDetail = fixture.stageType == TournamentStageType.knockoutStage
        ? _knockoutRoundLabel(
            fixture.roundIndex ?? 0,
            maxRoundIndex: maxRoundIndex,
          )
        : controller.groupLabelFor(fixture.groupId);

    final statusColor = _matchStatusColor(fixture);
    final homeName = controller.fixtureTeamLabel(fixture, isHome: true);
    final awayName = controller.fixtureTeamLabel(fixture, isHome: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: El7reefSurface(
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
            const SizedBox(height: AppDimensions.md),
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
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                _MetricChip(
                  label: 'النشر',
                  value: _fixtureStatusLabelText(fixture.fixtureStatus),
                ),
                _MetricChip(
                  label: 'الموعد',
                  value: _formatDateTime(fixture.scheduledAt),
                ),
                if (fixture.venueId != null && fixture.venueId!.isNotEmpty)
                  _MetricChip(label: 'الملعب', value: fixture.venueId!),
                if (fixture.scoreTeamA != null && fixture.scoreTeamB != null)
                  _MetricChip(
                    label: 'النتيجة',
                    value: '${fixture.scoreTeamA} - ${fixture.scoreTeamB}',
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              _fixtureHint(fixture),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                  icon: const Icon(Icons.sports_soccer),
                  label: Text(
                    controller.canManageTournament
                        ? 'إدارة المباراة'
                        : 'عرض المباراة',
                  ),
                ),
                if (controller.canManageTournament) ...[
                  FilledButton.icon(
                    onPressed: onStartMatch,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ابدأ المباراة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _scoreActionForMatch(controller, fixture),
                    icon: Icon(_scoreActionIcon(fixture)),
                    label: Text(_scoreActionLabel(fixture)),
                  ),
                  FilledButton.icon(
                    onPressed: onSchedule,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      fixture.scheduledAt == null ? 'جدولة' : 'تعديل الموعد',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
      style: AppTextStyles.titleLarge.copyWith(
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
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
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
        style: AppTextStyles.headlineMedium.copyWith(
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

  const _ScaffoldListScreen({
    required this.title,
    required this.child,
  });

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

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondaryTinted,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    MatchStatus.completed ||
    MatchStatus.pendingReview => () => controller.approveFixtureScore(match.id),
    MatchStatus.settled => null,
    _ => null,
  };
}

String _scoreActionLabel(Match match) => switch (match.status) {
  MatchStatus.live => 'سجّل النتيجة',
  MatchStatus.completed => 'اعتمد النتيجة',
  MatchStatus.pendingReview => 'راجع واعتمد',
  MatchStatus.settled => 'معتمدة',
  _ => 'مراجعة النتيجة',
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
    _ => 'دور ${roundIndex + 1}',
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
    return 'بعد جاهزية الطرفين يمكنك بدء المباراة من هنا.';
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
