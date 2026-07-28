import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/identity/identity_preset.dart';
import '../../../core/identity/identity_preset_field.dart';
import '../../../core/identity/identity_visual.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../core/widgets/section_state_card.dart';
import '../../../domain/entities/tournament.dart';
import '../controllers/tournament_controller.dart';
import '../widgets/tournament_visual_language.dart';

/// شاشة بطولاتي — لا تعرض بطولات عامة عشوائية داخل مساحة المستخدم الشخصية
class TournamentListScreen extends GetView<TournamentController> {
  const TournamentListScreen({super.key});

  // ── فلتر الحالات التفاعلي (مجعول static لتمكين الـ const constructor) ──
  static final RxString _selectedFilter = 'all'.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بطولاتي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'تحديث البيانات',
            onPressed: controller.loadMyTournaments,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          final myTournaments = controller.myTournaments;
          if (controller.isLoadingMyTournaments.value &&
              myTournaments.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // تصفية القائمة بناءً على الفلتر النشط
          final filteredList = myTournaments.where((t) {
            switch (_selectedFilter.value) {
              case 'registration':
                return t.status == TournamentStatus.registration;
              case 'active':
                return t.status != TournamentStatus.registration &&
                    t.status != TournamentStatus.completed &&
                    t.status != TournamentStatus.cancelled;
              case 'completed':
                return t.status == TournamentStatus.completed ||
                    t.status == TournamentStatus.cancelled;
              default:
                return true;
            }
          }).toList();
          final followedList = controller.followedOnlyTournaments;
          final hasBlockingMyTournamentsError =
              controller.myTournamentsErrorMessage.value.isNotEmpty &&
              myTournaments.isEmpty;
          final showCreateActionAboveList =
              myTournaments.isNotEmpty || hasBlockingMyTournamentsError;

          return RefreshIndicator(
            onRefresh: controller.loadMyTournaments,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _TournamentPortfolioHeader(
                    tournamentCount: myTournaments.length,
                    activeCount: myTournaments
                        .where(
                          (tournament) =>
                              tournament.status != TournamentStatus.completed &&
                              tournament.status != TournamentStatus.cancelled,
                        )
                        .length,
                    onCreate: showCreateActionAboveList
                        ? () => _showCreateSheet(context)
                        : null,
                    onExplore: () => Get.toNamed(AppRoutes.tournamentExplore),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.md),
                ),

                if (myTournaments.isNotEmpty) ...[
                  // ── شريط الفلترة التفاعلي (Chips) ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding,
                      ),
                      child: El7reefGlassSurface(
                        role: El7reefGlassRole.floatingToolbar,
                        padding: const EdgeInsets.all(AppDimensions.xs),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'كل بطولاتي',
                                filter: 'all',
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              _buildFilterChip(
                                label: 'تسجيل مفتوح',
                                filter: 'registration',
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              _buildFilterChip(
                                label: 'جارية الآن',
                                filter: 'active',
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              _buildFilterChip(
                                label: 'منتهية',
                                filter: 'completed',
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.md),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppDimensions.md,
                        runSpacing: AppDimensions.xs,
                        children: [
                          Text(
                            _getFilterTitle(),
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _CountBadge(count: filteredList.length),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.sm),
                  ),
                ],

                if (controller.myTournamentsErrorMessage.value.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePadding,
                        0,
                        AppDimensions.pagePadding,
                        AppDimensions.md,
                      ),
                      child: SectionStateCard.error(
                        message: controller.myTournamentsErrorMessage.value,
                        onAction: controller.loadMyTournaments,
                      ),
                    ),
                  ),

                // ── قائمة البطولات المفلترة ──
                hasBlockingMyTournamentsError
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : filteredList.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmpty(
                          context,
                          compact: followedList.isNotEmpty,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.pagePadding,
                              vertical: AppDimensions.xs,
                            ),
                            child: _TournamentCard(tournament: filteredList[i]),
                          ),
                          childCount: filteredList.length,
                        ),
                      ),

                if (followedList.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.lg),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'متابعاتي',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _CountBadge(count: followedList.length),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.sm),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                          vertical: AppDimensions.xs,
                        ),
                        child: _TournamentCard(tournament: followedList[i]),
                      ),
                      childCount: followedList.length,
                    ),
                  ),
                ],

                if (!hasBlockingMyTournamentsError &&
                    controller.followedTournamentsErrorMessage.value.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePadding,
                        AppDimensions.md,
                        AppDimensions.pagePadding,
                        0,
                      ),
                      child: SectionStateCard.error(
                        message:
                            controller.followedTournamentsErrorMessage.value,
                        onAction: controller.loadMyTournaments,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxl),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String filter}) {
    final isSelected = _selectedFilter.value == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _selectedFilter.value = filter,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
    );
  }

  String _getFilterTitle() {
    return switch (_selectedFilter.value) {
      'registration' => 'تسجيلات مفتوحة للفرق',
      'active' => 'منافسات مشتعلة جارية',
      'completed' => 'بطولات كُتب تاريخها',
      _ => 'بطولاتي',
    };
  }

  Widget _buildEmpty(BuildContext context, {bool compact = false}) {
    final isAllFilter = _selectedFilter.value == 'all';
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.xxl,
        vertical: compact ? AppDimensions.lg : AppDimensions.xxxl,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: AppColors.competitive,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'لا توجد بطولات لديك حتى الآن',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              isAllFilter
                  ? 'ابدأ بطولة شعبية وسجل الفرق والنتائج عشان تظهر كروت الفخر.'
                  : 'لا توجد بطولات تطابق هذا التصنيف حالياً.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: El7reefButton(
                text: isAllFilter ? 'ابدأ دورة شعبية' : 'عرض كل بطولاتي',
                icon: isAllFilter
                    ? Icons.add_circle_outline_rounded
                    : Icons.filter_alt_off_rounded,
                isOutlined: !isAllFilter,
                onPressed: isAllFilter
                    ? () => _showCreateSheet(context)
                    : () => _selectedFilter.value = 'all',
              ),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  void _showCreateSheet(BuildContext context) {
    controller.createTournamentErrorMessage.value = '';
    Get.bottomSheet(
      _CreateTournamentSheet(controller: controller),
      isScrollControlled: true,
    );
  }
}

class _TournamentPortfolioHeader extends StatelessWidget {
  final int tournamentCount;
  final int activeCount;
  final VoidCallback? onCreate;
  final VoidCallback onExplore;

  const _TournamentPortfolioHeader({
    required this.tournamentCount,
    required this.activeCount,
    required this.onCreate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.md,
        AppDimensions.pagePadding,
        AppDimensions.xs,
      ),
      child: El7reefSolidSurface(
        tone: El7reefGlassTone.competitive,
        elevated: true,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: TournamentFieldPattern(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملعب بطولاتك',
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tournamentCount == 0
                                  ? 'ابدأ أول بطولة، وسجّل كل لحظة فيها.'
                                  : '$tournamentCount بطولة، منها $activeCount في الملعب الآن',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondaryTinted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  if (onCreate != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeightLg,
                      child: FilledButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('أنشئ دورة جديدة الآن'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onExplore,
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('استكشف بطولات مفتوحة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentDefaultsSummary extends StatelessWidget {
  final String formatLabel;
  final int teamSize;
  final int maxTeams;
  final bool isPublic;

  const _TournamentDefaultsSummary({
    required this.formatLabel,
    required this.teamSize,
    required this.maxTeams,
    required this.isPublic,
  });

  @override
  Widget build(BuildContext context) {
    final summary =
        '$formatLabel، $teamSize ضد $teamSize، $maxTeams فرق، ${isPublic ? 'عامة' : 'خاصة'}';
    final expandedChips = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final setupChips = [
      _TournamentSetupChip(
        icon: Icons.account_tree_rounded,
        label: formatLabel,
        expanded: expandedChips,
      ),
      _TournamentSetupChip(
        icon: Icons.sports_soccer_rounded,
        label: '$teamSize ضد $teamSize',
        expanded: expandedChips,
      ),
      _TournamentSetupChip(
        icon: Icons.groups_rounded,
        label: '$maxTeams فرق',
        expanded: expandedChips,
      ),
      _TournamentSetupChip(
        icon: isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
        label: isPublic ? 'عامة' : 'خاصة',
        expanded: expandedChips,
      ),
    ];
    return Semantics(
      container: true,
      label: 'إعداد البطولة الحالي: $summary',
      child: El7reefSurface(
        color: AppColors.primarySurface,
        borderColor: AppColors.primary.withValues(alpha: 0.32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.xs),
                Expanded(
                  child: Text(
                    'الإعداد السريع الجاهز',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            if (expandedChips)
              Column(
                spacing: AppDimensions.xs,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: setupChips,
              )
            else
              Wrap(
                spacing: AppDimensions.xs,
                runSpacing: AppDimensions.xs,
                children: setupChips,
              ),
          ],
        ),
      ),
    );
  }
}

class _TournamentSetupChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;

  const _TournamentSetupChip({
    required this.icon,
    required this.label,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 4),
          if (expanded)
            Expanded(child: Text(label, style: AppTextStyles.labelMedium))
          else
            Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

class CreateTournamentIntentScreen extends StatefulWidget {
  const CreateTournamentIntentScreen({super.key});

  @override
  State<CreateTournamentIntentScreen> createState() =>
      _CreateTournamentIntentScreenState();
}

class _CreateTournamentIntentScreenState
    extends State<CreateTournamentIntentScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = Get.find<TournamentController>();
      controller.createTournamentErrorMessage.value = '';
      Get.bottomSheet(
        _CreateTournamentSheet(controller: controller),
        isScrollControlled: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const TournamentListScreen();
}

/// شاشة استكشاف البطولات العامة المفتوحة. لا تحتوي على أدوات إدارة.
class TournamentExploreScreen extends StatefulWidget {
  const TournamentExploreScreen({super.key});

  @override
  State<TournamentExploreScreen> createState() =>
      _TournamentExploreScreenState();
}

class _TournamentExploreScreenState extends State<TournamentExploreScreen> {
  TournamentController get controller => Get.find<TournamentController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadDiscoverableTournaments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استكشف بطولات مفتوحة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'تحديث البيانات',
            onPressed: controller.loadDiscoverableTournaments,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoadingDiscoverableTournaments.value &&
              controller.discoverableTournaments.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final tournaments = controller.discoverableTournaments;
          final featuredTournaments = tournaments
              .where((tournament) => tournament.isFeatured)
              .toList(growable: false);
          final publicTournaments = tournaments
              .where((tournament) => !tournament.isFeatured)
              .toList(growable: false);
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadDiscoverableTournaments,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: El7reefSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'البطولات التي تستحق المتابعة',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'شاهد النتائج والترتيب وطريق الفرق نحو الكأس، أو تابع بطولة مفتوحة.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryTinted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (controller.errorMessage.value.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePadding,
                        0,
                        AppDimensions.pagePadding,
                        AppDimensions.md,
                      ),
                      child: SectionStateCard.error(
                        title: tournaments.isEmpty
                            ? 'تعذر فتح الاستكشاف'
                            : 'تعذر تحديث القائمة',
                        message: controller.errorMessage.value,
                        onAction: controller.loadDiscoverableTournaments,
                      ),
                    ),
                  ),
                if (tournaments.isEmpty &&
                    controller.errorMessage.value.isEmpty)
                  SliverToBoxAdapter(child: _buildExploreEmpty())
                else ...[
                  if (featuredTournaments.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: _ExploreSectionHeader(
                        title: 'بطولات مميزة',
                        subtitle: 'اختيارات الحريف التي تستحق المشاهدة',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.pagePadding,
                            0,
                            AppDimensions.pagePadding,
                            AppDimensions.md,
                          ),
                          child: _FeaturedTournamentCard(
                            tournament: featuredTournaments[i],
                            presentation: i == 0
                                ? _FeaturedTournamentPresentation.hero
                                : _FeaturedTournamentPresentation.solid,
                          ),
                        ),
                        childCount: featuredTournaments.length,
                      ),
                    ),
                  ],
                  if (publicTournaments.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: _ExploreSectionHeader(
                        title: 'بطولات عامة',
                        subtitle: 'بطولات جارية يمكنك متابعتها أو التسجيل فيها',
                        icon: Icons.public_rounded,
                      ),
                    ),
                  ],
                ],
                if (publicTournaments.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                          vertical: AppDimensions.xs,
                        ),
                        child: _TournamentCard(
                          tournament: publicTournaments[i],
                        ),
                      ),
                      childCount: publicTournaments.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxl),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExploreEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.xxl,
        vertical: AppDimensions.xxxl,
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.travel_explore_rounded,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppDimensions.md),
            Text('لا توجد بطولات مفتوحة الآن', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'عندما يفتح المنظمون بطولات عامة ستظهر هنا للاستكشاف.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ExploreSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.sm,
        AppDimensions.pagePadding,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
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

enum _FeaturedTournamentPresentation { hero, solid }

class _FeaturedTournamentCard extends StatelessWidget {
  final Tournament tournament;
  final _FeaturedTournamentPresentation presentation;

  const _FeaturedTournamentCard({
    required this.tournament,
    required this.presentation,
  });

  @override
  Widget build(BuildContext context) {
    final spec = tournamentVisualSpec(tournament.status);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      label: 'بطولة مميزة، ${tournament.name}، ${spec.statusLabel}',
      child: _FeaturedTournamentShell(
        key: ValueKey('featured-tournament-${tournament.id}'),
        presentation: presentation,
        child: InkWell(
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentDetailById(tournament.id)),
          child: TournamentFieldPattern(
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.sm,
                          vertical: AppDimensions.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                        child: Text(
                          'بطولة مميزة',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TournamentStatusPill(spec: spec),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IdentityVisual(
                        source: tournament.logoUrl,
                        size: 64,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        semanticLabel: 'رمز بطولة ${tournament.name}',
                        fallbackBuilder: (_) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.actionContainer,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: AppColors.actionLight,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Text(
                          tournament.name,
                          maxLines: textScale >= 1.5 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.textPrimaryTinted,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tournament.description?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      tournament.description!.trim(),
                      maxLines: textScale >= 1.5 ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.md),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          Text(
                            '${tournament.teamCount} منتخب',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'شاهد البطولة',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedTournamentShell extends StatelessWidget {
  const _FeaturedTournamentShell({
    super.key,
    required this.presentation,
    required this.child,
  });

  final _FeaturedTournamentPresentation presentation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (presentation) {
      _FeaturedTournamentPresentation.hero => El7reefGlassSurface(
        role: El7reefGlassRole.hero,
        tone: El7reefGlassTone.action,
        padding: EdgeInsets.zero,
        child: child,
      ),
      _FeaturedTournamentPresentation.solid => El7reefSolidSurface(
        tone: El7reefGlassTone.action,
        elevated: true,
        radius: 30,
        padding: EdgeInsets.zero,
        child: child,
      ),
    };
  }
}

// ══════════════════════════════════════════
// ── بطاقة الدورة المطورة بصرياً ──
// ══════════════════════════════════════════
class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  const _TournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final spec = tournamentVisualSpec(tournament.status);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showLocation = tournament.location?.trim().isNotEmpty ?? false;

    return Semantics(
      button: true,
      label:
          '${tournament.name}، ${spec.statusLabel}، ${tournament.teamCount} من ${tournament.maxTeams} فريق',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: spec.accent.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentDetailById(tournament.id)),
          child: TournamentFieldPattern(
            color: spec.accent,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TournamentStatusPill(spec: spec),
                            const SizedBox(height: AppDimensions.sm),
                            Text(
                              tournament.name,
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                              maxLines: textScale >= 1.5 ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      IdentityVisual(
                        source: tournament.logoUrl,
                        size: 48,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        semanticLabel: 'رمز بطولة ${tournament.name}',
                        fallbackBuilder: (_) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: spec.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(
                              color: spec.accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              spec.icon,
                              color: spec.accent,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    [
                      tournamentFormatLabel(tournament.format),
                      '${tournament.teamSize.value} ضد ${tournament.teamSize.value}',
                      if (showLocation) tournament.location!.trim(),
                    ].join('  •  '),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: textScale >= 1.5 ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  if (tournament.status == TournamentStatus.registration) ...[
                    Row(
                      children: [
                        Text(
                          '${tournament.teamCount}/${tournament.maxTeams} فريق',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimaryTinted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          tournament.canRegister
                              ? '${tournament.maxTeams - tournament.teamCount} أماكن متبقية'
                              : 'اكتمل العدد',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: spec.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                      child: LinearProgressIndicator(
                        value: tournament.fillRate.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceBorderStrong,
                        valueColor: AlwaysStoppedAnimation<Color>(spec.accent),
                        minHeight: 7,
                      ),
                    ),
                  ] else
                    TournamentStageRail(
                      activeIndex: spec.stageIndex,
                      accent: spec.accent,
                      semanticsLabel: spec.stageLabel,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ── نموذج إنشاء دورة مطور بصرياً ──
// ══════════════════════════════════════════
class _CreateTournamentSheet extends StatelessWidget {
  final TournamentController controller;
  const _CreateTournamentSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return El7reefGlassSurface(
      role: El7reefGlassRole.compactSheet,
      tone: El7reefGlassTone.competitive,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: controller.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // مقبض الورقة
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.competitive,
                      size: 28,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'أنشئ دورة جديدة بمجدها',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'اكتب الاسم فقط وابدأ. الإعداد الشائع جاهز ويمكنك تعديله عند الحاجة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // اسم الدورة
                TextFormField(
                  controller: controller.nameController,
                  validator: controller.validateName,
                  style: AppTextStyles.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'اسم البطولة',
                    hintText: 'مثال: كأس حي الزيتون الرمضاني',
                    prefixIcon: Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),

                Obx(
                  () => IdentityPresetField(
                    scope: IdentityPresetScope.tournament,
                    value: controller.selectedLogoUrl.value,
                    previewTitleController: controller.nameController,
                    onChanged: controller.selectLogo,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),

                AnimatedBuilder(
                  animation: controller.maxTeamsController,
                  builder: (context, _) => Obx(
                    () => _TournamentDefaultsSummary(
                      formatLabel: _compactFormatLabel(
                        controller.selectedFormat.value,
                      ),
                      teamSize: controller.selectedTeamSize.value.value,
                      maxTeams:
                          int.tryParse(controller.maxTeamsController.text) ?? 8,
                      isPublic:
                          controller.selectedVisibility.value ==
                          TournamentVisibility.public,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),

                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'خيارات متقدمة',
                      style: AppTextStyles.titleMedium,
                    ),
                    subtitle: Text(
                      'الملعب، حجم الفريق، النظام، العدد والظهور',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                      ),
                    ),
                    children: [
                      // الموقع
                      TextFormField(
                        controller: controller.locationController,
                        style: AppTextStyles.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'ملعب البطولة (اختياري)',
                          hintText: 'مثال: ملعب البلدية الخماسي',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // حجم الفريق
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_soccer_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'حجم الفريق (عدد اللاعبين)',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Obx(
                        () => Wrap(
                          spacing: AppDimensions.sm,
                          children: TournamentTeamSize.values.map((size) {
                            final selected =
                                controller.selectedTeamSize.value == size;
                            return ChoiceChip(
                              label: Text(
                                '${size.value} ضد ${size.value}',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: selected
                                      ? AppColors.textOnPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  controller.selectedTeamSize.value = size,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                                width: 1,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),

                      // نوع الدورة
                      Row(
                        children: [
                          const Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'نوع ونظام البطولة الكروية',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Obx(
                        () => Semantics(
                          container: true,
                          role: SemanticsRole.radioGroup,
                          child: Column(
                            children: TournamentFormat.values.map((f) {
                              final selected =
                                  controller.selectedFormat.value == f;
                              return Semantics(
                                checked: selected,
                                inMutuallyExclusiveGroup: true,
                                child: GestureDetector(
                                  onTap: () =>
                                      controller.selectedFormat.value = f,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(
                                      bottom: AppDimensions.sm,
                                    ),
                                    padding: const EdgeInsets.all(
                                      AppDimensions.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primarySurface
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.surfaceBorder,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                          size: 22,
                                        ),
                                        const SizedBox(width: AppDimensions.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatLabel(f),
                                                style: AppTextStyles.titleMedium
                                                    .copyWith(
                                                      color: selected
                                                          ? AppColors.primary
                                                          : AppColors
                                                                .textPrimary,
                                                      fontWeight: selected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatDesc(f),
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),

                      // عدد الفرق
                      TextFormField(
                        controller: controller.maxTeamsController,
                        validator: controller.validateMaxTeams,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للفرق المشاركة',
                          hintText: 'مثال: 8 أو 16 فريق',
                          prefixIcon: Icon(
                            Icons.groups_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),

                      Row(
                        children: [
                          const Icon(
                            Icons.visibility_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ظهور البطولة',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Obx(
                        () => Semantics(
                          container: true,
                          role: SemanticsRole.radioGroup,
                          child: Column(
                            children: [
                              _buildVisibilityOption(
                                visibility: TournamentVisibility.public,
                                label: 'عامة وتظهر في الاستكشاف',
                                description:
                                    'مناسبة للبطولات المفتوحة؛ تظهر للفرق في شاشة استكشف.',
                              ),
                              _buildVisibilityOption(
                                visibility: TournamentVisibility.private,
                                label: 'خاصة ولا تظهر في الاستكشاف',
                                description:
                                    'مناسبة للبطولات التي تديرها بالدعوات أو الروابط المباشرة.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                Obx(() {
                  final message = controller.createTournamentErrorMessage.value;
                  if (message.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.md),
                    child: Semantics(
                      liveRegion: true,
                      child: El7reefSurface(
                        color: AppColors.errorSurfaceSolid,
                        borderColor: AppColors.error.withValues(alpha: 0.55),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: Text(
                                message,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                Obx(
                  () => El7reefButton(
                    text: 'أنشئ البطولة',
                    icon: Icons.check_circle_outline,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.createTournament,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLabel(TournamentFormat f) => switch (f) {
    TournamentFormat.groupsOnly => 'دور مجموعات فقط (مباريات دورية)',
    TournamentFormat.knockoutOnly => 'إقصاء مباشر (خروج المغلوب)',
    TournamentFormat.groupsThenKnockout => 'مجموعات تليها مرحلة الإقصائيات',
  };

  String _formatDesc(TournamentFormat f) => switch (f) {
    TournamentFormat.groupsOnly =>
      'تلعب جميع الفرق ضد بعضها ويتم تحديد الفائز بالنقاط.',
    TournamentFormat.knockoutOnly =>
      'الخاسر يخرج فوراً وتستمر الفرق في التأهل حتى النهائي.',
    TournamentFormat.groupsThenKnockout =>
      'النظام الكلاسيكي الأكثر إثارة؛ مجموعات تمهد للتصفيات النارية.',
  };

  String _compactFormatLabel(TournamentFormat f) => switch (f) {
    TournamentFormat.groupsOnly => 'مجموعات',
    TournamentFormat.knockoutOnly => 'إقصائيات',
    TournamentFormat.groupsThenKnockout => 'مجموعات ثم إقصائيات',
  };

  Widget _buildVisibilityOption({
    required TournamentVisibility visibility,
    required String label,
    required String description,
  }) {
    final selected = controller.selectedVisibility.value == visibility;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: () => controller.selectedVisibility.value = visibility,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.background,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.surfaceBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$count بطولة',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
