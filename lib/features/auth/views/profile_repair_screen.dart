import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/navigation/pending_deep_link_service.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';

class ProfileRepairScreen extends StatelessWidget {
  const ProfileRepairScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Obx(() {
              final status = authService.profileStatus.value;
              if (!authService.isLoggedIn) {
                Future.microtask(() => Get.offAllNamed(AppRoutes.login));
              }
              if (status == AuthProfileStatus.ready) {
                Future.microtask(() {
                  final pendingRoute =
                      Get.isRegistered<PendingDeepLinkService>()
                      ? Get.find<PendingDeepLinkService>().take()
                      : null;
                  Get.offAllNamed(pendingRoute ?? AppRoutes.home);
                });
              }

              final isLoading = status == AuthProfileStatus.loading;
              final message = authService.profileErrorMessage.value.isEmpty
                  ? 'بنجهز حسابك على الحريف. لو الاتصال ضعيف، جرّب تاني بعد لحظة.'
                  : authService.profileErrorMessage.value;

              return Column(
                children: [
                  const Spacer(),
                  El7reefSolidSurface(
                    padding: const EdgeInsets.all(AppDimensions.xl),
                    child: Column(
                      children: [
                        const El7reefBrandMark(size: 96),
                        const SizedBox(height: AppDimensions.lg),
                        Text(
                          isLoading
                              ? 'بنجهز حسابك'
                              : 'حسابك محتاج محاولة تانية',
                          style: AppTextStyles.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        Text(
                          message,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.xl),
                        if (isLoading)
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          )
                        else ...[
                          El7reefButton(
                            text: 'حاول تجهيز الحساب',
                            icon: Icons.refresh_rounded,
                            onPressed: authService.refreshProfile,
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          TextButton(
                            onPressed: () async {
                              await authService.signOut();
                              Get.offAllNamed(AppRoutes.login);
                            },
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
