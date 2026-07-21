import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../constants/feature_flags.dart';

enum El7reefGlassVariant { base, raised, pride, error, sheet }

class El7reefGlassSurface extends StatelessWidget {
  final Widget child;
  final El7reefGlassVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const El7reefGlassSurface({
    super.key,
    required this.child,
    this.variant = El7reefGlassVariant.base,
    this.padding,
    this.margin,
    this.radius = AppDimensions.radiusLg,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _GlassSpec.forVariant(variant);
    final reduceVisualEffects =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        FeatureFlags.reduceGlassBlurEnabled;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(radius);
    final blurEnabled =
        spec.blur > 0 &&
        FeatureFlags.functionalGlassEnabled &&
        !reduceVisualEffects;
    final decorated = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: blurEnabled ? spec.background : spec.solidBackground,
        borderRadius: effectiveBorderRadius,
        border: Border.all(color: spec.border),
        boxShadow: spec.shadows,
      ),
      child: child,
    );

    if (!blurEnabled) {
      return Container(margin: margin, child: decorated);
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: spec.blur, sigmaY: spec.blur),
          child: decorated,
        ),
      ),
    );
  }
}

class _GlassSpec {
  final Color background;
  final Color solidBackground;
  final Color border;
  final double blur;
  final List<BoxShadow>? shadows;

  const _GlassSpec({
    required this.background,
    required this.solidBackground,
    required this.border,
    required this.blur,
    this.shadows,
  });

  factory _GlassSpec.forVariant(El7reefGlassVariant variant) {
    switch (variant) {
      case El7reefGlassVariant.raised:
        return _GlassSpec(
          background: AppColors.glassRaisedBg,
          solidBackground: AppColors.surfaceRaised,
          border: AppColors.glassRaisedBorder,
          blur: 0,
          shadows: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        );
      case El7reefGlassVariant.pride:
        return _GlassSpec(
          background: AppColors.glassPrideBg,
          solidBackground: AppColors.burgundySurface,
          border: AppColors.glassPrideBorder,
          blur: 0,
          shadows: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        );
      case El7reefGlassVariant.error:
        return _GlassSpec(
          background: AppColors.glassErrorBg,
          solidBackground: AppColors.errorSurfaceSolid,
          border: AppColors.glassErrorBorder,
          blur: 0,
        );
      case El7reefGlassVariant.sheet:
        return _GlassSpec(
          background: AppColors.glassSheetBg,
          solidBackground: AppColors.surfaceRaised,
          border: AppColors.glassRaisedBorder,
          blur: AppDimensions.functionalGlassBlur,
          shadows: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.42),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        );
      case El7reefGlassVariant.base:
        return const _GlassSpec(
          background: AppColors.glassBaseBg,
          solidBackground: AppColors.surface,
          border: AppColors.glassBaseBorder,
          blur: 0,
        );
    }
  }
}
