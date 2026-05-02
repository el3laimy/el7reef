import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../lineup/widgets/lineup_player_display.dart';
import '../models/lineup_share_data.dart';

class LineupShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 432;
  static const double exportLogicalHeight = 540;

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
        padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _LineupHeader(data: data, exportMode: exportMode),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _SharePitch(
                        players: data.pitchPlayers,
                        exportMode: exportMode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BenchStrip(
                      players: data.benchPlayers,
                      exportMode: exportMode,
                    ),
                    const SizedBox(height: 10),
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
    final temporaryCount =
        data.pitchPlayers.where((player) => player.isTemporary).length +
        data.benchPlayers.where((player) => player.isTemporary).length;
    return Row(
      children: [
        _TeamAvatar(data: data, exportMode: exportMode),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.teamName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: exportMode ? 22 : 24,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
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
                  if (temporaryCount > 0)
                    _InfoChip(
                      label: '$temporaryCount لاعب مؤقت',
                      accent: AppColors.warning,
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
    final size = exportMode ? 56.0 : 60.0;
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
            fontSize: exportMode ? 18 : 20,
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
            final nodeWidth = (constraints.maxWidth / 5).clamp(68.0, 78.0);
            final nodeHeight = exportMode ? 64.0 : 68.0;
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: exportMode ? 28 : 30,
                height: exportMode ? 28 : 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.48),
                      blurRadius: 12,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                child: Center(
                  child: Text(
                    player.shirtNumber == null
                        ? player.initials
                        : '${player.shirtNumber}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: player.shirtNumber == null ? 10 : 11,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              if (player.isTemporary)
                PositionedDirectional(
                  top: -1,
                  end: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0E3A29)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              player.displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: exportMode ? 9.8 : 10.5,
                fontWeight: FontWeight.w800,
                height: 1.08,
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
    final visible = players.take(6).toList(growable: false);
    final extra = players.length - visible.length;
    final names = [
      ...visible.map((player) => player.displayName),
      if (extra > 0) '+$extra',
    ].join('، ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'البدلاء: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: names),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: exportMode ? 10.5 : 11.5,
          fontWeight: FontWeight.w700,
          height: 1.25,
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
              fontSize: exportMode ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          'EL7REEF  •  الحريف',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontSize: exportMode ? 12 : 13,
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
        horizontal: exportMode ? 9 : 10,
        vertical: exportMode ? 5 : 6,
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
          fontSize: exportMode ? 9.5 : 10,
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
