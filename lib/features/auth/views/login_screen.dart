import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/auth_controller.dart';

/// شاشة تسجيل الدخول — Google Sign-In
class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

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
                const Spacer(flex: 2),

                // ── الشعار ──
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚽', style: TextStyle(fontSize: 52)),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.0, 0.0),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: AppDimensions.lg),

                // ── الاسم ──
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.displayLarge.copyWith(
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient.createShader(
                        const Rect.fromLTWH(0, 0, 200, 70),
                      ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOut),

                const SizedBox(height: AppDimensions.sm),

                Text(
                  AppConstants.appTagline,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 600.ms)
                    .slideY(begin: 0.2, duration: 600.ms),

                const Spacer(flex: 2),

                // ── رسالة الخطأ ──
                Obx(() => controller.errorMessage.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(bottom: AppDimensions.md),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                controller.errorMessage.value,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ).animate().shake(duration: 400.ms)
                    : const SizedBox.shrink()),

                // ── زر Google Sign-In ──
                Obx(() => _GoogleSignInButton(
                      isLoading: controller.isLoading.value,
                      onPressed: controller.signInWithGoogle,
                    )).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: AppDimensions.md),

                // ── نص الموافقة ──
                Text(
                  'بتسجيل دخولك، أنت موافق على شروط الاستخدام وسياسة الخصوصية',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 900.ms),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر Google Sign-In احترافي
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLg,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'سجّل دخولك بـ Google',
                    style: AppTextStyles.buttonText.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
