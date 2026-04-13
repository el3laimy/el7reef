import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/tournament.dart';
import '../controllers/tournament_controller.dart';
import 'tournament_detail_screen.dart';

/// شاشة الدورات — القائمة الرئيسية
class TournamentListScreen extends GetView<TournamentController> {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدورات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: controller.loadLiveTournaments,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value &&
              controller.liveTournaments.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadLiveTournaments,
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // ── زر إنشاء دورة ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    child: El7reefButton(
                      text: 'أنشئ دورة جديدة',
                      icon: Icons.emoji_events_rounded,
                      onPressed: () => _showCreateSheet(context),
                    ).animate().fadeIn(duration: 400.ms),
                  ),
                ),

                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pagePadding),
                    child: Row(
                      children: [
                        Text('الدورات الجارية',
                            style: AppTextStyles.titleLarge),
                        const Spacer(),
                        Obx(() => _CountBadge(
                            count: controller.liveTournaments.length)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.sm)),

                // ── القائمة ──
                controller.liveTournaments.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmpty())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.pagePadding,
                              vertical: AppDimensions.xs,
                            ),
                            child: _TournamentCard(
                              tournament: controller.liveTournaments[i],
                              index: i,
                            ),
                          ),
                          childCount: controller.liveTournaments.length,
                        ),
                      ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xxl)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.xxl),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppDimensions.md),
          Text('ما فيش دورات دلوقتي', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text('كن أول من ينظم!', style: AppTextStyles.bodyMedium),
        ],
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

// ══════════════════════════════════════════
// ── بطاقة الدورة ──
// ══════════════════════════════════════════
class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final int index;
  const _TournamentCard({required this.tournament, required this.index});

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String statusLabel) = _statusInfo(tournament.status);

    return GestureDetector(
      onTap: () => Get.to(() => TournamentDetailScreen(tournament: tournament)),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Expanded(
                  child: Text(tournament.name,
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusBadge(color: statusColor, label: statusLabel),
              ],
            ),

            const SizedBox(height: AppDimensions.sm),

            // ── تفاصيل ──
            Row(
              children: [
                _InfoChip(
                  icon: Icons.groups_rounded,
                  label:
                      '${tournament.teamCount}/${tournament.maxTeams} فريق',
                ),
                const SizedBox(width: AppDimensions.sm),
                _InfoChip(
                  icon: Icons.sports_soccer,
                  label: '${tournament.teamSize.value}v${tournament.teamSize.value}',
                ),
                if (tournament.location != null) ...[
                  const SizedBox(width: AppDimensions.sm),
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: tournament.location!,
                    maxWidth: 90,
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppDimensions.sm),

            // ── شريط الامتلاء ──
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: LinearProgressIndicator(
                value: tournament.fillRate.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceBorder,
                valueColor:
                    AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 4,
              ),
            ),

            if (tournament.isFantasyEnabled) ...[
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppColors.secondary, size: 14),
                  const SizedBox(width: 4),
                  Text('الفانتازي مفعَّل',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: (80 * index).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  (Color, String) _statusInfo(TournamentStatus s) => switch (s) {
    TournamentStatus.upcoming => (AppColors.textMuted, '⏳ قريباً'),
    TournamentStatus.registration => (AppColors.success, '✅ تسجيل مفتوح'),
    TournamentStatus.groupStage => (AppColors.primary, '🔵 مجموعات'),
    TournamentStatus.transferWindow => (AppColors.secondary, '🔄 نافذة تغيير'),
    TournamentStatus.knockoutStage => (AppColors.error, '⚡ إقصاء'),
    TournamentStatus.completed => (AppColors.textMuted, '🏆 منتهية'),
    TournamentStatus.cancelled => (AppColors.error, '❌ ملغاة'),
  };
}

// ── نموذج إنشاء دورة ──
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
            top: Radius.circular(AppDimensions.radiusXl)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: controller.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مقبض
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
              Text('أنشئ دورة جديدة 🏆', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.lg),

              // اسم الدورة
              TextFormField(
                controller: controller.nameController,
                validator: controller.validateName,
                decoration: const InputDecoration(
                  labelText: 'اسم الدورة',
                  hintText: 'مثال: كأس حي الزيتون',
                  prefixIcon: Icon(Icons.emoji_events_outlined,
                      color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // الموقع
              TextFormField(
                controller: controller.locationController,
                decoration: const InputDecoration(
                  labelText: 'الموقع (اختياري)',
                  hintText: 'مثال: ملعب البلدية',
                  prefixIcon:
                      Icon(Icons.location_on_outlined, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // حجم الفريق
              Text('حجم الفريق', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppDimensions.xs),
              Obx(() => Wrap(
                    spacing: AppDimensions.sm,
                    children: TournamentTeamSize.values.map((size) {
                      final selected =
                          controller.selectedTeamSize.value == size;
                      return ChoiceChip(
                        label: Text('${size.value}v${size.value}'),
                        selected: selected,
                        onSelected: (_) =>
                            controller.selectedTeamSize.value = size,
                        selectedColor: AppColors.primarySurface,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: AppDimensions.md),

              // نوع الدورة
              Text('نوع الدورة', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppDimensions.xs),
              Obx(() => Column(
                    children: TournamentFormat.values.map((f) {
                      final selected =
                          controller.selectedFormat.value == f;
                      return GestureDetector(
                        onTap: () => controller.selectedFormat.value = f,
                        child: Container(
                          margin: const EdgeInsets.only(
                              bottom: AppDimensions.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md,
                            vertical: AppDimensions.sm,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primarySurface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surfaceBorder,
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
                                size: 20,
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Text(_formatLabel(f),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: AppDimensions.md),

              // عدد الفرق
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller.maxTeamsController,
                      validator: controller.validateMaxTeams,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد الفرق',
                        prefixIcon: Icon(Icons.groups_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  // تفعيل الفانتازي
                  Obx(() => Column(
                        children: [
                          Switch(
                            value: controller.isFantasyEnabled.value,
                            onChanged: (v) =>
                                controller.isFantasyEnabled.value = v,
                            thumbColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.secondary;
                              }
                              return AppColors.textMuted;
                            }),
                            trackColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.secondary
                                    .withValues(alpha: 0.4);
                              }
                              return AppColors.surfaceBorder;
                            }),
                          ),
                          Text('فانتازي', style: AppTextStyles.labelSmall),
                        ],
                      )),
                ],
              ),
              const SizedBox(height: AppDimensions.xl),

              Obx(() => El7reefButton(
                    text: 'إنشاء الدورة',
                    icon: Icons.check_circle_outline,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.createTournament,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLabel(TournamentFormat f) => switch (f) {
    TournamentFormat.groupsOnly => 'مجموعات فقط (Round Robin)',
    TournamentFormat.knockoutOnly => 'إقصاء مباشر',
    TournamentFormat.groupsThenKnockout => 'مجموعات ثم إقصاء',
  };
}

// ── مكونات مساعدة ──
class _StatusBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;
  const _InfoChip({required this.icon, required this.label, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 120),
          child: Text(label,
              style: AppTextStyles.labelSmall,
              overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text('$count دورة',
          style:
              AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
    );
  }
}
