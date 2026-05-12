import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/rank_tier_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/auth/auth_service.dart';
import '../../match/views/match_discover_screen.dart';
import '../../match/controllers/match_controller.dart';
import '../../tournament/views/tournament_list_screen.dart';
import '../../profile/views/profile_screen.dart';
import '../../team/views/my_teams_screen.dart';
import '../../social/widgets/activity_feed_widget.dart';
import '../widgets/home_live_match_card.dart';
import '../widgets/home_my_match_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  late final List<Widget> _pages = [
    if (FeatureFlags.friendlyMatchTopLevelEnabled)
      _HomeTab(onNavigateToTab: (i) => setState(() => _currentIndex = i)),
    if (FeatureFlags.friendlyMatchTopLevelEnabled)
      const MatchDiscoverScreen()
    else
      const TournamentListScreen(),
    if (FeatureFlags.friendlyMatchTopLevelEnabled)
      const TournamentListScreen()
    else
      const MatchDiscoverScreen(),
    const MyTeamsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            if (FeatureFlags.friendlyMatchTopLevelEnabled)
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events_rounded),
              label: 'البطولات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_soccer_outlined),
              activeIcon: Icon(Icons.sports_soccer_rounded),
              label: 'المباريات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group_rounded),
              label: 'الفرق',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'أنا',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final void Function(int index) onNavigateToTab;
  const _HomeTab({required this.onNavigateToTab});

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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/logo_icon.png',
                                  height: 36,
                                  width: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
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

                if (player != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding,
                      ),
                      child: GlassmorphicContainer(
                        padding: const EdgeInsets.all(AppDimensions.lg),
                        borderRadius: AppDimensions.radiusLg,
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
                              '⚽',
                              'المباريات',
                              AppColors.primary,
                              () => onNavigateToTab(1),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            _actionCard(
                              '🏆',
                              'البطولات',
                              AppColors.secondary,
                              () => onNavigateToTab(2),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            _actionCard(
                              '👥',
                              'فرقي',
                              AppColors.accent,
                              () => onNavigateToTab(3),
                            ),
                          ],
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                        const SizedBox(height: AppDimensions.md),
                        if (FeatureFlags.fantasyUiEnabled) ...[
                          Row(
                            children: [
                              _actionCard(
                                '✨',
                                'فانتازي\nليج',
                                AppColors.secondary,
                                () => Get.toNamed(AppRoutes.fantasyHome),
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                flex: 2,
                                child: GlassmorphicContainer(
                                  padding: const EdgeInsets.all(
                                    AppDimensions.md,
                                  ),
                                  borderRadius: AppDimensions.radiusLg,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ابدأ فانتازي الحريف',
                                        style: AppTextStyles.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ابنِ تشكيلتك وادخل سباق النقاط في الدوري العالمي أو البطولات المفعّل عليها الفانتازي.',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 560.ms).slideY(begin: 0.1),
                        ],
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
                          onTap: () => onNavigateToTab(1),
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

                    if (matchCtrl.isLoading.value && liveMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: LoadingShimmer.list(count: 2),
                      );
                    }

                    if (liveMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          borderRadius: AppDimensions.radiusLg,
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
                                Get.toNamed('/match/lobby/${match.id}'),
                            child: HomeLiveMatchCard(match: match, index: index),
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

                    if (matchCtrl.isLoading.value && myMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: LoadingShimmer.list(count: 2),
                      );
                    }

                    if (myMatches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          borderRadius: AppDimensions.radiusLg,
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
                            onTap: () =>
                                Get.toNamed('/match/lobby/${e.value.id}'),
                            child: HomeMyMatchCard(match: e.value, index: e.key),
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
    String emoji,
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
              Text(emoji, style: const TextStyle(fontSize: 28)),
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
