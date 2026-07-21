import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/share_payload.dart';
import '../../shareables/controllers/lineup_share_controller.dart';
import '../../shareables/controllers/match_result_share_controller.dart';
import '../../shareables/controllers/mvp_share_controller.dart';
import '../../shareables/controllers/player_moment_share_controller.dart';
import '../../shareables/models/lineup_share_data.dart';
import '../../shareables/models/match_result_share_data.dart';
import '../../shareables/models/mvp_share_data.dart';
import '../../shareables/models/player_moment_share_data.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';
import '../../shareables/widgets/lineup_share_card.dart';
import '../../shareables/widgets/match_result_share_card.dart';
import '../../shareables/widgets/mvp_share_card.dart';
import '../../shareables/widgets/player_moment_share_card.dart';
import '../../shareables/widgets/pride_card_format_picker.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../controllers/match_result_lineup_controller.dart';
import '../widgets/bench_bar.dart';
import '../widgets/professional_match_header.dart';
import '../widgets/professional_pitch_card.dart';

class MatchResultLineupScreen extends GetView<MatchResultLineupController> {
  const MatchResultLineupScreen({super.key});

  static const _shareBuilder = MatchResultShareController();
  static const _mvpShareBuilder = MvpShareController();
  static const _playerMomentShareBuilder = PlayerMomentShareController();
  static const _captureService = ShareCardCaptureService();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النتيجة والتشكيلات'),
          actions: [
            Obx(
              () => IconButton(
                onPressed: _hasShareableScore
                    ? () => _shareResult(context)
                    : null,
                icon: const Icon(Icons.share_rounded),
                tooltip: 'مشاركة النتيجة',
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (controller.errorMessage.value.isNotEmpty) {
              return _ResultErrorState(
                message: controller.errorMessage.value,
                onRetry: controller.loadResultLineup,
              );
            }
            final match = controller.match.value;
            final home = controller.homeSide;
            final away = controller.awaySide;
            final goalScorers = match == null
                ? const <GoalScorerShareData>[]
                : _goalScorerCards(match);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.loadResultLineup,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                children: [
                  ProfessionalMatchHeader(
                    homeName: home.label,
                    awayName: away.label,
                    homeLogoUrl: home.logoUrl,
                    awayLogoUrl: away.logoUrl,
                    homeScore: match?.scoreTeamA,
                    awayScore: match?.scoreTeamB,
                    status: match?.status,
                    startedAt: match?.startedAt,
                    tournamentName: null,
                    location: match?.location,
                    onShare: _hasShareableScore
                        ? () => _shareResult(context)
                        : null,
                  ),
                  if (_hasShareableScore ||
                      _hasShareableMvp ||
                      goalScorers.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.md),
                    _PrideSharePanel(
                      canShareScore: _hasShareableScore,
                      canShareMvp: _hasShareableMvp,
                      canShareGoalScorer: goalScorers.isNotEmpty,
                      canOpenMvpProfile: _mvpProfileTarget != null,
                      onShareScore: () => _shareResult(context),
                      onShareMvp: () => _shareMvp(context),
                      onShareGoalScorer: () =>
                          _shareGoalScorer(context, goalScorers),
                      onOpenMvpProfile: _openMvpProfile,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.lg),
                  _SnapshotWarning(
                    hasHome: home.snapshot != null,
                    hasAway: away.snapshot != null,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 720;
                      final homeCard = _ResultTeamLineupCard(
                        controller: controller,
                        title: home.label,
                        side: home,
                        onShare: () =>
                            _shareLineup(context, home, AppColors.primary),
                      );
                      final awayCard = _ResultTeamLineupCard(
                        controller: controller,
                        title: away.label,
                        side: away,
                        onShare: () =>
                            _shareLineup(context, away, AppColors.error),
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            homeCard,
                            const SizedBox(height: AppDimensions.lg),
                            awayCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: homeCard),
                          const SizedBox(width: AppDimensions.lg),
                          Expanded(child: awayCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.xl),
                  Center(
                    child: Text(
                      'EL7REEF • الحريف',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  bool get _hasShareableScore {
    final match = controller.match.value;
    return match?.isOfficialTournamentResult ?? false;
  }

  bool get _hasShareableMvp =>
      (controller.match.value?.isOfficialTournamentResult ?? false) &&
      controller.hasShareableMvp;

  MvpPublicProfileTarget? get _mvpProfileTarget => controller.mvpProfileTarget;

  void _openMvpProfile() {
    final target = controller.mvpProfileTarget;
    if (target == null) return;
    Get.toNamed(
      AppRoutes.playerProfileByKindAndId(kind: target.kind.name, id: target.id),
    );
  }

  Future<void> _shareResult(BuildContext context) async {
    final match = controller.match.value;
    if (match == null || !match.isOfficialTournamentResult) {
      Get.snackbar('تعذر المشاركة', 'تظهر بطاقة النتيجة بعد اعتمادها رسميًا.');
      return;
    }

    final shareData = _buildShareData(match);
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
          onBeforeCapture: () => _precacheShareLogos(context, shareData),
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'MatchResultLineupScreen._shareResult',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت النتيجة.');
    }
  }

  Future<void> _shareMvp(BuildContext context) async {
    final match = controller.match.value;
    if (match == null || !match.isOfficialTournamentResult) {
      Get.snackbar(
        'تعذر المشاركة',
        'تظهر بطاقة نجم المباراة بعد اعتماد النتيجة رسميًا.',
      );
      return;
    }

    final shareData = _buildMvpShareData(match);
    if (shareData == null) {
      Get.snackbar('تعذر المشاركة', 'لا يوجد نجم مباراة لمشاركته بعد.');
      return;
    }

    try {
      final photoUrl = await _mvpPhotoUrl();
      if (!context.mounted) return;
      final enrichedShareData = _buildMvpShareData(match, photoUrl: photoUrl);
      if (enrichedShareData == null) return;
      final payload = await _claimablePridePayload(
        enrichedShareData.sharePayload,
      );
      if (!context.mounted) return;
      final claimableShareData = enrichedShareData.copyWith(
        sharePayload: payload,
      );
      final selection = await showPrideShareComposer(
        context: context,
        cardType: ShareCardType.mvp,
        previewBuilder: (format) => MvpShareCard(
          data: claimableShareData,
          exportMode: true,
          format: format,
        ),
      );
      if (selection == null || !context.mounted) return;
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: MvpShareCard(
            data: claimableShareData,
            exportMode: true,
            format: selection.format,
          ),
          exportRequest: PrideExportRequest(
            cardType: ShareCardType.mvp,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_mvp_${match.id}',
            includeAudio: selection.includeAudio,
          ),
          text: 'نجم المباراة على الحريف',
          payload: claimableShareData.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error('MatchResultLineupScreen._shareMvp', error, stackTrace);
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت نجم المباراة.');
    }
  }

  Future<void> _shareGoalScorer(
    BuildContext context,
    List<GoalScorerShareData> goalScorers,
  ) async {
    if (goalScorers.isEmpty) {
      Get.snackbar(
        'كارت الهداف غير متاح',
        'يظهر الكارت بعد اعتماد النتيجة وتسجيل الهدافين.',
      );
      return;
    }

    final selected = goalScorers.length == 1
        ? goalScorers.single
        : await showModalBottomSheet<GoalScorerShareData>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _GoalScorerPickerSheet(scorers: goalScorers),
          );
    if (selected == null || !context.mounted) return;

    final photoUrl = await _participantPhotoUrl(selected.actor);
    if (!context.mounted) return;
    var shareData = selected.copyWith(photoUrl: photoUrl);
    final payload = await _claimablePridePayload(shareData.sharePayload);
    if (!context.mounted) return;
    shareData = shareData.copyWith(sharePayload: payload);

    final selection = await showPrideShareComposer(
      context: context,
      cardType: shareData.sharePayload.cardType,
      previewBuilder: (format) => PlayerMomentShareCard(
        data: shareData,
        format: format,
        includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
      ),
    );
    if (selection == null || !context.mounted) return;

    try {
      final outcome = await _captureService.exportAndShareWidget(
        context: context,
        shareRequest: PrideWidgetShareRequest(
          widget: PlayerMomentShareCard(
            data: shareData,
            exportMode: true,
            format: selection.format,
            includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
          ),
          exportRequest: PrideExportRequest(
            cardType: shareData.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName:
                'el7reef_goal_scorer_${shareData.sharePayload.matchId}_${shareData.actor.id}',
            includeAudio: selection.includeAudio,
          ),
          text: shareData.isHatTrick
              ? 'هاتريك ${shareData.playerName} على الحريف'
              : '${shareData.playerName} هز الشباك على الحريف',
          payload: shareData.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'MatchResultLineupScreen._shareGoalScorer',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز كارت هداف المباراة.');
    }
  }

  Future<void> _shareLineup(
    BuildContext context,
    ResultLineupSide side,
    Color accentColor,
  ) async {
    final snapshot = side.snapshot;
    if (snapshot == null) {
      Get.snackbar('تعذر المشاركة', 'احفظ التشكيلة أولًا قبل مشاركتها.');
      return;
    }
    final shareData = Get.find<LineupShareController>().buildFromSnapshot(
      snapshot: snapshot,
      teamName: side.label,
      logoUrl: side.logoUrl,
      lineupOwnerType: _ownerType(snapshot),
      lineupTypeLabel: _lineupTypeLabel(snapshot),
      matchLabel: _lineupMatchLabel(),
      accentColor: accentColor,
    );

    final format = await showPrideCardFormatPicker(context);
    if (format == null || !context.mounted) return;
    try {
      await _captureService.captureAndShareWidget(
        context: context,
        widget: LineupShareCard(
          data: shareData,
          exportMode: true,
          format: format,
        ),
        fileName: 'el7reef_lineup_${shareData.matchId}_${shareData.ownerId}',
        text: 'تشكيلة ${shareData.teamName} على الحريف',
        payload: shareData.sharePayload,
        onBeforeCapture: () => _precacheLineupLogo(context, shareData),
      );
    } catch (error) {
      Get.snackbar('تعذر المشاركة', _readableShareError(error));
    }
  }

  MatchResultShareData _buildShareData(Match match) {
    final home = controller.homeSide;
    final away = controller.awaySide;
    return _shareBuilder.build(
      match: match,
      teamA: home,
      teamB: away,
      teamAFormation: controller.formationForSnapshot(home.snapshot),
      teamBFormation: controller.formationForSnapshot(away.snapshot),
      tournamentName: controller.tournamentName.value,
      mvpName: _mvpNameForResultShare(match),
      scorers: _goalScorersForResultShare(),
    );
  }

  List<GoalScorerShareData> _goalScorerCards(Match match) {
    if (!FeatureFlags.prideShareCatalogV2Enabled ||
        !match.isOfficialTournamentResult) {
      return const <GoalScorerShareData>[];
    }

    final actorsByIdentity = <String, ParticipantRef>{};
    for (final event in controller.goalEvents) {
      if (!event.isActive || !event.isGoal) continue;
      final actor = event.actor;
      if (actor.kind == ParticipantRefKind.matchSidePlayer) continue;
      actorsByIdentity['${actor.kind.name}:${actor.id}'] = actor;
    }

    final home = controller.homeSide;
    final away = controller.awaySide;
    final cards = actorsByIdentity.values
        .map(
          (actor) => _playerMomentShareBuilder.buildGoalScorerIfEligible(
            match: match,
            events: controller.goalEvents,
            actor: actor,
            tournamentName: controller.tournamentName.value,
            teamAName: home.label,
            teamBName: away.label,
          ),
        )
        .whereType<GoalScorerShareData>()
        .toList();
    cards.sort((left, right) {
      final goalComparison = right.goalsInMatch.compareTo(left.goalsInMatch);
      if (goalComparison != 0) return goalComparison;
      return left.playerName.compareTo(right.playerName);
    });
    return cards;
  }

  List<MatchResultScorerData> _goalScorersForResultShare() {
    final grouped = <String, MatchResultScorerData>{};
    for (final event in controller.goalEvents) {
      final actor = event.actor;
      final key = '${actor.kind.name}:${actor.id}';
      final current = grouped[key];
      grouped[key] = MatchResultScorerData(
        displayName: actor.displayName,
        sideKey: event.sideKey,
        goals: (current?.goals ?? 0) + 1,
      );
    }
    final scorers = grouped.values.toList();
    scorers.sort((left, right) {
      final goalCompare = right.goals.compareTo(left.goals);
      if (goalCompare != 0) return goalCompare;
      return left.displayName.compareTo(right.displayName);
    });
    return scorers;
  }

  String? _mvpNameForResultShare(Match match) {
    final eventName = controller.mvpEvent.value?.actor.displayName.trim();
    if (eventName != null && eventName.isNotEmpty) return eventName;
    final mvpPlayerId = match.mvpPlayerId?.trim();
    if (mvpPlayerId == null || mvpPlayerId.isEmpty) return null;
    return controller.displayNameForParticipantId(mvpPlayerId);
  }

  MvpShareData? _buildMvpShareData(Match match, {String? photoUrl}) {
    final home = controller.homeSide;
    final away = controller.awaySide;
    final event = controller.mvpEvent.value;
    if (event != null) {
      return _mvpShareBuilder.buildFromEvent(
        match: match,
        event: event,
        tournamentName: controller.tournamentName.value,
        teamALabel: home.label,
        teamBLabel: away.label,
        photoUrl: photoUrl,
      );
    }

    final mvpPlayerId = match.mvpPlayerId?.trim();
    if (mvpPlayerId == null || mvpPlayerId.isEmpty) return null;
    return _mvpShareBuilder.buildFallback(
      match: match,
      mvpPlayerId: mvpPlayerId,
      displayName: controller.displayNameForParticipantId(mvpPlayerId),
      isGuest: controller.isGuestParticipantId(mvpPlayerId),
      sideKey: controller.sideKeyForParticipantId(mvpPlayerId),
      tournamentName: controller.tournamentName.value,
      teamALabel: home.label,
      teamBLabel: away.label,
      actor: _mvpActorForPayload(mvpPlayerId),
      photoUrl: photoUrl,
    );
  }

  Future<String?> _mvpPhotoUrl() async {
    try {
      return await controller.mvpPhotoUrl();
    } catch (error, stackTrace) {
      AppLogger.error(
        'MatchResultLineupScreen._mvpPhotoUrl',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<String?> _participantPhotoUrl(ParticipantRef actor) async {
    try {
      return await controller
          .participantPhotoUrl(actor)
          .timeout(sharePreparationTimeout);
    } on TimeoutException {
      return null;
    } catch (error) {
      AppLogger.warning('MatchResultLineupScreen._participantPhotoUrl', error);
      return null;
    }
  }

  Future<SharePayload?> _claimablePridePayload(SharePayload? payload) async {
    if (payload == null || !FeatureFlags.prideGrowthLinksEnabled) {
      return payload;
    }
    if (!Get.isRegistered<GuestMvpClaimLinkService>()) return payload;
    final actorId = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>().currentUserId
        : null;
    try {
      return await Get.find<GuestMvpClaimLinkService>()
          .attachClaimUrl(payload: payload, actorId: actorId)
          .timeout(sharePreparationTimeout);
    } on TimeoutException {
      return payload;
    } catch (error) {
      AppLogger.warning(
        'MatchResultLineupScreen._claimablePridePayload',
        error,
      );
      return payload;
    }
  }

  ParticipantRef? _mvpActorForPayload(String mvpPlayerId) {
    final target = controller.mvpProfileTarget;
    if (target == null) return null;
    final displayName = controller
        .displayNameForParticipantId(mvpPlayerId)
        ?.trim();
    if (displayName == null || displayName.isEmpty) return null;
    return ParticipantRef(
      kind: target.kind,
      id: target.id,
      displayName: displayName,
    );
  }

  Future<void> _precacheShareLogos(
    BuildContext context,
    MatchResultShareData shareData,
  ) async {
    for (final logoUrl in [shareData.teamALogoUrl, shareData.teamBLogoUrl]) {
      final url = logoUrl?.trim();
      if (url == null || url.isEmpty) continue;
      if (!context.mounted) return;
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (error) {
        AppLogger.warning('MatchResultLineupScreen._precacheShareLogos', error);
        // Fallback initials are rendered if the logo cannot be loaded in time.
      }
    }
  }

  Future<void> _precacheLineupLogo(
    BuildContext context,
    LineupShareData shareData,
  ) async {
    final url = shareData.logoUrl?.trim();
    if (url == null || url.isEmpty) return;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (error) {
      AppLogger.warning('MatchResultLineupScreen._precacheLineupLogo', error);
      // Initials fallback is used if the logo cannot be loaded in time.
    }
  }

  LineupShareOwnerType _ownerType(MatchLineupSnapshot snapshot) {
    if (snapshot.teamId != null) return LineupShareOwnerType.officialTeam;
    if (snapshot.matchSideId != null) return LineupShareOwnerType.temporarySide;
    return LineupShareOwnerType.guestTeam;
  }

  String _lineupTypeLabel(MatchLineupSnapshot snapshot) {
    if (snapshot.teamId != null) return 'فريق رسمي';
    if (snapshot.matchSideId != null) return 'فريق مؤقت';
    return 'فريق ضيف';
  }

  String? _lineupMatchLabel() {
    final currentMatch = controller.match.value;
    if (currentMatch == null) return null;
    return currentMatch.tournamentId == null ? 'مباراة ودية' : null;
  }

  String _readableShareError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return 'تعذر تجهيز بطاقة المشاركة.';
  }
}

class _PrideSharePanel extends StatelessWidget {
  final bool canShareScore;
  final bool canShareMvp;
  final bool canShareGoalScorer;
  final bool canOpenMvpProfile;
  final VoidCallback onShareScore;
  final VoidCallback onShareMvp;
  final VoidCallback onShareGoalScorer;
  final VoidCallback onOpenMvpProfile;

  const _PrideSharePanel({
    required this.canShareScore,
    required this.canShareMvp,
    required this.canShareGoalScorer,
    required this.canOpenMvpProfile,
    required this.onShareScore,
    required this.onShareMvp,
    required this.onShareGoalScorer,
    required this.onOpenMvpProfile,
  });

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.secondary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const El7reefBadge(
            label: 'كروت الفخر جاهزة',
            color: AppColors.secondary,
            icon: Icons.ios_share_rounded,
          ),
          const SizedBox(height: AppDimensions.md),
          Text('شارك لحظة المباراة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'النتيجة والـ MVP والتشكيلات هي الوقود اللي بيخلي اللاعبين يرجعوا يطالبوا ببروفايلاتهم.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          if (canShareScore)
            FilledButton.icon(
              onPressed: onShareScore,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('شارك كارت النتيجة'),
            ),
          if (canShareMvp) ...[
            const SizedBox(height: AppDimensions.sm),
            OutlinedButton.icon(
              onPressed: onShareMvp,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('شارك كارت نجم المباراة'),
            ),
          ],
          if (canShareGoalScorer) ...[
            const SizedBox(height: AppDimensions.sm),
            OutlinedButton.icon(
              onPressed: onShareGoalScorer,
              icon: const Icon(Icons.sports_soccer_rounded),
              label: const Text('شارك هداف المباراة'),
            ),
          ],
          if (canOpenMvpProfile) ...[
            const SizedBox(height: AppDimensions.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onOpenMvpProfile,
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('افتح بروفايل النجم'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalScorerPickerSheet extends StatelessWidget {
  final List<GoalScorerShareData> scorers;

  const _GoalScorerPickerSheet({required this.scorers});

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
            Text('اختار الهداف', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'كل لاعب هنا له أهداف مسجلة في النتيجة المعتمدة.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: scorers.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppColors.surfaceBorder),
                itemBuilder: (context, index) {
                  final scorer = scorers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 56,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.16,
                      ),
                      foregroundColor: AppColors.primaryLight,
                      child: Text(
                        '${scorer.goalsInMatch}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      scorer.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_goalCountLabel(scorer.goalsInMatch)}${scorer.isHatTrick ? '، هاتريك' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.of(context).pop(scorer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _goalCountLabel(int count) {
    if (count == 1) return 'هدف واحد';
    if (count == 2) return 'هدفان';
    return '$count أهداف';
  }
}

class _ResultTeamLineupCard extends StatelessWidget {
  final MatchResultLineupController controller;
  final String title;
  final ResultLineupSide side;
  final VoidCallback onShare;

  const _ResultTeamLineupCard({
    required this.controller,
    required this.title,
    required this.side,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = side.snapshot;
    final playerCount = controller.playerCountForSnapshot(snapshot);
    final formation = controller.formationForSnapshot(snapshot);
    final playersByKey = controller.playersByKeyForSnapshot(snapshot);
    final slots = controller.slotsForSnapshot(snapshot);
    final bench = controller.benchForSnapshot(snapshot);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      snapshot == null
                          ? 'لم يتم حفظ snapshot للتشكيلة'
                          : '$formation • ${snapshot.starters.length}/$playerCount أساسي',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (snapshot != null)
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'مشاركة التشكيلة',
                ),
              _FormationPill(label: formation),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ProfessionalPitchCard(
            slots: slots,
            playersByKey: playersByKey,
            formationCode: formation,
            playerCount: playerCount,
            teamName: title,
            presentationMode: true,
          ),
          if (bench.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            BenchBar(players: bench, compact: true),
          ],
        ],
      ),
    );
  }
}

class _FormationPill extends StatelessWidget {
  final String label;

  const _FormationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SnapshotWarning extends StatelessWidget {
  final bool hasHome;
  final bool hasAway;

  const _SnapshotWarning({required this.hasHome, required this.hasAway});

  @override
  Widget build(BuildContext context) {
    if (hasHome && hasAway) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              'هذه الشاشة تعرض snapshots المباراة المحفوظة فقط، ولا تستخدم التشكيلة الحالية للفريق.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ResultErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
