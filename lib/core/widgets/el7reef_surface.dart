import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

class El7reefSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;

  const El7reefSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppDimensions.radiusLg,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color:
            color ?? (elevated ? AppColors.surfaceRaised : AppColors.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.surfaceBorder),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.shadowInk.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
