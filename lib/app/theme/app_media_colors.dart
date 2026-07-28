import 'package:flutter/material.dart';

/// Stable Night Match palette for exported media and code-native identities.
///
/// These colors deliberately do not follow the operational app theme. Pride
/// cards, lineup canvases, and built-in marks must render identically when the
/// app shell changes between visual themes.
abstract final class AppMediaColors {
  // Stable pitch palette. It preserves the established dark-green lineup
  // canvas while the operational shell moves to daylight colors.
  static const Color pitchAction = Color(0xFF7ED957);
  static const Color pitchActionStrong = Color(0xFF1F7A3E);
  static const Color pitchActionLight = Color(0xFF4ADE80);
  static const Color pitchCanvasDeep = Color(0xFF0B100C);
  static const Color pitchSurface = Color(0xFF1A2019);
  static const Color pitchRaised = Color(0xFF222A20);
  static const Color pitchSunken = Color(0xFF131812);
  static const Color pitchBorder = Color(0xFF30392E);
  static const Color pitchBorderStrong = Color(0xFF465143);
  static const Color pitchTextPrimary = Color(0xFFF4F7EE);
  static const Color pitchTextSecondary = Color(0xFFB7C0B3);
  static const Color pitchAchievement = Color(0xFFF5A623);
  static const Color pitchAchievementStrong = Color(0xFFD4891A);
  static const Color pitchAchievementLight = Color(0xFFFFCB57);
  static const Color pitchInkOnAccent = Color(0xFF0A1008);
  static const LinearGradient pitchAchievementGradient = LinearGradient(
    colors: <Color>[
      Color(0xFFFFD700),
      pitchAchievement,
      pitchAchievementStrong,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Night Match canvas and ink. These values preserve the established export
  // pixels while the operational shell moves to Chalk & Cobalt.
  static const Color canvas = Color(0xFF10140F);
  static const Color canvasDeep = Color(0xFF0B100C);
  static const Color surface = Color(0xFF1A2019);
  static const Color raised = Color(0xFF222A20);
  static const Color sunken = Color(0xFF131812);
  static const Color border = Color(0xFF30392E);
  static const Color borderStrong = Color(0xFF465143);

  static const Color textPrimary = Color(0xFFF4F7EE);
  static const Color textSecondary = Color(0xFFB7C0B3);
  static const Color textMuted = Color(0xFF96A190);
  static const Color inkOnAccent = Color(0xFF0A1008);

  // Established pitch green remains the action signature inside media.
  static const Color actionPrimary = Color(0xFF7ED957);
  static const Color actionStrong = Color(0xFF1F7A3E);
  static const Color actionLight = Color(0xFF4ADE80);
  static const Color actionContainer = Color(0xFF1F3D27);
  static const Color actionGlow = Color(0x407ED957);
  static const Color actionSurface = Color(0x267ED957);

  // Social heat: invitations and sharing energy.
  static const Color socialAccent = Color(0xFFFF765F);
  static const Color socialStrong = Color(0xFFD95242);
  static const Color socialLight = Color(0xFFFFA08F);
  static const Color socialContainer = Color(0xFF3A1E1A);
  static const Color socialSurface = Color(0x24FF765F);

  // Knockout and unresolved competition paths.
  static const Color competitive = Color(0xFFB69CFF);
  static const Color competitiveContainer = Color(0xFF2C234D);
  static const Color competitiveSurface = Color(0x24B69CFF);

  // Verified tactical states.
  static const Color tactical = Color(0xFF63D471);
  static const Color tacticalDark = Color(0xFF247A45);
  static const Color tacticalLight = Color(0xFF4ADE80);
  static const Color tacticalContainer = Color(0xFF173622);
  static const Color tacticalSurface = Color(0x2463D471);

  // Earned pride only.
  static const Color achievement = Color(0xFFF5A623);
  static const Color achievementDark = Color(0xFFD4891A);
  static const Color achievementLight = Color(0xFFFFCB57);
  static const LinearGradient achievementGradient = LinearGradient(
    colors: <Color>[Color(0xFFFFD700), achievement, achievementDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Information and system states used inside exported media.
  static const Color info = Color(0xFF69AEF2);
  static const Color infoDark = Color(0xFF2E6DB5);
  static const Color infoLight = Color(0xFF7DB4F0);
  static const Color infoContainer = Color(0xFF173047);
  static const Color infoSurface = Color(0x2469AEF2);

  static const Color warning = Color(0xFFF5B942);
  static const Color warningSurface = Color(0x24F5B942);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorSurface = Color(0x24FF6B6B);
  static const Color errorSurfaceSolid = Color(0xFF2C191B);

  // Brand is a signature inside media, not a generic success color.
  static const Color brand = tactical;
  static const Color brandDark = tacticalDark;
  static const Color brandLight = tacticalLight;

  // QR modules need an opaque, nearly white quiet zone and dark modules.
  static const Color qrBackground = Color(0xFFFDFEFF);
  static const Color qrForeground = canvasDeep;
}
