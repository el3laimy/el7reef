import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/navigation/pending_deep_link_service.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';

/// شاشة البداية — Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    await Future.delayed(const Duration(milliseconds: 900));

    try {
      final authService = Get.find<AuthService>();
      for (var attempt = 0; attempt < 20; attempt++) {
        if (!mounted) return;
        final status = authService.profileStatus.value;
        if (status != AuthProfileStatus.unknown &&
            status != AuthProfileStatus.loading) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;

      switch (authService.profileStatus.value) {
        case AuthProfileStatus.ready:
          Get.offAllNamed(_takePendingRoute() ?? AppRoutes.home);
        case AuthProfileStatus.repairRequired:
          Get.offAllNamed(AppRoutes.profileRepair);
        case AuthProfileStatus.unauthenticated:
          Get.offAllNamed(_takePendingRoute() ?? AppRoutes.onboarding);
        case AuthProfileStatus.loading:
        case AuthProfileStatus.unknown:
          Get.offAllNamed(
            authService.isLoggedIn
                ? AppRoutes.profileRepair
                : AppRoutes.onboarding,
          );
      }
    } catch (e) {
      AppLogger.error('SplashScreen.navigate', e);
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }

  String? _takePendingRoute() {
    if (!Get.isRegistered<PendingDeepLinkService>()) return null;
    return Get.find<PendingDeepLinkService>().take();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              children: [
                const Spacer(),
                El7reefGlassSurface(
                  variant: El7reefGlassVariant.raised,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.xl,
                    vertical: AppDimensions.xl,
                  ),
                  radius: AppDimensions.radiusXl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.32,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const El7reefBrandMark(size: 150),
                          )
                          .animate()
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.0, 1.0),
                            duration: 450.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .fadeIn(duration: 260.ms),
                      const SizedBox(height: AppDimensions.lg),
                      Text(
                            AppConstants.appName,
                            style: AppTextStyles.displayLarge.copyWith(
                              foreground: Paint()
                                ..shader =
                                    const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryLight,
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 70),
                                    ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 300.ms)
                          .slideY(begin: 0.08, end: 0, duration: 300.ms),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                            AppConstants.appTagline,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textSecondaryTinted,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 180.ms, duration: 300.ms)
                          .slideY(begin: 0.06, end: 0, duration: 300.ms),
                      const SizedBox(height: AppDimensions.xl),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.primary.withValues(alpha: 0.78),
                          ),
                        ),
                      ).animate().fadeIn(delay: 260.ms, duration: 260.ms),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'النسخة ١.٠.٠',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ).animate().fadeIn(delay: 320.ms, duration: 260.ms),
                const SizedBox(height: AppDimensions.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
