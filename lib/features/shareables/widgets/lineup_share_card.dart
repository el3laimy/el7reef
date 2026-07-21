import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/lineup/pitch_layout.dart';
import '../models/lineup_share_data.dart';
import '../models/pride_card_format.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';

// ── Design tokens ──
const _gold = AppColors.primary;
const _goldLight = AppColors.primaryLight;
const _cardBg = Color(0xFF0A0E0A);
const _cardBgRaised = Color(0xFF141A14);
const _pitchGreen = Color(0xFF1B5E20);
const _pitchGreenLight = Color(0xFF2E7D32);
const _pitchLine = Color(0x60FFFFFF);

class LineupShareCard extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const LineupShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final content = Container(
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
              _HeaderSection(data: data, exportMode: exportMode, dense: dense),
              Expanded(
                child: _PitchSection(
                  players: data.pitchPlayers,
                  teamSize: data.teamSize,
                  accentColor: data.accentColor,
                  exportMode: exportMode,
                  dense: dense,
                ),
              ),
              _FooterSection(data: data, exportMode: exportMode, dense: dense),
            ],
          ),
        ],
      ),
    );
    return PrideCardShell(
      exportMode: exportMode,
      format: format,
      semanticsLabel: 'بطاقة تشكيلة ${data.teamName}',
      payload: data.sharePayload,
      child: content,
    );
  }
}

// ═══════════════════════════════════════════
// Header: Title + Formation + Team Branding
// ═══════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;
  final bool dense;

  const _HeaderSection({
    required this.data,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: dense
          ? const EdgeInsets.fromLTRB(8, 6, 8, 4)
          : const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
          _TeamBranding(data: data, exportMode: exportMode, dense: dense),
          SizedBox(width: dense ? 6 : 12),
          // Title + formation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  data.statusLabel ?? 'التشكيلة الرسمية',
                  style: TextStyle(
                    color: _gold,
                    fontSize: dense ? 11 : (exportMode ? 20 : 22),
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: dense ? 1 : 2),
                Text(
                  data.matchLabel ?? data.lineupTypeLabel,
                  style: TextStyle(
                    color: _goldLight.withValues(alpha: 0.6),
                    fontSize: dense ? 7 : (exportMode ? 12 : 13),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: dense ? 2 : 6),
                Text(
                  data.formationLabel ?? data.formationCode,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: dense ? 16 : (exportMode ? 28 : 32),
                    fontWeight: FontWeight.w900,
                    letterSpacing: dense ? 1 : 2,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
  final bool dense;

  const _TeamBranding({
    required this.data,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = dense ? 34.0 : (exportMode ? 48.0 : 54.0);
    final url = data.logoUrl?.trim();
    final hasLogo = url != null && url.isNotEmpty;

    return Column(
      children: [
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
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _LogoFallback(
                    initials: data.initials,
                    exportMode: exportMode,
                    dense: dense,
                  ),
                  errorWidget: (context, url, error) => _LogoFallback(
                    initials: data.initials,
                    exportMode: exportMode,
                    dense: dense,
                  ),
                )
              : _LogoFallback(
                  initials: data.initials,
                  exportMode: exportMode,
                  dense: dense,
                ),
        ),
        SizedBox(height: dense ? 2 : 4),
        // Team name
        SizedBox(
          width: logoSize + 10,
          child: Text(
            data.teamName,
            textAlign: TextAlign.center,
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: dense ? 6.5 : (exportMode ? 10 : 11),
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
  final bool dense;

  const _LogoFallback({
    required this.initials,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: dense ? 9 : (exportMode ? 16 : 18),
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
  final int teamSize;
  final Color accentColor;
  final bool exportMode;
  final bool dense;

  const _PitchSection({
    required this.players,
    required this.teamSize,
    required this.accentColor,
    required this.exportMode,
    required this.dense,
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
            final playersPerLine = teamSize >= 10
                ? 5
                : teamSize >= 7
                ? 3
                : 2;
            final nodeW = (constraints.maxWidth / (playersPerLine + 0.6)).clamp(
              dense ? 48.0 : 52.0,
              dense ? 70.0 : 82.0,
            );
            final desiredNodeH = teamSize >= 10
                ? (dense ? 46.0 : 50.0)
                : (dense ? 66.0 : (exportMode ? 90.0 : 95.0));
            final verticalPositions = _verticalPositions(players);
            final lineCount = math.max(1, verticalPositions.length);
            final heightAllowedByLines =
                (constraints.maxHeight - ((lineCount - 1) * 3)) / lineCount;
            final minimumReadableHeight = teamSize >= 10
                ? 44.0
                : dense
                ? 48.0
                : 54.0;
            final nodeH = math.min(
              desiredNodeH,
              math.max(minimumReadableHeight, heightAllowedByLines),
            );
            final expandVertically = teamSize >= 10 && lineCount > 1;
            final minimumY = verticalPositions.isEmpty
                ? 0.0
                : verticalPositions.first;
            final maximumY = verticalPositions.isEmpty
                ? 100.0
                : verticalPositions.last;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                for (final player in players)
                  Positioned(
                    left: PitchLayout.positionedCoordinate(
                      percentage: player.slotX,
                      totalExtent: constraints.maxWidth,
                      childExtent: nodeW,
                    ),
                    top: expandVertically
                        ? _expandedVerticalCoordinate(
                            percentage: player.slotY,
                            minimumPercentage: minimumY,
                            maximumPercentage: maximumY,
                            totalExtent: constraints.maxHeight,
                            childExtent: nodeH,
                          )
                        : PitchLayout.positionedCoordinate(
                            percentage: player.slotY,
                            totalExtent: constraints.maxHeight,
                            childExtent: nodeH,
                          ),
                    child: _PlayerNode(
                      key: ValueKey('lineup-share-player-${player.id}'),
                      player: player,
                      width: nodeW,
                      height: nodeH,
                      accentColor: accentColor,
                      exportMode: exportMode,
                      dense: dense,
                      denseSquad: teamSize >= 10,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<double> _verticalPositions(List<LineupSharePlayerData> players) {
    final positions =
        players
            .map((player) => player.slotY.clamp(0, 100).toDouble())
            .toSet()
            .toList(growable: false)
          ..sort();
    return positions;
  }

  double _expandedVerticalCoordinate({
    required double percentage,
    required double minimumPercentage,
    required double maximumPercentage,
    required double totalExtent,
    required double childExtent,
  }) {
    const edgeInset = 2.0;
    final percentageRange = maximumPercentage - minimumPercentage;
    if (percentageRange <= 0) {
      return PitchLayout.positionedCoordinate(
        percentage: percentage,
        totalExtent: totalExtent,
        childExtent: childExtent,
      );
    }
    final usableExtent = math.max(
      0.0,
      totalExtent - childExtent - (edgeInset * 2),
    );
    final normalized = ((percentage - minimumPercentage) / percentageRange)
        .clamp(0, 1);
    return edgeInset + (normalized * usableExtent);
  }
}

class _PlayerNode extends StatelessWidget {
  final LineupSharePlayerData player;
  final double width;
  final double height;
  final Color accentColor;
  final bool exportMode;
  final bool dense;
  final bool denseSquad;

  const _PlayerNode({
    super.key,
    required this.player,
    required this.width,
    required this.height,
    required this.accentColor,
    required this.exportMode,
    required this.dense,
    required this.denseSquad,
  });

  @override
  Widget build(BuildContext context) {
    final jerseyH = denseSquad
        ? (dense ? 26.0 : 30.0)
        : dense
        ? 30.0
        : (exportMode ? 40.0 : 44.0);

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
                    Text(
                      player.shirtNumber != null
                          ? '${player.shirtNumber}'
                          : player.initials,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: denseSquad
                            ? (dense ? 6 : 9)
                            : dense
                            ? 7.5
                            : (exportMode ? 14 : 15),
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: denseSquad ? 1 : (dense ? 1 : 3)),
          // Gold name card
          Container(
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: denseSquad ? 2 : (dense ? 2 : 4),
              vertical: denseSquad ? 1 : (dense ? 1 : 3),
            ),
            decoration: BoxDecoration(
              color: AppColors.textPrimaryTinted,
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
                    fontSize: denseSquad
                        ? (dense ? 6 : 8.5)
                        : dense
                        ? 6.5
                        : (exportMode ? 10.5 : 11),
                    fontWeight: FontWeight.w900,
                    height: 1.1,
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
// Footer: verified match context + bench
// ═══════════════════════════════════════════

class _FooterSection extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;
  final bool dense;

  const _FooterSection({
    required this.data,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBench = data.benchPlayers.take(5).toList(growable: false);
    final hiddenBenchCount = data.benchPlayers.length - visibleBench.length;
    return Container(
      padding: dense
          ? const EdgeInsets.fromLTRB(8, 4, 8, 5)
          : const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visibleBench.isNotEmpty) ...[
            Text(
              'البدلاء',
              style: TextStyle(
                color: AppColors.textSecondaryTinted,
                fontSize: dense ? 7 : (exportMode ? 10 : 11),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: dense ? 2 : 4),
            Wrap(
              spacing: dense ? 3 : 5,
              runSpacing: dense ? 2 : 4,
              children: [
                for (final player in visibleBench)
                  _BenchChip(
                    player: player,
                    exportMode: exportMode,
                    dense: dense,
                  ),
                if (hiddenBenchCount > 0)
                  _BenchMoreChip(
                    count: hiddenBenchCount,
                    exportMode: exportMode,
                    dense: dense,
                  ),
              ],
            ),
            SizedBox(height: dense ? 3 : 6),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  data.teamLabel ?? data.lineupTypeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryTinted,
                    fontSize: dense ? 6.5 : (exportMode ? 10 : 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (data.updatedLabel != null) ...[
                SizedBox(width: dense ? 4 : 8),
                Flexible(
                  child: Text(
                    'حُفظت ${data.updatedLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondaryTinted,
                      fontSize: dense ? 6.5 : (exportMode ? 10 : 11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(width: dense ? 4 : 8),
              Text(
                'EL7REEF',
                style: TextStyle(
                  color: _gold,
                  fontSize: dense ? 6.5 : (exportMode ? 11 : 12),
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenchChip extends StatelessWidget {
  final LineupShareBenchPlayerData player;
  final bool exportMode;
  final bool dense;

  const _BenchChip({
    required this.player,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final number = player.shirtNumber == null ? '' : '#${player.shirtNumber} ';
    return Container(
      constraints: BoxConstraints(maxWidth: dense ? 92 : 112),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 7,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _cardBgRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        '$number${player.displayName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimaryTinted,
          fontSize: dense ? 6.5 : (exportMode ? 10 : 11),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BenchMoreChip extends StatelessWidget {
  final int count;
  final bool exportMode;
  final bool dense;

  const _BenchMoreChip({
    required this.count,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '+$count',
      style: TextStyle(
        color: _gold,
        fontSize: dense ? 6.5 : (exportMode ? 10 : 11),
        fontWeight: FontWeight.w900,
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
        colors: [_goldLight.withValues(alpha: 0.14), Colors.transparent],
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
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, w, stripeH), stripePaint);
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
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, Paint()..color = _pitchLine);

    // Penalty areas
    final pw = w * 0.55;
    final ph = h * 0.14;
    final gw = w * 0.28;
    final gh = h * 0.05;

    for (final top in [true, false]) {
      final y = top ? m : h - m - ph;
      final gy = top ? m : h - m - gh;
      canvas.drawRect(Rect.fromLTWH((w - pw) / 2, y, pw, ph), lp);
      canvas.drawRect(Rect.fromLTWH((w - gw) / 2, gy, gw, gh), lp);
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
