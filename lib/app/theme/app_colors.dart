import 'package:flutter/material.dart';

/// لوحة ألوان EL7REEF — مستوحاة من أجواء الملاعب الشعبية
/// Dark-first design with vibrant accents
abstract class AppColors {
  // ── Primary (أخضر الملعب) ──
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF0D7C3D);
  static const Color primaryLight = Color(0xFF4ADE80);
  static const Color primarySurface = Color(0xFF0D3320);

  // ── Secondary (ذهبي الإنجازات) ──
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryDark = Color(0xFFD4891A);
  static const Color secondaryLight = Color(0xFFFFCB57);

  // ── Accent (أزرق كهربائي للتقييم) ──
  static const Color accent = Color(0xFF4A90D9);
  static const Color accentDark = Color(0xFF2E6DB5);
  static const Color accentLight = Color(0xFF7DB4F0);

  // ── Background (Dark Theme) ──
  static const Color background = Color(0xFF0A0E17);
  static const Color backgroundLight = Color(0xFF131A2B);
  static const Color surface = Color(0xFF1C2333);
  static const Color surfaceLight = Color(0xFF252D40);
  static const Color surfaceBorder = Color(0xFF2E3A50);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status ──
  static const Color success = Color(0xFF43A047);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF29B6F6);

  // ── Rank Tiers ──
  static const Color rankBronze = Color(0xFFCD7F32);
  static const Color rankSilver = Color(0xFFC0C0C0);
  static const Color rankGold = Color(0xFFFFD700);
  static const Color rankPlatinum = Color(0xFF00CED1);
  static const Color rankDiamond = Color(0xFFB9F2FF);
  static const Color rankLegendary1 = Color(0xFFFF6B6B);
  static const Color rankLegendary2 = Color(0xFFFFA500);

  // ── Glassmorphism ──
  static const Color glassBg = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white
  static const Color glassShadow = Color(0x40000000); // 25% black

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundLight],
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
