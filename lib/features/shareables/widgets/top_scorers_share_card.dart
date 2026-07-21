import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/pride_card_format.dart';
import '../models/top_scorers_share_data.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class TopScorersShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final TopScorersShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const TopScorersShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
  });

  @override
  Widget build(BuildContext context) {
    final cardBody = ClipRRect(
      borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
      child: Stack(
        children: [
          const Positioned.fill(child: _TopScorersBackground()),
          _TopScorersContent(
            data: data,
            exportMode: exportMode,
            format: format,
          ),
        ],
      ),
    );
    return PrideCardShell.framed(
      exportMode: exportMode,
      format: format,
      semanticsLabel: 'بطاقة ترتيب هدافي البطولة',
      payload: data.sharePayload,
      exportPadding: EdgeInsets.all(format.isStory ? 22 : 12),
      child: cardBody,
    );
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
  final PrideCardFormat format;

  const _TopScorersContent({
    required this.data,
    required this.exportMode,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final compact =
        format == PrideCardFormat.square1x1 || format.isLandscape || dense;
    final titleStyle = dense
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          )
        : exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          );
    final tournamentStyle = dense
        ? TextStyle(
            color: AppColors.textSecondaryTinted.withValues(alpha: 0.76),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          )
        : exportMode
        ? TextStyle(
            color: AppColors.textSecondaryTinted.withValues(alpha: 0.76),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )
        : AppTextStyles.labelLarge.copyWith(
            color: AppColors.textSecondaryTinted.withValues(alpha: 0.76),
          );

    return Padding(
      padding: EdgeInsets.all(dense ? 8 : (compact ? 12 : 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _BrandMark(
                  label: data.brandLabel,
                  exportMode: exportMode,
                  dense: dense,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _MetaChip(
                  label: 'أفضل 5',
                  exportMode: exportMode,
                  dense: dense,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 4 : (compact ? 8 : 22)),
          Text(
            data.title,
            style: titleStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: dense ? 1 : (compact ? 2 : 6)),
          Text(
            data.tournamentName,
            style: tournamentStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: dense ? 4 : (compact ? 8 : 24)),
          Expanded(
            child: Column(
              children: [
                for (final scorer in data.scorers)
                  _ShareScorerRow(
                    scorer: scorer,
                    exportMode: exportMode,
                    compact: compact,
                    dense: dense,
                  ),
              ],
            ),
          ),
          Text(
            'سجّل أهدافك وخلي اسمك يظهر',
            style:
                (dense
                        ? const TextStyle(fontSize: 7)
                        : exportMode
                        ? const TextStyle(fontSize: 10)
                        : AppTextStyles.labelSmall)
                    .copyWith(
                      color: AppColors.textSecondaryTinted.withValues(
                        alpha: 0.62,
                      ),
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
  final bool compact;
  final bool dense;

  const _ShareScorerRow({
    required this.scorer,
    required this.exportMode,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final nameStyle = dense
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          )
        : exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          )
        : AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary);
    final goalStyle = dense
        ? const TextStyle(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          )
        : exportMode
        ? const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.labelLarge.copyWith(color: AppColors.primary);

    return Container(
      margin: EdgeInsets.only(bottom: dense ? 3 : (compact ? 5 : 10)),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : (compact ? 8 : 12),
        vertical: dense ? 3 : (compact ? 5 : 10),
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: scorer.rank, exportMode: exportMode, dense: dense),
          SizedBox(width: dense ? 4 : (compact ? 6 : 10)),
          PrideIdentityAvatar(
            imageUrl: scorer.photoUrl,
            initials: scorer.initials,
            size: dense ? 20 : (compact ? 24 : (exportMode ? 30 : 34)),
            accent: scorer.isGuest ? AppColors.secondary : AppColors.primary,
          ),
          SizedBox(width: dense ? 4 : (compact ? 5 : 8)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scorer.displayName,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scorer.isGuest)
                  Text(
                    'ضيف',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: dense ? 7 : (compact ? 8 : 9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: dense ? 4 : (compact ? 5 : 10)),
          Text(
            compact ? '${scorer.goals}' : scorer.goalLabel,
            style: goalStyle,
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool exportMode;
  final bool dense;

  const _RankBadge({
    required this.rank,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dense ? 22 : 30,
      height: dense ? 22 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: dense ? 8 : (exportMode ? 13 : 12),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final String label;
  final bool exportMode;
  final bool dense;

  const _BrandMark({
    required this.label,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: dense ? 8 : (exportMode ? 13 : 12),
        fontWeight: FontWeight.w900,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool exportMode;
  final bool dense;

  const _MetaChip({
    required this.label,
    required this.exportMode,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: dense ? 7 : (exportMode ? 9 : 10),
          fontWeight: FontWeight.w900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
