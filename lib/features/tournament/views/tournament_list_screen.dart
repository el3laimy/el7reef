import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../domain/entities/tournament.dart';
import '../controllers/tournament_controller.dart';

/// شاشة بطولاتي — لا تعرض بطولات عامة عشوائية داخل مساحة المستخدم الشخصية
class TournamentListScreen extends GetView<TournamentController> {
  const TournamentListScreen({super.key});

  // ── فلتر الحالات التفاعلي (مجعول static لتمكين الـ const constructor) ──
  static final RxString _selectedFilter = 'all'.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بطولاتي 🏆'),
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

          return RefreshIndicator(
            onRefresh: controller.loadMyTournaments,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── ترويسة الشاشة الجذابة (Hero Header) ──
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.md,
                    ),
                    padding: const EdgeInsets.all(AppDimensions.cardPadding),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.backgroundLight,
                          AppColors.backgroundDeep,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بطولاتك أنت ⚽',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'هنا تظهر البطولات التي تنظمها أو يشارك فيها فريقك. البطولات العامة لها مساحة استكشاف منفصلة.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryTinted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                ),

                // ── إجراءات بطولاتي ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.xs,
                    ),
                    child: Column(
                      children: [
                        El7reefButton(
                          text: 'استكشف بطولات مفتوحة',
                          icon: Icons.travel_explore_rounded,
                          onPressed: () =>
                              Get.toNamed(AppRoutes.tournamentExplore),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        El7reefButton(
                          text: 'أنشئ دورة جديدة الآن',
                          icon: Icons.add_circle_outline_rounded,
                          onPressed: () => _showCreateSheet(context),
                        ),
                      ],
                    ).animate().fadeIn(duration: 450.ms),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.md),
                ),

                // ── شريط الفلترة التفاعلي (Chips) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip(label: 'كل بطولاتي', filter: 'all'),
                          const SizedBox(width: AppDimensions.sm),
                          _buildFilterChip(
                            label: '✅ تسجيل مفتوح',
                            filter: 'registration',
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          _buildFilterChip(
                            label: '🔵 جارية الآن',
                            filter: 'active',
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          _buildFilterChip(
                            label: '🏆 منتهية',
                            filter: 'completed',
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.md),
                ),

                // ── عدد البطولات المصنفة ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getFilterTitle(),
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _CountBadge(count: filteredList.length),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.sm),
                ),

                // ── قائمة البطولات المفلترة ──
                filteredList.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmpty(compact: followedList.isNotEmpty),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.pagePadding,
                              vertical: AppDimensions.xs,
                            ),
                            child: _TournamentCard(
                              tournament: filteredList[i],
                              index: i,
                            ),
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
                        child: _TournamentCard(
                          tournament: followedList[i],
                          index: filteredList.length + i,
                        ),
                      ),
                      childCount: followedList.length,
                    ),
                  ),
                ],

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

  Widget _buildEmpty({bool compact = false}) {
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
              child: const Text('🏆', style: TextStyle(fontSize: 64)),
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
              _selectedFilter.value == 'all'
                  ? 'يمكنك إنشاء بطولة جديدة أو استكشاف البطولات المفتوحة بإرادتك.'
                  : 'لا توجد بطولات تطابق هذا التصنيف حالياً.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  void _showCreateSheet(BuildContext context) {
    Get.bottomSheet(
      _CreateTournamentSheet(controller: controller),
      isScrollControlled: true,
    );
  }
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
                            'بطولات عامة يمكنك متابعتها أو تسجيل فريقك فيها',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            'هذه ليست قائمة بطولاتك الشخصية. اختر بطولة وافتح تفاصيلها للمشاهدة أو التسجيل.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryTinted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (tournaments.isEmpty)
                  SliverToBoxAdapter(child: _buildExploreEmpty())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                          vertical: AppDimensions.xs,
                        ),
                        child: _TournamentCard(
                          tournament: tournaments[i],
                          index: i,
                        ),
                      ),
                      childCount: tournaments.length,
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

// ══════════════════════════════════════════
// ── بطاقة الدورة المطورة بصرياً ──
// ══════════════════════════════════════════
class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final int index;
  const _TournamentCard({required this.tournament, required this.index});

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String statusLabel) = _statusInfo(
      tournament.status,
    );
    final isReg = tournament.status == TournamentStatus.registration;
    final isCompleted = tournament.status == TournamentStatus.completed;

    // تحديد إطار ولمعة الكارد بناءً على الحالة
    final Color cardBorderColor = isReg
        ? AppColors.primary.withValues(alpha: 0.35)
        : isCompleted
        ? AppColors.secondary.withValues(alpha: 0.25)
        : AppColors.surfaceBorder;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.tournamentDetailById(tournament.id)),
      child: El7reefSurface(
        elevated: isReg,
        borderColor: cardBorderColor,
        padding: const EdgeInsets.all(AppDimensions.md),
        margin: const EdgeInsets.only(bottom: AppDimensions.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── العنوان والحالة ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    tournament.name,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(color: statusColor, label: statusLabel),
              ],
            ),

            const SizedBox(height: AppDimensions.sm),

            // ── تفاصيل الدورة (Chips) ──
            Row(
              children: [
                _InfoChip(
                  icon: Icons.groups_rounded,
                  label: '${tournament.teamCount}/${tournament.maxTeams} فريق',
                ),
                const SizedBox(width: AppDimensions.md),
                _InfoChip(
                  icon: Icons.sports_soccer_rounded,
                  label:
                      '${tournament.teamSize.value} ضد ${tournament.teamSize.value}',
                ),
                if (tournament.location != null) ...[
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: tournament.location!,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppDimensions.md),

            // ── شريط التقدم لامتلاء البطولة ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusFull,
                    ),
                    child: LinearProgressIndicator(
                      value: tournament.fillRate.clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Text(
                  '${(tournament.fillRate * 100).toInt()}%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            // شارات الميزات الإضافية (مثل الفانتازي)
            if (FeatureFlags.fantasyUiEnabled &&
                tournament.isFantasyEnabled) ...[
              const SizedBox(height: AppDimensions.sm),
              const Divider(color: AppColors.surfaceBorder, height: 1),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.secondary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'دوري الفانتازي مفعَّل بصورة رسمية',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: (60 * index).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  (Color, String) _statusInfo(TournamentStatus s) => switch (s) {
    TournamentStatus.upcoming => (AppColors.textMuted, '⏳ قريباً'),
    TournamentStatus.registration => (AppColors.success, '✅ تسجيل مفتوح'),
    TournamentStatus.groupStage => (AppColors.primary, '🔵 مجموعات'),
    TournamentStatus.transferWindow => (
      AppColors.secondary,
      '🔄 نافذة انتقالات',
    ),
    TournamentStatus.knockoutStage => (AppColors.error, '⚡ إقصاء مباشر'),
    TournamentStatus.completed => (
      AppColors.secondary,
      '🏆 منتهية بتثبيت البطل',
    ),
    TournamentStatus.cancelled => (AppColors.error, '❌ ملغاة'),
  };
}

// ══════════════════════════════════════════
// ── نموذج إنشاء دورة مطور بصرياً ──
// ══════════════════════════════════════════
class _CreateTournamentSheet extends StatelessWidget {
  final TournamentController controller;
  const _CreateTournamentSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
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
                    const Text('🏆', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      'أنشئ دورة جديدة بمجدها',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'أدخل التفاصيل ووزع الفرق والعب البطولة الشعبية.',
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
                    Text(
                      'حجم الفريق (عدد اللاعبين)',
                      style: AppTextStyles.titleMedium,
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
                    Text(
                      'نوع ونظام البطولة الكروية',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Obx(
                  () => Column(
                    children: TournamentFormat.values.map((f) {
                      final selected = controller.selectedFormat.value == f;
                      return GestureDetector(
                        onTap: () => controller.selectedFormat.value = f,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.sm,
                          ),
                          padding: const EdgeInsets.all(AppDimensions.md),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatLabel(f),
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
                                      _formatDesc(f),
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
                      );
                    }).toList(),
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
                    Text('ظهور البطولة', style: AppTextStyles.titleMedium),
                  ],
                ),
                const SizedBox(height: AppDimensions.xs),
                Obx(
                  () => Column(
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
                const SizedBox(height: AppDimensions.xl),

                Obx(
                  () => El7reefButton(
                    text: 'إنشاء الدورة وبدء المغامرة',
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

  Widget _buildVisibilityOption({
    required TournamentVisibility visibility,
    required String label,
    required String description,
  }) {
    final selected = controller.selectedVisibility.value == visibility;
    return GestureDetector(
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
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    );
  }
}

// ── مكونات مساعدة مطورة ──
class _StatusBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondaryTinted,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
