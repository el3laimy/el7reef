import 'package:flutter/material.dart';

class PrideCardTextScale extends StatelessWidget {
  static const double denseLayoutThreshold = 1;
  static const double maximumScale = 2;

  final Widget child;

  const PrideCardTextScale({super.key, required this.child});

  static bool usesDenseLayout(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > denseLayoutThreshold;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final requestedScale = mediaQuery.textScaler.scale(1);
    // A fixed-size social canvas cannot reflow like a normal screen. As soon
    // as the user requests enlarged text, use the tested 200% layout so the
    // type never becomes smaller at an intermediate accessibility setting.
    final effectiveScale = requestedScale > denseLayoutThreshold
        ? maximumScale
        : requestedScale.clamp(0, maximumScale).toDouble();

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(effectiveScale)),
      child: child,
    );
  }
}
