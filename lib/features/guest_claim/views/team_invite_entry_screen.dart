import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/team_invite_entry_controller.dart';

class TeamInviteEntryScreen extends GetView<TeamInviteEntryController> {
  const TeamInviteEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const CircularProgressIndicator(
                    color: AppColors.primary,
                  );
                }

                if (controller.errorMessage.value.isNotEmpty) {
                  return _buildErrorState();
                }

                final team = controller.team.value;
                if (team == null) return const SizedBox.shrink();

                return El7reefSolidSurface(
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  radius: AppDimensions.radiusXl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          border: Border.all(
                            color: AppColors.textPrimaryTinted.withValues(
                              alpha: 0.2,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          team.name.isNotEmpty ? team.name[0] : '?',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.textOnPrimary,
                            fontSize: 48,
                          ),
                        ),
                      ).animate().scale(
                        duration: 250.ms,
                        curve: Curves.easeOutQuart,
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      Text(
                        'دعوة للانضمام',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryLight,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        team.name,
                        style: AppTextStyles.headlineMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                      const SizedBox(height: AppDimensions.lg),
                      Text(
                        'لقد تمت دعوتك للانضمام إلى قائمة الفريق. '
                        '${!controller.isLoggedIn ? 'قم بتسجيل الدخول أولاً لقبول الدعوة.' : 'اضغط أدناه للقبول.'}',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: AppDimensions.xxl),
                      El7reefButton(
                        text: controller.isLoggedIn
                            ? 'قبول الدعوة'
                            : 'تسجيل الدخول للقبول',
                        icon: controller.isLoggedIn
                            ? Icons.check_circle_outline_rounded
                            : Icons.login_rounded,
                        isLoading: controller.isSubmitting.value,
                        onPressed: controller.acceptInvite,
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.xl),
      radius: AppDimensions.radiusXl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.link_off_rounded,
            size: 64,
            color: AppColors.error,
          ).animate().shake(duration: 220.ms),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'عذراً',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            controller.errorMessage.value,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xl),
          El7reefButton(
            text: 'العودة للرئيسية',
            icon: Icons.home_rounded,
            onPressed: () => Get.offAllNamed(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}
