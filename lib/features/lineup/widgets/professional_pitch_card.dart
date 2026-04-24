import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_node.dart';

typedef FormationSlotCallback = void Function(FormationSlot slot);
typedef FormationPlayerSlotCallback =
    void Function(FormationSlot slot, LineupPlayer player);
typedef FormationSlotDropCallback =
    void Function(FormationSlot slot, LineupPlayer droppedPlayer);

class ProfessionalPitchCard extends StatelessWidget {
  final List<FormationSlot> slots;
  final Map<String, LineupPlayer> playersByKey;
  final String formationCode;
  final int playerCount;
  final bool editorMode;
  final bool presentationMode;
  final String? teamName;
  final FormationSlotCallback? onEmptySlotTap;
  final FormationPlayerSlotCallback? onPlayerTap;
  final FormationPlayerSlotCallback? onPlayerLongPress;
  final FormationSlotDropCallback? onPlayerDrop;

  const ProfessionalPitchCard({
    super.key,
    required this.slots,
    required this.playersByKey,
    required this.formationCode,
    required this.playerCount,
    this.editorMode = false,
    this.presentationMode = false,
    this.teamName,
    this.onEmptySlotTap,
    this.onPlayerTap,
    this.onPlayerLongPress,
    this.onPlayerDrop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - AppDimensions.pagePadding * 2;
        final heightFactor = presentationMode ? 1.58 : 1.5;
        final height = (width * heightFactor).clamp(430.0, 660.0);
        final compact = playerCount >= 9 || width < 360;
        final nodeWidth = compact ? 64.0 : 76.0;
        final nodeHeight = compact ? 72.0 : 84.0;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _LineupPitchPainter()),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.18),
                      radius: 0.8,
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.13),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 14,
                start: 14,
                child: _PitchBadge(
                  icon: Icons.grid_view_rounded,
                  label: formationCode,
                ),
              ),
              if ((teamName ?? '').isNotEmpty)
                PositionedDirectional(
                  top: 14,
                  end: 14,
                  child: _PitchBadge(
                    icon: Icons.shield_rounded,
                    label: teamName!,
                    maxWidth: width * 0.42,
                  ),
                ),
              ...slots.map((slot) {
                final player = slot.occupantKey == null
                    ? null
                    : playersByKey[slot.occupantKey];
                final left = (slot.x / 100) * width - nodeWidth / 2;
                final top = (slot.y / 100) * height - nodeHeight / 2;
                final clampedLeft = left
                    .clamp(4.0, math.max(4.0, width - nodeWidth - 4))
                    .toDouble();
                final clampedTop = top
                    .clamp(12.0, math.max(12.0, height - nodeHeight - 8))
                    .toDouble();

                Widget nodeWidget = LineupPlayerNode(
                  player: player,
                  role: slot.role,
                  compact: compact,
                  presentationMode: presentationMode,
                  onTap: player == null
                      ? (editorMode ? () => onEmptySlotTap?.call(slot) : null)
                      : () => onPlayerTap?.call(slot, player),
                  onLongPress: player == null
                      ? null
                      : () => onPlayerLongPress?.call(slot, player),
                );

                // Wrap occupied slot in Draggable for drag-out.
                if (editorMode && player != null) {
                  nodeWidget = Draggable<LineupPlayer>(
                    data: player,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: nodeWidth,
                        child: Opacity(opacity: 0.85, child: nodeWidget),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: nodeWidget),
                    child: nodeWidget,
                  );
                }

                // Wrap in DragTarget for drop-in.
                if (editorMode && onPlayerDrop != null) {
                  final targetChild = nodeWidget;
                  nodeWidget = DragTarget<LineupPlayer>(
                    onAcceptWithDetails: (details) {
                      onPlayerDrop!(slot, details.data);
                    },
                    builder: (context, candidateData, rejectedData) {
                      if (candidateData.isNotEmpty) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 2,
                            ),
                          ),
                          child: targetChild,
                        );
                      }
                      return targetChild;
                    },
                  );
                }

                return Positioned(
                  left: clampedLeft,
                  top: clampedTop,
                  width: nodeWidth,
                  child: nodeWidget,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _PitchBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;

  const _PitchBadge({required this.icon, required this.label, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryLight),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF155E2C),
          Color(0xFF0D4D27),
          Color(0xFF166534),
          Color(0xFF0B3D24),
        ],
        stops: [0, 0.34, 0.66, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;
    const stripeCount = 12;
    final stripeHeight = h / stripeCount;
    for (var i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, w, stripeHeight),
        stripePaint,
      );
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.26)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    final softLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;

    final margin = w * 0.055;
    final pitchRect = Rect.fromLTRB(margin, margin, w - margin, h - margin);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(14)),
      linePaint,
    );

    canvas.drawLine(
      Offset(margin, h / 2),
      Offset(w - margin, h / 2),
      linePaint,
    );
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.17, linePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), 3.2, dotPaint);

    final penaltyWidth = w * 0.58;
    final penaltyHeight = h * 0.16;
    final goalWidth = w * 0.3;
    final goalHeight = h * 0.058;

    _drawPenaltyArea(
      canvas: canvas,
      w: w,
      h: h,
      margin: margin,
      penaltyWidth: penaltyWidth,
      penaltyHeight: penaltyHeight,
      goalWidth: goalWidth,
      goalHeight: goalHeight,
      top: true,
      linePaint: linePaint,
      softLinePaint: softLinePaint,
      dotPaint: dotPaint,
    );
    _drawPenaltyArea(
      canvas: canvas,
      w: w,
      h: h,
      margin: margin,
      penaltyWidth: penaltyWidth,
      penaltyHeight: penaltyHeight,
      goalWidth: goalWidth,
      goalHeight: goalHeight,
      top: false,
      linePaint: linePaint,
      softLinePaint: softLinePaint,
      dotPaint: dotPaint,
    );

    final cornerRadius = w * 0.045;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(margin, margin), radius: cornerRadius),
      0,
      math.pi / 2,
      false,
      softLinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - margin, margin), radius: cornerRadius),
      math.pi / 2,
      math.pi / 2,
      false,
      softLinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(margin, h - margin), radius: cornerRadius),
      -math.pi / 2,
      math.pi / 2,
      false,
      softLinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(w - margin, h - margin),
        radius: cornerRadius,
      ),
      math.pi,
      math.pi / 2,
      false,
      softLinePaint,
    );
  }

  void _drawPenaltyArea({
    required Canvas canvas,
    required double w,
    required double h,
    required double margin,
    required double penaltyWidth,
    required double penaltyHeight,
    required double goalWidth,
    required double goalHeight,
    required bool top,
    required Paint linePaint,
    required Paint softLinePaint,
    required Paint dotPaint,
  }) {
    final y = top ? margin : h - margin - penaltyHeight;
    final goalY = top ? margin : h - margin - goalHeight;
    canvas.drawRect(
      Rect.fromLTWH((w - penaltyWidth) / 2, y, penaltyWidth, penaltyHeight),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - goalWidth) / 2, goalY, goalWidth, goalHeight),
      linePaint,
    );
    canvas.drawCircle(
      Offset(w / 2, top ? y + penaltyHeight * 0.68 : y + penaltyHeight * 0.32),
      2.4,
      dotPaint,
    );
    final arcCenterY = top ? y + penaltyHeight : y;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w / 2, arcCenterY),
        width: w * 0.24,
        height: w * 0.14,
      ),
      top ? 0 : math.pi,
      math.pi,
      false,
      softLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
