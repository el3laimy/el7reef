import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/pride_card_format.dart';
import '../models/tournament_announcement_share_data.dart';
import 'pride_card_shell.dart';
import 'pride_card_source_footer.dart';
import 'pride_card_text_scale.dart';

class TournamentAnnouncementShareCard extends StatelessWidget {
  final TournamentAnnouncementShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool includeGrowthLink;

  const TournamentAnnouncementShareCard({
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
    final isInvite = data is TournamentInviteShareData;
    final accent = isInvite ? AppColors.primary : AppColors.accentLight;
    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accent.withValues(alpha: 0.3), AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(color: accent.withValues(alpha: 0.58)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AnnouncementPitchPainter(accent: accent),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? 8 : (compact ? 12 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AnnouncementHeader(
                  label: isInvite ? 'دعوة الحارة' : 'الماتش الجاي',
                  accent: accent,
                  compact: compact,
                  dense: dense,
                ),
                SizedBox(height: dense ? 4 : (compact ? 8 : 16)),
                Expanded(
                  child: switch (data) {
                    TournamentInviteShareData invite => _InviteContent(
                      data: invite,
                      accent: accent,
                      landscape: format.isLandscape,
                      compact: compact,
                      dense: dense,
                    ),
                    UpcomingFixtureShareData fixture => _FixtureContent(
                      data: fixture,
                      accent: accent,
                      landscape: format.isLandscape,
                      compact: compact,
                      dense: dense,
                    ),
                  },
                ),
                SizedBox(height: dense ? 3 : (compact ? 6 : 10)),
                PrideCardSourceFooter(
                  payload: data.sharePayload,
                  accent: accent,
                  includeGrowthLink: includeGrowthLink,
                  compact: compact,
                  dense: dense,
                  linkedLabel: isInvite
                      ? 'امسح لفتح البطولة والتسجيل'
                      : 'امسح لفتح المباراة ومتابعة تفاصيلها',
                  verifiedLabel: isInvite
                      ? 'دعوة موثقة من البطولة الحقيقية'
                      : 'موعد موثق من جدول البطولة',
                  qrSemanticsLabel: isInvite
                      ? 'رمز QR لفتح البطولة'
                      : 'رمز QR لفتح المباراة',
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

class _AnnouncementHeader extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;
  final bool dense;

  const _AnnouncementHeader({
    required this.label,
    required this.accent,
    required this.compact,
    required this.dense,
  });

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
              color: accent,
              fontSize: dense ? 7 : (compact ? 10 : 13),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: _Pill(
            label: label,
            accent: accent,
            compact: compact,
            dense: dense,
          ),
        ),
      ],
    );
  }
}

class _InviteContent extends StatelessWidget {
  final TournamentInviteShareData data;
  final Color accent;
  final bool landscape;
  final bool compact;
  final bool dense;

  const _InviteContent({
    required this.data,
    required this.accent,
    required this.landscape,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final headline = _InviteHeadline(
      data: data,
      accent: accent,
      compact: compact,
      dense: dense,
    );
    final details = _InviteDetails(
      data: data,
      accent: accent,
      compact: compact,
      dense: dense,
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(flex: 6, child: headline),
          SizedBox(width: dense ? 6 : 16),
          Expanded(flex: 5, child: details),
        ],
      );
    }
    return Column(
      children: [
        Expanded(flex: 6, child: headline),
        SizedBox(height: dense ? 3 : (compact ? 6 : 12)),
        Flexible(flex: 4, child: details),
      ],
    );
  }
}

class _InviteHeadline extends StatelessWidget {
  final TournamentInviteShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _InviteHeadline({
    required this.data,
    required this.accent,
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
          Icons.how_to_reg_rounded,
          color: accent,
          size: dense ? 24 : (compact ? 34 : 52),
        ),
        SizedBox(height: dense ? 2 : (compact ? 5 : 10)),
        Text(
          'التسجيل مفتوح',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: dense ? 12 : (compact ? 18 : 24),
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
        Text(
          data.tournamentName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimaryTinted,
            fontSize: dense ? 15 : (compact ? 23 : 31),
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
      ],
    );
  }
}

class _InviteDetails extends StatelessWidget {
  final TournamentInviteShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _InviteDetails({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label})>[
      (icon: Icons.groups_2_rounded, label: data.teamSizeLabel),
      (icon: Icons.shield_rounded, label: 'حتى ${data.maxTeams} فرق'),
      if (data.startDate case final date?)
        (icon: Icons.sports_score_rounded, label: 'البداية ${_date(date)}'),
      if (data.registrationDeadline case final deadline?)
        (icon: Icons.timer_outlined, label: 'آخر تسجيل ${_date(deadline)}'),
      if (data.location case final location?)
        (icon: Icons.location_on_rounded, label: location),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: dense ? 3 : 6,
      runSpacing: dense ? 3 : 6,
      children: [
        for (final item in items.take(dense ? 3 : 5))
          _InfoChip(
            icon: item.icon,
            label: item.label,
            accent: accent,
            compact: compact,
            dense: dense,
          ),
      ],
    );
  }
}

class _FixtureContent extends StatelessWidget {
  final UpcomingFixtureShareData data;
  final Color accent;
  final bool landscape;
  final bool compact;
  final bool dense;

  const _FixtureContent({
    required this.data,
    required this.accent,
    required this.landscape,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final matchup = _Matchup(
      data: data,
      accent: accent,
      compact: compact,
      dense: dense,
    );
    final schedule = _FixtureSchedule(
      data: data,
      accent: accent,
      compact: compact,
      dense: dense,
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(flex: 7, child: matchup),
          SizedBox(width: dense ? 6 : 16),
          Expanded(flex: 4, child: schedule),
        ],
      );
    }
    return Column(
      children: [
        Expanded(flex: 7, child: matchup),
        SizedBox(height: dense ? 3 : (compact ? 5 : 10)),
        Flexible(flex: 3, child: schedule),
      ],
    );
  }
}

class _Matchup extends StatelessWidget {
  final UpcomingFixtureShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _Matchup({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.tournamentName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondaryTinted,
            fontSize: dense ? 7 : (compact ? 10 : 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: dense ? 3 : (compact ? 6 : 14)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TeamName(
                name: data.teamAName,
                dense: dense,
                compact: compact,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 8),
              child: Container(
                width: dense ? 28 : (compact ? 38 : 48),
                height: dense ? 28 : (compact ? 38 : 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Text(
                  'VS',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: accent,
                    fontSize: dense ? 8 : (compact ? 11 : 13),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _TeamName(
                name: data.teamBName,
                dense: dense,
                compact: compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamName extends StatelessWidget {
  final String name;
  final bool dense;
  final bool compact;

  const _TeamName({
    required this.name,
    required this.dense,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textPrimaryTinted,
        fontSize: dense ? 12 : (compact ? 18 : 24),
        fontWeight: FontWeight.w900,
        height: 1.12,
      ),
    );
  }
}

class _FixtureSchedule extends StatelessWidget {
  final UpcomingFixtureShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _FixtureSchedule({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.stageLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: dense ? 6.5 : (compact ? 9 : 10),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${_date(data.scheduledAt)} · ${_time(data.scheduledAt)}',
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryTinted,
              fontSize: dense ? 8 : (compact ? 12 : 14),
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (data.location case final location?)
            Text(
              location,
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
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;
  final bool dense;

  const _Pill({
    required this.label,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent,
          fontSize: dense ? 6.5 : (compact ? 9 : 10),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool compact;
  final bool dense;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: dense ? 105 : 170),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 8,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: dense ? 9 : (compact ? 13 : 15)),
          SizedBox(width: dense ? 2 : 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimaryTinted,
                fontSize: dense ? 6 : (compact ? 8 : 9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementPitchPainter extends CustomPainter {
  final Color accent;

  const _AnnouncementPitchPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inset = mathMin(size.width, size.height) * 0.08;
    final field = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRect(field, paint);
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      paint,
    );
    canvas.drawCircle(
      field.center,
      mathMin(size.width, size.height) * 0.1,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnnouncementPitchPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

double mathMin(double a, double b) => a < b ? a : b;

String _date(DateTime value) {
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${value.day} ${months[value.month - 1]}';
}

String _time(DateTime value) {
  final period = value.hour < 12 ? 'ص' : 'م';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}
