import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/permissions/tournament_viewer_context.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../core/widgets/section_state_card.dart';
import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/tournament.dart';
import '../../shareables/controllers/top_scorers_share_controller.dart';
import '../../shareables/controllers/tournament_announcement_share_controller.dart';
import '../../shareables/models/pride_export.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/pride_share_composer_sheet.dart';
import '../../shareables/widgets/tournament_announcement_share_card.dart';
import '../../shareables/widgets/top_scorers_share_card.dart';
import '../../shareables/widgets/pride_card_format_picker.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/tournament_detail_controller.dart';
import '../navigation/tournament_detail_routes.dart';
import '../widgets/tournament_visual_language.dart';

/// شاشة تفاصيل البطولة المطورة بالكامل
class TournamentDetailScreen extends GetView<TournamentDetailController> {
  static const _shareBuilder = TopScorersShareController();
  static const _announcementShareController =
      TournamentAnnouncementShareController();
  static const _captureService = ShareCardCaptureService();

  const TournamentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          final tournament = tournamentDetailInfo;

          if (controller.isLoading.value && tournament == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (tournament == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: SectionStateCard.error(
                  title: 'تعذر فتح الدورة',
                  message: controller.errorMessage.value.isEmpty
                      ? 'تعذر تحميل تفاصيل الدورة'
                      : controller.errorMessage.value,
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'إعادة المحاولة',
                  onAction: controller.loadTournament,
                ),
              ),
            );
          }

          final viewerContext = TournamentViewerContext.fromTournament(
            tournament: tournament,
            userId: authService.currentUserId,
            isFollower: controller.isFollowing.value,
          );
          final isOrganizer = viewerContext.canViewAdminDashboard;
          final inviteShareData = FeatureFlags.prideShareCatalogV2Enabled
              ? _announcementShareController.buildInviteIfEligible(
                  tournament: tournament,
                )
              : null;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _TournamentHeroAppBar(tournament: tournament),

              // ── جسم الصفحة المتكامل بصرياً لتجنب مشاكل الاختبارات ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TournamentIdentityPanel(tournament: tournament),
                      const SizedBox(height: AppDimensions.lg),

                      _TournamentStoryStrip(
                        tournament: tournament,
                        topScorer: controller.topScorers.isEmpty
                            ? null
                            : controller.topScorers.first,
                        hasOfficialResultsWithoutScorerDetails:
                            controller.officialTournamentResultCount.value >
                                0 &&
                            controller.topScorers.isEmpty,
                        championName: controller.winnerDisplayName.value,
                      ).animate().fadeIn(
                        duration: const Duration(milliseconds: 380),
                      ),
                      const SizedBox(height: AppDimensions.md),

                      _TournamentNavigationDeck(
                        tournament: tournament,
                        canShareTopScorers: controller.topScorers.isNotEmpty,
                        onShareTopScorers: () =>
                            _shareTopScorers(context, tournament),
                        onShareInvite: inviteShareData == null
                            ? null
                            : () => _shareTournamentInvite(context, tournament),
                      ),
                      const SizedBox(height: AppDimensions.md),

                      if (viewerContext.canFollowTournament) ...[
                        _FollowTournamentButton(
                          isFollowing: controller.isFollowing.value,
                          isLoading: controller.isFollowActionLoading.value,
                          onPressed: controller.toggleFollow,
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 430),
                        ),
                        const SizedBox(height: AppDimensions.md),
                      ],

                      // منصة التتويج وهدافو البطولة (لوحة الفخر)
                      _TopScorersSection(
                        isLoading: controller.isLoadingTopScorers.value,
                        errorMessage: controller.topScorersErrorMessage.value,
                        scorers: controller.topScorers,
                        officialMatchCount:
                            controller.officialTournamentResultCount.value,
                        onRetry: controller.loadTopScorers,
                        onShare: () => _shareTopScorers(context, tournament),
                      ).animate().fadeIn(
                        duration: const Duration(milliseconds: 450),
                      ),
                      const SizedBox(height: AppDimensions.md),

                      // زر تسجيل الفريق لغير المنظم
                      if (!isOrganizer &&
                          tournament.status ==
                              TournamentStatus.registration) ...[
                        _RegisterTeamButton(
                          tournament: tournament,
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 450),
                        ),
                        const SizedBox(height: AppDimensions.md),
                      ],

                      // إجراءات المنظم الخاصة
                      if (isOrganizer) ...[
                        _OrganizerDashboardCta(
                          tournament: tournament,
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 500),
                        ),
                        const SizedBox(height: AppDimensions.md),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Tournament? get tournamentDetailInfo => controller.tournament.value;

  Future<void> _shareTopScorers(
    BuildContext context,
    Tournament tournament,
  ) async {
    final scorers = controller.topScorers.toList(growable: false);
    if (scorers.isEmpty) {
      Get.snackbar('تعذر المشاركة', 'لا يوجد هدافون لمشاركتهم بعد.');
      return;
    }

    final format = await showPrideCardFormatPicker(context);
    if (format == null || !context.mounted) return;
    final photoUrls = await controller.topScorerPhotoUrls();
    if (!context.mounted) return;
    final shareData = _shareBuilder.build(
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      scorers: scorers,
      limit: 5,
      photoUrls: photoUrls,
    );
    if (shareData == null) {
      Get.snackbar('تعذر المشاركة', 'لا توجد بيانات هدافين مؤكدة للمشاركة.');
      return;
    }
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(
              key: boundaryKey,
              child: TopScorersShareCard(
                data: shareData,
                exportMode: true,
                format: format,
              ),
            ),
          ),
        ),
      ),
    );

    var inserted = false;
    try {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        Get.snackbar('تعذر المشاركة', 'تعذر تجهيز نافذة المشاركة.');
        return;
      }

      overlay.insert(entry);
      inserted = true;
      await WidgetsBinding.instance.endOfFrame;
      await _captureService.captureAndShare(
        boundaryKey: boundaryKey,
        fileName: 'el7reef_top_scorers_${tournament.id}',
        text: 'هدافو ${tournament.name} على الحريف 🏆⚽',
        payload: shareData.sharePayload,
        pixelRatio: matchResultShareExportPixelRatio,
      );
    } catch (error) {
      Get.snackbar('تعذر المشاركة', _readableShareError(error));
    } finally {
      if (inserted) entry.remove();
    }
  }

  Future<void> _shareTournamentInvite(
    BuildContext context,
    Tournament tournament,
  ) async {
    if (!FeatureFlags.prideShareCatalogV2Enabled) return;
    final inviteCard = _announcementShareController.buildInviteIfEligible(
      tournament: tournament,
    );
    if (inviteCard == null) {
      Get.snackbar(
        'الدعوة غير متاحة',
        'تظهر دعوة التسجيل فقط أثناء فتح باب التسجيل.',
      );
      return;
    }

    final selection = await showPrideShareComposer(
      context: context,
      cardType: inviteCard.sharePayload.cardType,
      previewBuilder: (format) => TournamentAnnouncementShareCard(
        data: inviteCard,
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
            data: inviteCard,
            exportMode: true,
            format: selection.format,
            includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
          ),
          exportRequest: PrideExportRequest(
            cardType: inviteCard.sharePayload.cardType,
            format: selection.format,
            mediaType: selection.mediaType,
            fileName: 'el7reef_tournament_invite_${tournament.id}',
            includeAudio: selection.includeAudio,
          ),
          text: 'التسجيل مفتوح في ${tournament.name} على الحريف',
          payload: inviteCard.sharePayload,
        ),
      );
      if (context.mounted) showPrideShareFallbackNotice(context, outcome);
    } catch (error, stackTrace) {
      AppLogger.error(
        'TournamentDetailScreen.shareTournamentInvite',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر المشاركة', 'تعذر تجهيز دعوة البطولة.');
    }
  }
}

class _TournamentHeroAppBar extends StatelessWidget {
  final Tournament tournament;

  const _TournamentHeroAppBar({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final spec = tournamentVisualSpec(tournament.status);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final expandedHeight = 312 + (textScale - 1).clamp(0, 1.5).toDouble() * 170;
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the rich hero only while the sliver is effectively fully
          // expanded. During a short collapse (or hot reload), the previous
          // threshold left too little vertical room for the stage rail.
          final expanded = constraints.maxHeight >= expandedHeight - 8;
          return ClipRect(
            child: TournamentFieldPattern(
              color: spec.accent,
              child: ColoredBox(
                color: AppColors.surfaceRaised.withValues(alpha: 0.93),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppDimensions.pagePadding,
                      expanded ? 62 : 0,
                      AppDimensions.pagePadding,
                      AppDimensions.md,
                    ),
                    child: expanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TournamentStatusPill(spec: spec),
                              const Spacer(),
                              Text(
                                tournament.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.displaySmall.copyWith(
                                  color: AppColors.textPrimaryTinted,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.xs),
                              Text(
                                '${tournamentFormatLabel(tournament.format)}  •  ${tournament.teamSize.value} ضد ${tournament.teamSize.value}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryTinted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.lg),
                              TournamentStageRail(
                                activeIndex: spec.stageIndex,
                                accent: spec.accent,
                                semanticsLabel: spec.stageLabel,
                              ),
                            ],
                          )
                        : Align(
                            alignment: AlignmentDirectional.bottomStart,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 40,
                              ),
                              child: Text(
                                tournament.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TournamentIdentityPanel extends StatelessWidget {
  final Tournament tournament;

  const _TournamentIdentityPanel({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final spec = tournamentVisualSpec(tournament.status);
    final registrationOpen = tournament.status == TournamentStatus.registration;
    final facts = [
      _TournamentFactData(
        label: 'حجم الفريق',
        value: '${tournament.teamSize.value} ضد ${tournament.teamSize.value}',
        icon: Icons.sports_soccer_rounded,
      ),
      _TournamentFactData(
        label: 'عدد الفرق',
        value: '${tournament.teamCount}/${tournament.maxTeams}',
        icon: Icons.groups_2_rounded,
      ),
      _TournamentFactData(
        label: 'نوع الدورة',
        value: tournamentFormatLabel(tournament.format),
        icon: Icons.schema_rounded,
      ),
    ];

    return El7reefSurface(
      padding: const EdgeInsets.all(AppDimensions.lg),
      borderColor: spec.accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              if (stack) {
                return Column(
                  children: facts
                      .map(
                        (fact) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimensions.sm,
                          ),
                          child: _TournamentFact(data: fact),
                        ),
                      )
                      .toList(growable: false),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: facts
                    .map((fact) => Expanded(child: _TournamentFact(data: fact)))
                    .toList(growable: false),
              );
            },
          ),
          if (tournament.location?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondaryTinted,
                  size: 18,
                ),
                const SizedBox(width: AppDimensions.xs),
                Expanded(
                  child: Text(
                    tournament.location!.trim(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.md,
            runSpacing: AppDimensions.xs,
            children: [
              Text(
                'التسجيلات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${tournament.teamCount}/${tournament.maxTeams}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: registrationOpen
                        ? AppColors.primary
                        : AppColors.textPrimaryTinted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: tournament.fillRate.clamp(0.0, 1.0),
              minHeight: 8,
              color: registrationOpen ? AppColors.primary : spec.accent,
              backgroundColor: AppColors.surfaceBorderStrong,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            registrationOpen
                ? '${tournament.maxTeams - tournament.teamCount} أماكن متبقية'
                : 'قائمة البطولة الحالية',
            style: AppTextStyles.labelSmall.copyWith(
              color: registrationOpen
                  ? AppColors.primary
                  : AppColors.textSecondaryTinted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentFactData {
  final String label;
  final String value;
  final IconData icon;

  const _TournamentFactData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _TournamentFact extends StatelessWidget {
  final _TournamentFactData data;

  const _TournamentFact({required this.data});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: ${data.value}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: AppColors.primary, size: 19),
            const SizedBox(width: AppDimensions.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryTinted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentStoryStrip extends StatelessWidget {
  final Tournament tournament;
  final TournamentTopScorerEntry? topScorer;
  final bool hasOfficialResultsWithoutScorerDetails;
  final String championName;

  const _TournamentStoryStrip({
    required this.tournament,
    required this.topScorer,
    required this.hasOfficialResultsWithoutScorerDetails,
    required this.championName,
  });

  @override
  Widget build(BuildContext context) {
    final topScorerLabel = topScorer != null
        ? '${topScorer!.actor.displayName} · ${_goalCountLabel(topScorer!.goals)}'
        : hasOfficialResultsWithoutScorerDetails
        ? 'تفاصيل الهدافين غير مسجلة'
        : 'بانتظار أول هدف';
    final prideLabel = tournament.status == TournamentStatus.completed
        ? (championName.trim().isEmpty ? 'بطل غير محدد' : championName.trim())
        : _nextMilestoneLabel(tournament);

    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.primary.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            children: [
              const El7reefBadge(
                label: 'قصة البطولة',
                color: AppColors.primary,
                icon: Icons.auto_stories_rounded,
              ),
              Text(
                _tournamentStatusLabel(tournament.status),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              final scorerBeat = _StoryBeat(
                icon: Icons.local_fire_department_rounded,
                label: 'الهداف',
                value: topScorerLabel,
                earned: topScorer != null,
              );
              final milestoneBeat = _StoryBeat(
                icon: tournament.status == TournamentStatus.completed
                    ? Icons.workspace_premium_rounded
                    : Icons.bolt_rounded,
                label: tournament.status == TournamentStatus.completed
                    ? 'البطل'
                    : 'المحطة التالية',
                value: prideLabel,
                earned: tournament.status == TournamentStatus.completed,
              );
              if (stacked) {
                return Column(
                  children: [
                    scorerBeat,
                    const Divider(color: AppColors.surfaceBorder),
                    milestoneBeat,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: scorerBeat),
                  const SizedBox(
                    height: 58,
                    child: VerticalDivider(color: AppColors.surfaceBorder),
                  ),
                  Expanded(child: milestoneBeat),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StoryBeat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool earned;

  const _StoryBeat({
    required this.icon,
    required this.label,
    required this.value,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    final color = earned ? AppColors.secondary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: earned ? color : AppColors.textPrimaryTinted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentNavigationDeck extends StatelessWidget {
  final Tournament tournament;
  final bool canShareTopScorers;
  final VoidCallback onShareTopScorers;
  final VoidCallback? onShareInvite;

  const _TournamentNavigationDeck({
    required this.tournament,
    required this.canShareTopScorers,
    required this.onShareTopScorers,
    required this.onShareInvite,
  });

  @override
  Widget build(BuildContext context) {
    final stackNavigation = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final groupsTile = _ArenaNavTile.stacked(
      label: 'المجموعات',
      detail: 'الجولات والفرق',
      icon: Icons.grid_view_rounded,
      accent: AppColors.primary,
      onTap: () => Get.toNamed(TournamentDetailRoutes.groups(tournament.id)),
    );
    final standingsTile = _ArenaNavTile.stacked(
      label: 'الترتيب',
      detail: 'النقاط والتأهل',
      icon: Icons.leaderboard_rounded,
      accent: AppColors.info,
      onTap: () => Get.toNamed(TournamentDetailRoutes.standings(tournament.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'داخل البطولة',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppDimensions.sm),
        _ArenaNavTile.prominent(
          label: 'المباريات',
          detail: 'المواعيد، النتائج، وإدارة يوم المباراة',
          icon: Icons.sports_soccer_rounded,
          accent: AppColors.primary,
          onTap: () =>
              Get.toNamed(TournamentDetailRoutes.fixtures(tournament.id)),
        ),
        const SizedBox(height: AppDimensions.sm),
        if (stackNavigation) ...[
          groupsTile,
          const SizedBox(height: AppDimensions.sm),
          standingsTile,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: groupsTile),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: standingsTile),
            ],
          ),
        const SizedBox(height: AppDimensions.xs),
        Wrap(
          spacing: AppDimensions.xs,
          runSpacing: AppDimensions.xs,
          children: [
            TextButton.icon(
              onPressed: () => Get.toNamed(
                TournamentDetailRoutes.participants(tournament.id),
              ),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('الفرق'),
            ),
            TextButton.icon(
              onPressed: () =>
                  Get.toNamed(TournamentDetailRoutes.bracket(tournament.id)),
              icon: const Icon(Icons.account_tree_rounded),
              label: const Text('الإقصائيات'),
            ),
          ],
        ),
        if (canShareTopScorers || onShareInvite != null) ...[
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              if (canShareTopScorers)
                OutlinedButton.icon(
                  onPressed: onShareTopScorers,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('شارك الهدافين'),
                ),
              if (onShareInvite != null)
                FilledButton.tonalIcon(
                  onPressed: onShareInvite,
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('شارك دعوة التسجيل'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ArenaNavTile extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final _ArenaNavLayout layout;

  const _ArenaNavTile.prominent({
    required this.label,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : layout = _ArenaNavLayout.prominent;

  const _ArenaNavTile.stacked({
    required this.label,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : layout = _ArenaNavLayout.stacked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: layout == _ArenaNavLayout.prominent
          ? AppColors.surfaceRaised
          : accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: layout == _ArenaNavLayout.prominent ? 92 : 104,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: layout == _ArenaNavLayout.prominent
                ? Row(
                    children: [
                      _ArenaNavIcon(icon: icon, accent: accent),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: _ArenaNavCopy(label: label, detail: detail),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textSecondaryTinted,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ArenaNavIcon(icon: icon, accent: accent),
                      const SizedBox(height: AppDimensions.sm),
                      _ArenaNavCopy(label: label, detail: detail),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum _ArenaNavLayout { prominent, stacked }

class _ArenaNavIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _ArenaNavIcon({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(icon, color: accent, size: 21),
    );
  }
}

class _ArenaNavCopy extends StatelessWidget {
  final String label;
  final String detail;

  const _ArenaNavCopy({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryTinted,
          ),
        ),
      ],
    );
  }
}

class _FollowTournamentButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;

  const _FollowTournamentButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      borderColor: isFollowing
          ? AppColors.primary.withValues(alpha: 0.35)
          : AppColors.surfaceBorder,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              isFollowing
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFollowing ? 'تتابع هذه البطولة' : 'تابع البطولة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFollowing
                      ? 'ستبقى البطولة محفوظة لك بدون صلاحيات إدارة.'
                      : 'احفظها للرجوع إلى نتائجها وترتيبها بسهولة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: Text(isFollowing ? 'إلغاء' : 'متابعة'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// ── تبويب لوحة الفخر والمنصة الثلاثية ──
// ══════════════════════════════════════════
class _TopScorersSection extends StatelessWidget {
  final bool isLoading;
  final String errorMessage;
  final List<TournamentTopScorerEntry> scorers;
  final int officialMatchCount;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;

  const _TopScorersSection({
    required this.isLoading,
    required this.errorMessage,
    required this.scorers,
    required this.officialMatchCount,
    this.onRetry,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return El7reefSurface(
      elevated: scorers.isNotEmpty,
      borderColor: scorers.isNotEmpty
          ? AppColors.secondary.withValues(alpha: 0.25)
          : AppColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const El7reefBadge(
                label: 'لوحة الفخر',
                color: AppColors.secondary,
                icon: Icons.local_fire_department_rounded,
              ),
              const Spacer(),
              if (scorers.isNotEmpty)
                Text(
                  'أفضل ${scorers.length.clamp(1, 5)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text('هدافو البطولة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'الأهداف هنا تتحول لأسماء يتفاخر بها اللاعبون على واتساب.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          if (errorMessage.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            SectionStateCard.error(message: errorMessage, onAction: onRetry),
          ] else if (scorers.isEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  officialMatchCount > 0
                      ? 'النتائج محفوظة، تفاصيل الهدافين غير مسجلة'
                      : 'لم يتم تسجيل هدافين بعد',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  officialMatchCount > 0
                      ? 'تم اعتماد $officialMatchCount مباراة، لكن النتائج المستوردة لا تتضمن أسماء مسجلي الأهداف؛ لذلك لن نعرض ترتيبًا أو كارت مشاركة غير مؤكد.'
                      : 'بعد أول نتيجة بأهداف، ستظهر منصة الهدافين هنا ويصبح كارت المشاركة جاهزًا.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppDimensions.md),
            // ── منصة التتويج البصرية المذهلة (Podium) للمراكز الثلاثة الأولى ──
            _buildPodium(scorers.take(3).toList()),
            const SizedBox(height: AppDimensions.md),

            // بقية الهدافين في شكل قائمة
            if (scorers.length > 3) ...[
              const Divider(color: AppColors.surfaceBorder, height: 1),
              const SizedBox(height: AppDimensions.xs),
              ...scorers.skip(3).indexed.map((item) {
                final rank = item.$1 + 4;
                final scorer = item.$2;
                return _TopScorerRow(rank: rank, scorer: scorer);
              }),
            ],
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('شارك لوحة الهدافين'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // بناء منصة التتويج الأولمبية (2، 1، 3)
  Widget _buildPodium(List<TournamentTopScorerEntry> topThree) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // المركز الثاني
        if (second != null)
          _PodiumPillar(
            entry: second,
            rank: 2,
            height: 70,
            pillarColor: AppColors.surfaceRaised,
            badgeColor: AppColors.rankSilver,
            badgeLabel: '🥈 الثاني',
          )
        else
          const SizedBox(width: 70),

        // المركز الأول
        if (first != null)
          _PodiumPillar(
            entry: first,
            rank: 1,
            height: 90,
            pillarColor: AppColors.primarySurface,
            badgeColor: AppColors.secondary,
            badgeLabel: '👑 البطل',
            isChampion: true,
          )
        else
          const SizedBox(width: 80),

        // المركز الثالث
        if (third != null)
          _PodiumPillar(
            entry: third,
            rank: 3,
            height: 50,
            pillarColor: AppColors.surfaceSunken,
            badgeColor: AppColors.rankBronze,
            badgeLabel: '🥉 الثالث',
          )
        else
          const SizedBox(width: 70),
      ],
    );
  }
}

// ── عنصر منصة التتويج الفردي ──
class _PodiumPillar extends StatelessWidget {
  final TournamentTopScorerEntry entry;
  final int rank;
  final double height;
  final Color pillarColor;
  final Color badgeColor;
  final String badgeLabel;
  final bool isChampion;

  const _PodiumPillar({
    required this.entry,
    required this.rank,
    required this.height,
    required this.pillarColor,
    required this.badgeColor,
    required this.badgeLabel,
    this.isChampion = false,
  });

  @override
  Widget build(BuildContext context) {
    final actor = entry.actor;
    final isGuest = actor.kind == ParticipantRefKind.guestPlayer;
    final canOpenProfile = _canOpenPublicProfile(actor);

    return GestureDetector(
      onTap: canOpenProfile ? () => _openPublicProfile(actor) : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الهوية والاسم
          Container(
            width: isChampion ? 48 : 40,
            height: isChampion ? 48 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor, width: isChampion ? 2 : 1),
            ),
            child: Text(
              actor.displayName.isNotEmpty
                  ? actor.displayName.substring(0, 1)
                  : '⚽',
              style: AppTextStyles.titleMedium.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              actor.displayName,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: isChampion ? FontWeight.w900 : FontWeight.w700,
                fontSize: isChampion ? 11 : 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGuest) ...[
            const SizedBox(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                'ضيف',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            _goalCountLabel(entry.goals),
            style: AppTextStyles.labelSmall.copyWith(
              color: isChampion ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 6),

          // العمود الفعلي للمنصة
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: isChampion ? 75 : 65,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pillarColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMd),
              ),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: isChampion ? 20 : 16,
                  ),
                ),
                Text(
                  badgeLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── سطر الهدافين المطور بصرياً ──
class _TopScorerRow extends StatelessWidget {
  final int rank;
  final TournamentTopScorerEntry scorer;

  const _TopScorerRow({required this.rank, required this.scorer});

  @override
  Widget build(BuildContext context) {
    final actor = scorer.actor;
    final goals = scorer.goals;
    final isGuest = actor.kind == ParticipantRefKind.guestPlayer;
    final canOpenProfile = _canOpenPublicProfile(actor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: canOpenProfile ? () => _openPublicProfile(actor) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '$rank',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        actor.displayName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGuest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                        child: Text(
                          'ضيف',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                _goalCountLabel(goals),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canOpenProfile) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _canOpenPublicProfile(ParticipantRef actor) {
  return TournamentDetailRoutes.participantProfile(actor) != null;
}

void _openPublicProfile(ParticipantRef actor) {
  final route = TournamentDetailRoutes.participantProfile(actor);
  if (route != null) Get.toNamed(route);
}

String _goalCountLabel(int goals) {
  return goals == 1 ? '1 هدف' : '$goals أهداف';
}

String _readableShareError(Object error) {
  final raw = error.toString();
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }
  return 'تعذر تجهيز بطاقة المشاركة.';
}

// ── زر تسجيل فريق جديد ──
class _RegisterTeamButton extends StatelessWidget {
  final Tournament tournament;

  const _RegisterTeamButton({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      borderColor: AppColors.primary.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'سجّل فريقك',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'افتح صفحة التسجيل لاختيار فريقك ومعرفة حالة طلبات البطولة الحالية.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          El7reefButton(
            text: 'فتح صفحة التسجيل',
            icon: Icons.app_registration_rounded,
            onPressed: () =>
                Get.toNamed(TournamentDetailRoutes.registration(tournament.id)),
          ),
        ],
      ),
    );
  }
}

// ── كارت لوحة إدارة البطولة للمنظم ──
class _OrganizerDashboardCta extends StatelessWidget {
  final Tournament tournament;

  const _OrganizerDashboardCta({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      elevated: true,
      borderColor: AppColors.primary.withValues(alpha: 0.24),
      child: El7reefButton(
        text: 'إدارة البطولة',
        icon: Icons.dashboard_customize_rounded,
        onPressed: () => Get.toNamed(
          TournamentDetailRoutes.organizerDashboard(tournament.id),
        ),
      ),
    );
  }
}

String _tournamentStatusLabel(TournamentStatus status) => switch (status) {
  TournamentStatus.upcoming => 'لم تبدأ بعد',
  TournamentStatus.registration => 'التسجيل مفتوح',
  TournamentStatus.groupStage => 'مرحلة المجموعات',
  TournamentStatus.transferWindow => 'نافذة التغييرات',
  TournamentStatus.knockoutStage => 'مرحلة الإقصاء',
  TournamentStatus.completed => 'مكتملة',
  TournamentStatus.cancelled => 'ملغاة',
};

String _nextMilestoneLabel(Tournament tournament) =>
    switch (tournament.status) {
      TournamentStatus.upcoming => 'افتح التسجيل',
      TournamentStatus.registration =>
        tournament.canRegister ? 'كمّل الفرق' : 'جهّز الجدول',
      TournamentStatus.groupStage => 'اعتمد النتائج',
      TournamentStatus.transferWindow => 'راجع الفرق',
      TournamentStatus.knockoutStage => 'احسم البطل',
      TournamentStatus.cancelled => 'متوقفة',
      TournamentStatus.completed => 'اكتملت',
    };
