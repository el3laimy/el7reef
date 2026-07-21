import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/champion_share_data.dart';
import '../models/pride_card_format.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class ChampionShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final ChampionShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const ChampionShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final compact = !format.isStory || dense;
    final body = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.secondaryDark, AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.7),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ChampionRaysPainter())),
          Padding(
            padding: EdgeInsets.all(dense ? 6 : (compact ? 10 : 16)),
            child: Column(
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
                          color: AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w900,
                          fontSize: dense ? 8 : 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _Pill(label: 'أبطال الحواري', dense: dense),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.secondaryLight,
                  size: dense ? 28 : (compact ? 36 : 58),
                ),
                SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
                Text(
                  'بطل البطولة',
                  style:
                      (dense
                              ? const TextStyle(fontSize: 14)
                              : exportMode
                              ? TextStyle(fontSize: compact ? 20 : 24)
                              : AppTextStyles.headlineMedium)
                          .copyWith(
                            color: AppColors.textPrimaryTinted,
                            fontWeight: FontWeight.w900,
                          ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: dense ? 2 : (compact ? 4 : 10)),
                Center(
                  child: PrideIdentityAvatar(
                    imageUrl: data.logoUrl,
                    initials: data.initials,
                    size: dense ? 44 : (compact ? 56 : 78),
                    accent: AppColors.secondary,
                    fallbackIcon: Icons.shield_rounded,
                  ),
                ),
                SizedBox(height: dense ? 2 : (compact ? 6 : 10)),
                Text(
                  data.championName,
                  style: TextStyle(
                    color: AppColors.textPrimaryTinted,
                    fontSize: dense
                        ? 14
                        : compact
                        ? 20
                        : (exportMode ? 25 : 27),
                    fontWeight: FontWeight.w900,
                    height: 1.14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: dense ? 2 : (compact ? 4 : 6)),
                Center(
                  child: _Pill(label: data.teamKindLabel, dense: dense),
                ),
                SizedBox(height: dense ? 2 : (compact ? 4 : 10)),
                Text(
                  data.tournamentName,
                  style: TextStyle(
                    color: AppColors.textPrimaryTinted.withValues(alpha: 0.82),
                    fontSize: dense ? 8 : (exportMode ? 13 : 14),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  'تتويج مستحق · الحريف',
                  style: TextStyle(
                    color: AppColors.textPrimaryTinted.withValues(alpha: 0.74),
                    fontSize: dense ? 7 : (exportMode ? 10 : 11),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      semanticsLabel: 'بطاقة بطل البطولة',
      payload: data.sharePayload,
      child: body,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool dense;

  const _Pill({required this.label, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimaryTinted,
          fontSize: dense ? 7 : 10,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ChampionRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondaryLight.withValues(alpha: 0.11)
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height * 0.35);
    for (var index = 0; index < 12; index += 1) {
      final angle = index * 0.523599;
      final endpoint = Offset(
        center.dx + 280 * math.cos(angle),
        center.dy + 280 * math.sin(angle),
      );
      canvas.drawLine(center, endpoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
