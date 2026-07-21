import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/pride_card_format.dart';
import '../models/qualification_share_data.dart';
import 'pride_card_shell.dart';
import 'pride_card_source_footer.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class QualificationShareCard extends StatelessWidget {
  final QualificationShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool includeGrowthLink;

  const QualificationShareCard({
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
        format.isLandscape || format == PrideCardFormat.square1x1 || dense;
    const accent = AppColors.secondary;
    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.secondaryDark, AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.72),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _QualificationPathPainter()),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? 8 : (compact ? 12 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(compact: compact, dense: dense),
                SizedBox(height: dense ? 3 : (compact ? 6 : 12)),
                Expanded(
                  child: format.isLandscape
                      ? Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _Identity(
                                data: data,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                            SizedBox(width: dense ? 6 : 16),
                            Expanded(
                              flex: 5,
                              child: _QualificationFacts(
                                data: data,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              flex: 7,
                              child: _Identity(
                                data: data,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                            SizedBox(height: dense ? 3 : (compact ? 6 : 12)),
                            Flexible(
                              flex: 3,
                              child: _QualificationFacts(
                                data: data,
                                compact: compact,
                                dense: dense,
                              ),
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
                  linkedLabel: 'امسح لمتابعة الفريق في الأدوار القادمة',
                  verifiedLabel: 'تأهل رسمي موثق من نتائج المجموعة',
                  qrSemanticsLabel: 'رمز QR لفتح صفحة الفريق المتأهل',
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
      semanticsLabel: data.semanticsLabel,
      payload: includeGrowthLink ? data.sharePayload : null,
      child: body,
    );
  }
}

class _Header extends StatelessWidget {
  final bool compact;
  final bool dense;

  const _Header({required this.compact, required this.dense});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'EL7REEF',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.secondaryLight,
              fontSize: dense ? 7 : (compact ? 10 : 13),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 10,
            vertical: dense ? 2 : 5,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.secondaryLight.withValues(alpha: 0.42),
            ),
          ),
          child: Text(
            'ختم التأهل',
            style: TextStyle(
              color: AppColors.secondaryLight,
              fontSize: dense ? 6.5 : (compact ? 9 : 10),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  final QualificationShareData data;
  final bool compact;
  final bool dense;

  const _Identity({
    required this.data,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.verified_rounded,
          color: AppColors.secondaryLight,
          size: dense ? 22 : (compact ? 34 : 48),
        ),
        SizedBox(height: dense ? 2 : (compact ? 5 : 10)),
        Text(
          'متأهل رسميًا',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.secondaryLight,
            fontSize: dense ? 12 : (compact ? 19 : 26),
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: dense ? 2 : (compact ? 5 : 10)),
        Center(
          child: PrideIdentityAvatar(
            imageUrl: data.logoUrl,
            initials: data.initials,
            size: dense ? 38 : (compact ? 54 : 76),
            accent: AppColors.secondary,
            fallbackIcon: Icons.shield_rounded,
          ),
        ),
        SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
        Text(
          data.teamName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimaryTinted,
            fontSize: dense ? 14 : (compact ? 21 : 28),
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        Text(
          data.teamKindLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondaryTinted,
            fontSize: dense ? 6.5 : (compact ? 9 : 10),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QualificationFacts extends StatelessWidget {
  final QualificationShareData data;
  final bool compact;
  final bool dense;

  const _QualificationFacts({
    required this.data,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final difference = data.goalDifference > 0
        ? '+${data.goalDifference}'
        : '${data.goalDifference}';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${data.groupName} · ${data.tournamentName}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondaryTinted,
            fontSize: dense ? 6.5 : (compact ? 9 : 11),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: dense ? 3 : (compact ? 6 : 10)),
        Row(
          children: [
            Expanded(
              child: _Fact(
                label: 'المركز',
                value: '#${data.rank}',
                compact: compact,
                dense: dense,
              ),
            ),
            SizedBox(width: dense ? 3 : 6),
            Expanded(
              child: _Fact(
                label: 'النقاط',
                value: '${data.points}',
                compact: compact,
                dense: dense,
              ),
            ),
            SizedBox(width: dense ? 3 : 6),
            Expanded(
              child: _Fact(
                label: 'فارق',
                value: difference,
                compact: compact,
                dense: dense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  final bool dense;

  const _Fact({
    required this.label,
    required this.value,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 3 : 6,
        vertical: dense ? 3 : (compact ? 6 : 9),
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondaryLight.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.secondaryLight,
              fontSize: dense ? 9 : (compact ? 14 : 18),
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryTinted,
              fontSize: dense ? 5.5 : (compact ? 8 : 9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualificationPathPainter extends CustomPainter {
  const _QualificationPathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondaryLight.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(size.width, size.height * 0.2)
      ..lineTo(size.width * 0.68, size.height * 0.2)
      ..lineTo(size.width * 0.55, size.height * 0.5)
      ..lineTo(size.width * 0.3, size.height * 0.5)
      ..lineTo(0, size.height * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
