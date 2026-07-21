/// Spacing, sizing, and radius tokens - 8px Grid System
abstract class AppDimensions {
  // ── Spacing System (8px Grid) ──
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 16.0;
  static const double space4 = 24.0;
  static const double space5 = 32.0;

  // ── Legacy Spacing (Mapped) ──
  static const double xs = space1;
  static const double sm = space2;
  static const double md = space3;
  static const double lg = space4;
  static const double xl = space5;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // ── Padding ──
  static const double pagePadding = 16.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;

  // ── Border Radius ──
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // Button Radius
  static const double radiusLg = 16.0; // Card Radius
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // ── Icon Sizes ──
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ── Avatar Sizes ──
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 72.0;
  static const double avatarXl = 100.0;
  static const double avatarHero = 120.0;

  // ── Button Heights ──
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 48.0;
  static const double buttonHeightLg = 56.0;
  static const double minTouchTarget = 48.0;

  // ── Card ──
  static const double cardElevation = 0.0;
  static const double cardBorderWidth = 1.0;

  // ── Bottom Nav ──
  static const double bottomNavHeight = 72.0;

  // ── Functional glass ──
  static const double functionalGlassBlur = 14.0;

  // ── Animation Durations (ms) ──
  static const int animFast = 150;
  static const int animNormal = 220;
  static const int animSlow = 250;
  static const int animCelebration = 650;

  /// باقٍ للتوافق مع المؤثرات القديمة، ولا يستخدم لحركة تشغيلية متكررة.
  static const int animVerySlow = animCelebration;
}
