import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/knockout_tie.dart';
import '../../../domain/entities/tournament_group.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentOperationsDashboardScreen
    extends GetView<TournamentOperationsController> {
  const TournamentOperationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament Operations Dashboard')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final tournament = controller.tournament.value;
          if (tournament == null) {
            return _StateMessage(
              title: 'تعذر تحميل مركز التشغيل',
              message: controller.errorMessage.value.isEmpty
                  ? 'لم نتمكن من العثور على البطولة المطلوبة.'
                  : controller.errorMessage.value,
            );
          }

          final report = controller.migrationReport.value;
          return RefreshIndicator(
            onRefresh: controller.refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الحالة الحالية: ${controller.statusLabelFor(tournament.status)}',
                        ),
                        Text(
                          'المشاركون النشطون: ${controller.activeParticipantsCount}',
                        ),
                        if (tournament.participantListFinalizedAt != null)
                          Text(
                            'تم قفل القائمة: ${tournament.participantListFinalizedAt}',
                          ),
                        if (controller.shouldShowMaintenanceTools &&
                            report != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Backfill approved registrations: ${report.approvedRegistrationsBackfilled}',
                          ),
                          Text(
                            'Legacy team backfill: ${report.legacyTeamsBackfilled}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (controller.isBlockedByManualMigration)
                  const Card(
                    color: Color(0xFFFFF3CD),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'هذه البطولة تحتاج manual ops migration قبل السماح بالتشغيل الكامل.',
                      ),
                    ),
                  ),
                if (controller.errorMessage.value.isNotEmpty)
                  Card(
                    color: const Color(0xFFFFE5E5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(controller.errorMessage.value),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (controller.shouldShowMaintenanceTools)
                      FilledButton.icon(
                        onPressed: controller.isActing.value
                            ? null
                            : controller.syncApprovedRegistrations,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Participants'),
                      ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canManualAddParticipants
                          ? null
                          : () => _showManualAddParticipantDialog(
                              context,
                              controller,
                            ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Manual Add Participant'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canFinalizeParticipantsAction
                          ? null
                          : controller.finalizeParticipantList,
                      icon: const Icon(Icons.verified),
                      label: const Text('Finalize Participants'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canStartGroupStageAction
                          ? null
                          : controller.startGroupStage,
                      icon: const Icon(Icons.groups_2),
                      label: const Text('Start Group Stage'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canPublishFixtures
                          ? null
                          : controller.publishFixtures,
                      icon: const Icon(Icons.publish),
                      label: const Text('Publish Fixtures'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canRegenerateGroupStage
                          ? null
                          : controller.regenerateGroupStage,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate Groups'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canStartKnockoutAction
                          ? null
                          : controller.startKnockout,
                      icon: const Icon(Icons.account_tree),
                      label: const Text('Start Knockout'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              !controller.canCompleteTournamentAction
                          ? null
                          : controller.completeTournament,
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('Complete Tournament'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OperationsMetricsCard(controller: controller),
                const SizedBox(height: 12),
                _ReadinessChecklistCard(controller: controller),
                if (controller.pendingActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PendingActionsCard(controller: controller),
                ],
                const SizedBox(height: 12),
                if (controller.groups.isNotEmpty)
                  Card(
                    color: const Color(0xFFF4F7FB),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        controller.canRegenerateGroupStage
                            ? 'يمكن إعادة توليد المجموعات الآن لأن fixtures ما زالت draft ولم تُسجل عليها نتائج.'
                            : 'إعادة توليد المجموعات تتوقف تلقائيًا بعد نشر fixtures أو إدخال أي نتيجة أو بدء الإقصاء.',
                      ),
                    ),
                  ),
                if (controller.groups.isNotEmpty) const SizedBox(height: 8),
                if (!controller.canReplaceParticipants ||
                    !controller.canManualAddParticipants)
                  Card(
                    color: const Color(0xFFF9F1E7),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        controller.hasOperationalStageStarted
                            ? 'تم قفل manual add وreplace بعد بدء تشغيل البطولة الفعلي لحماية fixtures والمجموعات الحالية.'
                            : 'تم قفل manual add بعد finalize participants. يمكن الاستبدال فقط قبل بدء المجموعات.',
                      ),
                    ),
                  ),
                if (!controller.canReplaceParticipants ||
                    !controller.canManualAddParticipants)
                  const SizedBox(height: 8),
                _LinkTile(
                  title: 'Participants',
                  subtitle: '${controller.participants.length} عنصر',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentParticipantsById(tournament.id),
                  ),
                ),
                _LinkTile(
                  title: 'Groups',
                  subtitle: '${controller.groups.length} مجموعة',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentGroupsById(tournament.id),
                  ),
                ),
                _LinkTile(
                  title: 'Fixtures',
                  subtitle: '${controller.fixtures.length} مباراة',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentFixturesById(tournament.id),
                  ),
                ),
                _LinkTile(
                  title: 'Standings',
                  subtitle: '${controller.standings.length} snapshot',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentStandingsById(tournament.id),
                  ),
                ),
                _LinkTile(
                  title: 'Bracket',
                  subtitle: controller.knockoutBracket.value == null
                      ? 'لم يبدأ الإقصاء بعد'
                      : '${controller.knockoutTies.length} tie',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentBracketById(tournament.id),
                  ),
                ),
                _LinkTile(
                  title: 'Assistants',
                  subtitle: '${tournament.assistants.length} مساعدين',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentAssistantsById(tournament.id),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class TournamentParticipantsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sortedParticipants = controller.participants.toList(growable: false)
        ..sort(_compareParticipants);
      final activeParticipants = sortedParticipants
          .where((participant) => participant.isActive)
          .toList(growable: false);
      final withdrawnParticipants = sortedParticipants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.withdrawn,
          )
          .toList(growable: false);
      final replacedParticipants = sortedParticipants
          .where(
            (participant) =>
                participant.status == TournamentParticipantStatus.replaced,
          )
          .toList(growable: false);

      return _ScaffoldListScreen(
        title: 'Participants',
        floatingActionButton: controller.canManualAddParticipants
            ? FloatingActionButton.extended(
                onPressed: controller.isActing.value
                    ? null
                    : () =>
                          _showManualAddParticipantDialog(context, controller),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Manual Add'),
              )
            : null,
        child: controller.participants.isEmpty
            ? _StateMessage(
                title: 'لا يوجد participants بعد',
                message: controller.canManualAddParticipants
                    ? 'اعتمد التسجيلات أو أضف participant يدويًا.'
                    : 'اعتمد التسجيلات أولًا أو راجع حالة تشغيل البطولة الحالية.',
              )
            : ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            label: 'Active',
                            value: activeParticipants.length.toString(),
                          ),
                          _MetricChip(
                            label: 'Withdrawn',
                            value: withdrawnParticipants.length.toString(),
                          ),
                          _MetricChip(
                            label: 'Replaced',
                            value: replacedParticipants.length.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeParticipants.isNotEmpty)
                    _ParticipantSection(
                      title: 'Active Participants',
                      participants: activeParticipants,
                      controller: controller,
                    ),
                  if (withdrawnParticipants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ParticipantSection(
                      title: 'Withdrawn',
                      participants: withdrawnParticipants,
                      controller: controller,
                    ),
                  ],
                  if (replacedParticipants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ParticipantSection(
                      title: 'Replaced',
                      participants: replacedParticipants,
                      controller: controller,
                    ),
                  ],
                ],
              ),
      );
    });
  }

  int _compareParticipants(
    TournamentParticipant left,
    TournamentParticipant right,
  ) {
    final leftSeed = left.seed ?? 9999;
    final rightSeed = right.seed ?? 9999;
    if (leftSeed != rightSeed) {
      return leftSeed.compareTo(rightSeed);
    }
    return left.displayName.compareTo(right.displayName);
  }
}

class _OperationsMetricsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const _OperationsMetricsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مؤشرات التشغيل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Fixtures',
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
                  label: 'Official Results',
                  value: controller.officialResultsCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessChecklistCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const _ReadinessChecklistCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جاهزية التشغيل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...controller.readinessChecklist.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isReady ? Icons.check_circle : Icons.hourglass_top,
                      color: item.isReady ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label),
                          const SizedBox(height: 2),
                          Text(
                            item.detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingActionsCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const _PendingActionsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEDF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الخطوات التالية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...controller.pendingActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.playlist_add_check_circle_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.title),
                          const SizedBox(height: 2),
                          Text(
                            action.detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

class TournamentGroupsScreen extends GetView<TournamentOperationsController> {
  const TournamentGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Groups',
      child: Obx(() {
        if (controller.groups.isEmpty) {
          return const _StateMessage(
            title: 'لم يتم إنشاء المجموعات بعد',
            message: 'ابدأ مرحلة المجموعات من dashboard أولاً.',
          );
        }
        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: 'Groups',
                      value: controller.groups.length.toString(),
                    ),
                    _MetricChip(
                      label: 'Fixtures',
                      value: controller.groupStageFixtures.length.toString(),
                    ),
                    _MetricChip(
                      label: 'Official',
                      value: controller.groupStageFixtures
                          .where(
                            (fixture) => fixture.isOfficialTournamentResult,
                          )
                          .length
                          .toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...controller.groups.map(
              (group) => _GroupCard(group: group, controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

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

class TournamentStandingsScreen
    extends GetView<TournamentOperationsController> {
  const TournamentStandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Standings',
      child: Obx(() {
        if (controller.standings.isEmpty) {
          return const _StateMessage(
            title: 'لا توجد standings بعد',
            message: 'لن تظهر standings إلا بعد إنشاء المجموعات.',
          );
        }
        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترتيب المجموعات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tie-breakers: ${controller.standings.first.tiebreakerOrder.map(_standingsMetricLabel).join(' → ')}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...controller.standings.map(
              (snapshot) =>
                  _StandingCard(snapshot: snapshot, controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

class TournamentBracketScreen extends GetView<TournamentOperationsController> {
  const TournamentBracketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Bracket',
      child: Obx(() {
        final bracket = controller.knockoutBracket.value;
        if (bracket == null) {
          return const _StateMessage(
            title: 'لا يوجد bracket بعد',
            message: 'ابدأ الإقصاء بعد اكتمال المؤهلين.',
          );
        }
        final tiesByRound = <int, List<KnockoutTie>>{};
        final matchById = {
          for (final fixture in controller.knockoutFixtures)
            fixture.id: fixture,
        };
        for (final tie in controller.knockoutTies) {
          tiesByRound
              .putIfAbsent(tie.roundIndex, () => <KnockoutTie>[])
              .add(tie);
        }
        final sortedRounds = tiesByRound.keys.toList(growable: true)..sort();
        final finalRoundIndex = sortedRounds.isEmpty ? 0 : sortedRounds.last;
        final finalTie = tiesByRound[finalRoundIndex]?.firstOrNull;

        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الإقصاء',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Format: Single Elimination'),
                    Text(
                      'Qualifiers: ${bracket.qualifierParticipantIds.length}',
                    ),
                    Text(
                      bracket.championParticipantId == null
                          ? 'البطل لم يتحدد بعد'
                          : 'البطل: ${controller.participantLabelFor(bracket.championParticipantId)}',
                    ),
                  ],
                ),
              ),
            ),
            if (finalTie != null) ...[
              const SizedBox(height: 12),
              _KnockoutFinalSummaryCard(
                tie: finalTie,
                match: finalTie.matchId == null
                    ? null
                    : matchById[finalTie.matchId!],
                controller: controller,
              ),
            ],
            const SizedBox(height: 12),
            ...sortedRounds.expand(
              (roundIndex) => <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _knockoutRoundLabel(
                      roundIndex,
                      maxRoundIndex: finalRoundIndex,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...tiesByRound[roundIndex]!.map(
                  (tie) => _KnockoutTieCard(
                    tie: tie,
                    match: tie.matchId == null ? null : matchById[tie.matchId!],
                    controller: controller,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _ScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  const _ScaffoldListScreen({
    required this.title,
    required this.child,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

Future<void> _showManualAddParticipantDialog(
  BuildContext context,
  TournamentOperationsController controller,
) async {
  final candidate = await _showParticipantPickerDialog(
    context: context,
    controller: controller,
    title: 'إضافة participant يدويًا',
  );
  if (candidate == null) {
    return;
  }
  await controller.addManualParticipant(
    sourceType: candidate.sourceType,
    sourceEntityId: candidate.sourceEntityId,
  );
}

Future<void> _showReplaceParticipantDialog(
  BuildContext context,
  TournamentOperationsController controller,
  TournamentParticipant participant,
) async {
  final candidate = await _showParticipantPickerDialog(
    context: context,
    controller: controller,
    title: 'استبدال ${participant.displayName}',
    initialSourceType: participant.sourceType,
    replacingParticipant: participant,
  );
  if (candidate == null) {
    return;
  }
  await controller.replaceParticipant(
    participantId: participant.id,
    replacementSourceType: candidate.sourceType,
    replacementSourceEntityId: candidate.sourceEntityId,
  );
}

Future<void> _showSeedEditorDialog(
  BuildContext context,
  TournamentOperationsController controller,
  TournamentParticipant participant,
) async {
  final seedController = TextEditingController(
    text: participant.seed?.toString() ?? '',
  );
  try {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تعديل Seed لـ ${participant.displayName}'),
        content: TextField(
          controller: seedController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Seed',
            hintText: 'اتركها فارغة لإزالة الـ seed',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('__clear__'),
            child: const Text('إزالة'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(seedController.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }
    if (result == '__clear__') {
      await controller.updateParticipantSeed(
        participantId: participant.id,
        seed: null,
      );
      return;
    }
    final parsedSeed = int.tryParse(result);
    if (parsedSeed == null || parsedSeed <= 0) {
      return;
    }
    await controller.updateParticipantSeed(
      participantId: participant.id,
      seed: parsedSeed,
    );
  } finally {
    seedController.dispose();
  }
}

Future<TournamentParticipantCandidate?> _showParticipantPickerDialog({
  required BuildContext context,
  required TournamentOperationsController controller,
  required String title,
  TournamentParticipantSourceType initialSourceType =
      TournamentParticipantSourceType.registeredTeam,
  TournamentParticipant? replacingParticipant,
}) async {
  final searchController = TextEditingController();
  TournamentParticipantSourceType selectedSourceType = initialSourceType;
  var isSearching = false;
  var hasSearched = false;
  var searchError = '';
  var results = const <TournamentParticipantCandidate>[];
  Timer? searchDebounce;
  var searchSequence = 0;

  Future<void> performSearch(
    StateSetter setState, {
    String? queryOverride,
  }) async {
    final requestId = ++searchSequence;
    final query = (queryOverride ?? searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        hasSearched = true;
        searchError = 'اكتب اسم الفريق أولاً.';
        results = const <TournamentParticipantCandidate>[];
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchError = '';
    });
    try {
      final found = await controller.searchParticipantCandidates(
        query: query,
        sourceType: selectedSourceType,
        replacingParticipant: replacingParticipant,
      );
      if (requestId != searchSequence) {
        return;
      }
      setState(() {
        results = found;
      });
    } catch (error) {
      if (requestId != searchSequence) {
        return;
      }
      setState(() {
        searchError = error.toString().replaceFirst('Exception: ', '').trim();
        results = const <TournamentParticipantCandidate>[];
      });
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  void scheduleSearch(StateSetter setState, String value) {
    searchDebounce?.cancel();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      setState(() {
        hasSearched = false;
        searchError = '';
        results = const <TournamentParticipantCandidate>[];
      });
      return;
    }
    searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => performSearch(setState, queryOverride: normalized),
    );
  }

  try {
    return await showDialog<TournamentParticipantCandidate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<TournamentParticipantSourceType>(
                    initialValue: selectedSourceType,
                    decoration: const InputDecoration(labelText: 'نوع المصدر'),
                    items: TournamentParticipantSourceType.values
                        .map(
                          (sourceType) => DropdownMenuItem(
                            value: sourceType,
                            child: Text(
                              sourceType ==
                                      TournamentParticipantSourceType
                                          .registeredTeam
                                  ? 'Registered Team'
                                  : 'Guest Team',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: isSearching
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              selectedSourceType = value;
                              results =
                                  const <TournamentParticipantCandidate>[];
                              searchError = '';
                              hasSearched = false;
                            });
                            if (searchController.text.trim().isNotEmpty) {
                              scheduleSearch(setState, searchController.text);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'ابحث بالاسم',
                      hintText: 'مثال: Blue أو Falcons',
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => scheduleSearch(setState, value),
                    onSubmitted: (_) => performSearch(setState),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: isSearching
                          ? null
                          : () => performSearch(setState),
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else if (searchError.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        searchError,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else if (results.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final candidate = results[index];
                          return ListTile(
                            title: Text(candidate.displayName),
                            subtitle: Text(
                              '${candidate.sourceType.name} • ${candidate.sourceEntityId}',
                            ),
                            onTap: () =>
                                Navigator.of(dialogContext).pop(candidate),
                          );
                        },
                      ),
                    )
                  else if (hasSearched)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'لا توجد نتائج مناسبة أو أن الفريق موجود بالفعل داخل البطولة.',
                      ),
                    )
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ابحث ثم اختر فريقًا مسجلًا أو ضيفًا لإضافته أو استبداله.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  } finally {
    searchDebounce?.cancel();
    searchController.dispose();
  }
}

class _GroupCard extends StatelessWidget {
  final TournamentGroup group;
  final TournamentOperationsController controller;

  const _GroupCard({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    final participants = controller.participantsForGroup(group.id);
    final snapshot = controller.standings
        .where((item) => item.groupId == group.id)
        .firstOrNull;
    final qualifiers = snapshot?.qualifierParticipantIds.toSet() ?? <String>{};
    final groupFixtures =
        controller.groupStageFixtures
            .where((fixture) => fixture.groupId == group.id)
            .toList(growable: false)
          ..sort((left, right) {
            final leftDate = left.scheduledAt ?? left.createdAt;
            final rightDate = right.scheduledAt ?? right.createdAt;
            return leftDate.compareTo(rightDate);
          });
    final officialFixtures = groupFixtures
        .where((fixture) => fixture.isOfficialTournamentResult)
        .length;
    final scheduledFixtures = groupFixtures
        .where((fixture) => fixture.scheduledAt != null)
        .length;

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
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (qualifiers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6EA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${qualifiers.length} Qualified',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Teams',
                  value: participants.length.toString(),
                ),
                _MetricChip(
                  label: 'Fixtures',
                  value: groupFixtures.length.toString(),
                ),
                _MetricChip(
                  label: 'Scheduled',
                  value: scheduledFixtures.toString(),
                ),
                _MetricChip(
                  label: 'Official',
                  value: officialFixtures.toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${participant.seed ?? '-'} • ${participant.displayName}',
                      ),
                    ),
                    if (qualifiers.contains(participant.id))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9F2D9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Qualified'),
                      ),
                  ],
                ),
              ),
            ),
            if (groupFixtures.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'مباريات المجموعة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...groupFixtures.map(
                (fixture) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${controller.fixtureTeamLabel(fixture, isHome: true)} vs ${controller.fixtureTeamLabel(fixture, isHome: false)}',
                  ),
                  subtitle: Text(
                    '${_formatDateTime(fixture.scheduledAt)} • ${_matchScoreLabel(fixture)}',
                  ),
                  trailing: fixture.isOfficialTournamentResult
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right),
                  onTap: () =>
                      Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantSection extends StatelessWidget {
  final String title;
  final List<TournamentParticipant> participants;
  final TournamentOperationsController controller;

  const _ParticipantSection({
    required this.title,
    required this.participants,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...participants.map(
          (participant) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ParticipantCard(
              participant: participant,
              controller: controller,
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final TournamentParticipant participant;
  final TournamentOperationsController controller;

  const _ParticipantCard({required this.participant, required this.controller});

  @override
  Widget build(BuildContext context) {
    final canReplace = controller.canReplaceParticipant(participant);
    final canWithdraw = participant.isActive && !controller.isActing.value;
    final canEditSeed = controller.canEditParticipantSeed(participant);
    final canReactivate = controller.canReactivateParticipant(participant);

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
                        participant.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participant.groupId == null
                            ? 'لم يُسند إلى مجموعة بعد'
                            : 'المجموعة: ${controller.groupLabelFor(participant.groupId)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (participant.replacedByParticipantId != null &&
                          participant.replacedByParticipantId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'تم استبداله بواسطة: ${controller.participantLabelFor(participant.replacedByParticipantId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (participant.replacementForParticipantId != null &&
                          participant.replacementForParticipantId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'بديل عن: ${controller.participantLabelFor(participant.replacementForParticipantId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: _participantStatusLabel(participant.status),
                  backgroundColor: _participantStatusColor(participant.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: _participantSourceLabel(participant.sourceType),
                  backgroundColor: const Color(0xFFF1F3F5),
                ),
                if (participant.seed != null)
                  _StatusChip(
                    label: 'Seed ${participant.seed}',
                    backgroundColor: const Color(0xFFEAF1FF),
                  ),
              ],
            ),
            if (participant.isActive) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEditSeed)
                    OutlinedButton.icon(
                      onPressed: () => _showSeedEditorDialog(
                        context,
                        controller,
                        participant,
                      ),
                      icon: const Icon(Icons.tag),
                      label: const Text('Edit Seed'),
                    ),
                  if (canReplace)
                    OutlinedButton.icon(
                      onPressed: () => _showReplaceParticipantDialog(
                        context,
                        controller,
                        participant,
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Replace'),
                    ),
                  OutlinedButton.icon(
                    onPressed: canWithdraw
                        ? () => controller.withdrawParticipant(participant.id)
                        : null,
                    icon: const Icon(Icons.person_remove_alt_1),
                    label: const Text('Withdraw'),
                  ),
                ],
              ),
            ] else if (canReactivate) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    controller.reactivateParticipant(participant.id),
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Reactivate'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixtureOperationsCard extends StatelessWidget {
  final Match fixture;
  final TournamentOperationsController controller;
  final VoidCallback? onSchedule;

  const _FixtureOperationsCard({
    required this.fixture,
    required this.controller,
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
                  : fixture.fixtureStatus == FixtureStatus.draft
                  ? 'هذه fixture ما زالت draft ويمكن تعديل توقيتها قبل النشر.'
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
                OutlinedButton.icon(
                  onPressed: fixture.status == MatchStatus.open
                      ? null
                      : () => Get.toNamed(
                          AppRoutes.scoreApprovalForMatch(fixture.id),
                        ),
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('Score Review'),
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

class _StandingCard extends StatelessWidget {
  final GroupStandingSnapshot snapshot;
  final TournamentOperationsController controller;

  const _StandingCard({required this.snapshot, required this.controller});

  @override
  Widget build(BuildContext context) {
    final qualifiers = snapshot.qualifierParticipantIds.toSet();
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
                        controller.groupLabelFor(snapshot.groupId),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'آخر تحديث: ${intl.DateFormat('yyyy/MM/dd – HH:mm').format(snapshot.updatedAt)}',
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
                    color: const Color(0xFFEAF6EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${snapshot.qualifierParticipantIds.length} Qualified',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'هذا هو الـ canonical standings snapshot المعتمد للتأهل والترتيب.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Team')),
                  DataColumn(label: Text('P')),
                  DataColumn(label: Text('W')),
                  DataColumn(label: Text('D')),
                  DataColumn(label: Text('L')),
                  DataColumn(label: Text('GF')),
                  DataColumn(label: Text('GA')),
                  DataColumn(label: Text('GD')),
                  DataColumn(label: Text('Pts')),
                  DataColumn(label: Text('Status')),
                ],
                rows: snapshot.entries
                    .map((entry) {
                      final isQualified = qualifiers.contains(
                        entry.participantId,
                      );
                      return DataRow(
                        color: WidgetStatePropertyAll<Color?>(
                          isQualified ? const Color(0xFFF0FAF0) : null,
                        ),
                        cells: [
                          DataCell(Text(entry.rank.toString())),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(entry.displayName),
                                if (isQualified) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9F2D9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text('Qualified'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(Text(entry.played.toString())),
                          DataCell(Text(entry.wins.toString())),
                          DataCell(Text(entry.draws.toString())),
                          DataCell(Text(entry.losses.toString())),
                          DataCell(Text(entry.goalsFor.toString())),
                          DataCell(Text(entry.goalsAgainst.toString())),
                          DataCell(Text(entry.goalDifference.toString())),
                          DataCell(Text(entry.points.toString())),
                          DataCell(
                            Text(isQualified ? 'Advancing' : 'In Group'),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnockoutFinalSummaryCard extends StatelessWidget {
  final KnockoutTie tie;
  final Match? match;
  final TournamentOperationsController controller;

  const _KnockoutFinalSummaryCard({
    required this.tie,
    required this.match,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8F4E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص النهائي',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.participantLabelFor(tie.participantAId)} vs ${controller.participantLabelFor(tie.participantBId)}',
            ),
            const SizedBox(height: 4),
            Text(
              tie.winnerParticipantId == null
                  ? 'لم يُحسم النهائي بعد.'
                  : 'الفائز الحالي: ${controller.participantLabelFor(tie.winnerParticipantId)}',
            ),
            if (match != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: 'Score', value: _matchScoreLabel(match)),
                  _MetricChip(
                    label: 'Status',
                    value: _matchStatusLabel(match!.status),
                  ),
                  _MetricChip(
                    label: 'Schedule',
                    value: _formatDateTime(match!.scheduledAt),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match!.id)),
                    icon: const Icon(Icons.sports_soccer),
                    label: const Text('Matchday'),
                  ),
                  OutlinedButton.icon(
                    onPressed: match!.status == MatchStatus.open
                        ? null
                        : () => Get.toNamed(
                            AppRoutes.scoreApprovalForMatch(match!.id),
                          ),
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: const Text('Score Review'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnockoutTieCard extends StatelessWidget {
  final KnockoutTie tie;
  final Match? match;
  final TournamentOperationsController controller;

  const _KnockoutTieCard({
    required this.tie,
    required this.match,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
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
                        '${controller.participantLabelFor(tie.participantAId)} vs ${controller.participantLabelFor(tie.participantBId)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slot ${tie.slotNumber + 1}${tie.nextTieId == null ? '' : ' • الفائز يتقدم للمرحلة التالية'}',
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
                    color: tie.winnerParticipantId == null
                        ? const Color(0xFFF4F4F4)
                        : const Color(0xFFE7F7ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tie.winnerParticipantId == null ? 'Pending' : 'Winner Set',
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
                _MetricChip(label: 'Ready', value: tie.isReady ? 'Yes' : 'No'),
                if (match != null)
                  _MetricChip(label: 'Score', value: _matchScoreLabel(match)),
                if (match != null)
                  _MetricChip(
                    label: 'Status',
                    value: _matchStatusLabel(match!.status),
                  ),
                if (match != null)
                  _MetricChip(
                    label: 'Schedule',
                    value: _formatDateTime(match!.scheduledAt),
                  ),
              ],
            ),
            if (tie.winnerParticipantId != null) ...[
              const SizedBox(height: 12),
              Text(
                'الفائز: ${controller.participantLabelFor(tie.winnerParticipantId)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (match != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match!.id)),
                    icon: const Icon(Icons.sports_soccer),
                    label: const Text('Matchday'),
                  ),
                  OutlinedButton.icon(
                    onPressed: match!.status == MatchStatus.open
                        ? null
                        : () => Get.toNamed(
                            AppRoutes.scoreApprovalForMatch(match!.id),
                          ),
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: const Text('Score Review'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _fixtureStatusLabelText(FixtureStatus status) => switch (status) {
  FixtureStatus.draft => 'Draft',
  FixtureStatus.published => 'Published',
  FixtureStatus.completed => 'Completed',
};

String _tournamentStageLabel(TournamentStageType? stage) => switch (stage) {
  TournamentStageType.groupStage => 'المجموعات',
  TournamentStageType.knockoutStage => 'الإقصاء',
  null => 'غير محدد',
};

String _standingsMetricLabel(GroupStandingsMetric metric) => switch (metric) {
  GroupStandingsMetric.points => 'Points',
  GroupStandingsMetric.goalDifference => 'Goal Difference',
  GroupStandingsMetric.goalsFor => 'Goals For',
  GroupStandingsMetric.randomDraw => 'Random Draw',
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
};

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd – HH:mm').format(value);
}

String _matchScoreLabel(Match? match) {
  if (match == null || match.scoreTeamA == null || match.scoreTeamB == null) {
    return '-';
  }
  return '${match.scoreTeamA} - ${match.scoreTeamB}';
}

String _participantStatusLabel(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => 'Approved',
      TournamentParticipantStatus.finalized => 'Finalized',
      TournamentParticipantStatus.withdrawn => 'Withdrawn',
      TournamentParticipantStatus.replaced => 'Replaced',
    };

String _participantSourceLabel(TournamentParticipantSourceType sourceType) =>
    switch (sourceType) {
      TournamentParticipantSourceType.registeredTeam => 'Registered Team',
      TournamentParticipantSourceType.guestTeam => 'Guest Team',
    };

Color _participantStatusColor(TournamentParticipantStatus status) =>
    switch (status) {
      TournamentParticipantStatus.approved => const Color(0xFFEAF1FF),
      TournamentParticipantStatus.finalized => const Color(0xFFE7F7ED),
      TournamentParticipantStatus.withdrawn => const Color(0xFFFFF2CC),
      TournamentParticipantStatus.replaced => const Color(0xFFF0F0F0),
    };

class _StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const _StatusChip({required this.label, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
