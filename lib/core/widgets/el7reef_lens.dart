import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_glass_theme.dart';

/// A materialized glass lens for repeated selection states.
///
/// It shares the Liquid Glass edge language without creating a backdrop blur.
class El7reefLens extends StatefulWidget {
  const El7reefLens({
    super.key,
    required this.child,
    this.tone = El7reefGlassTone.action,
    this.selected = false,
    this.onTap,
    this.padding,
    this.radius = AppDimensions.radiusMd,
  });

  final Widget child;
  final El7reefGlassTone tone;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  State<El7reefLens> createState() => _El7reefLensState();
}

class _El7reefLensState extends State<El7reefLens> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final glassTheme = AppGlassTheme.of(context);
    final tone = glassTheme.toneColor(widget.tone);
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    final restingColor = Color.lerp(
      AppColors.surface,
      tone,
      widget.selected ? 0.12 : 0.035,
    )!;
    final selectedColor = _pressed
        ? Color.lerp(restingColor, AppColors.actionPrimary, 0.1)!
        : restingColor;
    final border = widget.selected
        ? tone.withValues(alpha: 0.45)
        : AppColors.surfaceBorder;
    final content = AnimatedScale(
      scale: !reduceMotion && _pressed ? glassTheme.pressScale : 1,
      duration: reduceMotion ? Duration.zero : glassTheme.pressDuration,
      curve: glassTheme.motionCurve,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : glassTheme.selectionDuration,
        curve: glassTheme.motionCurve,
        padding:
            widget.padding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedColor,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: border),
          boxShadow: widget.selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1017202C),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return content;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
