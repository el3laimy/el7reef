import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/permissions/tournament_viewer_context.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/tournament.dart';
import '../../shareables/controllers/top_scorers_share_controller.dart';
import '../../shareables/services/share_card_capture_service.dart';
import '../../shareables/widgets/top_scorers_share_card.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/tournament_detail_controller.dart';

/// شاشة تفاصيل البطولة المطورة بالكامل
class TournamentDetailScreen extends GetView<TournamentDetailController> {
  static const _shareBuilder = TopScorersShareController();
  static const _captureService = ShareCardCaptureService();

  const TournamentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final bool isTesting = Platform.environment.containsKey('FLUTTER_TEST');

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      controller.errorMessage.value.isEmpty
                          ? 'تعذر تحميل تفاصيل الدورة'
                          : controller.errorMessage.value,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    El7reefButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: controller.loadTournament,
                    ),
                  ],
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

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── الترويسة الديناميكية الممتازة ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    tournament.name,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: AppColors.black.withValues(alpha: 0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // تدرج الخلفية الرياضي الممتاز
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryDark.withValues(alpha: 0.9),
                              AppColors.backgroundDeep,
                            ],
                          ),
                        ),
                      ),
                      // شبكة ملعب خفيفة
                      Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/tactical_board.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(),
                        ),
                      ),
                      // تدرج داكن للتعتيم
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      // أيقونة كأس مهيبة متوهجة
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child:
                              const Icon(
                                    Icons.emoji_events_rounded,
                                    color: AppColors.secondary,
                                    size: 72,
                                  )
                                  .animate(
                                    onPlay: (c) =>
                                        isTesting ? null : c.repeat(),
                                  )
                                  .shimmer(
                                    duration: const Duration(seconds: 2),
                                    color: AppColors.secondaryLight,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── جسم الصفحة المتكامل بصرياً لتجنب مشاكل الاختبارات ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // بطاقة المعلومات الرئيسية
                      _InfoCard(tournament: tournament)
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 350))
                          .slideY(begin: 0.05),
                      const SizedBox(height: AppDimensions.md),

                      // شريط التقدم للتسجيل
                      _RegistrationProgress(tournament: tournament)
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 400)),
                      const SizedBox(height: AppDimensions.md),

                      _PublicTournamentLinks(tournament: tournament)
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 420)),
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

    final shareData = _shareBuilder.build(
      tournamentName: tournament.name,
      scorers: scorers,
      limit: 5,
    );
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
              child: TopScorersShareCard(data: shareData, exportMode: true),
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
        pixelRatio: matchResultShareExportPixelRatio,
      );
    } catch (error) {
      Get.snackbar('تعذر المشاركة', _readableShareError(error));
    } finally {
      if (inserted) entry.remove();
    }
  }
}

class _PublicTournamentLinks extends StatelessWidget {
  final Tournament tournament;

  const _PublicTournamentLinks({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('متابعة البطولة', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'شاهد الفرق والجدول والترتيب بدون أدوات إدارة.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              _PublicLinkButton(
                label: 'الفرق',
                icon: Icons.groups_rounded,
                route: AppRoutes.tournamentParticipantsById(tournament.id),
              ),
              _PublicLinkButton(
                label: 'المجموعات',
                icon: Icons.grid_view_rounded,
                route: AppRoutes.tournamentGroupsById(tournament.id),
              ),
              _PublicLinkButton(
                label: 'المباريات',
                icon: Icons.sports_soccer_rounded,
                route: AppRoutes.tournamentFixturesById(tournament.id),
              ),
              _PublicLinkButton(
                label: 'الترتيب',
                icon: Icons.leaderboard_rounded,
                route: AppRoutes.tournamentStandingsById(tournament.id),
              ),
              _PublicLinkButton(
                label: 'الإقصائيات',
                icon: Icons.account_tree_rounded,
                route: AppRoutes.tournamentBracketById(tournament.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicLinkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;

  const _PublicLinkButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Get.toNamed(route),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
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
  final VoidCallback? onShare;

  const _TopScorersSection({
    required this.isLoading,
    required this.errorMessage,
    required this.scorers,
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
            Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ] else if (scorers.isEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لم يتم تسجيل هدافين بعد', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'بعد أول نتيجة بأهداف، ستظهر منصة الهدافين هنا ويصبح كارت المشاركة جاهزًا.',
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
  if (actor.id.trim().isEmpty) return false;
  return actor.kind == ParticipantRefKind.player ||
      actor.kind == ParticipantRefKind.guestPlayer;
}

void _openPublicProfile(ParticipantRef actor) {
  if (!_canOpenPublicProfile(actor)) return;
  Get.toNamed(
    AppRoutes.playerProfileByKindAndId(
      kind: actor.kind.name,
      id: actor.id.trim(),
    ),
  );
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

// ── كارد معلومات البطولة ──
class _InfoCard extends StatelessWidget {
  final Tournament tournament;

  const _InfoCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      borderColor: AppColors.surfaceBorder,
      child: Column(
        children: [
          _Row(
            icon: Icons.sports_soccer_rounded,
            label: 'حجم الفريق',
            value: '${tournament.teamSize.value}v${tournament.teamSize.value}',
          ),
          _Row(
            icon: Icons.format_list_bulleted_rounded,
            label: 'نوع الدورة',
            value: switch (tournament.format) {
              TournamentFormat.groupsOnly => 'مجموعات فقط',
              TournamentFormat.knockoutOnly => 'إقصاء مباشر',
              TournamentFormat.groupsThenKnockout => 'مجموعات + إقصاء',
            },
          ),
          _Row(
            icon: Icons.groups_rounded,
            label: 'عدد الفرق',
            value: '${tournament.maxTeams} فريق كحد أقصى',
          ),
          if (tournament.location != null)
            _Row(
              icon: Icons.location_on_outlined,
              label: 'الموقع',
              value: tournament.location!,
            ),
          _Row(
            icon: Icons.flag_circle_rounded,
            label: 'حالة البطولة',
            value: _tournamentStatusLabel(tournament.status),
          ),
          if (tournament.prizeDescription != null)
            _Row(
              icon: Icons.card_giftcard_rounded,
              label: 'الجائزة',
              value: tournament.prizeDescription!,
            ),
        ],
      ),
    );
  }
}

// ── شريط تقدم تسجيل البطولة ──
class _RegistrationProgress extends StatelessWidget {
  final Tournament tournament;

  const _RegistrationProgress({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'التسجيلات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${tournament.teamCount}/${tournament.maxTeams}',
                style: AppTextStyles.ratingMedium.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: tournament.fillRate.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tournament.canRegister
                ? '${tournament.maxTeams - tournament.teamCount} مكان متبقي'
                : 'اكتملت الأماكن أو أُغلق التسجيل',
            style: AppTextStyles.labelSmall.copyWith(
              color: tournament.canRegister
                  ? AppColors.success
                  : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
            onPressed: () => Get.toNamed(
              AppRoutes.teamRegistrationForTournament(tournament.id),
            ),
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
          AppRoutes.organizerDashboardForTournament(tournament.id),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.md),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
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
