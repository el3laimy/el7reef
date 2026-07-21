import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - (AppDimensions.pagePadding * 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      El7reefGlassSurface(
                        variant: El7reefGlassVariant.raised,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.lg,
                          vertical: AppDimensions.xl,
                        ),
                        radius: AppDimensions.radiusXl,
                        child: Column(
                          children: [
                            // ── الشعار ──
                            Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 34,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const El7reefBrandMark(size: 124),
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
                                .slideY(
                                  begin: 0.08,
                                  duration: 300.ms,
                                  curve: Curves.easeOut,
                                ),

                            const SizedBox(height: AppDimensions.sm),

                            Text(
                                  AppConstants.appTagline,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.textSecondaryTinted,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                                .animate()
                                .fadeIn(delay: 180.ms, duration: 300.ms)
                                .slideY(begin: 0.06, duration: 300.ms),

                            const SizedBox(height: AppDimensions.xl),

                            // ── رسالة الخطأ ──
                            Obx(
                              () => controller.errorMessage.isNotEmpty
                                  ? _AuthErrorBanner(
                                      message: controller.errorMessage.value,
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            Obx(
                              () => Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: controller
                                      .hasAcceptedCommunityPolicy
                                      .value,
                                  onChanged: (value) =>
                                      controller.setCommunityPolicyAccepted(
                                        value ?? false,
                                      ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'أوافق على قواعد المجتمع وسياسة الخصوصية',
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ),
                            ),

                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => Get.toNamed(
                                    AppRoutes.communityGuidelines,
                                  ),
                                  child: const Text('قواعد المجتمع'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Get.toNamed(AppRoutes.privacyPolicy),
                                  child: const Text('سياسة الخصوصية'),
                                ),
                              ],
                            ).animate().fadeIn(delay: 320.ms, duration: 260.ms),

                            const SizedBox(height: AppDimensions.md),

                            // يظل قابلاً للضغط كي يشرح شرط الموافقة بدلاً من
                            // الظهور كزر معطّل بلا سبب.
                            Obx(
                              () => _GoogleSignInButton(
                                isLoading: controller.isLoading.value,
                                onPressed: controller.signInWithGoogle,
                              ),
                            ).animate().fadeIn(delay: 240.ms, duration: 300.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final String message;

  const _AuthErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return El7reefGlassSurface(
      variant: El7reefGlassVariant.error,
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      radius: AppDimensions.radiusMd,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.05, duration: 180.ms);
  }
}

/// زر Google Sign-In احترافي
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, this.onPressed});

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
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.82),
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
