import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/mvp_share_data.dart';
import '../models/pride_card_format.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class MvpShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final MvpShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const MvpShareCard({
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
          const Positioned.fill(child: _MvpBackground()),
          _MvpContent(data: data, exportMode: exportMode, format: format),
        ],
      ),
    );
    return PrideCardShell.framed(
      exportMode: exportMode,
      format: format,
      semanticsLabel: 'بطاقة نجم المباراة',
      payload: data.sharePayload,
      exportPadding: EdgeInsets.all(format.isStory ? 18 : 12),
      child: cardBody,
    );
  }
}

class _MvpBackground extends StatelessWidget {
  const _MvpBackground();

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
          alignment: Alignment.topRight,
          child: _Glow(color: AppColors.secondary),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: _Glow(color: AppColors.primary),
        ),
        Positioned.fill(child: CustomPaint(painter: _StarPitchPainter())),
      ],
    );
  }
}

class _MvpContent extends StatelessWidget {
  final MvpShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const _MvpContent({
    required this.data,
    required this.exportMode,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    if (format == PrideCardFormat.square1x1 || format.isLandscape || dense) {
      return _ShortMvpContent(
        data: data,
        exportMode: exportMode,
        format: format,
        dense: dense,
      );
    }
    final compact = !format.isStory;
    final titleStyle = compact
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          )
        : exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          );
    final nameStyle = compact
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          )
        : exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.displayMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          );

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BrandMark(label: data.brandLabel, exportMode: exportMode),
              const Spacer(),
              _MetaChip(label: 'نجم المباراة', exportMode: exportMode),
            ],
          ),
          SizedBox(height: compact ? 10 : 24),
          Text(
            data.title,
            style: titleStyle,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.fade,
          ),
          SizedBox(height: compact ? 4 : 8),
          if (data.tournamentName case final tournamentName?)
            Text(
              tournamentName,
              style:
                  (exportMode
                          ? const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )
                          : AppTextStyles.labelLarge)
                      .copyWith(
                        color: AppColors.textSecondaryTinted.withValues(
                          alpha: 0.72,
                        ),
                      ),
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.fade,
            ),
          const Spacer(),
          _MvpMedal(data: data, exportMode: exportMode, format: format),
          SizedBox(height: compact ? 10 : 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  data.mvpDisplayName,
                  style: nameStyle,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.fade,
                ),
              ),
              if (data.isGuest) ...[
                const SizedBox(width: 8),
                _GuestBadge(exportMode: exportMode),
              ],
            ],
          ),
          SizedBox(height: compact ? 10 : 18),
          if (data.scoreLine != null)
            _WideChip(label: data.scoreLine!, exportMode: exportMode),
          if (data.sideLabel != null) ...[
            SizedBox(height: compact ? 6 : 10),
            _WideChip(label: data.sideLabel!, exportMode: exportMode),
          ],
          const Spacer(),
          Text(
            'لحظة فخر تستاهل المشاركة',
            style:
                (exportMode
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

class _ShortMvpContent extends StatelessWidget {
  final MvpShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool dense;

  const _ShortMvpContent({
    required this.data,
    required this.exportMode,
    required this.format,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(dense ? 6 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _BrandMark(
                    label: data.brandLabel,
                    exportMode: exportMode,
                    dense: dense,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _MetaChip(
                  label: 'نجم المباراة',
                  exportMode: exportMode,
                  dense: dense,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 3 : 8),
          Expanded(
            child: Row(
              children: [
                _MvpMedal(
                  data: data,
                  exportMode: exportMode,
                  format: format,
                  dense: dense,
                ),
                SizedBox(width: dense ? 7 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: dense ? 12 : 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: dense ? 1 : 2),
                      if (data.tournamentName case final tournamentName?)
                        Text(
                          tournamentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondaryTinted,
                            fontSize: dense ? 8 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      SizedBox(height: dense ? 3 : 8),
                      Text(
                        data.mvpDisplayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: dense ? 15 : 22,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (data.isGuest) ...[
                        SizedBox(height: dense ? 2 : 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _GuestBadge(
                            exportMode: exportMode,
                            dense: dense,
                          ),
                        ),
                      ],
                      if (data.scoreLine != null) ...[
                        SizedBox(height: dense ? 3 : 8),
                        _WideChip(
                          label: data.scoreLine!,
                          exportMode: exportMode,
                          dense: dense,
                        ),
                      ],
                      if (data.sideLabel != null) ...[
                        SizedBox(height: dense ? 2 : 5),
                        Text(
                          data.sideLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondaryTinted,
                            fontSize: dense ? 8 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
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

class _MvpMedal extends StatelessWidget {
  final MvpShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool dense;

  const _MvpMedal({
    required this.data,
    required this.exportMode,
    required this.format,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = !format.isStory;
    final medalSize = dense
        ? 54.0
        : compact
        ? 72.0
        : (exportMode ? 92.0 : 104.0);
    final avatarSize = dense
        ? 42.0
        : compact
        ? 58.0
        : (exportMode ? 72.0 : 82.0);
    return Center(
      child: Container(
        width: medalSize,
        height: medalSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary.withValues(alpha: 0.18),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.70),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            PrideIdentityAvatar(
              imageUrl: data.photoUrl,
              initials: data.initials,
              size: avatarSize,
              accent: data.isGuest ? AppColors.secondary : AppColors.primary,
            ),
            PositionedDirectional(
              bottom: -6,
              end: -6,
              child: Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.secondary,
                size: dense
                    ? 18
                    : compact
                    ? 25
                    : (exportMode ? 30 : 34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideChip extends StatelessWidget {
  final String label;
  final bool exportMode;
  final bool dense;

  const _WideChip({
    required this.label,
    required this.exportMode,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 12,
        vertical: dense ? 4 : 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: dense ? 8 : (exportMode ? 12 : 13),
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GuestBadge extends StatelessWidget {
  final bool exportMode;
  final bool dense;

  const _GuestBadge({required this.exportMode, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ضيف',
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: dense ? 7 : (exportMode ? 10 : 11),
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
    this.dense = false,
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
    this.dense = false,
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
          colors: [color.withValues(alpha: 0.32), Colors.transparent],
        ),
      ),
    );
  }
}

class _StarPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimaryTinted.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(size.center(Offset.zero), 68, paint);
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.18),
      Offset(size.width * 0.84, size.height * 0.82),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, size.height * 0.18),
      Offset(size.width * 0.16, size.height * 0.82),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
