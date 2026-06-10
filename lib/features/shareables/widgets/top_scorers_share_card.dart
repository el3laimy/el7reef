import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/top_scorers_share_data.dart';

class TopScorersShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final TopScorersShareData data;
  final bool exportMode;

  const TopScorersShareCard({
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
          color: AppColors.backgroundDeep,
          borderRadius: BorderRadius.circular(exportMode ? 20 : 28),
          border: Border.all(
            color: AppColors.textPrimaryTinted.withValues(alpha: 0.12),
          ),
          boxShadow: exportMode
              ? null
              : [
                  BoxShadow(
                    color: AppColors.backgroundDeep.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
          child: Stack(
            children: [
              const Positioned.fill(child: _TopScorersBackground()),
              _TopScorersContent(data: data, exportMode: exportMode),
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

class _TopScorersBackground extends StatelessWidget {
  const _TopScorersBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceRaised, AppColors.backgroundDeep],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: _Glow(color: AppColors.primary),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: _Glow(color: AppColors.secondary),
        ),
        Positioned.fill(child: CustomPaint(painter: _PitchStripePainter())),
      ],
    );
  }
}

class _TopScorersContent extends StatelessWidget {
  final TopScorersShareData data;
  final bool exportMode;

  const _TopScorersContent({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final titleStyle = exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          );
    final tournamentStyle = exportMode
        ? TextStyle(
            color: AppColors.textSecondaryTinted.withValues(alpha: 0.76),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )
        : AppTextStyles.labelLarge.copyWith(
            color: AppColors.textSecondaryTinted.withValues(alpha: 0.76),
          );

    return Padding(
      padding: EdgeInsets.all(exportMode ? 18 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BrandMark(label: data.brandLabel, exportMode: exportMode),
              const Spacer(),
              _MetaChip(label: 'أفضل 5', exportMode: exportMode),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            data.title,
            style: titleStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            data.tournamentName,
            style: tournamentStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: [
                for (final scorer in data.scorers)
                  _ShareScorerRow(scorer: scorer, exportMode: exportMode),
              ],
            ),
          ),
          Text(
            'سجّل أهدافك وخلي اسمك يظهر',
            style:
                (exportMode
                        ? const TextStyle(fontSize: 10)
                        : AppTextStyles.labelSmall)
                    .copyWith(
              color: AppColors.textSecondaryTinted.withValues(alpha: 0.62),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ShareScorerRow extends StatelessWidget {
  final TopScorersShareEntryData scorer;
  final bool exportMode;

  const _ShareScorerRow({required this.scorer, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final nameStyle = exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          )
        : AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary);
    final goalStyle = exportMode
        ? const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.labelLarge.copyWith(color: AppColors.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: scorer.rank, exportMode: exportMode),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    scorer.displayName,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (scorer.isGuest) ...[
                  const SizedBox(width: 8),
                  _GuestBadge(exportMode: exportMode),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(scorer.goalLabel, style: goalStyle),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool exportMode;

  const _RankBadge({required this.rank, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: exportMode ? 13 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GuestBadge extends StatelessWidget {
  final bool exportMode;

  const _GuestBadge({required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ضيف',
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: exportMode ? 9 : 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final String label;
  final bool exportMode;

  const _BrandMark({required this.label, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: exportMode ? 13 : 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool exportMode;

  const _MetaChip({required this.label, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: exportMode ? 9 : 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;

  const _Glow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.30), Colors.transparent],
        ),
      ),
    );
  }
}

class _PitchStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimaryTinted.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var y = 40.0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), paint);
    }
    canvas.drawCircle(size.center(Offset.zero), 54, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
