import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../lineup/widgets/lineup_player_display.dart';
import '../models/lineup_share_data.dart';

class LineupShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF07111F),
          borderRadius: BorderRadius.circular(exportMode ? 20 : 26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: exportMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
          child: Stack(
            children: [
              Positioned.fill(child: _LineupShareBackground(data: data)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _LineupHeader(data: data, exportMode: exportMode),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _SharePitch(
                        players: data.pitchPlayers,
                        exportMode: exportMode,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BenchStrip(
                      players: data.benchPlayers,
                      exportMode: exportMode,
                    ),
                    const SizedBox(height: 8),
                    _Footer(data: data, exportMode: exportMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (exportMode) {
      return Material(color: Colors.transparent, child: content);
    }
    return AspectRatio(aspectRatio: 4 / 5, child: content);
  }
}

class _LineupShareBackground extends StatelessWidget {
  final LineupShareData data;

  const _LineupShareBackground({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0C1728), Color(0xFF040813)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  data.accentColor.withValues(alpha: 0.36),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _CardTexturePainter())),
      ],
    );
  }
}

class _LineupHeader extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _LineupHeader({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TeamAvatar(data: data, exportMode: exportMode),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.teamName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: exportMode ? 18 : 20,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    label: data.formationLabel ?? data.formationCode,
                    accent: data.accentColor,
                    exportMode: exportMode,
                  ),
                  _InfoChip(
                    label: data.lineupTypeLabel,
                    accent: AppColors.primaryLight,
                    exportMode: exportMode,
                  ),
                  if (data.matchLabel != null)
                    _InfoChip(
                      label: data.matchLabel!,
                      accent: AppColors.success,
                      exportMode: exportMode,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _TeamAvatar({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final size = exportMode ? 48.0 : 54.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [data.accentColor, data.accentColor.withValues(alpha: 0.58)],
        ),
      ),
      child: Center(
        child: Text(
          data.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: exportMode ? 16 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    final url = data.logoUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: data.accentColor.withValues(alpha: 0.5)),
        color: data.accentColor.withValues(alpha: 0.12),
      ),
      child: url == null || url.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

class _SharePitch extends StatelessWidget {
  final List<LineupSharePlayerData> players;
  final bool exportMode;

  const _SharePitch({required this.players, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E3A29).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nodeWidth = exportMode ? 56.0 : 62.0;
            final nodeHeight = exportMode ? 44.0 : 48.0;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                for (final player in players)
                  Positioned(
                    left: _position(
                      player.slotX,
                      constraints.maxWidth,
                      nodeWidth,
                    ),
                    top: _position(
                      player.slotY,
                      constraints.maxHeight,
                      nodeHeight,
                    ),
                    child: _PitchPlayerNode(
                      player: player,
                      width: nodeWidth,
                      height: nodeHeight,
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

  double _position(double percent, double total, double extent) {
    final raw = (percent.clamp(0, 100) / 100) * total - (extent / 2);
    return raw.clamp(4, total - extent - 4).toDouble();
  }
}

class _PitchPlayerNode extends StatelessWidget {
  final LineupSharePlayerData player;
  final double width;
  final double height;
  final bool exportMode;

  const _PitchPlayerNode({
    required this.player,
    required this.width,
    required this.height,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = lineupRoleColor(player.slotRole);
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: exportMode ? 24 : 28,
            height: exportMode ? 24 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.48), blurRadius: 12),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            ),
            child: Center(
              child: Text(
                player.shirtNumber == null
                    ? player.initials
                    : '${player.shirtNumber}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: player.shirtNumber == null ? 9 : 10,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Text(
              player.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: exportMode ? 8 : 9,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenchStrip extends StatelessWidget {
  final List<LineupShareBenchPlayerData> players;
  final bool exportMode;

  const _BenchStrip({required this.players, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const SizedBox(height: 16);
    }
    final visible = players.take(4).toList(growable: false);
    final extra = players.length - visible.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(
            'البدلاء',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: exportMode ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final player in visible)
                  _BenchChip(player: player, exportMode: exportMode),
                if (extra > 0)
                  _ExtraBenchChip(extra: extra, exportMode: exportMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenchChip extends StatelessWidget {
  final LineupShareBenchPlayerData player;
  final bool exportMode;

  const _BenchChip({required this.player, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        player.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: exportMode ? 8 : 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ExtraBenchChip extends StatelessWidget {
  final int extra;
  final bool exportMode;

  const _ExtraBenchChip({required this.extra, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$extra',
        style: TextStyle(
          color: AppColors.primaryLight,
          fontSize: exportMode ? 8 : 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final LineupShareData data;
  final bool exportMode;

  const _Footer({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final meta = [
      data.statusLabel,
      if (data.updatedLabel != null) data.updatedLabel,
    ].whereType<String>().where((value) => value.isNotEmpty).join('  •  ');
    return Column(
      children: [
        if (meta.isNotEmpty) ...[
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: exportMode ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          'EL7REEF  •  الحريف',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontSize: exportMode ? 10 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool exportMode;

  const _InfoChip({
    required this.label,
    required this.accent,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: exportMode ? 8 : 9,
        vertical: exportMode ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: exportMode ? 8 : 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    canvas.drawCircle(center, size.shortestSide * 0.14, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.18,
          0,
          size.width * 0.64,
          size.height * 0.16,
        ),
        const Radius.circular(10),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.84,
          size.width * 0.64,
          size.height * 0.16,
        ),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 36), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
