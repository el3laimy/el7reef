import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/navigation/pending_deep_link_service.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';

/// بداية سريعة تركز على نية المستخدم، لا شرح طويل.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, _) {
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppDimensions.pagePadding),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => Get.offAllNamed(AppRoutes.login),
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('تسجيل الدخول'),
                            ),
                          ),
                          const Spacer(),
                          El7reefGlassSurface(
                                variant: El7reefGlassVariant.raised,
                                padding: const EdgeInsets.all(AppDimensions.xl),
                                radius: AppDimensions.radiusXl,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: El7reefBrandMark(size: 92),
                                    ),
                                    const SizedBox(height: AppDimensions.lg),
                                    Text(
                                      'اختار بدايتك في الحريف',
                                      style: AppTextStyles.displaySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppDimensions.sm),
                                    Text(
                                      'الدورة، الفريق، النتيجة، وكارت الفخر يبدأوا من خطوة واحدة.',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppDimensions.xl),
                                    _IntentAction(
                                      icon: Icons.emoji_events_rounded,
                                      title: 'أنظم بطولة',
                                      subtitle:
                                          'ابدأ دورة شعبية وسجل الفرق والنتائج.',
                                      onTap: () => _openAfterLogin(
                                        AppRoutes.createTournament,
                                      ),
                                    ),
                                    _IntentAction(
                                      icon: Icons.groups_2_rounded,
                                      title: 'أنا كابتن فريق',
                                      subtitle:
                                          'كوّن فريقك وجهّز اللاعيبة للبطولات.',
                                      onTap: () =>
                                          _openAfterLogin(AppRoutes.createTeam),
                                    ),
                                    _IntentAction(
                                      icon: Icons.sports_soccer_rounded,
                                      title: 'أنا لاعب',
                                      subtitle:
                                          'استكشف البطولات وخلّي لعبك متوثق.',
                                      onTap: () => _openAfterLogin(
                                        AppRoutes.tournamentExplore,
                                      ),
                                    ),
                                    _IntentAction(
                                      icon: Icons.qr_code_scanner_rounded,
                                      title: 'معايا رابط أو QR',
                                      subtitle:
                                          'افتح دعوة، استلام لاعب، أو تسجيل بطولة.',
                                      onTap: () =>
                                          Get.toNamed(AppRoutes.qrScanner),
                                    ),
                                    const SizedBox(height: AppDimensions.lg),
                                    El7reefButton(
                                      text: 'المتابعة بحساب Google',
                                      icon: Icons.login_rounded,
                                      onPressed: () =>
                                          Get.offAllNamed(AppRoutes.login),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 220.ms)
                              .slideY(
                                begin: 0.04,
                                duration: 220.ms,
                                curve: Curves.easeOutCubic,
                              ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static void _openAfterLogin(String route) {
    _pendingDeepLinkService().store(route);
    Get.offAllNamed(AppRoutes.login);
  }

  static PendingDeepLinkService _pendingDeepLinkService() {
    return Get.isRegistered<PendingDeepLinkService>()
        ? Get.find<PendingDeepLinkService>()
        : Get.put(PendingDeepLinkService(), permanent: true);
  }
}

class _IntentAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IntentAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
