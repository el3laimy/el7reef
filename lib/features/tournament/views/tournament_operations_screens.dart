import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/match.dart';
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
                        Text('الحالة الحالية: ${tournament.status.name}'),
                        Text(
                          'المشاركون النشطون: ${controller.activeParticipantsCount}',
                        ),
                        if (tournament.participantListFinalizedAt != null)
                          Text(
                            'تم قفل القائمة: ${tournament.participantListFinalizedAt}',
                          ),
                        if (report != null) ...[
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
                              controller.isBlockedByManualMigration
                          ? null
                          : controller.finalizeParticipantList,
                      icon: const Icon(Icons.verified),
                      label: const Text('Finalize Participants'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          controller.isActing.value ||
                              controller.isBlockedByManualMigration
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
                              controller.isBlockedByManualMigration
                          ? null
                          : controller.startKnockout,
                      icon: const Icon(Icons.account_tree),
                      label: const Text('Start Knockout'),
                    ),
                    FilledButton.icon(
                      onPressed: controller.isActing.value
                          ? null
                          : controller.completeTournament,
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('Complete Tournament'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
    return Obx(
      () => _ScaffoldListScreen(
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
                    : 'اعتمد التسجيلات أو شغّل backfill أولاً.',
              )
            : ListView.separated(
                itemCount: controller.participants.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final participant = controller.participants[index];
                  final canReplace = controller.canReplaceParticipant(
                    participant,
                  );
                  final canWithdraw =
                      participant.isActive && !controller.isActing.value;
                  return ListTile(
                    title: Text(participant.displayName),
                    subtitle: Text(
                      '${participant.sourceType.name} • ${participant.status.name}'
                      '${participant.seed == null ? '' : ' • Seed ${participant.seed}'}',
                    ),
                    trailing: participant.isActive
                        ? SizedBox(
                            width: canReplace ? 96 : 48,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canReplace)
                                  IconButton(
                                    tooltip: 'Replace participant',
                                    icon: const Icon(Icons.swap_horiz),
                                    onPressed: () =>
                                        _showReplaceParticipantDialog(
                                          context,
                                          controller,
                                          participant,
                                        ),
                                  ),
                                IconButton(
                                  tooltip: 'Withdraw participant',
                                  icon: const Icon(Icons.person_remove_alt_1),
                                  onPressed: canWithdraw
                                      ? () => controller.withdrawParticipant(
                                          participant.id,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          )
                        : null,
                  );
                },
              ),
      ),
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
          children: controller.groups
              .map((group) => _GroupCard(group: group, controller: controller))
              .toList(growable: false),
        );
      }),
    );
  }
}

class TournamentFixturesScreen extends GetView<TournamentOperationsController> {
  const TournamentFixturesScreen({super.key});

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
        return ListView.separated(
          itemCount: controller.fixtures.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final fixture = controller.fixtures[index];
            return ListTile(
              isThreeLine: true,
              title: Text(
                '${fixture.teamAId ?? 'TBD'} vs ${fixture.teamBId ?? 'TBD'}',
              ),
              subtitle: Text(
                '${fixture.stageType?.name ?? 'unknown'} • ${fixture.fixtureStatus.name}'
                '${fixture.groupId == null ? '' : ' • ${fixture.groupId}'}\n'
                'الموعد: ${_formatSchedule(fixture)}'
                '${fixture.venueId == null ? '' : ' • الملعب: ${fixture.venueId}'}',
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fixture.scoreTeamA != null && fixture.scoreTeamB != null)
                    Text('${fixture.scoreTeamA} - ${fixture.scoreTeamB}'),
                  IconButton(
                    tooltip: 'جدولة fixture',
                    icon: const Icon(Icons.calendar_month),
                    onPressed:
                        controller.isActing.value ||
                            fixture.isOfficialTournamentResult
                        ? null
                        : () => _showScheduleDialog(context, fixture),
                  ),
                ],
              ),
            );
          },
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

  String _formatSchedule(Match fixture) {
    final scheduledAt = fixture.scheduledAt;
    if (scheduledAt == null) {
      return 'غير محدد';
    }
    return intl.DateFormat('yyyy/MM/dd – HH:mm', 'ar').format(scheduledAt);
  }
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
          children: controller.standings
              .map((snapshot) => _StandingCard(snapshot: snapshot))
              .toList(growable: false),
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
        return ListView(
          children: controller.knockoutTies
              .map(
                (tie) => Card(
                  child: ListTile(
                    title: Text(
                      'Round ${tie.roundIndex + 1} • Slot ${tie.slotNumber + 1}',
                    ),
                    subtitle: Text(
                      '${tie.participantAId ?? 'TBD'} vs ${tie.participantBId ?? 'TBD'}',
                    ),
                    trailing: tie.winnerParticipantId == null
                        ? null
                        : Text('Winner: ${tie.winnerParticipantId}'),
                  ),
                ),
              )
              .toList(growable: false),
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

  Future<void> performSearch(StateSetter setState) async {
    final query = searchController.text.trim();
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
      setState(() {
        results = found;
      });
    } catch (error) {
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

  try {
    return await showDialog<TournamentParticipantCandidate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
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
                            results = const <TournamentParticipantCandidate>[];
                            searchError = '';
                            hasSearched = false;
                          });
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
                    height: 240,
                    child: ListView.separated(
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
    searchController.dispose();
  }
}

class _GroupCard extends StatelessWidget {
  final TournamentGroup group;
  final TournamentOperationsController controller;

  const _GroupCard({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    final participants = controller.participants
        .where((participant) => group.participantIds.contains(participant.id))
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${participant.seed ?? '-'} • ${participant.displayName}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  final GroupStandingSnapshot snapshot;

  const _StandingCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.groupId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...snapshot.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '#${entry.rank} ${entry.displayName} • ${entry.points} pts • GD ${entry.goalDifference}',
                ),
              ),
            ),
          ],
        ),
      ),
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
