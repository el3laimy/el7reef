import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/group_standing_snapshot.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_group.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../../shareables/controllers/qualification_share_controller.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/models/qualification_share_data.dart';
import '../../shareables/models/tournament_stage_share_data.dart';
import '../../shareables/services/pride_share_payload_builder.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/pride_card_format_picker.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../../shareables/widgets/qualification_share_card.dart';
import '../../shareables/widgets/tournament_stage_share_card.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_group_stage_overview.dart';
import '../widgets/tournament_stage_components.dart';

class TournamentGroupsScreen extends GetView<TournamentOperationsController> {
  const TournamentGroupsScreen({super.key});

  static const _captureService = ShareCardCaptureService();
  static const _payloadBuilder = PrideSharePayloadBuilder();
  static const _qualificationShareController = QualificationShareController();

  @override
  Widget build(BuildContext context) {
    return TournamentStageScaffold(
      title: 'دور المجموعات',
      onRefresh: controller.refreshAll,
      child: Obx(() {
        final hasData = controller.groups.isNotEmpty;
        if (controller.isLoading.value && !hasData) {
          return const TournamentStageSkeleton(rows: 6);
        }
        if (controller.errorMessage.value.isNotEmpty && !hasData) {
          return TournamentStageStateView(
            title: 'تعذر تحميل المجموعات',
            message: controller.errorMessage.value,
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            actionLabel: 'إعادة المحاولة',
            actionIcon: Icons.refresh_rounded,
            onAction: controller.refreshAll,
          );
        }
        if (!hasData) {
          return _EmptyGroupsState(controller: controller);
        }

        final allFixtures = controller.groupStageFixtures;
        final visibleFixtures = controller.canManageTournament
            ? allFixtures
            : allFixtures
                  .where(
                    (fixture) => fixture.fixtureStatus != FixtureStatus.draft,
                  )
                  .toList(growable: false);
        final participantsById = <String, TournamentParticipant>{
          for (final participant in controller.participants)
            participant.id: participant,
          for (final participant in controller.participants)
            participant.sourceEntityId: participant,
        };
        final participantsByGroupId = {
          for (final group in controller.groups)
            group.id: group.participantIds
                .map((participantId) => participantsById[participantId])
                .whereType<TournamentParticipant>()
                .toList(growable: false),
        };

        String fixtureTeamLabel(Match fixture, {required bool isHome}) {
          final participantId = isHome
              ? fixture.teamAParticipantId
              : fixture.teamBParticipantId;
          final fallbackId = isHome ? fixture.teamAId : fixture.teamBId;
          return participantsById[participantId]?.displayName ??
              (fallbackId == null || fallbackId.isEmpty
                  ? 'لم يتحدد'
                  : participantsById[fallbackId]?.displayName ??
                        'فريق غير متاح');
        }

        return Column(
          children: [
            if (controller.errorMessage.value.isNotEmpty) ...[
              TournamentStageDataNotice.cachedError(
                onRetry: controller.refreshAll,
              ),
              const SizedBox(height: AppDimensions.md),
            ] else if (controller.isLoading.value) ...[
              const TournamentStageDataNotice.refreshing(),
              const SizedBox(height: AppDimensions.md),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    TournamentGroupStageOverview(
                      groups: controller.groups.toList(growable: false),
                      participantsByGroupId: participantsByGroupId,
                      standings: controller.standings.toList(growable: false),
                      visibleFixtures: visibleFixtures,
                      allFixtures: allFixtures,
                      fixtureTeamLabel: fixtureTeamLabel,
                      onFixtureTap: (fixture) =>
                          Get.toNamed(AppRoutes.matchDetailsById(fixture.id)),
                      onShareStandings: FeatureFlags.prideShareCatalogV2Enabled
                          ? (group, entries, qualifiers, isOfficial) =>
                                _shareStandings(
                                  context,
                                  group: group,
                                  entries: entries,
                                  qualifiers: qualifiers,
                                  isOfficial: isOfficial,
                                )
                          : null,
                      onShareQualification:
                          FeatureFlags.prideShareCatalogV2Enabled
                          ? (group, entries, qualifiers, isOfficial) =>
                                _shareQualification(
                                  context,
                                  group: group,
                                  entries: entries,
                                  qualifiers: qualifiers,
                                  isOfficial: isOfficial,
                                )
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.xl),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _shareStandings(
    BuildContext context, {
    required TournamentGroup group,
    required List<GroupStandingEntry> entries,
    required Set<String> qualifiers,
    required bool isOfficial,
  }) async {
    final tournament = controller.tournament.value;
    if (tournament == null || entries.isEmpty) {
      Get.snackbar('تعذر المشاركة', 'لا توجد بيانات ترتيب مؤكدة لمشاركتها.');
      return;
    }
    final format = await showPrideCardFormatPicker(context);
    if (format == null || !context.mounted) return;
    final payload = _payloadBuilder.groupStandings(tournamentId: tournament.id);
    final data = TournamentStageShareData(
      kind: TournamentStagePrideKind.groupStandings,
      tournamentName: tournament.name,
      title: 'جدول ${group.name}',
      statusLabel: isOfficial ? 'ترتيب رسمي' : 'ترتيب مؤقت',
      rows: entries
          .map(
            (entry) => TournamentStageShareRowData(
              leading: '#${entry.rank}',
              title: entry.displayName,
              subtitle:
                  'لعب ${entry.played} · فرق ${entry.goalDifference >= 0 ? '+' : ''}${entry.goalDifference}',
              trailing: '${entry.points}',
              emphasized: qualifiers.contains(entry.participantId),
              earned: isOfficial && qualifiers.contains(entry.participantId),
            ),
          )
          .toList(growable: false),
      sharePayload: payload,
    );
    await _captureService.captureAndShareWidget(
      context: context,
      widget: TournamentStageShareCard(
        data: data,
        exportMode: true,
        format: format,
        includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
      ),
      fileName: 'el7reef_group_${group.id}',
      text: 'جدول ${group.name} في ${tournament.name}',
      payload: payload,
    );
  }

  Future<void> _shareQualification(
    BuildContext context, {
    required TournamentGroup group,
    required List<GroupStandingEntry> entries,
    required Set<String> qualifiers,
    required bool isOfficial,
  }) async {
    final tournament = controller.tournament.value;
    final snapshot = controller.standings
        .where(
          (candidate) =>
              candidate.tournamentId == tournament?.id &&
              candidate.groupId == group.id &&
              candidate.groupStageId == group.groupStageId,
        )
        .firstOrNull;
    if (!FeatureFlags.prideShareCatalogV2Enabled ||
        tournament == null ||
        snapshot == null ||
        !isOfficial ||
        snapshot.qualifierParticipantIds.isEmpty) {
      Get.snackbar(
        'بطاقة التأهل غير متاحة',
        'تظهر البطاقة بعد اعتماد كل نتائج المجموعة وتأكيد المتأهلين.',
      );
      return;
    }

    final candidates = _officialQualifierCandidates(
      snapshot.entries,
      snapshot.qualifierParticipantIds.toSet(),
    );
    if (candidates.isEmpty) {
      Get.snackbar(
        'تعذر تحديد المتأهل',
        'بيانات الفريق المتأهل غير مكتملة، حدّث المجموعة ثم حاول مرة أخرى.',
      );
      return;
    }

    final selected = await _selectOfficialQualifier(
      context,
      group: group,
      candidates: candidates,
    );
    if (selected == null || !context.mounted) return;

    await _composeQualificationCard(
      context,
      request: _QualificationShareRequest(
        tournament: tournament,
        group: group,
        snapshot: snapshot,
        qualifier: selected,
        qualificationIsOfficial: isOfficial,
      ),
    );
  }

  List<_OfficialQualifier> _officialQualifierCandidates(
    List<GroupStandingEntry> entries,
    Set<String> qualifiers,
  ) {
    final participantsById = <String, TournamentParticipant>{
      for (final participant in controller.participants)
        participant.id: participant,
      for (final participant in controller.participants)
        participant.sourceEntityId: participant,
    };
    final candidates = <_OfficialQualifier>[];
    for (final entry in entries) {
      final participant = participantsById[entry.participantId];
      if (qualifiers.contains(entry.participantId) && participant != null) {
        candidates.add(
          _OfficialQualifier(entry: entry, participant: participant),
        );
      }
    }
    return candidates
      ..sort((left, right) => left.entry.rank.compareTo(right.entry.rank));
  }

  Future<void> _composeQualificationCard(
    BuildContext context, {
    required _QualificationShareRequest request,
  }) async {
    final qualificationCard = _qualificationShareController.buildIfOfficial(
      tournament: request.tournament,
      group: request.group,
      snapshot: request.snapshot,
      entry: request.qualifier.entry,
      participant: request.qualifier.participant,
      qualificationIsOfficial: request.qualificationIsOfficial,
    );
    if (qualificationCard == null) {
      Get.snackbar(
        'بطاقة التأهل غير متاحة',
        'تعذر التحقق من أن هذا الفريق ضمن المتأهلين رسميًا.',
      );
      return;
    }

    final selection = await showPrideShareComposer(
      context: context,
      cardType: qualificationCard.sharePayload.cardType,
      previewBuilder: (format) => QualificationShareCard(
        data: qualificationCard,
        format: format,
        includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
      ),
    );
    if (selection == null || !context.mounted) return;

    await _exportQualificationCard(
      context,
      card: qualificationCard,
      request: request,
      selection: selection,
    );
  }

  Future<void> _exportQualificationCard(
    BuildContext context, {
    required QualificationShareData card,
    required _QualificationShareRequest request,
    required PrideShareSelection selection,
  }) async {
    final participant = request.qualifier.participant;
    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: QualificationShareCard(
            data: card,
            exportMode: true,
            format: selection.format,
            includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
          ),
          exportRequest: PrideExportRequest(
            cardType: card.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName:
                'el7reef_qualification_${request.tournament.id}_${participant.id}',
            includeAudio: selection.includeAudio,
          ),
          text:
              '${participant.displayName} متأهل رسميًا من ${request.group.name} في ${request.tournament.name}',
          payload: card.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'TournamentGroupsScreen.shareQualification',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز بطاقة التأهل الآن.');
    }
  }

  Future<_OfficialQualifier?> _selectOfficialQualifier(
    BuildContext context, {
    required TournamentGroup group,
    required List<_OfficialQualifier> candidates,
  }) {
    return showModalBottomSheet<_OfficialQualifier>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _OfficialQualifierSheet(group: group, candidates: candidates),
    );
  }
}

class _OfficialQualifier {
  final GroupStandingEntry entry;
  final TournamentParticipant participant;

  const _OfficialQualifier({required this.entry, required this.participant});
}

class _QualificationShareRequest {
  final Tournament tournament;
  final TournamentGroup group;
  final GroupStandingSnapshot snapshot;
  final _OfficialQualifier qualifier;
  final bool qualificationIsOfficial;

  const _QualificationShareRequest({
    required this.tournament,
    required this.group,
    required this.snapshot,
    required this.qualifier,
    required this.qualificationIsOfficial,
  });
}

class _OfficialQualifierSheet extends StatelessWidget {
  final TournamentGroup group;
  final List<_OfficialQualifier> candidates;

  const _OfficialQualifierSheet({
    required this.group,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          0,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر الفريق المتأهل',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'كل الفرق هنا متأهلة رسميًا من ${group.name}. اختر الفريق الذي تريد مشاركة بطاقته.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppDimensions.sm),
                itemBuilder: (context, index) =>
                    _qualifierTile(context, candidates[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualifierTile(BuildContext context, _OfficialQualifier candidate) {
    final participant = candidate.participant;
    final goalDifference = candidate.entry.goalDifference;
    return Material(
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: ListTile(
        minTileHeight: 64,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: const BorderSide(color: AppColors.surfaceBorderStrong),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.16),
          foregroundColor: AppColors.success,
          child: Text('#${candidate.entry.rank}'),
        ),
        title: Text(
          participant.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${candidate.entry.points} نقطة، فارق ${goalDifference >= 0 ? '+' : ''}$goalDifference',
          textDirection: TextDirection.rtl,
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).pop(candidate),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  final TournamentOperationsController controller;

  const _EmptyGroupsState({required this.controller});

  @override
  Widget build(BuildContext context) {
    final canStart = controller.canStartGroupStageAction;
    final canManage = controller.canManageTournament;
    return TournamentStageStateView(
      title: 'المجموعات لم تبدأ بعد',
      message: canManage
          ? canStart
                ? 'الفرق جاهزة. أنشئ المجموعات والمباريات لتبدأ المنافسة.'
                : 'أكمل تجهيز الفرق واعتماد قائمة المشاركين من لوحة التشغيل.'
          : 'سيظهر جدول المجموعات هنا فور إنشائه ونشر مبارياته.',
      icon: Icons.groups_2_rounded,
      actionLabel: !canManage
          ? null
          : canStart
          ? 'أنشئ المجموعات والمباريات'
          : 'ارجع إلى لوحة التشغيل',
      actionIcon: canStart
          ? Icons.auto_awesome_motion_rounded
          : Icons.dashboard_customize_rounded,
      onAction: !canManage
          ? null
          : canStart
          ? controller.startGroupStage
          : () {
              final tournamentId = controller.tournamentId;
              if (tournamentId != null && tournamentId.isNotEmpty) {
                Get.offNamed(
                  AppRoutes.organizerDashboardForTournament(tournamentId),
                );
              }
            },
      actionLoading: controller.isActing.value,
    );
  }
}
