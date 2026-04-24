import 'package:flutter/material.dart';

/// لوحة ألوان EL7REEF — النظام التصميمي الجديد
abstract class AppColors {
  // ── Primary ──
  static const Color primary = Color(0xFF7ED957);
  static const Color primaryDark = Color(0xFF1F7A3E);
  static const Color primaryGlow = Color(0x407ED957); // 25% opacity
  static const Color primarySurface = Color(0x267ED957); // 15% opacity for tags
  static const Color primaryLight = Color(0xFF4ADE80);

  // ── Neutral ──
  static const Color black = Color(0xFF0B0B0B);
  static const Color background = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFF1A1A1A); // Player Card Background
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF1E1E1E);
  static const Color surfaceBorder = Color(0xFF2A2A2A);

  // ── Text ──
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFF0B0B0B);

  // ── Secondary (ذهبي الإنجازات) ──
  static const Color secondary = Color(0xFFF5A623);
  static const Color secondaryDark = Color(0xFFD4891A);
  static const Color secondaryLight = Color(0xFFFFCB57);

  // ── Accent (أزرق كهربائي للتقييم) ──
  static const Color accent = Color(0xFF4A90D9);
  static const Color accentDark = Color(0xFF2E6DB5);
  static const Color accentLight = Color(0xFF7DB4F0);

  // ── Semantic ──
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF4D4F);
  static const Color warning = Color(0xFFFFC107);
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
    colors: [background, black],
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
