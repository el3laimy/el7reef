import 'package:flutter/widgets.dart';

class ProfessionalPitchLayoutMetrics {
  final double width;
  final double height;
  final bool denseSquad;
  final bool compact;
  final double nodeWidth;
  final double nodeHeight;
  final double hitPadding;
  final double hitWidth;
  final double hitHeight;

  const ProfessionalPitchLayoutMetrics({
    required this.width,
    required this.height,
    required this.denseSquad,
    required this.compact,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.hitPadding,
    required this.hitWidth,
    required this.hitHeight,
  });

  factory ProfessionalPitchLayoutMetrics.calculate({
    required double width,
    required int playerCount,
    required bool presentationMode,
    required bool editorMode,
  }) {
    final denseSquad = playerCount >= 11;
    final heightFactor = presentationMode
        ? 1.66
        : denseSquad
        ? 1.55
        : 1.42;
    final height = (width * heightFactor).clamp(410.0, 680.0);
    final compact = denseSquad || playerCount >= 9 || width < 360;
    final nodeWidth = denseSquad
        ? 48.0
        : compact
        ? 64.0
        : 76.0;
    final nodeHeight = denseSquad
        ? 76.0
        : compact
        ? 94.0
        : 112.0;
    final hitPadding = editorMode
        ? denseSquad
              ? 6.0
              : 10.0
        : 0.0;
    return ProfessionalPitchLayoutMetrics(
      width: width,
      height: height,
      denseSquad: denseSquad,
      compact: compact,
      nodeWidth: nodeWidth,
      nodeHeight: nodeHeight,
      hitPadding: hitPadding,
      hitWidth: nodeWidth + hitPadding * 2,
      hitHeight: nodeHeight + hitPadding * 2,
    );
  }
}

class PitchLayout {
  const PitchLayout._();

  static Offset project({
    required double x,
    required double y,
    required double width,
    required double height,
    double? minY,
    double? maxY,
    bool expandVertical = false,
    bool denseSquad = false,
  }) {
    final normalizedX = x / 100.0;
    final normalizedY = y / 100.0;
    final horizontalPerspective = denseSquad
        ? 0.92 + (0.98 - 0.92) * normalizedY
        : 0.8 + (0.92 - 0.8) * normalizedY;
    final usableWidth = width * (denseSquad ? 0.96 : 0.92);
    final marginY = height * 0.13;
    final usableHeight = height * 0.77;
    final screenX =
        width / 2 + (normalizedX - 0.5) * usableWidth * horizontalPerspective;
    final verticalRange = (maxY ?? 0) - (minY ?? 0);
    final screenY = expandVertical && verticalRange > 0
        ? height * 0.17 + ((y - minY!) / verticalRange) * height * 0.7
        : marginY + normalizedY * usableHeight;
    return Offset(screenX, screenY);
  }

  static double positionedCoordinate({
    required double percentage,
    required double totalExtent,
    required double childExtent,
    double edgeInset = 2,
  }) {
    final raw =
        (percentage.clamp(0, 100) / 100) * totalExtent - childExtent / 2;
    final max = totalExtent - childExtent - edgeInset;
    if (max <= edgeInset) return edgeInset;
    return raw.clamp(edgeInset, max).toDouble();
  }
}
