import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
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
      title: 'Fixtures',
      child: Obx(() {
        if (controller.fixtures.isEmpty) {
          return const _StateMessage(
            title: 'لا توجد fixtures بعد',
            message: 'ابدأ المجموعات أو الإقصاء لتوليد المباريات.',
          );
        }
        final filteredFixtures =
            controller.fixtures
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة fixtures',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricChip(
                          label: 'All',
                          value: controller.fixtures.length.toString(),
                        ),
                        _MetricChip(
                          label: 'Draft',
                          value: controller.draftFixturesCount.toString(),
                        ),
                        _MetricChip(
                          label: 'Published',
                          value: controller.publishedFixturesCount.toString(),
                        ),
                        _MetricChip(
                          label: 'Scheduled',
                          value: controller.scheduledFixturesCount.toString(),
                        ),
                        _MetricChip(
                          label: 'Official',
                          value: controller.officialResultsCount.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الفلاتر',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عرض ${filteredFixtures.length} من أصل ${controller.fixtures.length} fixture',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('كل المراحل'),
                          selected: _stageFilter == null,
                          onSelected: (_) =>
                              setState(() => _stageFilter = null),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('كل الحالات'),
                          selected: _publicationFilter == null,
                          onSelected: (_) =>
                              setState(() => _publicationFilter = null),
                        ),
                        ...FixtureStatus.values.map(
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('كل المجموعات'),
                            selected: _groupFilter == null,
                            onSelected: (_) =>
                                setState(() => _groupFilter = null),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
            ),
            const SizedBox(height: 12),
            if (filteredFixtures.isEmpty)
              const _StateMessage(
                title: 'لا توجد نتائج مطابقة',
                message: 'غيّر الفلاتر الحالية لإظهار fixtures أخرى.',
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
          title: const Text('جدولة fixture'),
          content: TextField(
            controller: venueController,
            decoration: const InputDecoration(
              labelText: 'Venue / Pitch',
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${controller.fixtureTeamLabel(fixture, isHome: true)} vs ${controller.fixtureTeamLabel(fixture, isHome: false)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tournamentStageLabel(fixture.stageType)} • $stageDetail',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: fixture.isOfficialTournamentResult
                        ? const Color(0xFFE7F7ED)
                        : fixture.status == MatchStatus.pendingReview
                        ? const Color(0xFFFFF2CC)
                        : const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _matchStatusLabel(fixture.status),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Fixture',
                  value: _fixtureStatusLabelText(fixture.fixtureStatus),
                ),
                _MetricChip(
                  label: 'Schedule',
                  value: _formatDateTime(fixture.scheduledAt),
                ),
                if (fixture.venueId != null && fixture.venueId!.isNotEmpty)
                  _MetricChip(label: 'Venue', value: fixture.venueId!),
                if (fixture.scoreTeamA != null && fixture.scoreTeamB != null)
                  _MetricChip(
                    label: 'Score',
                    value: '${fixture.scoreTeamA} - ${fixture.scoreTeamB}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fixture.isOfficialTournamentResult
                  ? 'النتيجة معتمدة وتؤثر مباشرة على الترتيب أو الإقصاء.'
                  : fixture.status == MatchStatus.live
                  ? 'المباراة جارية الآن ويمكن الدخول مباشرة إلى مراجعة النتيجة.'
                  : fixture.fixtureStatus == FixtureStatus.draft
                  ? 'هذه fixture ما زالت draft ويجب نشرها قبل بدء المباراة.'
                  : fixture.status == MatchStatus.open
                  ? 'بعد check-in وقفل التشكيل للطرفين يمكنك بدء المباراة من هنا.'
                  : fixture.scheduledAt == null
                  ? 'يفضل تحديد الموعد والملعب قبل يوم التشغيل.'
                  : 'الـ fixture جاهزة للوصول السريع إلى التشغيل أو مراجعة النتيجة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('Matchday'),
                ),
                FilledButton.icon(
                  onPressed: onStartMatch,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Match'),
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
                    fixture.scheduledAt == null ? 'Schedule' : 'Reschedule',
                  ),
                ),
              ],
            ),
          ],
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
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String message;

  const _StateMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
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
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _fixtureStatusLabelText(FixtureStatus status) => switch (status) {
  FixtureStatus.draft => 'Draft',
  FixtureStatus.published => 'Published',
  FixtureStatus.completed => 'Completed',
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
  MatchStatus.live => 'Submit Score',
  MatchStatus.completed => 'Approve Score',
  MatchStatus.pendingReview => 'Review & Approve',
  MatchStatus.settled => 'Approved',
  _ => 'Score Review',
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
    _ => 'Round ${roundIndex + 1}',
  };
}

String _matchStatusLabel(MatchStatus status) => switch (status) {
  MatchStatus.open => 'Open',
  MatchStatus.full => 'Full',
  MatchStatus.live => 'Live',
  MatchStatus.pendingReview => 'Pending Review',
  MatchStatus.completed => 'Completed',
  MatchStatus.settled => 'Settled',
  MatchStatus.ratingWindow => 'Rating Window',
  MatchStatus.frozen => 'Frozen',
  MatchStatus.cancelled => 'Cancelled',
};

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd – HH:mm').format(value);
}


