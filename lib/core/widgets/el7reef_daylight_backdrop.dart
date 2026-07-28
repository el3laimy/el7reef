import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The single, static background treatment used by operational Android routes.
///
/// Screens may choose one semantic [glowColor]. The glow remains deliberately
/// faint and never animates, so content surfaces retain outdoor readability.
class El7reefDaylightBackdrop extends StatelessWidget {
  const El7reefDaylightBackdrop({
    super.key,
    required this.child,
    this.glowColor = AppColors.actionPrimary,
  });

  final Widget child;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.9),
                  radius: 0.9,
                  colors: <Color>[
                    glowColor.withValues(
                      alpha: AppColors.contextualGlowOpacity,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
