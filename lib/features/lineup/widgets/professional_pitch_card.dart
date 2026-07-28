import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_media_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/pitch_layout.dart';
import 'lineup_player_display.dart';
import 'lineup_player_node.dart';

typedef FormationSlotCallback = void Function(FormationSlot slot);
typedef FormationPlayerSlotCallback =
    void Function(FormationSlot slot, LineupPlayer player);
typedef FormationSlotDropCallback =
    void Function(FormationSlot slot, LineupDragPayload payload);

class ProfessionalPitchCard extends StatefulWidget {
  final List<FormationSlot> slots;
  final Map<String, LineupPlayer> playersByKey;
  final String formationCode;
  final int playerCount;
  final bool editorMode;
  final bool presentationMode;
  final String? teamName;
  final String? selectedPlayerKey;
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
    this.selectedPlayerKey,
    this.onEmptySlotTap,
    this.onPlayerTap,
    this.onPlayerLongPress,
    this.onPlayerDrop,
  });

  @override
  State<ProfessionalPitchCard> createState() => _ProfessionalPitchCardState();
}

class _ProfessionalPitchCardState extends State<ProfessionalPitchCard> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - AppDimensions.pagePadding * 2;
        final layout = ProfessionalPitchLayoutMetrics.calculate(
          width: width,
          playerCount: widget.playerCount,
          presentationMode: widget.presentationMode,
          editorMode: widget.editorMode,
        );
        final denseSquad = layout.denseSquad;
        final height = layout.height;
        final compact = layout.compact;
        final nodeWidth = layout.nodeWidth;
        final hitPadding = layout.hitPadding;
        final hitWidth = layout.hitWidth;
        final hitHeight = layout.hitHeight;
        final expandVertical =
            !widget.presentationMode && widget.slots.length >= 5;
        final minSlotY = widget.slots.isEmpty
            ? 0.0
            : widget.slots.map((slot) => slot.y).reduce(math.min);
        final maxSlotY = widget.slots.isEmpty
            ? 100.0
            : widget.slots.map((slot) => slot.y).reduce(math.max);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: AppMediaColors.pitchActionLight.withValues(alpha: 0.38),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppMediaColors.pitchCanvasDeep.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── LAYER 1: STATIC PITCH BACKGROUND ──
              Positioned.fill(
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: widget.presentationMode
                            ? Image.asset(
                                'assets/images/pitch_3d_bg.png',
                                fit: BoxFit.cover,
                              )
                            : const CustomPaint(
                                painter: _StreetSquadPitchPainter(),
                              ),
                      ),
                      if (!widget.presentationMode)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, -0.08),
                                radius: 0.92,
                                colors: [
                                  AppMediaColors.pitchActionLight.withValues(
                                    alpha: 0.06,
                                  ),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                                stops: const [0, 0.58, 1],
                              ),
                            ),
                          ),
                        ),

                      // Zone labels (GK/DEF/MID/ATT markers)
                      ..._buildZoneLabels(height),
                    ],
                  ),
                ),
              ),

              // ── LAYER 2: TACTICAL NETWORKS ──
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: CustomPaint(
                    painter: TacticalNetworkPainter(
                      slots: widget.slots,
                      presentationMode: widget.presentationMode,
                      expandVertical: expandVertical,
                      minY: minSlotY,
                      maxY: maxSlotY,
                      denseSquad: denseSquad,
                    ),
                  ),
                ),
              ),

              // ── LAYER 3: STATIC PITCH BADGES ──
              if (!widget.presentationMode) ...[
                PositionedDirectional(
                  top: 14,
                  start: 14,
                  child: _PitchBadge(
                    icon: Icons.grid_view_rounded,
                    label: widget.formationCode,
                  ),
                ),
                if ((widget.teamName ?? '').isNotEmpty)
                  PositionedDirectional(
                    top: 14,
                    end: 14,
                    child: _PitchBadge(
                      icon: Icons.shield_rounded,
                      label: widget.teamName!,
                      maxWidth: width * 0.42,
                    ),
                  ),
              ],

              // ── LAYER 4: PRESENTATIONAL POSTER HEADERS ──
              if (widget.presentationMode) ...[
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        'التشكيلة الرسمية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: (width * 0.078).clamp(24.0, 32.0),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFCB57),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: width * 0.12,
                            height: 1.0,
                            color: const Color(
                              0xFFF5A623,
                            ).withValues(alpha: 0.45),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'الخطة التكتيكية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: (width * 0.038).clamp(11.0, 14.0),
                                fontWeight: FontWeight.w700,
                                color: AppMediaColors.pitchTextSecondary,
                              ),
                            ),
                          ),
                          Container(
                            width: width * 0.12,
                            height: 1.0,
                            color: const Color(
                              0xFFF5A623,
                            ).withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCD0A0E0B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF5A623),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF5A623,
                              ).withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.formationCode,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: (width * 0.052).clamp(16.0, 20.0),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFF5A623),
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  top: 20,
                  start: 16,
                  child: _buildEmblemBadge(width),
                ),
              ],

              // ── LAYER 5: INTERACTIVE PLAYER NODES ──
              ...widget.slots.map((slot) {
                final player = slot.occupantKey == null
                    ? null
                    : widget.playersByKey[slot.occupantKey];

                final projected = PitchLayout.project(
                  x: slot.x,
                  y: slot.y,
                  width: width,
                  height: height,
                  expandVertical: expandVertical,
                  minY: minSlotY,
                  maxY: maxSlotY,
                  denseSquad: denseSquad,
                );
                final left = projected.dx - hitWidth / 2;
                final top = projected.dy - hitHeight / 2;

                final clampedLeft = left
                    .clamp(2.0, math.max(2.0, width - hitWidth - 2))
                    .toDouble();
                final clampedTop = top
                    .clamp(12.0, math.max(12.0, height - hitHeight - 6))
                    .toDouble();

                final perspectiveScale = widget.presentationMode
                    ? 0.78 + 0.18 * (slot.y / 100)
                    : 1.0;

                Widget nodeWidget = Transform.scale(
                  scale: perspectiveScale,
                  child: LineupPlayerNode(
                    key: ValueKey('lineup-node-${slot.id}'),
                    player: player,
                    role: slot.role,
                    isSelected:
                        player != null &&
                        player.key == widget.selectedPlayerKey,
                    compact: compact,
                    dense: denseSquad,
                    onTap: player == null
                        ? (widget.editorMode
                              ? () => widget.onEmptySlotTap?.call(slot)
                              : null)
                        : () => widget.onPlayerTap?.call(slot, player),
                    onLongPress: player == null
                        ? null
                        : () => widget.onPlayerLongPress?.call(slot, player),
                  ),
                );

                if (widget.editorMode && player != null) {
                  nodeWidget = Draggable<LineupDragPayload>(
                    data: LineupDragPayload(
                      player: player,
                      sourceSlotId: slot.id,
                    ),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedbackOffset: Offset.zero,
                    maxSimultaneousDrags: 1,
                    onDragStarted: () {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                      });
                    },
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

                if (widget.editorMode && widget.onPlayerDrop != null) {
                  final targetChild = nodeWidget;
                  final targetColor = lineupRoleColor(slot.role);
                  final selectedTapModeActive =
                      widget.selectedPlayerKey != null &&
                      !widget.presentationMode;
                  final isSelectedSlot =
                      player != null && player.key == widget.selectedPlayerKey;
                  nodeWidget = DragTarget<LineupDragPayload>(
                    onWillAcceptWithDetails: (details) {
                      return details.data.sourceSlotId != slot.id;
                    },
                    onAcceptWithDetails: (details) {
                      widget.onPlayerDrop!(slot, details.data);
                    },
                    builder: (context, candidateData, rejectedData) {
                      LineupDragPayload? payload;
                      for (final candidate in candidateData) {
                        if (candidate != null) {
                          payload = candidate;
                          break;
                        }
                      }
                      final isActive = payload != null;
                      final incomingPlayer = isActive ? payload.player : null;
                      final actionLabel = player == null
                          ? 'ضع هنا'
                          : incomingPlayer == null
                          ? 'بدّل'
                          : 'بدّل مع ${lineupDisplayName(player)}';
                      if (candidateData.isNotEmpty) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.all(hitPadding * 0.45),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: targetColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: targetColor.withValues(alpha: 0.95),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: targetColor.withValues(alpha: 0.42),
                                blurRadius: 18,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              targetChild,
                              PositionedDirectional(
                                top: -8,
                                child: _DropActionBadge(
                                  label: actionLabel,
                                  color: targetColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (selectedTapModeActive && !isSelectedSlot) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.all(hitPadding * 0.45),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: targetColor.withValues(alpha: 0.07),
                            border: Border.all(
                              color: targetColor.withValues(alpha: 0.58),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: targetColor.withValues(alpha: 0.18),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              targetChild,
                              PositionedDirectional(
                                top: -7,
                                child: _DropActionBadge(
                                  label: player == null ? 'انقل هنا' : 'بدّل',
                                  color: targetColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.all(hitPadding * 0.45),
                        child: targetChild,
                      );
                    },
                  );
                }

                return Positioned(
                  key: ValueKey('lineup-slot-${slot.id}'),
                  left: clampedLeft,
                  top: clampedTop,
                  width: hitWidth,
                  height: hitHeight,
                  child: Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: nodeWidget,
                  ),
                );
              }),

              // ── LAYER 6: PRESENTATIONAL BOTTOM PANELS ──
              if (widget.presentationMode) ...[
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    width: (width * 0.38).clamp(110.0, 160.0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xE60A0E0B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ملاحظات تكتيكية',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF5A623),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTacticalNotesText(),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF4F7EE),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60A0E0B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppMediaColors.pitchAchievementGradient,
                          ),
                          child: const Icon(
                            Icons.sports_soccer_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'روح واحدة .. هدف واحد',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFFFCB57),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmblemBadge(double width) {
    return Container(
      width: (width * 0.12).clamp(38.0, 48.0),
      height: (width * 0.12).clamp(38.0, 48.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCD0A0E0B),
        border: Border.all(color: const Color(0xFFF5A623), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5A623).withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) =>
              AppMediaColors.pitchAchievementGradient.createShader(bounds),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  String _getTacticalNotesText() {
    return switch (widget.formationCode) {
      '3-2-3' =>
        '• التمرير السريع من المحاور\n• استغلال انطلاقات الأطراف الهجومية\n• الحارس يوجه قلوب الدفاع لبدء الهجمة',
      '4-3-3' =>
        '• الضغط العالي من المهاجمين\n• أطراف الملعب تفتح مسافات الاختراق\n• المحور يغطي المساحات الخلفية',
      '4-4-2' =>
        '• التمركز المتوازي للاعبي الوسط\n• ثنائي الهجوم يعتمد على الكرات العرضية\n• الدفاع يحافظ على التماسك الدفاعي',
      '3-5-2' =>
        '• كثافة عددية بمنتصف الملعب\n• انطلاقات الأجنحة تزيد الدعم الهجومي\n• ثلاثي الدفاع يمنع المرتدات السريعة',
      _ =>
        '• تنظيم متناسق ومتكامل للخطوط\n• مبادلة تفاعلية ومستمرة للمراكز\n• روح المسؤولية والأداء الجماعي الحاسم',
    };
  }

  List<Widget> _buildZoneLabels(double height) {
    return [
      _buildZoneLabelText('الهجوم', height * 0.36),
      _buildZoneLabelText('الوسط', height * 0.53),
      _buildZoneLabelText('الدفاع', height * 0.70),
      _buildZoneLabelText('حارس المرمى', height * 0.86),
    ];
  }

  Widget _buildZoneLabelText(String label, double topOffset) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF5A623).withValues(alpha: 0.12),
            letterSpacing: 2.0,
          ),
        ),
      ),
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
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC0D130F),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppMediaColors.pitchActionLight.withValues(alpha: 0.38),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppMediaColors.pitchActionLight),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFFF4F7EE),
                fontSize: 10,
                fontWeight: FontWeight.w800,
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

class _DropActionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DropActionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppMediaColors.pitchCanvasDeep.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _StreetSquadPitchPainter extends CustomPainter {
  const _StreetSquadPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF183D24), Color(0xFF102C1A), Color(0xFF09150E)],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final stripeWidth = size.width / 7;
    for (var index = 0; index < 7; index += 2) {
      canvas.drawRect(
        Rect.fromLTWH(index * stripeWidth, 0, stripeWidth, size.height),
        stripePaint,
      );
    }

    final fieldRect = Rect.fromLTWH(
      size.width * 0.055,
      size.height * 0.055,
      size.width * 0.89,
      size.height * 0.89,
    );
    final linePaint = Paint()
      ..color = const Color(0xFFF4F7EE).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faintLinePaint = Paint()
      ..color = const Color(0xFFF4F7EE).withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(10)),
      linePaint,
    );
    canvas.drawLine(
      Offset(fieldRect.left, fieldRect.center.dy),
      Offset(fieldRect.right, fieldRect.center.dy),
      faintLinePaint,
    );
    canvas.drawCircle(fieldRect.center, size.width * 0.115, faintLinePaint);
    canvas.drawCircle(
      fieldRect.center,
      2.2,
      Paint()..color = const Color(0xFFF4F7EE).withValues(alpha: 0.48),
    );

    final penaltyWidth = fieldRect.width * 0.48;
    final penaltyHeight = fieldRect.height * 0.14;
    final topPenalty = Rect.fromCenter(
      center: Offset(fieldRect.center.dx, fieldRect.top + penaltyHeight / 2),
      width: penaltyWidth,
      height: penaltyHeight,
    );
    final bottomPenalty = Rect.fromCenter(
      center: Offset(fieldRect.center.dx, fieldRect.bottom - penaltyHeight / 2),
      width: penaltyWidth,
      height: penaltyHeight,
    );
    canvas.drawRect(topPenalty, faintLinePaint);
    canvas.drawRect(bottomPenalty, faintLinePaint);

    final goalWidth = fieldRect.width * 0.22;
    final goalDepth = size.height * 0.018;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(fieldRect.center.dx, fieldRect.top - goalDepth / 2),
        width: goalWidth,
        height: goalDepth,
      ),
      faintLinePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(fieldRect.center.dx, fieldRect.bottom + goalDepth / 2),
        width: goalWidth,
        height: goalDepth,
      ),
      faintLinePaint,
    );

    final asphaltPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var index = 0; index < 34; index++) {
      final x = ((index * 47) % 97) / 97 * size.width;
      final y = ((index * 71) % 101) / 101 * size.height;
      canvas.drawCircle(Offset(x, y), index.isEven ? 0.8 : 0.5, asphaltPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StreetSquadPitchPainter oldDelegate) => false;
}

class TacticalNetworkPainter extends CustomPainter {
  final List<FormationSlot> slots;
  final bool presentationMode;
  final bool expandVertical;
  final double minY;
  final double maxY;
  final bool denseSquad;

  TacticalNetworkPainter({
    required this.slots,
    this.presentationMode = false,
    this.expandVertical = false,
    this.minY = 0,
    this.maxY = 100,
    this.denseSquad = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slots.length < 2) return;

    final w = size.width;
    final h = size.height;

    final linkColor = presentationMode
        ? const Color(0xFF4A90D9)
        : AppMediaColors.pitchActionLight;
    final linePaint = Paint()
      ..color = linkColor.withValues(alpha: presentationMode ? 0.35 : 0.24)
      ..strokeWidth = presentationMode ? 1.5 : 1.15
      ..style = PaintingStyle.stroke;

    if (presentationMode) {
      final glowPaint = Paint()
        ..color = linkColor.withValues(alpha: 0.16)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

      _drawLinks(canvas, w, h, glowPaint);
    }

    _drawLinks(canvas, w, h, linePaint);
  }

  void _drawLinks(Canvas canvas, double w, double h, Paint paint) {
    final gks = slots.where((s) => s.role == SlotRole.gk).toList();
    final defs = slots.where((s) => s.role == SlotRole.def).toList();
    final mids = slots.where((s) => s.role == SlotRole.mid).toList();
    final atts = slots.where((s) => s.role == SlotRole.att).toList();

    Offset getOffset(FormationSlot slot) => PitchLayout.project(
      x: slot.x,
      y: slot.y,
      width: w,
      height: h,
      expandVertical: expandVertical,
      minY: minY,
      maxY: maxY,
      denseSquad: denseSquad,
    );

    // GK to DEF
    for (final gk in gks) {
      final gkPt = getOffset(gk);
      for (final def in defs) {
        canvas.drawLine(gkPt, getOffset(def), paint);
      }
    }

    // DEF horizontal & DEF to MID
    for (int i = 0; i < defs.length; i++) {
      final defPt = getOffset(defs[i]);
      if (i < defs.length - 1) {
        canvas.drawLine(defPt, getOffset(defs[i + 1]), paint);
      }
      for (final mid in mids) {
        if ((defs[i].x - mid.x).abs() < 36) {
          canvas.drawLine(defPt, getOffset(mid), paint);
        }
      }
    }

    // MID horizontal & MID to ATT
    for (int i = 0; i < mids.length; i++) {
      final midPt = getOffset(mids[i]);
      if (i < mids.length - 1) {
        canvas.drawLine(midPt, getOffset(mids[i + 1]), paint);
      }
      for (final att in atts) {
        if ((mids[i].x - att.x).abs() < 36) {
          canvas.drawLine(midPt, getOffset(att), paint);
        }
      }
    }

    // ATT horizontal
    for (int i = 0; i < atts.length; i++) {
      final attPt = getOffset(atts[i]);
      if (i < atts.length - 1) {
        canvas.drawLine(attPt, getOffset(atts[i + 1]), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TacticalNetworkPainter oldDelegate) {
    return oldDelegate.slots != slots ||
        oldDelegate.presentationMode != presentationMode ||
        oldDelegate.expandVertical != expandVertical ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.denseSquad != denseSquad;
  }
}
