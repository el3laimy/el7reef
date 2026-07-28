import 'package:flutter/material.dart';

/// لوحة «نهار البطولة» التشغيلية لأندرويد.
///
/// الأسطح فاتحة ومحايدة، والكوبالت للفعل، والمرجاني للطاقة الاجتماعية،
/// والأخضر للحالة المؤكدة فقط. ألوان الوسائط الداكنة معزولة في
/// `AppMediaColors` حتى لا تتأثر ملفات Pride والملعب بثيم التطبيق.
abstract final class AppColors {
  // ── Cobalt action ──
  static const Color actionPrimary = Color(0xFF315CC6);
  static const Color actionStrong = Color(0xFF2549A3);
  static const Color actionLight = Color(0xFF5F83DF);
  static const Color actionContainer = Color(0xFFDFE7FA);
  static const Color actionGlow = Color(0x12315CC6);
  static const Color actionSurface = Color(0xFFE8EEFC);

  // أسماء توافقية للشاشات القديمة.
  static const Color primary = actionPrimary;
  static const Color primaryDark = actionStrong;
  static const Color primaryGlow = actionGlow;
  static const Color primarySurface = actionSurface;
  static const Color primaryLight = actionLight;

  // ── Social heat ──
  static const Color socialAccent = Color(0xFFC84232);
  static const Color socialStrong = Color(0xFFA53227);
  static const Color socialLight = Color(0xFFE06B5B);
  static const Color socialContainer = Color(0xFFFBE5E0);
  static const Color socialSurface = socialContainer;

  // ── Knockout violet ──
  static const Color competitive = Color(0xFF6746B8);
  static const Color competitiveStrong = Color(0xFF503394);
  static const Color competitiveContainer = Color(0xFFECE6F8);
  static const Color competitiveSurface = competitiveContainer;

  // ── Verified tactical state ──
  static const Color tactical = Color(0xFF167247);
  static const Color tacticalDark = Color(0xFF0F5938);
  static const Color tacticalLight = Color(0xFF3A9467);
  static const Color tacticalContainer = Color(0xFFDEF1E5);
  static const Color tacticalSurface = tacticalContainer;

  static const Color brand = tactical;
  static const Color brandDark = tacticalDark;
  static const Color brandLight = tacticalLight;
  static const Color brandSurface = tacticalSurface;

  // ── Daylight chalk surfaces ──
  static const Color black = Color(0xFF17202C);
  static const Color shadowInk = black;
  static const Color background = Color(0xFFEEF2F6);
  static const Color backgroundDeep = Color(0xFFE3E8EF);
  static const Color backgroundLight = Color(0xFFF6F8FB);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceRaised = Color(0xFFFDFBF6);
  static const Color surfaceSunken = Color(0xFFE7ECF2);
  static const Color surfaceLight = Color(0xFFFDFEFF);
  static const Color surfaceBorder = Color(0xFFCDD6E2);
  static const Color surfaceBorderStrong = Color(0xFF8292A7);
  static const double contextualGlowOpacity = 0.07;

  // ── Text ──
  // chalk remains an asset/media neutral; operational text uses ink tokens.
  static const Color chalk = Color(0xFFF5F7FB);
  static const Color textPrimary = Color(0xFF17202C);
  static const Color textPrimaryTinted = textPrimary;
  static const Color textSecondary = Color(0xFF46566A);
  static const Color textSecondaryTinted = textSecondary;
  static const Color textMuted = Color(0xFF617187);
  static const Color textOnPrimary = Color(0xFFF8FAFC);
  static const Color textOnTactical = Color(0xFFF8FAFC);
  static const Color textOnSocial = Color(0xFFF8FAFC);
  static const Color textOnCompetitive = Color(0xFFF8FAFC);

  // ── Context surfaces ──
  static const Color burgundyDeep = Color(0xFFF3D9D7);
  static const Color burgundySurface = Color(0xFFFBE8E5);

  // ── Earned achievement ──
  static const Color achievement = Color(0xFF8A5A00);
  static const Color achievementDark = Color(0xFF694200);
  static const Color achievementLight = Color(0xFFD89B24);
  static const Color achievementSurface = Color(0xFFF8EBC9);

  // ── Semantic states ──
  static const Color success = tactical;
  static const Color successSurface = tacticalSurface;
  static const Color error = Color(0xFFBF2940);
  static const Color errorSurface = Color(0xFFF9E2E7);
  static const Color errorSurfaceSolid = errorSurface;
  static const Color warning = Color(0xFF9A4A08);
  static const Color warningSurface = Color(0xFFFBE8D6);
  static const Color info = Color(0xFF086C91);
  static const Color infoDark = Color(0xFF075675);
  static const Color infoLight = Color(0xFF2D8AAF);
  static const Color infoContainer = Color(0xFFDDEFF6);
  static const Color infoSurface = infoContainer;

  @Deprecated('Use a semantic AppColors role instead.')
  static const Color secondary = info;
  @Deprecated('Use a semantic AppColors role instead.')
  static const Color secondaryDark = infoDark;
  @Deprecated('Use a semantic AppColors role instead.')
  static const Color secondaryLight = infoLight;

  static const Color accent = info;
  static const Color accentDark = infoDark;
  static const Color accentLight = infoLight;

  // ── Rank tiers (identity-bearing and intentionally stable) ──
  static const Color rankBronze = Color(0xFF9B5C24);
  static const Color rankSilver = Color(0xFF667085);
  static const Color rankGold = Color(0xFF9A6400);
  static const Color rankPlatinum = Color(0xFF087F86);
  static const Color rankDiamond = Color(0xFF287A9B);
  static const Color rankLegendary1 = Color(0xFFC33F4D);
  static const Color rankLegendary2 = Color(0xFFB55E00);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[actionStrong, actionPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[backgroundLight, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: <Color>[achievementLight, achievement, achievementDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient legendaryGradient = LinearGradient(
    colors: <Color>[rankLegendary1, rankLegendary2, achievement],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ratingPositiveGradient = LinearGradient(
    colors: <Color>[tacticalDark, tacticalLight],
  );

  static const LinearGradient ratingNegativeGradient = LinearGradient(
    colors: <Color>[Color(0xFFB42336), Color(0xFFD85462)],
  );
}
