import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/rank_tier_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/section_state_card.dart';
import '../../../core/auth/auth_service.dart';
import '../../../domain/entities/tournament.dart';
import '../../match/views/match_discover_screen.dart';
import '../../match/controllers/match_controller.dart';
import '../../tournament/views/tournament_list_screen.dart';
import '../../tournament/controllers/tournament_controller.dart';
import '../../profile/views/profile_screen.dart';
import '../../team/views/my_teams_screen.dart';
import '../../social/widgets/activity_feed_widget.dart';
import '../widgets/home_live_match_card.dart';
import '../widgets/home_my_match_card.dart';

class HomeScreen extends StatefulWidget {
  final bool? friendlyMatchTopLevelEnabled;

  const HomeScreen({super.key, this.friendlyMatchTopLevelEnabled});

  @visibleForTesting
  static List<String> debugNavigationLabels({
    required bool friendlyMatchTopLevelEnabled,
  }) {
    return _buildDestinationSpecs(
      friendlyMatchTopLevelEnabled: friendlyMatchTopLevelEnabled,
    ).map((destination) => destination.label).toList(growable: false);
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<_HomeDestination> _destinations = _buildDestinations();

  @override
  void initState() {
    super.initState();
  }

  List<_HomeDestination> _buildDestinations() {
    return _buildDestinationSpecs(
          friendlyMatchTopLevelEnabled:
              widget.friendlyMatchTopLevelEnabled ??
              FeatureFlags.friendlyMatchTopLevelEnabled,
        )
        .map((spec) {
          return _HomeDestination(
            spec: spec,
            page: switch (spec.key) {
              _HomeDestinationKey.home => _HomeTab(
                onNavigateToDestination: _selectDestination,
              ),
              _HomeDestinationKey.tournaments => const TournamentListScreen(),
              _HomeDestinationKey.matches => const MatchDiscoverScreen(),
              _HomeDestinationKey.teams => const MyTeamsScreen(),
              _HomeDestinationKey.profile => const ProfileScreen(),
            },
          );
        })
        .toList(growable: false);
  }

  void _selectDestination(_HomeDestinationKey key) {
    final index = _destinations.indexWhere(
      (destination) => destination.spec.key == key,
    );
    if (index < 0 || index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [for (final destination in _destinations) destination.page],
      ),
      bottomNavigationBar: El7reefGlassSurface(
        variant: El7reefGlassVariant.sheet,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            for (final destination in _destinations)
              destination.spec.navigationItem,
          ],
        ),
      ),
    );
  }
}

enum _HomeDestinationKey { home, tournaments, matches, teams, profile }

class _HomeDestinationSpec {
  final _HomeDestinationKey key;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _HomeDestinationSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  BottomNavigationBarItem get navigationItem {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Icon(activeIcon),
      label: label,
    );
  }
}

class _HomeDestination {
  final _HomeDestinationSpec spec;
  final Widget page;

  const _HomeDestination({required this.spec, required this.page});
}

List<_HomeDestinationSpec> _buildDestinationSpecs({
  required bool friendlyMatchTopLevelEnabled,
}) {
  return [
    if (friendlyMatchTopLevelEnabled)
      const _HomeDestinationSpec(
        key: _HomeDestinationKey.home,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'الرئيسية',
      ),
    const _HomeDestinationSpec(
      key: _HomeDestinationKey.tournaments,
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'البطولات',
    ),
    const _HomeDestinationSpec(
      key: _HomeDestinationKey.matches,
      icon: Icons.sports_soccer_outlined,
      activeIcon: Icons.sports_soccer_rounded,
      label: 'المباريات',
    ),
    const _HomeDestinationSpec(
      key: _HomeDestinationKey.teams,
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'الفرق',
    ),
    const _HomeDestinationSpec(
      key: _HomeDestinationKey.profile,
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'أنا',
    ),
  ];
}

class _HomeTab extends StatelessWidget {
  final void Function(_HomeDestinationKey key) onNavigateToDestination;
  const _HomeTab({required this.onNavigateToDestination});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Obx(() {
          final player = authService.currentPlayer.value;

          return RefreshIndicator(
            onRefresh: () async {
              final matchCtrl = Get.find<MatchController>();
              await Future.wait([
                matchCtrl.loadLiveMatches(),
                matchCtrl.loadMyMatches(),
              ]);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const El7reefBrandMark(size: 36),
                              const SizedBox(height: AppDimensions.sm),
                              Text(
                                'أهلاً ${player?.name ?? 'يا حريف'} 👋',
                                style: AppTextStyles.headlineMedium,
                              ),
                              Text(
                                'جاهز للملعب النهارده؟',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 500.ms),
                        const SizedBox(width: AppDimensions.sm),
                        if (player != null) ...[
                          RankTierBadge(
                            rating: player.rating,
                          ).animate().fadeIn(delay: 200.ms),
                          const SizedBox(width: AppDimensions.sm),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primarySurface,
                            backgroundImage: player.photoThumbUrl != null
                                ? NetworkImage(player.photoThumbUrl!)
                                : null,
                            child: player.photoThumbUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 22,
                                  )
                                : null,
                          ).animate().fadeIn(delay: 300.ms),
                        ],
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    child: _NextActionHero(
                      onNavigateToDestination: onNavigateToDestination,
                    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.md),
                ),

                if (player != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding,
                      ),
                      child: El7reefGlassSurface(
                        variant: El7reefGlassVariant.base,
                        padding: const EdgeInsets.all(AppDimensions.lg),
                        radius: AppDimensions.radiusLg,
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تقييمك الحالي',
                                  style: AppTextStyles.labelMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${player.rating}',
                                  style: AppTextStyles.ratingLarge.copyWith(
                                    fontSize: 36,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              children: [
                                _miniStat('${player.totalMatches}', 'مباراة'),
                                const SizedBox(height: 8),
                                _miniStat('${player.wins}', 'فوز'),
                              ],
                            ),
                            const SizedBox(width: AppDimensions.lg),
                            Column(
                              children: [
                                _miniStat('${player.mvpCount}', 'MVP'),
                                const SizedBox(height: 8),
                                _miniStat(
                                  '${player.winRate.toStringAsFixed(0)}%',
                                  'نسبة',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجراءات سريعة',
                          style: AppTextStyles.titleLarge,
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: AppDimensions.md),
                        Row(
                          children: [
                            _actionCard(
                              Icons.sports_soccer_rounded,
                              'المباريات',
                              AppColors.primary,
                              () => onNavigateToDestination(
                                _HomeDestinationKey.matches,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            _actionCard(
                              Icons.emoji_events_rounded,
                              'البطولات',
                              AppColors.secondary,
                              () => onNavigateToDestination(
                                _HomeDestinationKey.tournaments,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            _actionCard(
                              Icons.groups_rounded,
                              'فرقي',
                              AppColors.accent,
                              () => onNavigateToDestination(
                                _HomeDestinationKey.teams,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                        const SizedBox(height: AppDimensions.md),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.sm),
                ),

                if (FeatureFlags.activityFeedEnabled)
                  const SliverToBoxAdapter(child: ActivityFeedWidget()),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.lg),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.pagePadding,
                      0,
                      AppDimensions.pagePadding,
                      AppDimensions.sm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'المباريات الجارية',
                          style: AppTextStyles.titleLarge,
                        ).animate().fadeIn(delay: 500.ms),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => onNavigateToDestination(
                            _HomeDestinationKey.matches,
                          ),
                          child: Text(
                            'عرض الكل',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Obx(() {
                    final matchCtrl = Get.find<MatchController>();
                    final liveMatches = matchCtrl.liveMatches;
                    final liveError = matchCtrl.liveMatchesErrorMessage.value;

                    if (matchCtrl.isLoading.value && liveMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: LoadingShimmer.list(count: 2),
                      );
                    }

                    if (liveError.isNotEmpty && liveMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: SectionStateCard.error(
                          message: liveError,
                          onAction: matchCtrl.loadLiveMatches,
                        ).animate().fadeIn(delay: 600.ms),
                      );
                    }

                    if (liveMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: El7reefGlassSurface(
                          variant: El7reefGlassVariant.base,
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Row(
                            children: [
                              const Text('⚽', style: TextStyle(fontSize: 32)),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ما فيش مباريات جارية',
                                      style: AppTextStyles.titleMedium,
                                    ),
                                    Text(
                                      'كن أول من يبدأ!',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                      );
                    }

                    return SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        itemCount: liveMatches.length.clamp(0, 5),
                        itemBuilder: (context, index) {
                          final match = liveMatches[index];
                          return GestureDetector(
                            onTap: () =>
                                Get.toNamed(AppRoutes.matchLobbyById(match.id)),
                            child: HomeLiveMatchCard(
                              match: match,
                              index: index,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.md),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    child: Text(
                      'آخر مبارياتي',
                      style: AppTextStyles.titleLarge,
                    ).animate().fadeIn(delay: 600.ms),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.sm),
                ),

                SliverToBoxAdapter(
                  child: Obx(() {
                    final matchCtrl = Get.find<MatchController>();
                    final myMatches = matchCtrl.myMatches;
                    final myMatchesError =
                        matchCtrl.myMatchesErrorMessage.value;

                    if (matchCtrl.isLoading.value && myMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: LoadingShimmer.list(count: 2),
                      );
                    }

                    if (myMatchesError.isNotEmpty && myMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: SectionStateCard.error(
                          message: myMatchesError,
                          onAction: matchCtrl.loadMyMatches,
                        ).animate().fadeIn(delay: 700.ms),
                      );
                    }

                    if (myMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: El7reefGlassSurface(
                          variant: El7reefGlassVariant.base,
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          child: Row(
                            children: [
                              const Text('📋', style: TextStyle(fontSize: 32)),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ماعندكش مباريات لسه',
                                      style: AppTextStyles.titleMedium,
                                    ),
                                    Text(
                                      'العب أول مباراة وابدأ رحلتك!',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),
                      );
                    }

                    return Column(
                      children: myMatches.take(3).toList().asMap().entries.map((
                        e,
                      ) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.pagePadding,
                            0,
                            AppDimensions.pagePadding,
                            AppDimensions.sm,
                          ),
                          child: GestureDetector(
                            onTap: () => Get.toNamed(
                              AppRoutes.matchLobbyById(e.value.id),
                            ),
                            child: HomeMyMatchCard(
                              match: e.value,
                              index: e.key,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
        ),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextActionHero extends StatelessWidget {
  final void Function(_HomeDestinationKey key) onNavigateToDestination;

  const _NextActionHero({required this.onNavigateToDestination});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final tournamentController = Get.isRegistered<TournamentController>()
        ? Get.find<TournamentController>()
        : null;

    return Obx(() {
      final player = authService.currentPlayer.value;
      final myTournaments = tournamentController?.myTournaments ?? const [];
      final liveOrganized = tournamentController?.myOrganizedTournaments
          .where(_isPlayableTournament)
          .toList(growable: false);
      final liveParticipating = tournamentController?.myParticipatingTournaments
          .where(_isPlayableTournament)
          .toList(growable: false);

      final spec = _resolveNextAction(
        hasPlayer: player != null,
        organized: liveOrganized ?? const [],
        participating: liveParticipating ?? const [],
        anyTournamentCount: myTournaments.length,
        onNavigateToDestination: onNavigateToDestination,
      );

      return El7reefGlassSurface(
        variant: spec.variant,
        padding: const EdgeInsets.all(AppDimensions.lg),
        radius: AppDimensions.radiusXl,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: spec.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: spec.accentColor.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(spec.icon, color: spec.accentColor, size: 28),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spec.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    spec.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            IconButton.filled(
              tooltip: spec.tooltip,
              onPressed: spec.onTap,
              style: IconButton.styleFrom(
                backgroundColor: spec.accentColor,
                foregroundColor: AppColors.textOnPrimary,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ],
        ),
      );
    });
  }

  static bool _isPlayableTournament(Tournament tournament) {
    return tournament.status != TournamentStatus.completed &&
        tournament.status != TournamentStatus.cancelled;
  }

  _NextActionSpec _resolveNextAction({
    required bool hasPlayer,
    required List<Tournament> organized,
    required List<Tournament> participating,
    required int anyTournamentCount,
    required void Function(_HomeDestinationKey key) onNavigateToDestination,
  }) {
    if (!hasPlayer) {
      return _NextActionSpec(
        icon: Icons.login_rounded,
        title: 'ادخل الملعب باسمك',
        subtitle: 'سجل دخولك عشان بطولاتك وفرقك وكروت الفخر تبقى محفوظة.',
        tooltip: 'تسجيل الدخول',
        accentColor: AppColors.primary,
        variant: El7reefGlassVariant.raised,
        onTap: () => Get.toNamed(AppRoutes.login),
      );
    }

    if (organized.isNotEmpty) {
      final tournament = organized.first;
      return _NextActionSpec(
        icon: Icons.admin_panel_settings_rounded,
        title: 'كمل تشغيل دورتك',
        subtitle: tournament.name,
        tooltip: 'فتح لوحة إدارة البطولة',
        accentColor: AppColors.secondary,
        variant: El7reefGlassVariant.pride,
        onTap: () => Get.toNamed(
          AppRoutes.organizerDashboardForTournament(tournament.id),
        ),
      );
    }

    if (participating.isNotEmpty) {
      final tournament = participating.first;
      return _NextActionSpec(
        icon: Icons.emoji_events_rounded,
        title: 'تابع بطولتك الحالية',
        subtitle: tournament.name,
        tooltip: 'فتح تفاصيل البطولة',
        accentColor: AppColors.primary,
        variant: El7reefGlassVariant.raised,
        onTap: () => Get.toNamed(AppRoutes.tournamentDetailById(tournament.id)),
      );
    }

    if (anyTournamentCount > 0) {
      return _NextActionSpec(
        icon: Icons.travel_explore_rounded,
        title: 'اختار بطولتك التالية',
        subtitle: 'راجع بطولاتك أو استكشف بطولة مفتوحة تناسب فريقك.',
        tooltip: 'فتح البطولات',
        accentColor: AppColors.primary,
        variant: El7reefGlassVariant.raised,
        onTap: () => onNavigateToDestination(_HomeDestinationKey.tournaments),
      );
    }

    return _NextActionSpec(
      icon: Icons.add_circle_outline_rounded,
      title: 'ابدأ دورة شعبية',
      subtitle: 'ضيف فرق مسجلة أو ضيوف، وبعد أول نتيجة تظهر كروت الفخر.',
      tooltip: 'فتح البطولات',
      accentColor: AppColors.secondary,
      variant: El7reefGlassVariant.pride,
      onTap: () => onNavigateToDestination(_HomeDestinationKey.tournaments),
    );
  }
}

class _NextActionSpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tooltip;
  final Color accentColor;
  final El7reefGlassVariant variant;
  final VoidCallback onTap;

  const _NextActionSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.accentColor,
    required this.variant,
    required this.onTap,
  });
}
