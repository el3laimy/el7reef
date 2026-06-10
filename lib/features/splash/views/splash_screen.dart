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
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // التحقق من حالة المصادقة
    try {
      final authService = Get.find<AuthService>();
      if (authService.isLoggedIn) {
        Get.offAllNamed(AppRoutes.home);
      } else {
        Get.offAllNamed(AppRoutes.onboarding);
      }
    } catch (e) {
      AppLogger.error('SplashScreen.navigate', e);
      // إذا AuthService مش مسجل بعد، يروح للـ onboarding
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            // ── خلفية: دوائر متوهجة ──
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 2000.ms, curve: Curves.easeOut)
                .fadeIn(duration: 1000.ms),

            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 2500.ms, curve: Curves.easeOut)
                .fadeIn(duration: 1200.ms),

            // ── المحتوى الرئيسي ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/logo_icon.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      .animate()
                      .scale(begin: const Offset(0.0, 0.0), end: const Offset(1.0, 1.0), duration: 800.ms, curve: Curves.elasticOut)
                      .fadeIn(duration: 400.ms)
                      .shimmer(delay: 1000.ms, duration: 1500.ms, color: AppColors.textPrimaryTinted.withValues(alpha: 0.2)),

                  const SizedBox(height: AppDimensions.lg),

                  Text(
                    AppConstants.appName,
                    style: AppTextStyles.displayLarge.copyWith(
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOut),

                  const SizedBox(height: AppDimensions.lg),
                  
                  Text(
                    AppConstants.appTagline,
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOut),

                  const SizedBox(height: AppDimensions.xxl),

                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary.withValues(alpha: 0.7)),
                    ),
                  ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
                ],
              ),
            ),

            Positioned(
              bottom: AppDimensions.xxl,
              left: 0,
              right: 0,
              child: Text(
                'النسخة ١.٠.٠',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(delay: 1500.ms, duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }
}
