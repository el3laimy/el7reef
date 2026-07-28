import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_glass_theme.dart';
import '../../app/theme/app_dimensions.dart';
import '../constants/feature_flags.dart';

export '../../app/theme/app_glass_theme.dart'
    show El7reefGlassRole, El7reefGlassTone;
export 'el7reef_lens.dart';
export 'el7reef_solid_surface.dart';

enum El7reefGlassQuality { auto, solid }

/// Establishes one shared backdrop input for non-overlapping glass islands.
///
/// A modal sheet can set [suspendBackdrop] to render the chrome below it with
/// the solid fallback, avoiding overlapping filters.
class El7reefGlassScope extends StatelessWidget {
  const El7reefGlassScope({
    super.key,
    required this.child,
    this.quality = El7reefGlassQuality.auto,
    this.suspendBackdrop = false,
  });

  final Widget child;
  final El7reefGlassQuality quality;
  final bool suspendBackdrop;

  static El7reefGlassScopeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<El7reefGlassScopeData>();
  }

  @override
  Widget build(BuildContext context) {
    return El7reefGlassScopeData(
      quality: quality,
      suspendBackdrop: suspendBackdrop,
      child: BackdropGroup(child: child),
    );
  }
}

class El7reefGlassScopeData extends InheritedWidget {
  const El7reefGlassScopeData({
    super.key,
    required this.quality,
    required this.suspendBackdrop,
    required super.child,
  });

  final El7reefGlassQuality quality;
  final bool suspendBackdrop;

  @override
  bool updateShouldNotify(covariant El7reefGlassScopeData oldWidget) {
    return quality != oldWidget.quality ||
        suspendBackdrop != oldWidget.suspendBackdrop;
  }
}

/// A functional Liquid Glass island.
///
/// Use this only for navigation, a single hero, floating toolbars, compact
/// sheets, preview chrome, or controls over media. Content cards, rows, forms,
/// errors and tables belong in `El7reefSolidSurface`.
class El7reefGlassSurface extends StatelessWidget {
  const El7reefGlassSurface({
    super.key,
    required this.child,
    required this.role,
    this.tone = El7reefGlassTone.neutral,
    this.padding,
    this.margin,
    this.radius,
    this.width,
    this.height,
    this.borderRadius,
    this.forceSolid = false,
  });

  final Widget child;
  final El7reefGlassRole role;
  final El7reefGlassTone tone;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final bool forceSolid;

  @override
  Widget build(BuildContext context) {
    final glassTheme = AppGlassTheme.of(context);
    final spec = glassTheme.resolve(role);
    final scope = El7reefGlassScope.maybeOf(context);
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final media = MediaQuery.maybeOf(context);
    final keyboardVisible = (media?.viewInsets.bottom ?? 0) > 0;
    final reduceEffects =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false) ||
        (media?.highContrast ?? false) ||
        FeatureFlags.reduceGlassBlurEnabled;
    // A route covered by a modal or a pushed screen keeps the exact fallback
    // geometry but stops sampling the backdrop. This guarantees that a short
    // sheet is the only active blur above the previous screen.
    final coveredByAnotherRoute = !routeIsCurrent;
    final blurEnabled =
        !forceSolid &&
        FeatureFlags.functionalGlassEnabled &&
        !reduceEffects &&
        !(scope?.suspendBackdrop ?? false) &&
        !coveredByAnotherRoute &&
        scope?.quality != El7reefGlassQuality.solid &&
        !(role == El7reefGlassRole.compactSheet && keyboardVisible);
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(radius ?? spec.radius);
    final toneColor = glassTheme.toneColor(tone);
    final baseColor = blurEnabled ? spec.fill : spec.fallback;
    final tintedColor = tone == El7reefGlassTone.neutral
        ? baseColor
        : Color.lerp(
            baseColor,
            toneColor.withValues(alpha: baseColor.a),
            role == El7reefGlassRole.hero ? 0.08 : 0.06,
          )!;

    Widget contents = Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Padding(
            padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
            child: child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassSpecularPainter(
                  color: spec.highlight,
                  radius: radius ?? spec.radius,
                  strokeWidth: glassTheme.specularWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    contents = DecoratedBox(
      decoration: BoxDecoration(
        color: tintedColor,
        borderRadius: effectiveRadius,
        border: Border.all(color: spec.border),
      ),
      child: contents,
    );

    if (blurEnabled) {
      contents = BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: spec.blurSigma,
          sigmaY: spec.blurSigma,
        ),
        child: contents,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: spec.shadowColor,
            blurRadius: spec.shadowBlur,
            offset: spec.shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: effectiveRadius, child: contents),
    );
  }
}

class _GlassSpecularPainter extends CustomPainter {
  const _GlassSpecularPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final safeRadius = radius.clamp(0.0, size.shortestSide / 2).toDouble();
    final path = Path()
      ..moveTo(0, safeRadius)
      ..quadraticBezierTo(0, 0, safeRadius, 0)
      ..lineTo(size.width - safeRadius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, safeRadius);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassSpecularPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
