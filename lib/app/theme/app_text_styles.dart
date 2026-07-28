import 'package:flutter/material.dart';

import 'app_colors.dart';

/// سلم Cairo موحد لواجهة عربية واضحة وصور قابلة للقراءة.
///
/// أصغر نص وظيفي هو 12sp. أرقام النتائج تستخدم tabular figures، بينما يحدد
/// مكوّن النتيجة نفسه اتجاه LTR حتى لا يتغير ترتيب الفريقين داخل RTL.
abstract final class AppTextStyles {
  static TextStyle _cairo({
    required double size,
    required FontWeight weight,
    required Color color,
    required double height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: const <String>['Noto Sans Arabic'],
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      color: color,
      height: height,
      fontFeatures: fontFeatures,
    );
  }

  // ── Display ──
  static final TextStyle displayLarge = _cairo(
    size: 36,
    weight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
  );
  static final TextStyle displayMedium = _cairo(
    size: 30,
    weight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  static final TextStyle displaySmall = _cairo(
    size: 26,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // ── Headline ──
  static final TextStyle headlineLarge = _cairo(
    size: 24,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  static final TextStyle headlineMedium = _cairo(
    size: 20,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );
  static final TextStyle headlineSmall = _cairo(
    size: 18,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ── Title ──
  static final TextStyle titleLarge = _cairo(
    size: 18,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  static final TextStyle titleMedium = _cairo(
    size: 16,
    weight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  static final TextStyle titleSmall = _cairo(
    size: 14,
    weight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  // ── Body ──
  static final TextStyle bodyLarge = _cairo(
    size: 16,
    weight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.55,
  );
  static final TextStyle bodyMedium = _cairo(
    size: 14,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.55,
  );
  static final TextStyle bodySmall = _cairo(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.55,
  );

  // ── Label ──
  static final TextStyle labelLarge = _cairo(
    size: 14,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  static final TextStyle labelMedium = _cairo(
    size: 12,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  static final TextStyle labelSmall = _cairo(
    size: 12,
    weight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // ── Scores & achievements ──
  static final TextStyle scoreLarge = _cairo(
    size: 48,
    weight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
  static final TextStyle scoreMedium = _cairo(
    size: 30,
    weight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
  static final TextStyle ratingLarge = scoreLarge.copyWith(
    color: AppColors.textPrimary,
  );
  static final TextStyle ratingMedium = scoreMedium.copyWith(
    color: AppColors.textPrimary,
  );
  static final TextStyle ratingDelta = _cairo(
    size: 20,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
  static final TextStyle buttonText = _cairo(
    size: 16,
    weight: FontWeight.w700,
    color: AppColors.textOnPrimary,
    height: 1.4,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
