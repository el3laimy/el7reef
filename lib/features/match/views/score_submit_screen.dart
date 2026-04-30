import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';
import '../controllers/score_submit_controller.dart';

class ScoreSubmitScreen extends StatelessWidget {
  const ScoreSubmitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScoreSubmitController controller = Get.find<ScoreSubmitController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إحصائيات المباراة وتأكيد النتيجة'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.teamAPlayers.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.match.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Text(
                  controller.errorMessage.value,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: Get.mediaQuery.padding.top + kToolbarHeight + 10,
              ),
              controller.isFriendlyMatch
                  ? _buildFriendlyScoreInput(controller)
                  : _buildRegisteredScoreHeader(controller),
              const SizedBox(height: AppDimensions.lg),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.pagePadding,
                    right: AppDimensions.pagePadding,
                    bottom: 120, // space for sticky button
                  ),
                  children: [
                    Text(
                      controller.teamASideName.value,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (controller.teamAPlayers.isEmpty)
                      _buildNoRegisteredPlayersNote()
                    else
                      ...controller.teamAPlayers.map(
                        (p) => _buildPlayerStatRow(p, controller),
                      ),

                    const SizedBox(height: AppDimensions.xl),

                    Text(
                      controller.teamBSideName.value,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (controller.teamBPlayers.isEmpty)
                      _buildNoRegisteredPlayersNote()
                    else
                      ...controller.teamBPlayers.map(
                        (p) => _buildPlayerStatRow(p, controller),
                      ),

                    const SizedBox(height: AppDimensions.xl),
                    if (controller.teamAPlayers.isNotEmpty ||
                        controller.teamBPlayers.isNotEmpty) ...[
                      Text(
                        'أفضل لاعب (MVP)',
                        style: AppTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      _buildMvpSelector(controller),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePadding,
          ),
          child: SizedBox(
            width: double.infinity,
            child: El7reefButton(
              text: 'حفظ النتيجة ⚽',
              isLoading: controller.isLoading.value,
              onPressed: () {
                _handleSubmit(context, controller);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    ScoreSubmitController controller,
  ) async {
    final updatedMatch = await controller.submit();
    if (updatedMatch == null || !context.mounted) return;

    Get.bottomSheet(
      _ResultSubmitSuccessSheet(
        scoreLine: _scoreLine(updatedMatch, controller),
        onShareResult: () {
          Get.back();
          Get.offNamed(AppRoutes.matchResultLineupById(updatedMatch.id));
        },
        onReturnToMatch: () {
          Get.back();
          Get.back(result: updatedMatch);
        },
      ),
      isScrollControlled: true,
    );
  }

  String? _scoreLine(Match match, ScoreSubmitController controller) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    if (scoreA == null || scoreB == null) return null;
    return '${controller.teamASideName.value} $scoreA - $scoreB ${controller.teamBSideName.value}';
  }

  Widget _buildFriendlyScoreInput(ScoreSubmitController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('النتيجة النهائية', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'أدخل نتيجة الفريقين مباشرة. إحصائيات اللاعبين اختيارية للمسجلين فقط.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: _buildTeamScoreField(
                    label: controller.teamASideName.value,
                    color: AppColors.primary,
                    textController: controller.teamAScoreController,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                  ),
                  child: Text('VS', style: AppTextStyles.titleLarge),
                ),
                Expanded(
                  child: _buildTeamScoreField(
                    label: controller.teamBSideName.value,
                    color: AppColors.error,
                    textController: controller.teamBScoreController,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredScoreHeader(ScoreSubmitController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  controller.teamASideName.value,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.totalTeamAGoals}',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            Text('VS', style: AppTextStyles.headlineMedium),
            Column(
              children: [
                Text(
                  controller.teamBSideName.value,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.totalTeamBGoals}',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreField({
    required String label,
    required Color color,
    required TextEditingController textController,
  }) {
    return TextField(
      controller: textController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: AppTextStyles.displayLarge.copyWith(color: color),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildNoRegisteredPlayersNote() {
    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Text(
        'لا يوجد لاعبون مسجلون لهذا الطرف. اللاعبون المؤقتون لا تُسجل لهم إحصائيات.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildPlayerStatRow(Player player, ScoreSubmitController controller) {
    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(player.name, style: AppTextStyles.titleMedium),
              const Spacer(),
              // Cards indicator
              Obx(() {
                final st = controller.playerStats[player.id]!;
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          controller.toggleCard(player.id, 'yellowCard'),
                      child: Container(
                        width: 16,
                        height: 24,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: st['yellowCard'] == true
                              ? Colors.yellow
                              : AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.toggleCard(player.id, 'redCard'),
                      child: Container(
                        width: 16,
                        height: 24,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: st['redCard'] == true
                              ? Colors.red
                              : AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCounter('أهداف', 'goals', player.id, controller),
              _buildStatCounter('أسيست', 'assists', player.id, controller),
              _buildStatCounter('تصدي', 'saves', player.id, controller),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildStatCounter(
    String label,
    String key,
    String playerId,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final val = controller.playerStats[playerId]?[key] ?? 0;
      return Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            children: [
              _btn(Icons.remove, () => controller.decrementStat(playerId, key)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$val', style: AppTextStyles.titleLarge),
              ),
              _btn(Icons.add, () => controller.incrementStat(playerId, key)),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildMvpSelector(ScoreSubmitController controller) {
    final allPlayers = [...controller.teamAPlayers, ...controller.teamBPlayers];
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: allPlayers.map((p) {
        final isSelected = controller.selectedMvpId.value == p.id;
        return ChoiceChip(
          label: Text(p.name),
          selected: isSelected,
          onSelected: (_) =>
              controller.selectedMvpId.value = isSelected ? '' : p.id,
          selectedColor: AppColors.primarySurface,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.secondary : AppColors.textPrimary,
          ),
        );
      }).toList(),
    );
  }
}

class _ResultSubmitSuccessSheet extends StatelessWidget {
  final String? scoreLine;
  final VoidCallback onShareResult;
  final VoidCallback onReturnToMatch;

  const _ResultSubmitSuccessSheet({
    required this.scoreLine,
    required this.onShareResult,
    required this.onReturnToMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
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
              Text('تم تسجيل النتيجة ✅', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'النتيجة جاهزة للمشاركة مع اللاعبين.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (scoreLine != null) ...[
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    scoreLine!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              FilledButton.icon(
                onPressed: onShareResult,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('مشاركة النتيجة'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextButton(
                onPressed: onReturnToMatch,
                child: const Text('العودة للمباراة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
