import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_media_colors.dart';
import 'identity_preset.dart';

/// Scalable, dependency-free renderer for a built-in identity preset.
class IdentityPresetMark extends StatelessWidget {
  const IdentityPresetMark({
    super.key,
    required this.preset,
    this.size = 72,
    this.semanticLabel,
  });

  final IdentityPreset preset;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel ?? preset.nameAr,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            key: ValueKey<String>('identity-mark-${preset.value}'),
            painter: _IdentityPresetPainter(preset),
          ),
        ),
      ),
    );
  }
}

class _IdentityPresetPainter extends CustomPainter {
  const _IdentityPresetPainter(this.preset);

  final IdentityPreset preset;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final bounds = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side * 0.9,
      height: side * 0.9,
    );

    switch (preset.family) {
      case IdentityPresetFamily.teamBadge:
        _paintBadge(canvas, bounds);
      case IdentityPresetFamily.teamPennant:
        _paintPennant(canvas, bounds);
      case IdentityPresetFamily.tournamentEmblem:
        _paintTournamentEmblem(canvas, bounds);
    }
  }

  void _paintBadge(Canvas canvas, Rect rect) {
    final shield = Path()
      ..moveTo(rect.left + rect.width * 0.17, rect.top + rect.height * 0.08)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top - rect.height * 0.01,
        rect.right - rect.width * 0.17,
        rect.top + rect.height * 0.08,
      )
      ..lineTo(rect.right - rect.width * 0.08, rect.top + rect.height * 0.48)
      ..quadraticBezierTo(
        rect.right - rect.width * 0.14,
        rect.bottom - rect.height * 0.18,
        rect.center.dx,
        rect.bottom,
      )
      ..quadraticBezierTo(
        rect.left + rect.width * 0.14,
        rect.bottom - rect.height * 0.18,
        rect.left + rect.width * 0.08,
        rect.top + rect.height * 0.48,
      )
      ..close();

    _paintFrame(canvas, shield, rect);
    canvas.save();
    canvas.clipPath(shield);
    _paintMotif(canvas, rect.deflate(rect.width * 0.2));
    canvas.restore();
    _paintOutline(canvas, shield, rect.width * 0.035);
  }

  void _paintPennant(Canvas canvas, Rect rect) {
    final pennant = Path()
      ..moveTo(rect.left + rect.width * 0.12, rect.top + rect.height * 0.05)
      ..lineTo(rect.right - rect.width * 0.08, rect.top + rect.height * 0.05)
      ..lineTo(rect.right - rect.width * 0.08, rect.bottom - rect.height * 0.27)
      ..lineTo(rect.center.dx, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.12, rect.bottom - rect.height * 0.27)
      ..close();

    canvas.drawPath(
      pennant,
      Paint()
        ..color = preset.primaryColor
        ..style = PaintingStyle.fill,
    );
    canvas.save();
    canvas.clipPath(pennant);
    _paintPennantPattern(canvas, rect);
    canvas.restore();
    _paintOutline(canvas, pennant, rect.width * 0.035);

    canvas.drawLine(
      Offset(rect.left + rect.width * 0.12, rect.top),
      Offset(rect.left + rect.width * 0.12, rect.bottom - rect.height * 0.21),
      Paint()
        ..color = AppMediaColors.textPrimary
        ..strokeWidth = rect.width * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTournamentEmblem(Canvas canvas, Rect rect) {
    final hex = Path();
    for (var index = 0; index < 6; index++) {
      final angle = -math.pi / 2 + index * math.pi / 3;
      final point = Offset(
        rect.center.dx + math.cos(angle) * rect.width * 0.48,
        rect.center.dy + math.sin(angle) * rect.height * 0.48,
      );
      if (index == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();

    _paintFrame(canvas, hex, rect);
    canvas.drawCircle(
      rect.center,
      rect.width * 0.32,
      Paint()
        ..color = AppMediaColors.canvasDeep.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      rect.center,
      rect.width * 0.32,
      Paint()
        ..color = preset.secondaryColor
        ..strokeWidth = rect.width * 0.025
        ..style = PaintingStyle.stroke,
    );
    _paintMotif(canvas, rect.deflate(rect.width * 0.25));
    _paintOutline(canvas, hex, rect.width * 0.035);
  }

  void _paintFrame(Canvas canvas, Path path, Rect rect) {
    canvas.drawPath(
      path,
      Paint()
        ..color = preset.primaryColor
        ..style = PaintingStyle.fill,
    );

    final inset = rect.width * 0.045;
    canvas.drawPath(
      path.shift(Offset(0, inset * 0.15)),
      Paint()
        ..color = preset.secondaryColor.withValues(alpha: 0.34)
        ..strokeWidth = inset
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintOutline(Canvas canvas, Path path, double width) {
    canvas.drawPath(
      path,
      Paint()
        ..color = AppMediaColors.canvasDeep.withValues(alpha: 0.72)
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintMotif(Canvas canvas, Rect rect) {
    final foreground = Paint()
      ..color = preset.secondaryColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (preset.motif) {
      case IdentityPresetMotif.bolt:
        _paintBolt(canvas, rect, foreground);
      case IdentityPresetMotif.wing:
        _paintWing(canvas, rect, foreground);
      case IdentityPresetMotif.gate:
        _paintGate(canvas, rect, foreground);
      case IdentityPresetMotif.flame:
        _paintIcon(canvas, rect, Icons.local_fire_department_rounded);
      case IdentityPresetMotif.bridge:
        _paintBridge(canvas, rect, foreground);
      case IdentityPresetMotif.stripes:
        _paintStripes(canvas, rect, foreground);
      case IdentityPresetMotif.panther:
        _paintIcon(canvas, rect, Icons.pets_rounded);
      case IdentityPresetMotif.goalNet:
        _paintGoalNet(canvas, rect, foreground);
      case IdentityPresetMotif.sunrise:
        _paintSunrise(canvas, rect, foreground);
      case IdentityPresetMotif.crossedLines:
        _paintCrossedLines(canvas, rect, foreground);
      case IdentityPresetMotif.floodlights:
        _paintFloodlights(canvas, rect, foreground);
      case IdentityPresetMotif.cityBlocks:
        _paintCityBlocks(canvas, rect, foreground);
      case IdentityPresetMotif.centerCircle:
        _paintCenterCircle(canvas, rect, foreground);
      case IdentityPresetMotif.whistle:
        _paintIcon(canvas, rect, Icons.sports_rounded);
      case IdentityPresetMotif.matchBall:
        _paintIcon(canvas, rect, Icons.sports_soccer_rounded);
      case IdentityPresetMotif.diagonal:
      case IdentityPresetMotif.chevron:
      case IdentityPresetMotif.split:
      case IdentityPresetMotif.horizon:
      case IdentityPresetMotif.sash:
      case IdentityPresetMotif.channels:
        _paintIcon(canvas, rect, Icons.sports_soccer_rounded);
    }
  }

  void _paintBolt(Canvas canvas, Rect rect, Paint paint) {
    final bolt = Path()
      ..moveTo(rect.center.dx + rect.width * 0.08, rect.top)
      ..lineTo(
        rect.left + rect.width * 0.22,
        rect.center.dy + rect.height * 0.06,
      )
      ..lineTo(
        rect.center.dx - rect.width * 0.02,
        rect.center.dy + rect.height * 0.06,
      )
      ..lineTo(rect.center.dx - rect.width * 0.12, rect.bottom)
      ..lineTo(
        rect.right - rect.width * 0.18,
        rect.center.dy - rect.height * 0.12,
      )
      ..lineTo(
        rect.center.dx + rect.width * 0.08,
        rect.center.dy - rect.height * 0.12,
      )
      ..close();
    canvas.drawPath(bolt, paint..style = PaintingStyle.fill);
  }

  void _paintWing(Canvas canvas, Rect rect, Paint paint) {
    final wing = Path()
      ..moveTo(rect.left, rect.center.dy + rect.height * 0.27)
      ..quadraticBezierTo(rect.center.dx, rect.top, rect.right, rect.top)
      ..quadraticBezierTo(
        rect.center.dx + rect.width * 0.12,
        rect.center.dy,
        rect.left,
        rect.center.dy + rect.height * 0.27,
      )
      ..close();
    canvas.drawPath(wing, paint..style = PaintingStyle.fill);
    for (var index = 1; index <= 3; index++) {
      canvas.drawLine(
        Offset(
          rect.left + rect.width * 0.18 * index,
          rect.bottom - rect.height * 0.2,
        ),
        Offset(
          rect.left + rect.width * 0.31 * index,
          rect.top + rect.height * 0.12,
        ),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.055,
      );
    }
  }

  void _paintGate(Canvas canvas, Rect rect, Paint paint) {
    final gate = Path()
      ..moveTo(rect.left + rect.width * 0.12, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.12, rect.center.dy)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top,
        rect.right - rect.width * 0.12,
        rect.center.dy,
      )
      ..lineTo(rect.right - rect.width * 0.12, rect.bottom)
      ..lineTo(rect.right - rect.width * 0.32, rect.bottom)
      ..lineTo(
        rect.right - rect.width * 0.32,
        rect.center.dy + rect.height * 0.03,
      )
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top + rect.height * 0.3,
        rect.left + rect.width * 0.32,
        rect.center.dy + rect.height * 0.03,
      )
      ..lineTo(rect.left + rect.width * 0.32, rect.bottom)
      ..close();
    canvas.drawPath(gate, paint..style = PaintingStyle.fill);
  }

  void _paintBridge(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.08;
    final deckY = rect.center.dy + rect.height * 0.22;
    final bridge = Path()
      ..moveTo(rect.left, deckY)
      ..quadraticBezierTo(rect.center.dx, rect.top, rect.right, deckY);
    canvas.drawPath(bridge, paint);
    canvas.drawLine(Offset(rect.left, deckY), Offset(rect.right, deckY), paint);
    for (var index = 1; index <= 3; index++) {
      final x = rect.left + rect.width * index / 4;
      canvas.drawLine(
        Offset(x, deckY),
        Offset(x, rect.top + rect.height * 0.24),
        paint..strokeWidth = rect.width * 0.035,
      );
    }
  }

  void _paintStripes(Canvas canvas, Rect rect, Paint paint) {
    final stripeWidth = rect.width * 0.16;
    for (var index = 0; index < 3; index++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + rect.width * (0.18 + index * 0.24),
            rect.top,
            stripeWidth,
            rect.height,
          ),
          Radius.circular(stripeWidth / 2),
        ),
        paint..style = PaintingStyle.fill,
      );
    }
  }

  void _paintGoalNet(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.035;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.08)),
      paint,
    );
    for (var index = 1; index < 4; index++) {
      final x = rect.left + rect.width * index / 4;
      final y = rect.top + rect.height * index / 4;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _paintSunrise(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.065;
    final center = Offset(rect.center.dx, rect.bottom);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rect.width * 0.31),
      math.pi,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    for (var index = 0; index < 5; index++) {
      final angle = math.pi + index * math.pi / 4;
      final ray = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + ray * rect.width * 0.36,
        center + ray * rect.width * 0.48,
        paint..strokeWidth = rect.width * 0.045,
      );
    }
  }

  void _paintCrossedLines(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.09;
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
    canvas.drawCircle(
      rect.center,
      rect.width * 0.12,
      paint..style = PaintingStyle.fill,
    );
  }

  void _paintCityBlocks(Canvas canvas, Rect rect, Paint paint) {
    const relativeHeights = <double>[0.52, 0.82, 0.66, 0.94];
    paint.style = PaintingStyle.fill;
    for (var index = 0; index < relativeHeights.length; index++) {
      final blockHeight = rect.height * relativeHeights[index];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + rect.width * (0.08 + index * 0.23),
            rect.bottom - blockHeight,
            rect.width * 0.18,
            blockHeight,
          ),
          Radius.circular(rect.width * 0.025),
        ),
        paint,
      );
    }
  }

  void _paintCenterCircle(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.055;
    canvas.drawCircle(rect.center, rect.width * 0.3, paint);
    canvas.drawLine(
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      paint,
    );
    canvas.drawCircle(
      rect.center,
      rect.width * 0.055,
      paint..style = PaintingStyle.fill,
    );
  }

  void _paintFloodlights(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.055;
    for (final direction in <double>[-1, 1]) {
      final poleX = rect.center.dx + direction * rect.width * 0.27;
      canvas.drawLine(
        Offset(poleX, rect.bottom),
        Offset(
          poleX - direction * rect.width * 0.08,
          rect.top + rect.height * 0.25,
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              poleX - direction * rect.width * 0.1,
              rect.top + rect.height * 0.18,
            ),
            width: rect.width * 0.24,
            height: rect.height * 0.18,
          ),
          Radius.circular(rect.width * 0.04),
        ),
        paint..style = PaintingStyle.fill,
      );
    }
  }

  void _paintPennantPattern(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = preset.secondaryColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (preset.motif) {
      case IdentityPresetMotif.diagonal:
        _paintDiagonalPennant(canvas, rect, paint);
      case IdentityPresetMotif.chevron:
        _paintChevronPennant(canvas, rect, paint);
      case IdentityPresetMotif.split:
        _paintSplitPennant(canvas, rect, paint);
      case IdentityPresetMotif.horizon:
        _paintHorizonPennant(canvas, rect, paint);
      case IdentityPresetMotif.sash:
        _paintSashPennant(canvas, rect, paint);
      case IdentityPresetMotif.channels:
        _paintChannelsPennant(canvas, rect, paint);
      case IdentityPresetMotif.bolt:
      case IdentityPresetMotif.wing:
      case IdentityPresetMotif.gate:
      case IdentityPresetMotif.flame:
      case IdentityPresetMotif.bridge:
      case IdentityPresetMotif.stripes:
      case IdentityPresetMotif.panther:
      case IdentityPresetMotif.goalNet:
      case IdentityPresetMotif.sunrise:
      case IdentityPresetMotif.crossedLines:
      case IdentityPresetMotif.floodlights:
      case IdentityPresetMotif.cityBlocks:
      case IdentityPresetMotif.centerCircle:
      case IdentityPresetMotif.whistle:
      case IdentityPresetMotif.matchBall:
        break;
    }
  }

  void _paintDiagonalPennant(Canvas canvas, Rect rect, Paint paint) {
    final band = Path()
      ..moveTo(rect.left - rect.width * 0.1, rect.top + rect.height * 0.21)
      ..lineTo(rect.left + rect.width * 0.09, rect.top)
      ..lineTo(rect.right, rect.bottom - rect.height * 0.19)
      ..lineTo(rect.right, rect.bottom + rect.height * 0.08)
      ..close();
    canvas.drawPath(band, paint);
  }

  void _paintChevronPennant(Canvas canvas, Rect rect, Paint paint) {
    final chevron = Path()
      ..moveTo(rect.left + rect.width * 0.16, rect.top + rect.height * 0.24)
      ..lineTo(rect.center.dx, rect.center.dy + rect.height * 0.11)
      ..lineTo(rect.right - rect.width * 0.08, rect.top + rect.height * 0.24);
    canvas.drawPath(
      chevron,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.14,
    );
  }

  void _paintSplitPennant(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRect(
      Rect.fromLTRB(rect.center.dx, rect.top, rect.right, rect.bottom),
      paint,
    );
  }

  void _paintHorizonPennant(Canvas canvas, Rect rect, Paint paint) {
    final wave = Path()
      ..moveTo(rect.left, rect.center.dy)
      ..quadraticBezierTo(
        rect.left + rect.width * 0.27,
        rect.center.dy - rect.height * 0.12,
        rect.center.dx,
        rect.center.dy,
      )
      ..quadraticBezierTo(
        rect.right - rect.width * 0.2,
        rect.center.dy + rect.height * 0.12,
        rect.right,
        rect.center.dy,
      )
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    canvas.drawPath(wave, paint);
  }

  void _paintSashPennant(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.08, rect.bottom - rect.height * 0.18),
      Offset(rect.right, rect.top + rect.height * 0.15),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.18,
    );
  }

  void _paintChannelsPennant(Canvas canvas, Rect rect, Paint paint) {
    for (var index = 0; index < 3; index++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + rect.width * (0.22 + index * 0.21),
            rect.top + rect.height * 0.1,
            rect.width * 0.1,
            rect.height * 0.68,
          ),
          Radius.circular(rect.width * 0.05),
        ),
        paint..style = PaintingStyle.fill,
      );
    }
  }

  void _paintIcon(Canvas canvas, Rect rect, IconData icon) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: preset.secondaryColor,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: rect.shortestSide * 0.9,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _IdentityPresetPainter oldDelegate) {
    return oldDelegate.preset.reference != preset.reference ||
        oldDelegate.preset.primaryColor != preset.primaryColor ||
        oldDelegate.preset.secondaryColor != preset.secondaryColor;
  }
}
