import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/player.dart';
import '../controllers/fan_voting_controller.dart';

class FanVotingScreen extends StatelessWidget {
  const FanVotingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FanVotingController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('تصويت الجماهير (MOM)', style: AppTextStyles.titleLarge),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.players.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return _buildMessage(
              icon: Icons.error_outline,
              color: AppColors.error,
              title: 'تعذر التصويت',
              message: controller.errorMessage.value,
            );
          }

          if (controller.hasVoted.value ||
              controller.successMessage.value.isNotEmpty) {
            return _buildMessage(
              icon: Icons.how_to_vote,
              color: AppColors.success,
              title: 'شكراً لمشاركتك!',
              message: controller.successMessage.value.isNotEmpty
                  ? controller.successMessage.value
                  : 'لقد قمت بالتصويت مسبقاً لرجل المباراة في هذا اللقاء.',
            );
          }

          if (controller.session.value?.isClosed ?? true) {
            return _buildMessage(
              icon: Icons.timer_off_outlined,
              color: AppColors.warning,
              title: 'انتهى التصويت',
              message: 'تم إغلاق نافذة التصويت الجماهيري لهذه المباراة.',
            );
          }

          if (controller.session.value?.isOpen == false) {
            return _buildMessage(
              icon: Icons.lock_clock_outlined,
              color: AppColors.warning,
              title: 'التصويت غير متاح',
              message: 'التصويت لم يفتح بعد لهذه المباراة.',
            );
          }

          if (controller.players.isEmpty) {
            return _buildMessage(
              icon: Icons.group_off_outlined,
              color: AppColors.warning,
              title: 'التصويت غير متاح',
              message: 'لا يوجد لاعبون مسجلون مؤهلون للتصويت في هذه المباراة.',
            );
          }

          return SafeArea(
            child: Column(
              children: [
                _buildTimerHeader(controller),
                const SizedBox(height: AppDimensions.md),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppDimensions.sm,
                          mainAxisSpacing: AppDimensions.sm,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: controller.players.length,
                    itemBuilder: (context, index) {
                      final p = controller.players[index];
                      return _buildPlayerCard(p, controller)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 50 * index))
                          .slideY(begin: 0.1);
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimerHeader(FanVotingController controller) {
    return GlassmorphicContainer(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      padding: const EdgeInsets.all(AppDimensions.lg),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        children: [
          Text('الوقت المتبقي لغلق التصويت', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
                controller.timeRemaining.value,
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 2,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1,
                end: 1.02,
                duration: const Duration(seconds: 1),
              ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player, FanVotingController controller) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surfaceBorder,
            child: Text(
              player.name.substring(0, 1).toUpperCase(),
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            player.name,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: El7reefButton(
              text: 'صوّت',
              onPressed: () => _confirmVote(Get.context!, player, controller),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmVote(
    BuildContext context,
    Player player,
    FanVotingController controller,
  ) {
    Get.defaultDialog(
      title: 'تأكيد التصويت',
      titleStyle: AppTextStyles.headlineMedium,
      middleText:
          'هل أنت متأكد من منح صوتك لـ ${player.name}؟ هذا الإجراء لا يمكن التراجع عنه.',
      middleTextStyle: AppTextStyles.bodyMedium,
      backgroundColor: AppColors.surface,
      radius: AppDimensions.radiusMd,
      textConfirm: 'نعم، صوّت',
      textCancel: 'إلغاء',
      confirmTextColor: AppColors.textPrimary,
      cancelTextColor: AppColors.textMuted,
      buttonColor: AppColors.primary,
      onConfirm: () {
        Get.back();
        controller.submitVote(player.id);
      },
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: GlassmorphicContainer(
        margin: const EdgeInsets.all(AppDimensions.pagePadding),
        padding: const EdgeInsets.all(AppDimensions.xl),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: color,
            ).animate().scale(delay: const Duration(milliseconds: 200)),
            const SizedBox(height: AppDimensions.md),
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppDimensions.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            El7reefButton(text: 'العودة للمباراة', onPressed: () => Get.back()),
          ],
        ),
      ),
    );
  }
}
