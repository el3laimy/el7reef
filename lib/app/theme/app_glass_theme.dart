import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_colors.dart';

enum El7reefGlassRole {
  navigation,
  hero,
  floatingToolbar,
  compactSheet,
  previewToolbar,
  mediaOverlay,
}

enum El7reefGlassTone {
  neutral,
  action,
  social,
  tactical,
  competitive,
  achievement,
  error,
}

@immutable
class AppGlassSpec {
  const AppGlassSpec({
    required this.fill,
    required this.fallback,
    required this.foreground,
    required this.border,
    required this.highlight,
    required this.shadowColor,
    required this.blurSigma,
    required this.radius,
    required this.shadowBlur,
    required this.shadowOffset,
  });

  final Color fill;
  final Color fallback;
  final Color foreground;
  final Color border;
  final Color highlight;
  final Color shadowColor;
  final double blurSigma;
  final double radius;
  final double shadowBlur;
  final Offset shadowOffset;

  AppGlassSpec copyWith({
    Color? fill,
    Color? fallback,
    Color? foreground,
    Color? border,
    Color? highlight,
    Color? shadowColor,
    double? blurSigma,
    double? radius,
    double? shadowBlur,
    Offset? shadowOffset,
  }) {
    return AppGlassSpec(
      fill: fill ?? this.fill,
      fallback: fallback ?? this.fallback,
      foreground: foreground ?? this.foreground,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      shadowColor: shadowColor ?? this.shadowColor,
      blurSigma: blurSigma ?? this.blurSigma,
      radius: radius ?? this.radius,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffset: shadowOffset ?? this.shadowOffset,
    );
  }

  static AppGlassSpec lerp(AppGlassSpec a, AppGlassSpec b, double t) {
    return AppGlassSpec(
      fill: Color.lerp(a.fill, b.fill, t)!,
      fallback: Color.lerp(a.fallback, b.fallback, t)!,
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      highlight: Color.lerp(a.highlight, b.highlight, t)!,
      shadowColor: Color.lerp(a.shadowColor, b.shadowColor, t)!,
      blurSigma: ui.lerpDouble(a.blurSigma, b.blurSigma, t)!,
      radius: ui.lerpDouble(a.radius, b.radius, t)!,
      shadowBlur: ui.lerpDouble(a.shadowBlur, b.shadowBlur, t)!,
      shadowOffset: Offset.lerp(a.shadowOffset, b.shadowOffset, t)!,
    );
  }
}

/// Liquid Glass tokens for the daylight Android experience.
///
/// Callers choose a functional role and a semantic tone. They cannot provide
/// arbitrary blur values, which keeps contrast and the GPU budget predictable.
@immutable
class AppGlassTheme extends ThemeExtension<AppGlassTheme> {
  const AppGlassTheme({
    required this.navigation,
    required this.hero,
    required this.floatingToolbar,
    required this.compactSheet,
    required this.previewToolbar,
    required this.mediaOverlay,
    required this.specularWidth,
    required this.pressScale,
    required this.pressDuration,
    required this.selectionDuration,
    required this.sheetDuration,
    required this.motionCurve,
  });

  final AppGlassSpec navigation;
  final AppGlassSpec hero;
  final AppGlassSpec floatingToolbar;
  final AppGlassSpec compactSheet;
  final AppGlassSpec previewToolbar;
  final AppGlassSpec mediaOverlay;
  final double specularWidth;
  final double pressScale;
  final Duration pressDuration;
  final Duration selectionDuration;
  final Duration sheetDuration;
  final Curve motionCurve;

  static const AppGlassTheme daylight = AppGlassTheme(
    navigation: AppGlassSpec(
      fill: Color(0xC7F8FAFC),
      fallback: Color(0xFFF5F7FA),
      foreground: AppColors.textPrimary,
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x2117202C),
      blurSigma: 18,
      radius: 28,
      shadowBlur: 28,
      shadowOffset: Offset(0, 10),
    ),
    hero: AppGlassSpec(
      fill: Color(0xB3F8FAFC),
      fallback: Color(0xFFF5F7FA),
      foreground: AppColors.textPrimary,
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x1F17202C),
      blurSigma: 16,
      radius: 30,
      shadowBlur: 26,
      shadowOffset: Offset(0, 10),
    ),
    floatingToolbar: AppGlassSpec(
      fill: Color(0xB8F8FAFC),
      fallback: Color(0xFFF5F7FA),
      foreground: AppColors.textPrimary,
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x1A17202C),
      blurSigma: 12,
      radius: 20,
      shadowBlur: 18,
      shadowOffset: Offset(0, 6),
    ),
    compactSheet: AppGlassSpec(
      fill: Color(0xE8FDFBF6),
      fallback: Color(0xFFF8F7F2),
      foreground: AppColors.textPrimary,
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x1A17202C),
      blurSigma: 16,
      radius: 28,
      shadowBlur: 28,
      shadowOffset: Offset(0, -8),
    ),
    previewToolbar: AppGlassSpec(
      fill: Color(0xBDF8FAFC),
      fallback: Color(0xFFF5F7FA),
      foreground: AppColors.textPrimary,
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x1F17202C),
      blurSigma: 14,
      radius: 24,
      shadowBlur: 24,
      shadowOffset: Offset(0, 8),
    ),
    mediaOverlay: AppGlassSpec(
      fill: Color(0x9417202C),
      fallback: Color(0xFF263140),
      foreground: Color(0xFFF5F7FB),
      border: Color(0x3D8292A7),
      highlight: Color(0xCCFDFEFF),
      shadowColor: Color(0x21080B11),
      blurSigma: 10,
      radius: 20,
      shadowBlur: 18,
      shadowOffset: Offset(0, 6),
    ),
    specularWidth: 0.75,
    pressScale: 0.98,
    pressDuration: Duration(milliseconds: 150),
    selectionDuration: Duration(milliseconds: 220),
    sheetDuration: Duration(milliseconds: 250),
    motionCurve: Curves.easeOutQuart,
  );

  static AppGlassTheme of(BuildContext context) {
    return Theme.of(context).extension<AppGlassTheme>() ?? daylight;
  }

  AppGlassSpec resolve(El7reefGlassRole role) {
    return switch (role) {
      El7reefGlassRole.navigation => navigation,
      El7reefGlassRole.hero => hero,
      El7reefGlassRole.floatingToolbar => floatingToolbar,
      El7reefGlassRole.compactSheet => compactSheet,
      El7reefGlassRole.previewToolbar => previewToolbar,
      El7reefGlassRole.mediaOverlay => mediaOverlay,
    };
  }

  Color toneColor(El7reefGlassTone tone) {
    return switch (tone) {
      El7reefGlassTone.neutral => Colors.transparent,
      El7reefGlassTone.action => AppColors.actionPrimary,
      El7reefGlassTone.social => AppColors.socialAccent,
      El7reefGlassTone.tactical => AppColors.tactical,
      El7reefGlassTone.competitive => AppColors.competitive,
      El7reefGlassTone.achievement => AppColors.achievement,
      El7reefGlassTone.error => AppColors.error,
    };
  }

  @override
  AppGlassTheme copyWith({
    AppGlassSpec? navigation,
    AppGlassSpec? hero,
    AppGlassSpec? floatingToolbar,
    AppGlassSpec? compactSheet,
    AppGlassSpec? previewToolbar,
    AppGlassSpec? mediaOverlay,
    double? specularWidth,
    double? pressScale,
    Duration? pressDuration,
    Duration? selectionDuration,
    Duration? sheetDuration,
    Curve? motionCurve,
  }) {
    return AppGlassTheme(
      navigation: navigation ?? this.navigation,
      hero: hero ?? this.hero,
      floatingToolbar: floatingToolbar ?? this.floatingToolbar,
      compactSheet: compactSheet ?? this.compactSheet,
      previewToolbar: previewToolbar ?? this.previewToolbar,
      mediaOverlay: mediaOverlay ?? this.mediaOverlay,
      specularWidth: specularWidth ?? this.specularWidth,
      pressScale: pressScale ?? this.pressScale,
      pressDuration: pressDuration ?? this.pressDuration,
      selectionDuration: selectionDuration ?? this.selectionDuration,
      sheetDuration: sheetDuration ?? this.sheetDuration,
      motionCurve: motionCurve ?? this.motionCurve,
    );
  }

  @override
  AppGlassTheme lerp(covariant AppGlassTheme? other, double t) {
    if (other == null) return this;
    return AppGlassTheme(
      navigation: AppGlassSpec.lerp(navigation, other.navigation, t),
      hero: AppGlassSpec.lerp(hero, other.hero, t),
      floatingToolbar: AppGlassSpec.lerp(
        floatingToolbar,
        other.floatingToolbar,
        t,
      ),
      compactSheet: AppGlassSpec.lerp(compactSheet, other.compactSheet, t),
      previewToolbar: AppGlassSpec.lerp(
        previewToolbar,
        other.previewToolbar,
        t,
      ),
      mediaOverlay: AppGlassSpec.lerp(mediaOverlay, other.mediaOverlay, t),
      specularWidth: ui.lerpDouble(specularWidth, other.specularWidth, t)!,
      pressScale: ui.lerpDouble(pressScale, other.pressScale, t)!,
      pressDuration: t < 0.5 ? pressDuration : other.pressDuration,
      selectionDuration: t < 0.5 ? selectionDuration : other.selectionDuration,
      sheetDuration: t < 0.5 ? sheetDuration : other.sheetDuration,
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
    );
  }
}
