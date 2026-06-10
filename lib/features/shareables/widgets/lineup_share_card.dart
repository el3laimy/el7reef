import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/lineup_share_data.dart';

// ── Design tokens ──
const _gold = Color(0xFFD4A843);
const _goldLight = Color(0xFFE8C96A);
const _goldDark = Color(0xFF8B6914);
const _cardBg = Color(0xFF0A0E0A);
const _cardBgRaised = Color(0xFF141A14);
const _pitchGreen = Color(0xFF1B5E20);
const _pitchGreenLight = Color(0xFF2E7D32);
const _pitchLine = Color(0x60FFFFFF);

class LineupShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 432;
  static const double exportLogicalHeight = 648; // 2:3 ratio

  final LineupShareData data;
  final bool exportMode;

  const LineupShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: exportMode ? exportLogicalWidth : null,
        height: exportMode ? exportLogicalHeight : null,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
          border: Border.all(color: _gold.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CardBgPainter())),
            Column(
              children: [
                _HeaderSection(data: data, exportMode: exportMode),
                Expanded(
                  child: _PitchSection(
                    players: data.pitchPlayers,
                    accentColor: data.accentColor,
                    exportMode: exportMode,
                  ),
                ),
                _FooterSection(data: data, exportMode: exportMode),
              ],
            ),
          ],
        ),
      ),
    );

    if (exportMode) {
      return Material(color: Colors.transparent, child: content);
    }
    return AspectRatio(aspectRatio: 2 / 3, child: content);
  }
}

// ═══════════════════════════════════════════
// Header: Title + Formation + Team Branding
// ═══════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _HeaderSection({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _cardBg,
            _cardBgRaised.withValues(alpha: 0.9),
            Colors.transparent,
          ],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team branding (right side in RTL)
          _TeamBranding(data: data, exportMode: exportMode),
          const SizedBox(width: 12),
          // Title + formation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'التشكيلة الرسمية',
                  style: TextStyle(
                    color: _gold,
                    fontSize: exportMode ? 20 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'الخطة التكتيكية',
                  style: TextStyle(
                    color: _goldLight.withValues(alpha: 0.6),
                    fontSize: exportMode ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.formationLabel ?? data.formationCode,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: exportMode ? 32 : 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamBranding extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _TeamBranding({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final logoSize = exportMode ? 48.0 : 54.0;
    final url = data.logoUrl?.trim();
    final hasLogo = url != null && url.isNotEmpty;

    return Column(
      children: [
        // Stars
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(Icons.star, color: _gold, size: exportMode ? 10 : 12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Logo / avatar
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.accentColor,
                data.accentColor.withValues(alpha: 0.5),
              ],
            ),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasLogo
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => _LogoFallback(
                    initials: data.initials,
                    exportMode: exportMode,
                  ),
                )
              : _LogoFallback(
                  initials: data.initials,
                  exportMode: exportMode,
                ),
        ),
        const SizedBox(height: 4),
        // Team name
        SizedBox(
          width: logoSize + 10,
          child: Text(
            data.teamName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: exportMode ? 10 : 11,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final String initials;
  final bool exportMode;

  const _LogoFallback({required this.initials, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: exportMode ? 16 : 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Pitch: Realistic grass + Player nodes
// ═══════════════════════════════════════════

class _PitchSection extends StatelessWidget {
  final List<LineupSharePlayerData> players;
  final Color accentColor;
  final bool exportMode;

  const _PitchSection({
    required this.players,
    required this.accentColor,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012) // perspective
        ..rotateX(0.08), // subtle tilt
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _pitchLine.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nodeW = (constraints.maxWidth / 4.5).clamp(70.0, 90.0);
            final nodeH = exportMode ? 90.0 : 95.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _PitchPainter()),
                ),
                for (final player in players)
                  Positioned(
                    left: _pos(player.slotX, constraints.maxWidth, nodeW),
                    top: _pos(player.slotY, constraints.maxHeight, nodeH),
                    child: _PlayerNode(
                      player: player,
                      width: nodeW,
                      height: nodeH,
                      accentColor: accentColor,
                      exportMode: exportMode,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _pos(double pct, double total, double extent) {
    final raw = (pct.clamp(0, 100) / 100) * total - (extent / 2);
    return raw.clamp(2, total - extent - 2).toDouble();
  }
}

class _PlayerNode extends StatelessWidget {
  final LineupSharePlayerData player;
  final double width;
  final double height;
  final Color accentColor;
  final bool exportMode;

  const _PlayerNode({
    required this.player,
    required this.width,
    required this.height,
    required this.accentColor,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    final jerseyH = exportMode ? 40.0 : 44.0;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Jersey silhouette
          SizedBox(
            width: jerseyH,
            height: jerseyH,
            child: CustomPaint(
              painter: _JerseyPainter(color: accentColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Short name on back
                    if (player.shortName != null)
                      Text(
                        player.shortName!,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: exportMode ? 5.5 : 6,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          height: 1.0,
                        ),
                      ),
                    // Shirt number
                    Text(
                      player.shirtNumber != null
                          ? '${player.shirtNumber}'
                          : player.initials,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: exportMode ? 14 : 15,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Gold name card
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_goldDark, _gold, _goldLight, _gold, _goldDark],
                stops: [0, 0.2, 0.5, 0.8, 1],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _cardBg,
                    fontSize: exportMode ? 8 : 8.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (player.positionLabel != null)
                  Text(
                    player.positionLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: _cardBg.withValues(alpha: 0.7),
                      fontSize: exportMode ? 6.5 : 7,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Footer: Tactical notes + Motivational quote
// ═══════════════════════════════════════════

class _FooterSection extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _FooterSection({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            _cardBg.withValues(alpha: 0.95),
            _cardBg,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tactical notes (right in RTL)
              if (data.tacticalNotes.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 10,
                              color: _gold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ملاحظات تكتيكية',
                            style: TextStyle(
                              color: _gold,
                              fontSize: exportMode ? 9 : 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...data.tacticalNotes.take(5).map(
                            (note) => Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Icon(
                                      Icons.star,
                                      size: 6,
                                      color: _gold.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        color: AppColors.textPrimary
                                            .withValues(alpha: 0.8),
                                        fontSize: exportMode ? 8 : 8.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              // Motivational quote (left in RTL)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      data.motivationalQuote,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: _goldLight,
                        fontSize: exportMode ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // App branding
          Text(
            'EL7REEF  •  الحريف',
            style: TextStyle(
              color: _gold.withValues(alpha: 0.5),
              fontSize: exportMode ? 8 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Custom Painters
// ═══════════════════════════════════════════

class _CardBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark gradient background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1F1A), _cardBg, Color(0xFF0D120D)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ── Stadium floodlights (bright, like the reference) ──
    // Left floodlight
    final leftLight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.7, -1.1),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.30),
          _goldLight.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0, 0.3, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.35), leftLight);

    // Right floodlight
    final rightLight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -1.1),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.30),
          _goldLight.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0, 0.3, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.35), rightLight);

    // Center warm glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -1.0),
        radius: 0.45,
        colors: [
          _goldLight.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.3), centerGlow);

    // Light beam streaks
    final beamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.5;
    // Left beams
    for (var i = 0; i < 5; i++) {
      final startX = w * 0.08;
      final startY = 0.0;
      final endX = w * (0.2 + i * 0.08);
      final endY = h * 0.25;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), beamPaint);
    }
    // Right beams
    for (var i = 0; i < 5; i++) {
      final startX = w * 0.92;
      final startY = 0.0;
      final endX = w * (0.8 - i * 0.08);
      final endY = h * 0.25;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), beamPaint);
    }

    // Subtle texture lines
    final texturePaint = Paint()
      ..color = _gold.withValues(alpha: 0.02)
      ..strokeWidth = 0.5;
    for (var y = 0.0; y < h; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(w, y + 36), texturePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grass background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_pitchGreen, _pitchGreenLight, _pitchGreen],
        stops: [0, 0.5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grass stripes
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    const stripeCount = 14;
    final stripeH = h / stripeCount;
    for (var i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeH, w, stripeH),
        stripePaint,
      );
    }

    // Vignette
    final vPaint = Paint()
      ..shader = RadialGradient(
        radius: 0.85,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vPaint);

    // Line paint
    final lp = Paint()
      ..color = _pitchLine
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final slp = Paint()
      ..color = _pitchLine.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final m = w * 0.05;
    final pitchRect = Rect.fromLTRB(m, m, w - m, h - m);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(8)),
      lp,
    );

    // Halfway
    canvas.drawLine(Offset(m, h / 2), Offset(w - m, h / 2), lp);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.14, lp);
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      2.5,
      Paint()..color = _pitchLine,
    );

    // Penalty areas
    final pw = w * 0.55;
    final ph = h * 0.14;
    final gw = w * 0.28;
    final gh = h * 0.05;

    for (final top in [true, false]) {
      final y = top ? m : h - m - ph;
      final gy = top ? m : h - m - gh;
      canvas.drawRect(
        Rect.fromLTWH((w - pw) / 2, y, pw, ph),
        lp,
      );
      canvas.drawRect(
        Rect.fromLTWH((w - gw) / 2, gy, gw, gh),
        lp,
      );
      final arcY = top ? y + ph : y;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w / 2, arcY),
          width: w * 0.2,
          height: w * 0.12,
        ),
        top ? 0 : math.pi,
        math.pi,
        false,
        slp,
      );
    }

    // Corner arcs
    final cr = w * 0.04;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(m, m), radius: cr),
      0,
      math.pi / 2,
      false,
      slp,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - m, m), radius: cr),
      math.pi / 2,
      math.pi / 2,
      false,
      slp,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(m, h - m), radius: cr),
      -math.pi / 2,
      math.pi / 2,
      false,
      slp,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - m, h - m), radius: cr),
      math.pi,
      math.pi / 2,
      false,
      slp,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JerseyPainter extends CustomPainter {
  final Color color;
  const _JerseyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      // Collar center
      ..moveTo(w * 0.35, 0)
      // Left shoulder
      ..lineTo(w * 0.08, h * 0.08)
      // Left sleeve
      ..lineTo(0, h * 0.32)
      ..lineTo(w * 0.15, h * 0.38)
      // Left body
      ..lineTo(w * 0.15, h * 0.95)
      // Bottom
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.85, h * 0.95)
      // Right body
      ..lineTo(w * 0.85, h * 0.38)
      // Right sleeve
      ..lineTo(w, h * 0.32)
      ..lineTo(w * 0.92, h * 0.08)
      // Right shoulder
      ..lineTo(w * 0.65, 0)
      // Collar
      ..quadraticBezierTo(w * 0.5, h * 0.08, w * 0.35, 0)
      ..close();

    // Jersey fill
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.7),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);

    // Jersey outline
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, outline);

    // Collar highlight
    final collarPath = Path()
      ..moveTo(w * 0.35, 0)
      ..quadraticBezierTo(w * 0.5, h * 0.08, w * 0.65, 0);
    canvas.drawPath(
      collarPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _JerseyPainter oldDelegate) =>
      oldDelegate.color != color;
}
