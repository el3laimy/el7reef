import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/match_result_share_data.dart';

class MatchResultShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final MatchResultShareData data;
  final bool exportMode;

  const MatchResultShareCard({
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF08111F),
          borderRadius: BorderRadius.circular(exportMode ? 20 : 28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: exportMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
          child: Stack(
            children: [
              Positioned.fill(child: _GlowBackground(data: data)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.1,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              _CardContent(data: data, exportMode: exportMode),
            ],
          ),
        ),
      ),
    );

    if (exportMode) {
      return Material(color: Colors.transparent, child: content);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: content);
  }
}

class _GlowBackground extends StatelessWidget {
  final MatchResultShareData data;

  const _GlowBackground({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1728), Color(0xFF050914)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _Glow(color: data.teamAAccent),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _Glow(color: data.teamBAccent),
        ),
        Positioned.fill(child: CustomPaint(painter: _PitchLinePainter())),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;

  const _Glow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.42), Colors.transparent],
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final MatchResultShareData data;
  final bool exportMode;

  const _CardContent({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final titleStyle = exportMode
        ? const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          );
    final subtitleStyle = exportMode
        ? TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          )
        : AppTextStyles.labelSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          );

    return Padding(
      padding: EdgeInsets.all(exportMode ? 18 : 18),
      child: Column(
        children: [
          _TopMeta(data: data, exportMode: exportMode),
          SizedBox(height: exportMode ? 20 : 16),
          Text(
            data.title,
            style: titleStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            data.subtitle,
            style: subtitleStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          _TeamScoreRow(data: data, exportMode: exportMode),
          const Spacer(),
          _FooterMeta(data: data, exportMode: exportMode),
        ],
      ),
    );
  }
}

class _TopMeta extends StatelessWidget {
  final MatchResultShareData data;
  final bool exportMode;

  const _TopMeta({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final chipStyle = TextStyle(
      color: Colors.white,
      fontSize: exportMode ? 9 : 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );
    return Row(
      children: [
        _MetaChip(
          label: data.statusLabel,
          accent: AppColors.success,
          exportMode: exportMode,
          style: chipStyle,
        ),
        const Spacer(),
        if (data.tournamentName != null && data.tournamentName!.isNotEmpty)
          Flexible(
            child: Text(
              data.tournamentName!,
              style: chipStyle.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
      ],
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  final MatchResultShareData data;
  final bool exportMode;

  const _TeamScoreRow({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // Score semantics are fixed: Team A is left, Team B is right.
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _TeamPanel(
              name: data.teamAName,
              logoUrl: data.teamALogoUrl,
              formation: data.teamAFormation,
              accent: data.teamAAccent,
              winnerSide: data.winnerSide == 'A',
              exportMode: exportMode,
            ),
          ),
          _ScoreBlock(data: data, exportMode: exportMode),
          Expanded(
            child: _TeamPanel(
              name: data.teamBName,
              logoUrl: data.teamBLogoUrl,
              formation: data.teamBFormation,
              accent: data.teamBAccent,
              winnerSide: data.winnerSide == 'B',
              exportMode: exportMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final String? formation;
  final Color accent;
  final bool winnerSide;
  final bool exportMode;

  const _TeamPanel({
    required this.name,
    required this.logoUrl,
    required this.formation,
    required this.accent,
    required this.winnerSide,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = exportMode ? 54.0 : 58.0;
    final nameStyle = TextStyle(
      color: Colors.white,
      fontSize: exportMode ? 14 : 14,
      fontWeight: FontWeight.w900,
      height: 1.08,
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: logoSize + (exportMode ? 12 : 12),
                height: logoSize + (exportMode ? 12 : 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
              ),
              _TeamLogo(
                name: name,
                logoUrl: logoUrl,
                accent: accent,
                size: logoSize,
                exportMode: exportMode,
              ),
              if (winnerSide)
                PositionedDirectional(
                  top: exportMode ? -6 : -6,
                  end: exportMode ? -6 : -6,
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: exportMode ? 18 : 18,
                    color: const Color(0xFFF7C948),
                  ),
                ),
            ],
          ),
          SizedBox(height: exportMode ? 10 : 10),
          Text(
            name,
            style: nameStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: exportMode ? 8 : 8),
          if (formation != null && formation!.isNotEmpty)
            _FormationChip(
              label: formation!,
              accent: accent,
              exportMode: exportMode,
            ),
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final Color accent;
  final double size;
  final bool exportMode;

  const _TeamLogo({
    required this.name,
    required this.logoUrl,
    required this.accent,
    required this.size,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.58)],
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: exportMode ? 18 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    if (url == null || url.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'EL';
    if (words.length == 1) return words.first.characters.take(2).toString();
    return '${words[0].characters.first}${words[1].characters.first}';
  }
}

class _ScoreBlock extends StatelessWidget {
  final MatchResultShareData data;
  final bool exportMode;

  const _ScoreBlock({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final scoreStyle = TextStyle(
      color: Colors.white,
      fontSize: exportMode ? 44 : 46,
      fontWeight: FontWeight.w900,
      height: 0.95,
      letterSpacing: 0,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: exportMode ? 12 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${data.scoreA} - ${data.scoreB}', style: scoreStyle),
          SizedBox(height: exportMode ? 6 : 6),
          Container(
            width: exportMode ? 54 : 54,
            height: exportMode ? 3 : 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [data.teamAAccent, data.teamBAccent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterMeta extends StatelessWidget {
  final MatchResultShareData data;
  final bool exportMode;

  const _FooterMeta({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final playedAt = data.playedAt == null
        ? null
        : intl.DateFormat('yyyy/MM/dd').format(data.playedAt!);
    final meta = [
      ?playedAt,
      if (data.mvpName != null && data.mvpName!.isNotEmpty)
        'MVP ${data.mvpName}',
    ].join('  •  ');
    return Column(
      children: [
        if (meta.isNotEmpty) ...[
          Text(
            meta,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: exportMode ? 9 : 11,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: exportMode ? 8 : 8),
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

class _MetaChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool exportMode;
  final TextStyle style;

  const _MetaChip({
    required this.label,
    required this.accent,
    required this.exportMode,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: exportMode ? 10 : 10,
        vertical: exportMode ? 5 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Text(label, style: style),
    );
  }
}

class _FormationChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool exportMode;

  const _FormationChip({
    required this.label,
    required this.accent,
    required this.exportMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: exportMode ? 10 : 10,
        vertical: exportMode ? 5 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.46)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: exportMode ? 9 : 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PitchLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * 0.18,
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.18),
      Offset(size.width / 2, size.height * 0.82),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 18, size.width - 36, size.height - 36),
        const Radius.circular(22),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
