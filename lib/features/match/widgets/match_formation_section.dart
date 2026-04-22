import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/player.dart';
import '../controllers/match_lobby_controller.dart';

class MatchFormationSection extends StatelessWidget {
  final MatchLobbyController controller;

  const MatchFormationSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('خطة اللعب', style: AppTextStyles.titleLarge),
              TextButton.icon(
                onPressed: controller.resetFormation,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('إعادة تعيين'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Obx(() {
          // Determine current user's team
          final uid = controller.currentUserId;
          final isTeamA = controller.teamAPlayers.any((p) => p.id == uid);
          final isTeamB = controller.teamBPlayers.any((p) => p.id == uid);
          
          if (!isTeamA && !isTeamB && !controller.isOrganizer) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.md),
              child: Text('يجب الانضمام للمباراة أولاً لوضع خطة اللعب', textAlign: TextAlign.center),
            );
          }

          final myTeamPlayers = isTeamA ? controller.teamAPlayers : controller.teamBPlayers;

          // ── توزيع تلقائي للاعبين في خطة افتراضية ──
          if (controller.playerPositions.isEmpty && myTeamPlayers.isNotEmpty) {
            _autoPlacePlayers(myTeamPlayers, controller);
          }

          final placedPlayers = controller.playerPositions.keys.toList();
          final unplacedPlayers = myTeamPlayers.where((p) => !placedPlayers.contains(p.id)).toList();

          return Column(
            children: [
              // Pitch (DragTarget)
              Container(
                height: 380,
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: DragTarget<Player>(
                    onAcceptWithDetails: (details) {
                      final RenderBox renderBox = context.findRenderObject() as RenderBox;
                      final localOffset = renderBox.globalToLocal(details.offset);
                      final dx = localOffset.dx.clamp(20.0, renderBox.size.width - 60);
                      controller.updatePlayerPosition(details.data.id, Offset(dx, localOffset.dy.clamp(20.0, 340.0)));
                    },
                    builder: (context, candidateData, rejectedData) {
                      return CustomPaint(
                        painter: _PremiumPitchPainter(),
                        child: Stack(
                          children: [
                            // Placed Players
                            ...controller.playerPositions.entries.map((entry) {
                              final player = myTeamPlayers.firstWhereOrNull((p) => p.id == entry.key);
                              if (player == null) return const SizedBox.shrink();

                              return Positioned(
                                left: entry.value.dx,
                                top: entry.value.dy,
                                child: Draggable<Player>(
                                  data: player,
                                  feedback: _PremiumPlayerToken(player: player, isDragging: true),
                                  childWhenDragging: const SizedBox.shrink(),
                                  child: _PremiumPlayerToken(player: player),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: AppDimensions.md),
              
              // Bench (Unplaced Players)
              if (unplacedPlayers.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat_rounded, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'الاحتياطي (${unplacedPlayers.length})',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                        itemCount: unplacedPlayers.length,
                        itemBuilder: (context, index) {
                          final player = unplacedPlayers[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Draggable<Player>(
                              data: player,
                              feedback: _PremiumPlayerToken(player: player, isDragging: true),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: _PremiumPlayerToken(player: player, isBench: true),
                              ),
                              child: _PremiumPlayerToken(player: player, isBench: true),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
      ],
    );
  }

  /// توزيع اللاعبين تلقائياً في تشكيلة افتراضية حسب عددهم
  void _autoPlacePlayers(List<Player> players, MatchLobbyController ctrl) {
    // الملعب: العرض التقريبي ~330, الارتفاع ~380
    // نقطة البداية من الأسفل (مرمانا) إلى الأعلى (هجوم)
    const pitchW = 300.0;
    const pitchH = 340.0;
    const marginX = 30.0;
    const marginY = 25.0;

    // خطط افتراضية حسب عدد اللاعبين
    final count = players.length;
    final List<List<int>> formation;

    switch (count) {
      case 1:
        formation = [[1]];
      case 2:
        formation = [[1], [1]];
      case 3:
        formation = [[1], [1], [1]];
      case 4:
        formation = [[1], [2], [1]];
      case 5:
        formation = [[1], [2], [1], [1]]; // حارس - دفاع - وسط - هجوم
      case 6:
        formation = [[1], [2], [2], [1]];
      case 7:
        formation = [[1], [3], [2], [1]];
      case 8:
        formation = [[1], [3], [2], [2]];
      case 9:
        formation = [[1], [3], [3], [2]];
      case 10:
        formation = [[1], [4], [3], [2]];
      case 11:
        formation = [[1], [4], [3], [3]];
      default:
        formation = [[1], [3], [3], count > 7 ? [count - 7] : [1]];
    }

    final totalRows = formation.length;
    int playerIndex = 0;

    for (int row = 0; row < totalRows; row++) {
      final playersInRow = formation[row][0];
      // من الأسفل (حارس المرمى) إلى الأعلى (الهجوم)
      final y = marginY + pitchH - ((row + 0.5) / totalRows) * pitchH;

      for (int col = 0; col < playersInRow; col++) {
        if (playerIndex >= count) break;
        final x = marginX + ((col + 0.5) / playersInRow) * pitchW;
        ctrl.updatePlayerPosition(players[playerIndex].id, Offset(x, y));
        playerIndex++;
      }
    }
  }
}

/// رسم ملعب احترافي بتفاصيل كاملة مثل الدوريات الأوروبية الكبرى
class _PremiumPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── خلفية الملعب بتدرج أخضر واقعي ──
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1B5E20),
          const Color(0xFF2E7D32),
          const Color(0xFF1B5E20),
          const Color(0xFF2E7D32),
          const Color(0xFF1B5E20),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── خطوط العشب (Grass Stripes) ──
    final stripePaint = Paint()..color = const Color(0xFF256D2A).withValues(alpha: 0.25);
    const stripeCount = 10;
    final stripeHeight = h / stripeCount;
    for (int i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, w, stripeHeight),
        stripePaint,
      );
    }

    // ── إعداد فرشاة الخطوط ──
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final thinLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // ── حدود الملعب ──
    final borderMargin = 12.0;
    final pitchRect = Rect.fromLTRB(borderMargin, borderMargin, w - borderMargin, h - borderMargin);
    canvas.drawRect(pitchRect, linePaint);

    // ── خط المنتصف ──
    canvas.drawLine(
      Offset(borderMargin, h / 2),
      Offset(w - borderMargin, h / 2),
      linePaint,
    );

    // ── دائرة المنتصف ──
    final centerCircleRadius = w * 0.12;
    canvas.drawCircle(Offset(w / 2, h / 2), centerCircleRadius, linePaint);

    // ── نقطة المنتصف ──
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), 3, dotPaint);

    // ── منطقة الجزاء العلوية (Goal Area Top) ──
    final penaltyWidth = w * 0.52;
    final penaltyHeight = h * 0.15;
    final goalWidth = w * 0.28;
    final goalHeight = h * 0.06;

    // Penalty box top
    canvas.drawRect(
      Rect.fromLTWH((w - penaltyWidth) / 2, borderMargin, penaltyWidth, penaltyHeight),
      linePaint,
    );
    // Goal box top
    canvas.drawRect(
      Rect.fromLTWH((w - goalWidth) / 2, borderMargin, goalWidth, goalHeight),
      linePaint,
    );
    // Penalty dot top
    canvas.drawCircle(Offset(w / 2, borderMargin + penaltyHeight * 0.7), 2.5, dotPaint);
    // Penalty arc top
    final penaltyArcTop = Rect.fromCenter(
      center: Offset(w / 2, borderMargin + penaltyHeight),
      width: centerCircleRadius * 1.6,
      height: centerCircleRadius * 0.8,
    );
    canvas.drawArc(penaltyArcTop, 0.0, 3.14159, false, thinLinePaint);

    // ── منطقة الجزاء السفلية (Goal Area Bottom) ──
    // Penalty box bottom
    canvas.drawRect(
      Rect.fromLTWH((w - penaltyWidth) / 2, h - borderMargin - penaltyHeight, penaltyWidth, penaltyHeight),
      linePaint,
    );
    // Goal box bottom
    canvas.drawRect(
      Rect.fromLTWH((w - goalWidth) / 2, h - borderMargin - goalHeight, goalWidth, goalHeight),
      linePaint,
    );
    // Penalty dot bottom
    canvas.drawCircle(Offset(w / 2, h - borderMargin - penaltyHeight * 0.7), 2.5, dotPaint);
    // Penalty arc bottom
    final penaltyArcBottom = Rect.fromCenter(
      center: Offset(w / 2, h - borderMargin - penaltyHeight),
      width: centerCircleRadius * 1.6,
      height: centerCircleRadius * 0.8,
    );
    canvas.drawArc(penaltyArcBottom, 3.14159, 3.14159, false, thinLinePaint);

    // ── أقواس الركنيات (Corner Arcs) ──
    final cornerRadius = w * 0.04;
    // Top-left
    canvas.drawArc(
      Rect.fromLTWH(borderMargin - cornerRadius, borderMargin - cornerRadius, cornerRadius * 2, cornerRadius * 2),
      0, 1.5708, false, linePaint,
    );
    // Top-right
    canvas.drawArc(
      Rect.fromLTWH(w - borderMargin - cornerRadius, borderMargin - cornerRadius, cornerRadius * 2, cornerRadius * 2),
      1.5708, 1.5708, false, linePaint,
    );
    // Bottom-left
    canvas.drawArc(
      Rect.fromLTWH(borderMargin - cornerRadius, h - borderMargin - cornerRadius, cornerRadius * 2, cornerRadius * 2),
      -1.5708, 1.5708, false, linePaint,
    );
    // Bottom-right
    canvas.drawArc(
      Rect.fromLTWH(w - borderMargin - cornerRadius, h - borderMargin - cornerRadius, cornerRadius * 2, cornerRadius * 2),
      3.14159, 1.5708, false, linePaint,
    );

    // ── المرمى العلوي ──
    final goalNetWidth = w * 0.18;
    final goalNetHeight = 6.0;
    final goalNetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - goalNetWidth) / 2, borderMargin - goalNetHeight, goalNetWidth, goalNetHeight),
        const Radius.circular(2),
      ),
      goalNetPaint,
    );

    // ── المرمى السفلي ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - goalNetWidth) / 2, h - borderMargin, goalNetWidth, goalNetHeight),
        const Radius.circular(2),
      ),
      goalNetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// رمز اللاعب الاحترافي — مستوحى من تصميم دوريات أوروبا الكبرى
class _PremiumPlayerToken extends StatelessWidget {
  final Player player;
  final bool isDragging;
  final bool isBench;

  const _PremiumPlayerToken({
    required this.player,
    this.isDragging = false,
    this.isBench = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isDragging ? 26.0 : 22.0;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── الصورة / الرقم ──
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isBench
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.surfaceLight,
                        AppColors.surface,
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFE0E0E0),
                      ],
                    ),
              border: Border.all(
                color: isDragging
                    ? AppColors.primaryLight
                    : isBench
                        ? AppColors.surfaceBorder
                        : Colors.white.withValues(alpha: 0.8),
                width: isDragging ? 2.5 : 2,
              ),
              boxShadow: [
                if (isDragging)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                else if (!isBench)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: ClipOval(
              child: player.photoThumbUrl != null
                  ? Image.network(
                      player.photoThumbUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => _buildInitial(radius),
                    )
                  : _buildInitial(radius),
            ),
          ),

          const SizedBox(height: 3),

          // ── الاسم ──
          if (!isDragging)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isBench
                    ? AppColors.surface
                    : Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: isBench
                    ? Border.all(color: AppColors.surfaceBorder, width: 0.5)
                    : null,
              ),
              child: Text(
                player.name.split(' ').first,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isBench ? AppColors.textMuted : Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitial(double radius) {
    return Center(
      child: Text(
        player.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
          color: isBench ? Colors.white : const Color(0xFF1B5E20),
        ),
      ),
    );
  }
}
