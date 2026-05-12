import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_widgets.dart';

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
            return TournamentStateMessage(
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
                              : () => showManualAddParticipantDialog(
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
                TournamentOperationsMetricsCard(controller: controller),
                const SizedBox(height: 12),
                TournamentReadinessChecklistCard(controller: controller),
                if (controller.pendingActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TournamentPendingActionsCard(controller: controller),
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
                TournamentLinkTile(
                  title: 'Participants',
                  subtitle: '${controller.participants.length} عنصر',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentParticipantsById(tournament.id),
                  ),
                ),
                TournamentLinkTile(
                  title: 'Groups',
                  subtitle: '${controller.groups.length} مجموعة',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentGroupsById(tournament.id),
                  ),
                ),
                TournamentLinkTile(
                  title: 'Fixtures',
                  subtitle: '${controller.fixtures.length} مباراة',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentFixturesById(tournament.id),
                  ),
                ),
                TournamentLinkTile(
                  title: 'Standings',
                  subtitle: '${controller.standings.length} snapshot',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentStandingsById(tournament.id),
                  ),
                ),
                TournamentLinkTile(
                  title: 'Bracket',
                  subtitle: controller.knockoutBracket.value == null
                      ? 'لم يبدأ الإقصاء بعد'
                      : '${controller.knockoutTies.length} tie',
                  onTap: () => Get.toNamed(
                    AppRoutes.tournamentBracketById(tournament.id),
                  ),
                ),
                TournamentLinkTile(
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

      return TournamentScaffoldListScreen(
        title: 'Participants',
        floatingActionButton: controller.canManualAddParticipants
            ? FloatingActionButton.extended(
                onPressed: controller.isActing.value
                    ? null
                    : () =>
                          showManualAddParticipantDialog(context, controller),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Manual Add'),
              )
            : null,
        child: controller.participants.isEmpty
            ? TournamentStateMessage(
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
                          TournamentMetricChip(
                            label: 'Active',
                            value: activeParticipants.length.toString(),
                          ),
                          TournamentMetricChip(
                            label: 'Withdrawn',
                            value: withdrawnParticipants.length.toString(),
                          ),
                          TournamentMetricChip(
                            label: 'Replaced',
                            value: replacedParticipants.length.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeParticipants.isNotEmpty)
                    TournamentParticipantSection(
                      title: 'Active Participants',
                      participants: activeParticipants,
                      controller: controller,
                    ),
                  if (withdrawnParticipants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TournamentParticipantSection(
                      title: 'Withdrawn',
                      participants: withdrawnParticipants,
                      controller: controller,
                    ),
                  ],
                  if (replacedParticipants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TournamentParticipantSection(
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
