import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/player.dart';
import '../controllers/score_submit_controller.dart';

class ScoreSubmitScreen extends StatelessWidget {
  const ScoreSubmitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller is initialized and retrieved via routing bindings usually,
    // or passed via Get.put directly. Here we assume it's created during navigation.
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
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return Column(
            children: [
              SizedBox(height: Get.mediaQuery.padding.top + kToolbarHeight + 10),
              
              // Score Header Auto-calculation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                child: GlassmorphicContainer(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  borderRadius: AppDimensions.radiusLg,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('🔵 فريق A', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 8),
                          Text('${controller.totalTeamAGoals}', style: AppTextStyles.displayLarge.copyWith(color: AppColors.primary)),
                        ],
                      ),
                      Text('VS', style: AppTextStyles.headlineMedium),
                      Column(
                        children: [
                          Text('🔴 فريق B', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 8),
                          Text('${controller.totalTeamBGoals}', style: AppTextStyles.displayLarge.copyWith(color: AppColors.error)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.pagePadding,
                    right: AppDimensions.pagePadding,
                    bottom: 120, // space for sticky button
                  ),
                  children: [
                    Text('الفريق A', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppDimensions.sm),
                    ...controller.teamAPlayers.map((p) => _buildPlayerStatRow(p, controller)),
                    
                    const SizedBox(height: AppDimensions.xl),
                    
                    Text('الفريق B', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppDimensions.sm),
                    ...controller.teamBPlayers.map((p) => _buildPlayerStatRow(p, controller)),

                    const SizedBox(height: AppDimensions.xl),
                    Text('أفضل لاعب (MVP)', style: AppTextStyles.headlineMedium),
                    const SizedBox(height: AppDimensions.sm),
                    _buildMvpSelector(controller),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
        child: SizedBox(
          width: double.infinity,
          child: El7reefButton(
            text: 'اعتماد التشكيلة والنتيجة ⚽',
            isLoading: controller.isLoading.value,
            onPressed: controller.submit,
          ),
        ),
      )),
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
                      onTap: () => controller.toggleCard(player.id, 'yellowCard'),
                      child: Container(
                        width: 16, height: 24,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: st['yellowCard'] == true ? Colors.yellow : AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.toggleCard(player.id, 'redCard'),
                      child: Container(
                        width: 16, height: 24,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: st['redCard'] == true ? Colors.red : AppColors.surfaceBorder,
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

  Widget _buildStatCounter(String label, String key, String playerId, ScoreSubmitController controller) {
    return Obx(() {
      final val = controller.playerStats[playerId]?[key] ?? 0;
      return Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
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
          onSelected: (_) => controller.selectedMvpId.value = isSelected ? '' : p.id,
          selectedColor: AppColors.primarySurface,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(color: isSelected ? AppColors.secondary : AppColors.textPrimary),
        );
      }).toList(),
    );
  }
}
