import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/rank_tier_badge.dart';
import '../../../services/auth_service.dart';
import '../../match/views/match_discover_screen.dart';
import '../../match/controllers/match_controller.dart';
import '../../tournament/views/tournament_list_screen.dart';
import '../../tournament/controllers/tournament_controller.dart';
import '../../../domain/entities/match.dart';
import '../../../core/enums/match_status.dart';
import '../../profile/views/profile_screen.dart';
import '../../team/views/my_teams_screen.dart';
import '../../team/controllers/team_controller.dart';
import '../../profile/controllers/profile_controller.dart';

import '../../social/widgets/activity_feed_widget.dart';

/// الشاشة الرئيسية — Hub مع Bottom Navigation
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
    Get.put(ProfileController());
    Get.put(TeamController());
    Get.put(MatchController());
    Get.put(TournamentController());
  }

  final _pages = const [
    _HomeTab(),
    MatchDiscoverScreen(),
    TournamentListScreen(),
    MyTeamsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'اكتشاف',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events_rounded),
              label: 'دورات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group_rounded),
              label: 'فرقي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'بروفايل',
            ),
          ],
        ),
      ),
    );
  }
}

/// ── تاب الرئيسية ──
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Obx(() {
          final player = authService.currentPlayer.value;

          return CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      if (player != null)
                        RankTierBadge(rating: player.rating)
                            .animate()
                            .fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ),

              // ── بطاقة Rating السريعة ──
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
                          // Rating
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تقييمك الحالي',
                                  style: AppTextStyles.labelMedium),
                              const SizedBox(height: 4),
                              Text(
                                '${player.rating}',
                                style: AppTextStyles.ratingLarge.copyWith(fontSize: 36),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Stats مصغرة
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

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجراءات سريعة',
                              style: AppTextStyles.titleLarge)
                          .animate()
                          .fadeIn(delay: 400.ms),
                      const SizedBox(height: AppDimensions.md),
                      Row(
                        children: [
                          _actionCard(
                            '⚽', 'ابحث عن\nمباراة', AppColors.primary,
                            () {},
                          ),
                          const SizedBox(width: AppDimensions.md),
                          _actionCard(
                            '🏆', 'أنشئ\nدورة', AppColors.secondary,
                            () {},
                          ),
                          const SizedBox(width: AppDimensions.md),
                          _actionCard(
                            '👥', 'أنشئ\nفريق', AppColors.accent,
                            () {},
                          ),
                        ],
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),

              // ── Activity Feed ──
              const SliverToBoxAdapter(
                child: ActivityFeedWidget(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),

              // ── المباريات الجارية ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.pagePadding, 0,
                    AppDimensions.pagePadding, AppDimensions.sm,
                  ),
                  child: Row(
                    children: [
                      Text('المباريات الجارية', style: AppTextStyles.titleLarge)
                          .animate().fadeIn(delay: 500.ms),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          // الانتقال لتاب اكتشاف
                        },
                        child: Text('عرض الكل',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                            )).animate().fadeIn(delay: 500.ms),
                      ),
                    ],
                  ),
                ),
              ),

              // ── قائمة المباريات الحية ──
              SliverToBoxAdapter(
                child: Obx(() {
                  final matchCtrl = Get.find<MatchController>();
                  final liveMatches = matchCtrl.liveMatches;

                  if (matchCtrl.isLoading.value && liveMatches.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppDimensions.xl),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
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
                                  Text('ما فيش مباريات جارية',
                                      style: AppTextStyles.titleMedium),
                                  Text('كن أول من يبدأ!',
                                      style: AppTextStyles.bodySmall),
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
                        return _LiveMatchCard(match: match, index: index);
                      },
                    ),
                  );
                }),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),

              // ── آخر مباراياتي ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePadding,
                  ),
                  child: Text('آخر مبارياتي', style: AppTextStyles.titleLarge)
                      .animate().fadeIn(delay: 600.ms),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),

              SliverToBoxAdapter(
                child: Obx(() {
                  final matchCtrl = Get.find<MatchController>();
                  final myMatches = matchCtrl.myMatches;

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
                                  Text('ماعندكش مباريات لسه',
                                      style: AppTextStyles.titleMedium),
                                  Text('العب أول مباراة وابدأ رحلتك!',
                                      style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 700.ms),
                    );
                  }

                  return Column(
                    children: myMatches.take(3).toList().asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.pagePadding, 0,
                          AppDimensions.pagePadding, AppDimensions.sm,
                        ),
                        child: _MyMatchCard(match: e.value, index: e.key),
                      );
                    }).toList(),
                  );
                }),
              ),

            ],
          );
        }),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary)),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }

  Widget _actionCard(
      String emoji, String label, Color color, VoidCallback onTap) {
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




// ── بطاقة المباراة الجارية (أفقية - Carousel) ──
class _LiveMatchCard extends StatelessWidget {
  final Match match;
  final int index;

  const _LiveMatchCard({required this.match, required this.index});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = match.status == MatchStatus.live
        ? AppColors.primary
        : match.status == MatchStatus.open
            ? AppColors.success
            : AppColors.textMuted;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // حالة المباراة
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  match.status == MatchStatus.live
                      ? 'جارية الآن'
                      : match.status == MatchStatus.open
                          ? 'مفتوحة'
                          : 'منتهية',
                  style: AppTextStyles.labelSmall.copyWith(color: statusColor),
                ),
                const Spacer(),
                if (match.isGoldenRating)
                  const Icon(Icons.star_rounded,
                      color: AppColors.secondary, size: 16),
              ],
            ),

            // الفريقان والنتيجة
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔵', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                match.isCompleted && match.scoreTeamA != null
                    ? Text(
                        '${match.scoreTeamA} - ${match.scoreTeamB}',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      )
                    : Text('vs', style: AppTextStyles.titleMedium),
                const SizedBox(width: 6),
                Text('🔴', style: const TextStyle(fontSize: 22)),
              ],
            ),

            // تفاصيل
            Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${match.teamAPlayerIds.length + match.teamBPlayerIds.length} لاعب',
                  style: AppTextStyles.labelSmall,
                ),
                const Spacer(),
                if (match.isFrozen)
                  const Icon(Icons.lock, size: 14, color: AppColors.error),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: (100 * index).ms).fadeIn(duration: 400.ms).slideX(begin: 0.2);
  }
}

// ── بطاقة مبارياتي الأخيرة ──
class _MyMatchCard extends StatelessWidget {
  final Match match;
  final int index;

  const _MyMatchCard({required this.match, required this.index});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final uid = authService.currentUserId ?? '';

    // هل أنا في فريق A أو B؟
    final bool isTeamA = match.teamAPlayerIds.contains(uid);
    final int? myScore = isTeamA ? match.scoreTeamA : match.scoreTeamB;
    final int? oppScore = isTeamA ? match.scoreTeamB : match.scoreTeamA;

    // هل فزنا؟
    Color resultColor = AppColors.textMuted;
    String resultLabel = '—';
    if (myScore != null && oppScore != null) {
      if (myScore > oppScore) {
        resultColor = AppColors.success;
        resultLabel = 'فوز';
      } else if (myScore < oppScore) {
        resultColor = AppColors.error;
        resultLabel = 'خسارة';
      } else {
        resultColor = AppColors.secondary;
        resultLabel = 'تعادل';
      }
    }

    return GlassmorphicContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      borderRadius: AppDimensions.radiusMd,
      child: Row(
        children: [
          // أيقونة النتيجة
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: resultColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                resultLabel == 'فوز' ? '🏆' : resultLabel == 'خسارة' ? '😤' : '🤝',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),

          // معلومات المباراة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.status == MatchStatus.settled
                      ? 'مباراة منتهية'
                      : match.status == MatchStatus.live
                          ? 'مباراة جارية'
                          : 'قيد التسوية',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  _formatDate(match.createdAt),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),

          // النتيجة
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (myScore != null)
                Text(
                  '$myScore - $oppScore',
                  style: AppTextStyles.titleLarge.copyWith(color: resultColor),
                ),
              Text(
                resultLabel,
                style: AppTextStyles.labelSmall.copyWith(color: resultColor),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: (120 * index).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'النهارده';
    if (diff.inDays == 1) return 'امبارح';
    return '${diff.inDays} يوم';
  }
}

