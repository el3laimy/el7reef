import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/tournament_participant.dart';
import '../../shareables/models/tournament_stage_share_data.dart';
import '../../shareables/services/pride_share_payload_builder.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/pride_card_format_picker.dart';
import '../../shareables/widgets/tournament_stage_share_card.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/knockout_bracket_view.dart';
import '../widgets/tournament_stage_components.dart';

class TournamentBracketScreen extends GetView<TournamentOperationsController> {
  const TournamentBracketScreen({super.key});

  static const _captureService = ShareCardCaptureService();
  static const _payloadBuilder = PrideSharePayloadBuilder();

  @override
  Widget build(BuildContext context) {
    return TournamentStageScaffold(
      title: 'الأدوار الإقصائية',
      onRefresh: controller.refreshAll,
      child: Obx(() {
        final bracket = controller.knockoutBracket.value;
        final hasData = bracket != null;
        if (controller.isLoading.value && !hasData) {
          return const TournamentStageSkeleton(rows: 5);
        }
        if (controller.errorMessage.value.isNotEmpty && !hasData) {
          return TournamentStageStateView(
            title: 'تعذر تحميل الشجرة',
            message: controller.errorMessage.value,
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            actionLabel: 'إعادة المحاولة',
            actionIcon: Icons.refresh_rounded,
            onAction: controller.refreshAll,
          );
        }
        if (bracket == null) {
          return _EmptyBracketState(controller: controller);
        }

        final visibleFixtures = controller.canManageTournament
            ? controller.knockoutFixtures.toList(growable: false)
            : controller.knockoutFixtures
                  .where(
                    (fixture) => fixture.fixtureStatus != FixtureStatus.draft,
                  )
                  .toList(growable: false);
        final matchesById = <String, Match>{
          for (final fixture in visibleFixtures) fixture.id: fixture,
        };
        final participantsById = <String, TournamentParticipant>{
          for (final participant in controller.participants)
            participant.id: participant,
        };
        String participantLabel(String? participantId) {
          if (participantId == null || participantId.isEmpty) {
            return 'لم يتحدد';
          }
          return participantsById[participantId]?.displayName ?? 'فريق متأهل';
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
                    if (controller.knockoutTies.isEmpty)
                      TournamentStageStateView(
                        title: 'جارٍ تجهيز المواجهات',
                        message: controller.canManageTournament
                            ? 'حدث البيانات، أو راجع لوحة التشغيل إذا لم تظهر المواجهات.'
                            : 'ستظهر المواجهات هنا فور نشرها من المنظم.',
                        icon: Icons.account_tree_rounded,
                        actionLabel: controller.canManageTournament
                            ? 'تحديث الآن'
                            : null,
                        actionIcon: Icons.refresh_rounded,
                        onAction: controller.canManageTournament
                            ? controller.refreshAll
                            : null,
                      )
                    else
                      KnockoutBracketView(
                        ties: controller.knockoutTies.toList(growable: false),
                        matchesById: matchesById,
                        participantLabel: participantLabel,
                        hideUnpublishedParticipants:
                            !controller.canManageTournament,
                        onOpenMatch: (match) =>
                            Get.toNamed(AppRoutes.matchDetailsById(match.id)),
                        canReviewMatch: controller.canManageTournament
                            ? _canOpenScoreFlow
                            : null,
                        onReviewMatch: controller.canManageTournament
                            ? (match) => Get.toNamed(
                                AppRoutes.scoreApprovalForMatch(match.id),
                              )
                            : null,
                        headerData: KnockoutBracketHeaderData(
                          teamCount: bracket.qualifierParticipantIds.length,
                          byeCount: bracket.byeParticipantIds.length,
                          onShare: FeatureFlags.prideShareCatalogV2Enabled
                              ? () => _shareBracket(
                                  context,
                                  matchesById: matchesById,
                                  participantsById: participantsById,
                                )
                              : null,
                        ),
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

  Future<void> _shareBracket(
    BuildContext context, {
    required Map<String, Match> matchesById,
    required Map<String, TournamentParticipant> participantsById,
  }) async {
    final tournament = controller.tournament.value;
    final bracket = controller.knockoutBracket.value;
    final ties = controller.knockoutTies.toList(growable: false)
      ..sort((left, right) {
        final roundCompare = right.roundIndex.compareTo(left.roundIndex);
        return roundCompare != 0
            ? roundCompare
            : left.slotNumber.compareTo(right.slotNumber);
      });
    if (tournament == null || bracket == null || ties.isEmpty) {
      Get.snackbar('تعذر المشاركة', 'لا توجد شجرة مؤكدة لمشاركتها الآن.');
      return;
    }
    final format = await showPrideCardFormatPicker(context);
    if (format == null || !context.mounted) return;
    final maxRoundIndex = ties
        .map((tie) => tie.roundIndex)
        .reduce((left, right) => left > right ? left : right);

    String participantName(String? participantId) {
      if (participantId == null || participantId.isEmpty) {
        return 'بانتظار المتأهل';
      }
      return participantsById[participantId]?.displayName ?? 'فريق متأهل';
    }

    final rows = ties
        .map((tie) {
          final match = tie.matchId == null ? null : matchesById[tie.matchId];
          final hidden =
              !controller.canManageTournament &&
              tie.matchId != null &&
              match == null;
          final isBye = tie.resolutionType == KnockoutTieResolution.bye;
          final firstName = hidden
              ? 'مواجهة لم تُنشر'
              : participantName(tie.participantAId);
          final secondName = hidden
              ? null
              : tie.participantBId == null || tie.participantBId!.isEmpty
              ? null
              : participantName(tie.participantBId);
          final title = isBye
              ? '${participantName(tie.winnerParticipantId ?? tie.participantAId ?? tie.participantBId)} · تأهل مباشر'
              : secondName == null
              ? firstName
              : '$firstName × $secondName';
          final regulationScore = match?.scoreTeamA == null
              ? null
              : '${match!.scoreTeamA}-${match.scoreTeamB}';
          final penaltyScore = match?.penaltyScoreTeamA == null
              ? null
              : '${match!.penaltyScoreTeamA}-${match.penaltyScoreTeamB}';
          final trailing = penaltyScore == null
              ? regulationScore
              : regulationScore == null
              ? penaltyScore
              : '$regulationScore ($penaltyScore)';
          final isFinalWinner =
              tie.roundIndex == maxRoundIndex &&
              tie.winnerParticipantId != null;
          final roundLabel = knockoutRoundLabel(
            tie.roundIndex,
            maxRoundIndex: maxRoundIndex,
          );
          final shareTitle = isFinalWinner
              ? '${participantName(tie.winnerParticipantId)} · البطل'
              : title;
          return TournamentStageShareRowData(
            leading: '${tie.slotNumber + 1}',
            title: shareTitle,
            subtitle: isFinalWinner ? '$roundLabel · $title' : roundLabel,
            trailing: trailing,
            emphasized: tie.winnerParticipantId != null,
            earned: isFinalWinner,
          );
        })
        .toList(growable: false);
    final payload = _payloadBuilder.knockoutBracket(
      tournamentId: tournament.id,
    );
    final data = TournamentStageShareData(
      kind: TournamentStagePrideKind.knockoutBracket,
      tournamentName: tournament.name,
      title: 'طريق النهائي',
      statusLabel: bracket.championParticipantId == null
          ? 'الإقصائيات جارية'
          : 'البطل اتحدد',
      rows: rows,
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
      fileName: 'el7reef_bracket_${bracket.id}',
      text: 'طريق النهائي في ${tournament.name}',
      payload: payload,
    );
  }
}

class _EmptyBracketState extends StatelessWidget {
  final TournamentOperationsController controller;

  const _EmptyBracketState({required this.controller});

  @override
  Widget build(BuildContext context) {
    final canManage = controller.canManageTournament;
    final canStart = controller.canStartKnockoutAction;
    return TournamentStageStateView(
      title: 'الإقصائيات لم تبدأ بعد',
      message: canManage
          ? canStart
                ? 'المتأهلون جاهزون. أنشئ الشجرة لبدء طريق النهائي.'
                : 'أكمل واعتمد نتائج المجموعات أولًا، ثم ابدأ الإقصائيات.'
          : 'ستظهر شجرة الإقصائيات هنا بعد اكتمال التأهل ونشر المواجهات.',
      icon: Icons.account_tree_rounded,
      actionLabel: !canManage
          ? null
          : canStart
          ? 'أنشئ شجرة الإقصائيات'
          : 'افتح لوحة التشغيل',
      actionIcon: canStart
          ? Icons.account_tree_rounded
          : Icons.dashboard_customize_rounded,
      onAction: !canManage
          ? null
          : canStart
          ? controller.startKnockout
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

bool _canOpenScoreFlow(Match match) => switch (match.status) {
  MatchStatus.live ||
  MatchStatus.completed ||
  MatchStatus.pendingReview => true,
  _ => false,
};
