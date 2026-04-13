import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';

/// شاشة الترحيب — 3 slides تعريفية
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: '⚽',
      title: 'ملعبك، قواعدك',
      description: 'سجّل مبارياتك في الشارع وتابع أداءك الحقيقي مع كل لمسة كورة.',
      gradient: AppColors.primaryGradient,
    ),
    _OnboardingPage(
      icon: '📊',
      title: 'تقييم عادل',
      description: 'خوارزمية ذكية تحسب مستواك بناءً على أدائك الفعلي وقوة خصومك.',
      gradient: LinearGradient(
        colors: [Color(0xFF2E6DB5), Color(0xFF4A90D9)],
      ),
    ),
    _OnboardingPage(
      icon: '🏆',
      title: 'دورات وإنجازات',
      description: 'شارك في دورات محلية، اجمع بادجات، وأثبت إنك الحريف الحقيقي.',
      gradient: AppColors.goldGradient,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // زر تخطي
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: () => Get.offAllNamed(AppRoutes.login),
                  child: Text('تخطي', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
                ),
              ).animate().fadeIn(delay: 500.ms),

              // الصفحات
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) => _buildPage(_pages[index]),
                ),
              ),

              // مؤشرات الصفحات
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                      ),
                    ),
                  ),
                ),
              ),

              // أزرار
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.pagePadding,
                  0,
                  AppDimensions.pagePadding,
                  AppDimensions.xl,
                ),
                child: _currentPage == _pages.length - 1
                    ? El7reefButton(
                        text: 'ابدأ الآن',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => Get.offAllNamed(AppRoutes.login),
                      )
                    : El7reefButton(
                        text: 'التالي',
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة مع glow
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: page.gradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(page.icon, style: const TextStyle(fontSize: 64)),
            ),
          )
              .animate()
              .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.xl),

          Text(
            page.title,
            style: AppTextStyles.displaySmall,
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.2, duration: 500.ms),

          const SizedBox(height: AppDimensions.md),

          Text(
            page.description,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.2, duration: 500.ms),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String description;
  final LinearGradient gradient;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
