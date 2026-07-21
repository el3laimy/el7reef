import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/pride_card_format.dart';
import '../models/tournament_stage_share_data.dart';
import 'pride_card_shell.dart';
import 'pride_card_source_footer.dart';
import 'pride_card_text_scale.dart';

class TournamentStageShareCard extends StatelessWidget {
  final TournamentStageShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool includeGrowthLink;

  const TournamentStageShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
    this.includeGrowthLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final compact =
        format == PrideCardFormat.square1x1 || format.isLandscape || dense;
    final rowLimit = switch ((format, dense)) {
      (PrideCardFormat.square1x1, true) => 3,
      (PrideCardFormat.feed4x5, true) => 4,
      (PrideCardFormat.story9x16, true) => 6,
      (PrideCardFormat.landscape16x9, true) => 3,
      (PrideCardFormat.square1x1, false) => 4,
      (PrideCardFormat.feed4x5, false) => 6,
      (PrideCardFormat.story9x16, false) => 8,
      (PrideCardFormat.landscape16x9, false) => 3,
    };
    final visibleRows = data.rows.take(rowLimit).toList(growable: false);
    final hiddenCount = data.rows.length - visibleRows.length;
    final accent = data.kind == TournamentStagePrideKind.groupStandings
        ? AppColors.primary
        : AppColors.accent;
    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accent.withValues(alpha: 0.28), AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(color: accent.withValues(alpha: 0.52)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _StageGridPainter(accent: accent)),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? 8 : (compact ? 10 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StageHeader(
                  data: data,
                  accent: accent,
                  compact: compact,
                  dense: dense,
                ),
                SizedBox(height: dense ? 4 : (compact ? 8 : 14)),
                Expanded(
                  child: Column(
                    children: [
                      for (final row in visibleRows)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: dense ? 2 : 4),
                            child: _StageRow(
                              row: row,
                              accent: accent,
                              compact: compact,
                              dense: dense,
                            ),
                          ),
                        ),
                      if (hiddenCount > 0)
                        Text(
                          '+$hiddenCount صفوف أخرى',
                          style: TextStyle(
                            color: AppColors.textSecondaryTinted,
                            fontSize: dense ? 6 : (compact ? 9 : 10),
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                SizedBox(height: dense ? 3 : (compact ? 6 : 10)),
                PrideCardSourceFooter(
                  payload: data.sharePayload,
                  accent: accent,
                  includeGrowthLink: includeGrowthLink,
                  compact: compact,
                  dense: dense,
                  linkedLabel: 'امسح لمتابعة البطولة والنتائج الحقيقية',
                  verifiedLabel: 'بطاقة موثقة من بيانات البطولة الحقيقية',
                  qrSemanticsLabel: 'رمز QR لمتابعة البطولة',
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return PrideCardShell(
      exportMode: exportMode,
      format: format,
      semanticsLabel: data.kind == TournamentStagePrideKind.groupStandings
          ? 'بطاقة جدول ${data.title}'
          : 'بطاقة طريق النهائي',
      payload: includeGrowthLink ? data.sharePayload : null,
      child: body,
    );
  }
}

class _StageHeader extends StatelessWidget {
  final TournamentStageShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _StageHeader({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'EL7REEF',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: dense ? 7 : (compact ? 10 : 12),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 5 : 8,
                  vertical: dense ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
                child: Text(
                  data.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: dense ? 6 : (compact ? 8 : 9),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
        Text(
          data.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimaryTinted,
            fontSize: dense ? 12 : (compact ? 19 : 24),
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: dense ? 1 : 3),
        Text(
          data.tournamentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondaryTinted,
            fontSize: dense ? 7 : (compact ? 10 : 12),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final TournamentStageShareRowData row;
  final Color accent;
  final bool compact;
  final bool dense;

  const _StageRow({
    required this.row,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final rowAccent = row.earned
        ? AppColors.secondary
        : row.emphasized
        ? accent
        : AppColors.textSecondaryTinted;
    return Container(
      constraints: BoxConstraints(minHeight: dense ? 28 : (compact ? 34 : 40)),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : (compact ? 7 : 9),
        vertical: dense ? 2 : (compact ? 3 : 5),
      ),
      decoration: BoxDecoration(
        color: rowAccent.withValues(alpha: row.emphasized ? 0.13 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rowAccent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: dense ? 20 : (compact ? 24 : 30),
            child: Text(
              row.leading,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: rowAccent,
                fontSize: dense ? 7 : (compact ? 10 : 11),
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: dense ? 3 : 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryTinted,
                    fontSize: dense ? 7.5 : (compact ? 11 : 12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (row.subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondaryTinted,
                      fontSize: dense ? 6 : (compact ? 8 : 9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (row.trailing case final trailing?) ...[
            SizedBox(width: dense ? 3 : 6),
            Flexible(
              child: Text(
                trailing,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: rowAccent,
                  fontSize: dense ? 7 : (compact ? 11 : 13),
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageGridPainter extends CustomPainter {
  final Color accent;

  const _StageGridPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StageGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
