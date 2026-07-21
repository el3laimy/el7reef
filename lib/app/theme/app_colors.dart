import 'package:flutter/material.dart';

/// لوحة «ختم الحارة» — هوية EL7REEF لأندرويد.
///
/// تعتمد الألوان المحايدة على صبغة الملعب بدل الأسود/الأبيض الخالصين. الأخضر
/// مخصص للفعل والحالة النشطة، والذهبي لإنجاز مكتسب فقط.
abstract class AppColors {
  // ── Electric pitch: الفعل والتوثيق ──
  static const Color primary = Color(0xFF7ED957);
  static const Color primaryDark = Color(0xFF1F7A3E);
  static const Color primaryGlow = Color(0x407ED957); // 25% opacity
  static const Color primarySurface = Color(0x267ED957); // 15% opacity for tags
  static const Color primaryLight = Color(0xFF4ADE80);

  // ── Asphalt & chalk: أسطح صلبة عالية التباين ──
  static const Color black = Color(0xFF090C09);
  static const Color background = Color(0xFF10140F);
  static const Color backgroundDeep = Color(0xFF0B100C);
  static const Color backgroundLight = Color(0xFF181D17);
  static const Color surface = Color(0xFF1A2019);
  static const Color surfaceRaised = Color(0xFF222A20);
  static const Color surfaceSunken = Color(0xFF131812);
  static const Color surfaceLight = surfaceRaised;
  static const Color surfaceBorder = Color(0xFF30392E);
  static const Color surfaceBorderStrong = Color(0xFF465143);

  // ── Text ──
  static const Color chalk = Color(0xFFF4F7EE);
  static const Color textPrimary = chalk;
  static const Color textPrimaryTinted = Color(0xFFF4F7EE);
  static const Color textSecondary = Color(0xFFB7C0B3);
  static const Color textSecondaryTinted = textSecondary;
  static const Color textMuted = Color(0xFF96A190);
  static const Color textOnPrimary = Color(0xFF0A1008);

  // ── Street burgundy: سطح سياقي لا حالة خطأ ──
  static const Color burgundyDeep = Color(0xFF2B171C);
  static const Color burgundySurface = Color(0xFF24171A);

  // ── Secondary (ذهبي الإنجازات) ──
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryDark = Color(0xFFD4891A);
  static const Color secondaryLight = Color(0xFFFFCB57);

  // ── Accent (معلومة مساندة، وليس خصمًا) ──
  static const Color accent = Color(0xFF4A90D9);
  static const Color accentDark = Color(0xFF2E6DB5);
  static const Color accentLight = Color(0xFF7DB4F0);

  // ── Semantic ──
  static const Color success = Color(0xFF63D471);
  static const Color successSurface = Color(0x2463D471);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorSurface = Color(0x24FF6B6B);
  static const Color errorSurfaceSolid = Color(0xFF2C191B);
  static const Color warning = Color(0xFFF5B942);
  static const Color warningSurface = Color(0x24F5B942);
  static const Color info = Color(0xFF69AEF2);
  static const Color infoSurface = Color(0x2469AEF2);

  // ── Rank Tiers ──
  static const Color rankBronze = Color(0xFFCD7F32);
  static const Color rankSilver = Color(0xFFC0C0C0);
  static const Color rankGold = Color(0xFFFFD700);
  static const Color rankPlatinum = Color(0xFF00CED1);
  static const Color rankDiamond = Color(0xFFB9F2FF);
  static const Color rankLegendary1 = Color(0xFFFF6B6B);
  static const Color rankLegendary2 = Color(0xFFFFA500);

  // ── Functional glass: للتنقل وأدوات المعاينة فقط ──
  // الأسماء الثلاثة الأولى باقية للتوافق مع المكوّنات الحالية.
  static const Color glassBg = Color(0xC21A2019);
  static const Color glassBorder = Color(0x523F493C);
  static const Color glassShadow = Color(0x40000000); // 25% black
  static const Color glassBaseBg = Color(0xC21A2019);
  static const Color glassBaseBorder = Color(0x523F493C);
  static const Color glassRaisedBg = Color(0xD9222A20);
  static const Color glassRaisedBorder = Color(0x66465143);
  static const Color glassPrideBg = Color(0xD924171A);
  static const Color glassPrideBorder = Color(0x66F5A623);
  static const Color glassErrorBg = Color(0xD9241919);
  static const Color glassErrorBorder = Color(0x66FF6B6B);
  static const Color glassSheetBg = Color(0xF20F130E);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFF5A623), Color(0xFFD4891A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient legendaryGradient = LinearGradient(
    colors: [rankLegendary1, rankLegendary2, Color(0xFFFFD700)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ratingPositiveGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF4ADE80)],
  );

  static const LinearGradient ratingNegativeGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFFF6B6B)],
  );
}
