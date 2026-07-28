import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_glass_theme.dart';

/// Opaque content surface for cards, forms, rows, tables and state messages.
class El7reefSolidSurface extends StatelessWidget {
  const El7reefSolidSurface({
    super.key,
    required this.child,
    this.tone = El7reefGlassTone.neutral,
    this.padding,
    this.margin,
    this.radius = AppDimensions.radiusLg,
    this.borderRadius,
    this.width,
    this.height,
    this.color,
    this.borderColor,
    this.elevated = false,
  });

  final Widget child;
  final El7reefGlassTone tone;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final BorderRadiusGeometry? borderRadius;
  final double? width;
  final double? height;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone, elevated: elevated);
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: color ?? colors.$1,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.$2),
        boxShadow: elevated
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1417202C),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  (Color, Color) _colorsFor(El7reefGlassTone value, {required bool elevated}) {
    return switch (value) {
      El7reefGlassTone.neutral => (
        elevated ? AppColors.surfaceRaised : AppColors.surface,
        AppColors.surfaceBorder,
      ),
      El7reefGlassTone.action => (
        AppColors.actionSurface,
        AppColors.actionPrimary.withValues(alpha: 0.28),
      ),
      El7reefGlassTone.social => (
        AppColors.socialSurface,
        AppColors.socialAccent.withValues(alpha: 0.28),
      ),
      El7reefGlassTone.tactical => (
        AppColors.tacticalSurface,
        AppColors.tactical.withValues(alpha: 0.28),
      ),
      El7reefGlassTone.competitive => (
        AppColors.competitiveSurface,
        AppColors.competitive.withValues(alpha: 0.28),
      ),
      El7reefGlassTone.achievement => (
        AppColors.achievementSurface,
        AppColors.achievement.withValues(alpha: 0.28),
      ),
      El7reefGlassTone.error => (
        AppColors.errorSurface,
        AppColors.error.withValues(alpha: 0.28),
      ),
    };
  }
}
