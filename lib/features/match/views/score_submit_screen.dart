import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/share_payload.dart';
import '../../shareables/controllers/match_result_share_controller.dart';
import '../../shareables/controllers/mvp_share_controller.dart';
import '../../shareables/models/match_result_share_data.dart';
import '../../shareables/models/mvp_share_data.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';
import '../../shareables/services/pride_identity_image_resolver.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/match_result_share_card.dart';
import '../../shareables/widgets/mvp_share_card.dart';
import '../../shareables/widgets/post_match_pride_hub_sheet.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../controllers/score_submit_controller.dart';

part 'score_submit_steps.dart';

class ScoreSubmitScreen extends StatelessWidget {
  const ScoreSubmitScreen({super.key});

  static const _resultShareController = MatchResultShareController();
  static const _mvpShareController = MvpShareController();
  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    final ScoreSubmitController controller = Get.find<ScoreSubmitController>();

    return Obx(
      () => PopScope(
        canPop: !controller.isDirty.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit(context, controller);
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('تسجيل النتيجة'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              tooltip: 'إغلاق تسجيل النتيجة',
              onPressed: () => _requestExit(context, controller),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: Obx(() => _buildScoreFlow(controller)),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildStepActions(context, controller),
        ),
      ),
    );
  }

  Widget _buildScoreFlow(ScoreSubmitController controller) {
    if (controller.isLoading.value && controller.match.value == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (controller.errorMessage.value.isNotEmpty &&
        controller.match.value == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Text(
            controller.errorMessage.value,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(height: Get.mediaQuery.padding.top + kToolbarHeight + 6),
        _buildStepHeader(controller.currentStepIndex.value),
        if (controller.restoredDraft.value) _buildRestoredDraftBanner(),
        if (controller.fullRosterErrorMessage.value.isNotEmpty)
          _buildRosterErrorBanner(controller.fullRosterErrorMessage.value),
        if (controller.pendingPrideEventRetry.value) _buildPrideRetryBanner(),
        const SizedBox(height: AppDimensions.sm),
        Expanded(child: _buildCurrentStep(controller)),
      ],
    );
  }

  Widget _buildCurrentStep(ScoreSubmitController controller) {
    return switch (controller.currentStepIndex.value) {
      0 => _ScoreSubmitScoreStep(controller: controller),
      1 => _ScoreSubmitScorersStep(
        attributionOverview: _buildAttributionOverview(controller),
        teamASection: _buildTeamScoringSection(
          title: controller.teamASideName.value,
          sideKey: 'A',
          color: AppColors.primary,
          participants: controller.teamAScoringParticipants,
          controller: controller,
        ),
        teamBSection: _buildTeamScoringSection(
          title: controller.teamBSideName.value,
          sideKey: 'B',
          color: AppColors.accent,
          participants: controller.teamBScoringParticipants,
          controller: controller,
        ),
      ),
      2 => _ScoreSubmitMvpStep(
        selector: controller.allParticipants.isEmpty
            ? null
            : _buildMvpSelector(controller),
      ),
      _ => _ScoreSubmitReviewStep(
        controller: controller,
        attributionOverview: _buildAttributionOverview(controller),
      ),
    };
  }

  Widget _buildStepHeader(int currentStep) {
    const labels = ['النتيجة', 'الهدافون', 'MVP', 'المراجعة'];
    return Semantics(
      label: 'الخطوة ${currentStep + 1} من 4: ${labels[currentStep]}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePadding,
          vertical: AppDimensions.sm,
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index += 1) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= currentStep
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: AppTextStyles.labelSmall.copyWith(
                        color: index == currentStep
                            ? AppColors.primary
                            : AppColors.textSecondaryTinted,
                        fontWeight: index == currentStep
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (index != labels.length - 1)
                const SizedBox(width: AppDimensions.xs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepActions(
    BuildContext context,
    ScoreSubmitController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: Row(
        children: [
          if (!controller.isOnFirstStep) ...[
            Semantics(
              button: true,
              label: 'الخطوة السابقة',
              child: SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  onPressed: controller.goToPreviousStep,
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            child: El7reefButton(
              text: controller.nextStepLabel,
              icon: controller.isOnReviewStep
                  ? Icons.emoji_events_rounded
                  : Icons.arrow_back_rounded,
              isLoading: controller.isLoading.value,
              onPressed: () {
                if (controller.isOnReviewStep) {
                  _handleSubmit(context, controller);
                } else {
                  controller.goToNextStep();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionOverview(ScoreSubmitController controller) {
    final summaries = [
      controller.teamAGoalSummary,
      controller.teamBGoalSummary,
    ];
    final remaining = summaries.fold<int>(
      0,
      (total, summary) => total + summary.unattributedGoals,
    );
    final overAttributed = summaries.any((summary) => summary.isOverAttributed);
    final color = overAttributed
        ? AppColors.error
        : remaining > 0
        ? AppColors.warning
        : AppColors.primary;
    final message = overAttributed
        ? ScoreSubmitController.attributionOverScoreMessage
        : remaining > 0
        ? 'متبقي $remaining ${remaining == 1 ? 'هدف غير منسوب' : 'أهداف غير منسوبة'}.'
        : 'كل الأهداف منسوبة للاعبيها.';
    return Semantics(
      liveRegion: true,
      label: message,
      child: El7reefSurface(
        color: color.withValues(alpha: 0.1),
        borderColor: color.withValues(alpha: 0.32),
        child: Row(
          children: [
            Icon(
              overAttributed
                  ? Icons.error_outline_rounded
                  : remaining > 0
                  ? Icons.pending_actions_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoredDraftBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
        vertical: AppDimensions.xs,
      ),
      child: El7reefSurface(
        color: AppColors.info.withValues(alpha: 0.1),
        borderColor: AppColors.info.withValues(alpha: 0.32),
        child: const Row(
          children: [
            Icon(Icons.restore_rounded, color: AppColors.info),
            SizedBox(width: AppDimensions.sm),
            Expanded(child: Text('رجّعنا المسودة المحفوظة لهذه المباراة.')),
          ],
        ),
      ),
    );
  }

  Future<void> _requestExit(
    BuildContext context,
    ScoreSubmitController controller,
  ) async {
    if (!controller.isDirty.value) {
      Get.back();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تخرج من تسجيل النتيجة؟'),
        content: const Text(
          'المسودة محفوظة ويمكنك الرجوع لها، أو حذفها والخروج الآن.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('كمّل التسجيل'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('احذف واخرج'),
          ),
        ],
      ),
    );
    if (discard != true || !context.mounted) return;
    await controller.discardDraft();
    if (context.mounted) Get.back();
  }

  Future<void> _handleSubmit(
    BuildContext context,
    ScoreSubmitController controller,
  ) async {
    final updatedMatch = await controller.submit();
    if (updatedMatch == null || !context.mounted) return;

    final scoreLine = _scoreLine(updatedMatch, controller);
    void returnToMatch() {
      Get.back();
      Get.back(result: updatedMatch);
    }

    if (FeatureFlags.postMatchPrideHubEnabled) {
      Get.bottomSheet(
        PostMatchPrideHubSheet(
          scoreLine: scoreLine,
          hasMvp: updatedMatch.mvpPlayerId?.trim().isNotEmpty == true,
          mvpName: controller.selectedMvpSelection?.actor.displayName,
          canOpenTopScorers:
              updatedMatch.tournamentId?.trim().isNotEmpty == true,
          onOpenResult: () =>
              _shareResultFromHub(context, updatedMatch, controller),
          onOpenMvp: () => _shareMvpFromHub(context, updatedMatch, controller),
          onOpenTopScorers: () {
            final tournamentId = updatedMatch.tournamentId;
            if (tournamentId == null || tournamentId.isEmpty) return;
            Get.back();
            Get.offNamed(AppRoutes.tournamentDetailById(tournamentId));
          },
          onReturnToMatch: returnToMatch,
        ),
        isScrollControlled: true,
      );
      return;
    }

    Get.bottomSheet(
      _ResultSubmitSuccessSheet(
        scoreLine: scoreLine,
        onShareResult: () {
          Get.back();
          Get.offNamed(AppRoutes.matchResultLineupById(updatedMatch.id));
        },
        onReturnToMatch: returnToMatch,
        hasAttributedGoals: controller.hasAnyAttributedGoals,
        hasUnattributedGoals: controller.hasAnyUnattributedGoals,
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _shareResultFromHub(
    BuildContext context,
    Match match,
    ScoreSubmitController controller,
  ) async {
    final shareData = _resultShareController.buildFromLabels(
      match: match,
      teamAName: controller.teamASideName.value,
      teamBName: controller.teamBSideName.value,
      mvpName: controller.selectedMvpSelection?.actor.displayName,
      scorers: controller.allGoalDrafts
          .map(
            (draft) => MatchResultScorerData(
              displayName: draft.actor.displayName,
              sideKey: draft.sideKey,
              goals: draft.goals,
            ),
          )
          .toList(growable: false),
    );
    final selection = await showPrideShareComposer(
      context: context,
      cardType: ShareCardType.matchResult,
      previewBuilder: (format) => MatchResultShareCard(
        data: shareData,
        exportMode: true,
        format: format,
      ),
    );
    if (selection == null || !context.mounted) return;
    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: MatchResultShareCard(
            data: shareData,
            exportMode: true,
            format: selection.format,
          ),
          exportRequest: PrideExportRequest(
            cardType: ShareCardType.matchResult,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_match_${match.id}',
            includeAudio: selection.includeAudio,
          ),
          text: 'نتيجة المباراة على الحريف',
          payload: shareData.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error('ScoreSubmitScreen.shareResult', error, stackTrace);
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت النتيجة.');
    }
  }

  Future<void> _shareMvpFromHub(
    BuildContext context,
    Match match,
    ScoreSubmitController controller,
  ) async {
    final selection = controller.selectedMvpShareSelection;
    if (selection == null) {
      Get.snackbar('تعذر المشاركة', 'لا يوجد نجم مباراة لمشاركته.');
      return;
    }
    final photoUrl = await _mvpPhotoUrl(selection.actor);
    if (!context.mounted) return;
    final shareData = _mvpShareController.buildFallback(
      match: match,
      mvpPlayerId: selection.actor.id,
      displayName: selection.actor.displayName,
      isGuest: selection.actor.kind == ParticipantRefKind.guestPlayer,
      sideKey: selection.sideKey,
      teamALabel: controller.teamASideName.value,
      teamBLabel: controller.teamBSideName.value,
      actor: selection.actor,
      photoUrl: photoUrl,
    );
    if (shareData == null) {
      Get.snackbar(
        'تعذر المشاركة',
        'تظهر بطاقة نجم المباراة بعد اعتماد نتيجة البطولة رسميًا.',
      );
      return;
    }
    final payload = await _claimableMvpPayload(shareData);
    if (!context.mounted) return;
    final claimableShareData = shareData.copyWith(sharePayload: payload);
    final shareSelection = await showPrideShareComposer(
      context: context,
      cardType: ShareCardType.mvp,
      previewBuilder: (format) => MvpShareCard(
        data: claimableShareData,
        exportMode: true,
        format: format,
      ),
    );
    if (shareSelection == null || !context.mounted) return;
    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: MvpShareCard(
            data: claimableShareData,
            exportMode: true,
            format: shareSelection.format,
          ),
          exportRequest: PrideExportRequest(
            cardType: ShareCardType.mvp,
            format: shareSelection.format,
            mediaType: shareSelection.mediaType,
            fileName: 'el7reef_mvp_${match.id}',
            includeAudio: shareSelection.includeAudio,
          ),
          text: 'نجم المباراة على الحريف',
          payload: claimableShareData.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error('ScoreSubmitScreen.shareMvp', error, stackTrace);
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت نجم المباراة.');
    }
  }

  Future<String?> _mvpPhotoUrl(ParticipantRef actor) async {
    try {
      return await Get.find<PrideIdentityImageResolver>().imageUrlFor(actor);
    } on TimeoutException {
      return null;
    }
  }

  Future<SharePayload?> _claimableMvpPayload(MvpShareData shareData) async {
    final payload = shareData.sharePayload;
    if (payload == null || !FeatureFlags.prideGrowthLinksEnabled) {
      return payload;
    }
    final actorId = Get.find<AuthService>().currentUserId;
    try {
      return await Get.find<GuestMvpClaimLinkService>()
          .attachClaimUrl(payload: payload, actorId: actorId)
          .timeout(sharePreparationTimeout);
    } on TimeoutException {
      return payload;
    }
  }

  String? _scoreLine(Match match, ScoreSubmitController controller) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    if (scoreA == null || scoreB == null) return null;
    return '${controller.teamASideName.value} $scoreA - $scoreB ${controller.teamBSideName.value}';
  }

  Widget _buildTeamScoringSection({
    required String title,
    required String sideKey,
    required Color color,
    required List<ParticipantRef> participants,
    required ScoreSubmitController controller,
  }) {
    return El7reefSurface(
      borderColor: color.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              El7reefBadge(
                label: 'هدافو الطرف',
                color: color,
                icon: Icons.sports_soccer_rounded,
              ),
              Text(
                '${participants.length} لاعب',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            title,
            style: AppTextStyles.headlineMedium.copyWith(color: color),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'كل هدف منسوب هنا يدخل الهدافين ويظهر في كروت المشاركة.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          if (participants.isEmpty)
            _buildNoScoringParticipantsNote(controller, sideKey: sideKey)
          else
            ...participants.map(
              (participant) =>
                  _buildParticipantScoringRow(participant, controller),
            ),
        ],
      ),
    );
  }

  Widget _buildRosterErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: El7reefSurface(
        color: AppColors.warningSurface,
        borderColor: AppColors.warning.withValues(alpha: 0.28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                '$message يمكنك حفظ النتيجة فقط، لكن اختيارات الهدافين وMVP قد تكون غير مكتملة.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrideRetryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: El7reefSurface(
        borderColor: AppColors.secondary.withValues(alpha: 0.36),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppColors.secondary),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                'تم حفظ النتيجة، لكن أحداث الفخر ما زالت تحتاج إعادة محاولة قبل المشاركة.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoScoringParticipantsNote(
    ScoreSubmitController controller, {
    required String sideKey,
  }) {
    final route = controller.emptyScoringParticipantsRouteForSide(sideKey);

    return El7reefSurface(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      color: AppColors.surfaceSunken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لا يوجد لاعبون متاحون لهذا الطرف. أضف لاعبين للفريق أو لقائمة المباراة قبل تسجيل الأهداف.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (route != null) ...[
            const SizedBox(height: AppDimensions.md),
            El7reefButton(
              text: controller.emptyScoringParticipantsActionLabelForSide(
                sideKey,
              ),
              icon: Icons.group_add_rounded,
              isOutlined: true,
              onPressed: () => Get.toNamed(route),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantScoringRow(
    ParticipantRef participant,
    ScoreSubmitController controller,
  ) {
    final isRegisteredPlayer =
        participant.kind == ParticipantRefKind.player &&
        controller.playerStats.containsKey(participant.id);

    return El7reefSurface(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      participant.displayName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimaryTinted,
                      ),
                    ),
                    if (participant.kind != ParticipantRefKind.player)
                      _buildParticipantBadge(participant),
                  ],
                ),
              ),
              if (isRegisteredPlayer)
                _buildCardIndicators(participant.id, controller),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.lg,
            runSpacing: AppDimensions.sm,
            children: [
              _buildParticipantGoalCounter(participant, controller),
              if (isRegisteredPlayer) ...[
                _buildStatCounter(
                  'أسيست',
                  'assists',
                  participant.id,
                  controller,
                ),
                _buildStatCounter('تصدي', 'saves', participant.id, controller),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildParticipantBadge(ParticipantRef participant) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        _participantKindLabel(participant),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }

  String _participantKindLabel(ParticipantRef participant) {
    switch (participant.kind) {
      case ParticipantRefKind.player:
        return 'لاعب';
      case ParticipantRefKind.guestPlayer:
        return 'ضيف';
      case ParticipantRefKind.matchSidePlayer:
        return 'قائمة المباراة';
    }
  }

  Widget _buildCardIndicators(
    String playerId,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final st = controller.playerStats[playerId]!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            selected: st['yellowCard'] == true,
            label: 'بطاقة صفراء',
            child: InkWell(
              onTap: () => controller.toggleCard(playerId, 'yellowCard'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: SizedBox(
                width: AppDimensions.buttonHeightMd,
                height: AppDimensions.buttonHeightMd,
                child: Center(
                  child: Container(
                    width: 16,
                    height: 24,
                    decoration: BoxDecoration(
                      color: st['yellowCard'] == true
                          ? Colors.yellow
                          : AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            selected: st['redCard'] == true,
            label: 'بطاقة حمراء',
            child: InkWell(
              onTap: () => controller.toggleCard(playerId, 'redCard'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: SizedBox(
                width: AppDimensions.buttonHeightMd,
                height: AppDimensions.buttonHeightMd,
                child: Center(
                  child: Container(
                    width: 16,
                    height: 24,
                    decoration: BoxDecoration(
                      color: st['redCard'] == true
                          ? Colors.red
                          : AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildParticipantGoalCounter(
    ParticipantRef participant,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final val = controller.goalsForParticipant(participant);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أهداف',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(
                Icons.remove,
                () => controller.decrementParticipantGoals(participant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$val', style: AppTextStyles.titleLarge),
              ),
              _btn(
                Icons.add,
                () => controller.incrementParticipantGoals(participant),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildStatCounter(
    String label,
    String key,
    String playerId,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final val = controller.playerStats[playerId]?[key] ?? 0;
      return Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(Icons.remove, () => controller.decrementStat(playerId, key)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$val', style: AppTextStyles.titleLarge),
              ),
              _btn(Icons.add, () => controller.incrementStat(playerId, key)),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    final isIncrement = icon == Icons.add;
    return Semantics(
      button: true,
      label: isIncrement ? 'زيادة القيمة' : 'تقليل القيمة',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: Container(
          width: AppDimensions.buttonHeightMd,
          height: AppDimensions.buttonHeightMd,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceBorder.withValues(alpha: 0.34),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceBorderStrong),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimaryTinted),
        ),
      ),
    );
  }

  Widget _buildMvpSelector(ScoreSubmitController controller) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: controller.allParticipants.map((participant) {
        final participantKey = controller.participantKey(participant);
        final isSelected = controller.selectedMvpKey.value == participantKey;
        return FilterChip(
          avatar: Icon(
            isSelected ? Icons.star_rounded : Icons.person_rounded,
            size: 18,
            color: isSelected ? AppColors.secondary : AppColors.textMuted,
          ),
          label: Text(_mvpChoiceLabel(participant)),
          selected: isSelected,
          onSelected: (_) =>
              controller.selectMvp(isSelected ? '' : participantKey),
          selectedColor: AppColors.secondary.withValues(alpha: 0.18),
          backgroundColor: AppColors.surfaceSunken,
          side: BorderSide(
            color: isSelected
                ? AppColors.secondary.withValues(alpha: 0.55)
                : AppColors.surfaceBorderStrong,
          ),
          labelStyle: AppTextStyles.labelMedium.copyWith(
            color: isSelected
                ? AppColors.secondary
                : AppColors.textPrimaryTinted,
            fontWeight: FontWeight.w800,
          ),
        );
      }).toList(),
    );
  }

  String _mvpChoiceLabel(ParticipantRef participant) {
    if (participant.kind == ParticipantRefKind.player) {
      return participant.displayName;
    }
    return '${participant.displayName} (${_participantKindLabel(participant)})';
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        const SizedBox(width: AppDimensions.md),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _ResultSubmitSuccessSheet extends StatelessWidget {
  final String? scoreLine;
  final VoidCallback onShareResult;
  final VoidCallback onReturnToMatch;
  final bool hasAttributedGoals;
  final bool hasUnattributedGoals;

  const _ResultSubmitSuccessSheet({
    required this.scoreLine,
    required this.onShareResult,
    required this.onReturnToMatch,
    required this.hasAttributedGoals,
    required this.hasUnattributedGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const El7reefBadge(
                label: 'تم الاعتماد',
                color: AppColors.primary,
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: AppDimensions.md),
              Text('النتيجة اتسجلت', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.sm),
              Text(
                _successMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (scoreLine != null) ...[
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    scoreLine!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textPrimaryTinted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              Text(
                'الخطوة الجاية: شارك النتيجة وخلي اللاعبين يشوفوا لحظة الفخر.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              FilledButton.icon(
                onPressed: onShareResult,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('شارك كارت النتيجة'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextButton(
                onPressed: onReturnToMatch,
                child: const Text('العودة للمباراة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _successMessage {
    if (!hasAttributedGoals) {
      return 'تم حفظ النتيجة بدون أهداف منسوبة؛ لن تُضاف أهداف للهدافين من هذه المباراة.';
    }
    if (hasUnattributedGoals) {
      return 'تم حفظ النتيجة وتسجيل الأهداف المنسوبة. الأهداف غير المنسوبة لن تظهر في الهدافين.';
    }
    return 'تم حفظ النتيجة وتسجيل الأهداف المنسوبة للمشاركة مع اللاعبين.';
  }
}
