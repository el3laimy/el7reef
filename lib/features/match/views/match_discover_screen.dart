import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/match.dart';
import '../controllers/match_controller.dart';

/// شاشة اكتشاف المباريات المتاحة + إنشاء مباراة جديدة
class MatchDiscoverScreen extends GetView<MatchController> {
  const MatchDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المباريات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: controller.loadLiveMatches,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.liveMatches.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadLiveMatches,
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // ── زر إنشاء مباراة ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: El7reefButton(
                      text: 'ابدأ مباراة جديدة',
                      icon: Icons.sports_soccer,
                      onPressed: () => _showCreateMatchSheet(context),
                    ).animate().fadeIn(duration: 400.ms),
                  ),
                ),

                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    child: Row(
                      children: [
                        Text('المباريات الجارية',
                            style: AppTextStyles.titleLarge),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${controller.liveMatches.length} مباراة',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),

                // ── قائمة المباريات ──
                controller.liveMatches.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.pagePadding,
                              vertical: AppDimensions.xs,
                            ),
                            child: _MatchCard(
                              match: controller.liveMatches[index],
                              index: index,
                              controller: controller,
                            ),
                          ),
                          childCount: controller.liveMatches.length,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.xxl),
      child: Column(
        children: [
          const Text('⚽', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppDimensions.md),
          Text('ما فيش مباريات دلوقتي', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text('كن أول من يبدأ!', style: AppTextStyles.bodyMedium),
        ],
      ).animate().fadeIn(),
    );
  }

  void _showCreateMatchSheet(BuildContext context) {
    Get.bottomSheet(
      _CreateMatchSheet(controller: controller),
      isScrollControlled: true,
    );
  }
}

/// بطاقة المباراة
class _MatchCard extends StatelessWidget {
  final Match match;
  final int index;
  final MatchController controller;

  const _MatchCard({
    required this.match,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOrganizer = match.organizerId ==
        controller.authService.currentUserId;
    final canOpenMatchday =
        isOrganizer || match.isOrganized || match.teamAId != null || match.teamBId != null;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              _StatusBadge(status: match.status),
              const Spacer(),
              if (match.isGoldenRating)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text('⭐ ذهبي', style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                ),
              if (match.isFrozen) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock, color: AppColors.textMuted, size: 18),
              ],
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── الفريقان ──
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('🔵', style: TextStyle(fontSize: 28)),
                    Text(
                      '${match.teamAPlayerIds.length} لاعب',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (match.scoreTeamA != null && match.scoreTeamB != null)
                    Text(
                      '${match.scoreTeamA} - ${match.scoreTeamB}',
                      style: AppTextStyles.ratingMedium.copyWith(fontSize: 24),
                    )
                  else
                    Text('vs', style: AppTextStyles.headlineMedium),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('🔴', style: TextStyle(fontSize: 28)),
                    Text(
                      '${match.teamBPlayerIds.length} لاعب',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          if (canOpenMatchday)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: OutlinedButton.icon(
                onPressed: () =>
                    Get.toNamed(AppRoutes.matchDetailsById(match.id)),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('إدارة يوم المباراة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),

          // ── زر تصويت الجماهير (Fan Voting) ──
          if (match.status == MatchStatus.completed ||
              match.status == MatchStatus.pendingReview ||
              match.status == MatchStatus.settled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: OutlinedButton.icon(
                onPressed: () =>
                    Get.toNamed(AppRoutes.mvpVoteForMatch(match.id)),
                icon: const Icon(Icons.star_border_purple500, size: 18),
                label: const Text('تصويت رجل المباراة (الجماهير)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                ),
              ),
            ),

          // ── أزرار المنظم ──
          if (isOrganizer && !match.isFrozen && match.status == MatchStatus.live)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.scoreApprovalForMatch(match.id)),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('سجّل النتيجة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => controller.freezeMatch(match.id),
                  icon: const Icon(Icons.lock_outline, color: AppColors.error),
                  tooltip: 'تجميد',
                ),
                IconButton(
                  onPressed: () => controller.activateGoldenRating(match.id),
                  icon: const Icon(Icons.star_outline, color: AppColors.secondary),
                  tooltip: 'تقييم ذهبي',
                ),
              ],
            ),

          // ── زر إلغاء المباراة (للمنظم فقط) ──
          if (isOrganizer && match.status == MatchStatus.open)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.sm),
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancel(context),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('إلغاء المباراة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),

          if (isOrganizer &&
              (match.status == MatchStatus.completed ||
                  match.status == MatchStatus.pendingReview))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => controller.approveScore(match.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  match.status == MatchStatus.pendingReview
                      ? 'اعتماد بعد المراجعة'
                      : 'اعتماد النتيجة',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: (80 * index).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  void _confirmCancel(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('إلغاء المباراة'),
        content: const Text('هل أنت متأكد من إلغاء هذه المباراة؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.cancelMatch(match.id);
            },
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

/// Badge حالة المباراة
class _StatusBadge extends StatelessWidget {
  final MatchStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      MatchStatus.open => (AppColors.success, '🟢 مفتوحة'),
      MatchStatus.live => (AppColors.primary, '🔵 جارية'),
      MatchStatus.completed => (AppColors.secondary, '⏳ بانتظار الاعتماد'),
      MatchStatus.settled => (AppColors.textMuted, '✅ منتهية'),
      MatchStatus.pendingReview => (AppColors.warning, '🟠 قيد المراجعة'),
      MatchStatus.frozen => (AppColors.error, '🔒 مجمدة'),
      MatchStatus.full => (AppColors.accent, '🔴 مكتملة'),
      MatchStatus.cancelled => (AppColors.error, '❌ ملغاة'),
      _ => (AppColors.textMuted, '⏸ معلقة'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

/// Sheet إنشاء مباراة
class _CreateMatchSheet extends StatelessWidget {
  final MatchController controller;
  _CreateMatchSheet({required this.controller});

  final _locationController = TextEditingController();
  final _selectedTeamSize = 5.obs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.lg,
      ).copyWith(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
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
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text('ابدأ مباراة جديدة ⚽', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'أنشئ المباراة وادعُ اللاعبين للانضمام',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.lg),

          // ── المكان ──
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'المكان (اختياري)',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // ── عدد اللاعبين ──
          Text('عدد اللاعبين لكل فريق', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppDimensions.sm),
          Obx(() => Row(
            children: [5, 6, 7, 11].map((size) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('$size v $size'),
                  selected: _selectedTeamSize.value == size,
                  onSelected: (_) => _selectedTeamSize.value = size,
                  selectedColor: AppColors.primarySurface,
                ),
              ),
            )).toList(),
          )),
          const SizedBox(height: AppDimensions.lg),

          Obx(() => El7reefButton(
                text: 'إنشاء المباراة',
                icon: Icons.play_arrow_rounded,
                isLoading: controller.isLoading.value,
                onPressed: () async {
                  final uid = controller.authService.currentUserId;
                  if (uid == null) return;
                  final matchId = await controller.createMatch(
                    teamAIds: [uid],
                    teamBIds: [],
                    location: _locationController.text.trim().isNotEmpty
                        ? _locationController.text.trim()
                        : null,
                    teamSize: _selectedTeamSize.value,
                  );
                  Get.back();
                  if (matchId != null) {
                    Get.toNamed('/match/lobby/$matchId');
                  }
                },
              )),
        ],
      ),
    );
  }
}
