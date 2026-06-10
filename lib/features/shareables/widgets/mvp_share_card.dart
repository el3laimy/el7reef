import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/mvp_share_data.dart';

class MvpShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final MvpShareData data;
  final bool exportMode;

  const MvpShareCard({super.key, required this.data, this.exportMode = false});

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
                    color: AppColors.backgroundDeep.withValues(alpha: 0.34),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
          child: Stack(
            children: [
              const Positioned.fill(child: _MvpBackground()),
              _MvpContent(data: data, exportMode: exportMode),
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

  const _MvpContent({required this.data, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    final titleStyle = exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          );
    final nameStyle = exportMode
        ? const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          )
        : AppTextStyles.displayMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
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
              _MetaChip(label: 'نجم المباراة', exportMode: exportMode),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            data.title,
            style: titleStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            data.tournamentName,
            style:
                (exportMode
                        ? const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )
                        : AppTextStyles.labelLarge)
                    .copyWith(
              color: AppColors.textSecondaryTinted.withValues(alpha: 0.72),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          _MvpMedal(exportMode: exportMode),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  data.mvpDisplayName,
                  style: nameStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.isGuest) ...[
                const SizedBox(width: 8),
                _GuestBadge(exportMode: exportMode),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (data.scoreLine != null)
            _WideChip(label: data.scoreLine!, exportMode: exportMode),
          if (data.sideLabel != null) ...[
            const SizedBox(height: 10),
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
              color: AppColors.textSecondaryTinted.withValues(alpha: 0.62),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MvpMedal extends StatelessWidget {
  final bool exportMode;

  const _MvpMedal({required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: exportMode ? 92 : 104,
        height: exportMode ? 92 : 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary.withValues(alpha: 0.18),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.70),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.workspace_premium_rounded,
          color: AppColors.secondary,
          size: exportMode ? 48 : 56,
        ),
      ),
    );
  }
}

class _WideChip extends StatelessWidget {
  final String label;
  final bool exportMode;

  const _WideChip({required this.label, required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          fontSize: exportMode ? 12 : 13,
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

  const _GuestBadge({required this.exportMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ضيف',
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: exportMode ? 10 : 11,
          fontWeight: FontWeight.w900,
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
