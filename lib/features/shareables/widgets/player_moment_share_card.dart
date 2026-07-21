import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../models/player_moment_share_data.dart';
import '../models/pride_card_format.dart';
import 'pride_card_shell.dart';
import 'pride_card_source_footer.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class PlayerMomentShareCard extends StatelessWidget {
  final PlayerMomentShareData data;
  final bool exportMode;
  final PrideCardFormat format;
  final bool includeGrowthLink;

  const PlayerMomentShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
    this.includeGrowthLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final compact = !format.isStory || dense;
    final horizontalContent =
        format.isLandscape || (format == PrideCardFormat.square1x1 && dense);
    final hasClaimLink = data.sharePayload.claimUrl != null;
    final accent = switch (data) {
      GoalScorerShareData goal when goal.isHatTrick => AppColors.secondary,
      GoalScorerShareData() => AppColors.primary,
      PlayerMilestoneShareData() => AppColors.secondary,
    };
    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accent.withValues(alpha: 0.3), AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(color: accent.withValues(alpha: 0.62)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MomentStampPainter(accent: accent)),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? 8 : (compact ? 12 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MomentHeader(
                  data: data,
                  accent: accent,
                  compact: compact,
                  dense: dense,
                ),
                SizedBox(height: dense ? 3 : (compact ? 6 : 12)),
                Expanded(
                  child: horizontalContent
                      ? Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _PlayerIdentity(
                                data: data,
                                accent: accent,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                            SizedBox(width: dense ? 6 : 16),
                            Expanded(
                              flex: 5,
                              child: _MomentFact(
                                data: data,
                                accent: accent,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _PlayerIdentity(
                                data: data,
                                accent: accent,
                                compact: compact,
                                dense: dense,
                              ),
                            ),
                            SizedBox(height: dense ? 3 : (compact ? 6 : 12)),
                            Flexible(
                              flex: 4,
                              child: _MomentFact(
                                data: data,
                                accent: accent,
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
                  linkedLabel: data.isGuest && hasClaimLink
                      ? 'امسح لفتح أرقام اللاعب واستلام البروفايل'
                      : 'امسح لفتح أرقام اللاعب الموثقة',
                  verifiedLabel: switch (data) {
                    GoalScorerShareData() =>
                      'الأهداف موثقة من أحداث المباراة المعتمدة',
                    PlayerMilestoneShareData() =>
                      'الإنجاز محسوب من أحداث المباريات المعتمدة',
                  },
                  qrSemanticsLabel: 'رمز QR لفتح بروفايل ${data.playerName}',
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

class _MomentHeader extends StatelessWidget {
  final PlayerMomentShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _MomentHeader({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (data) {
      GoalScorerShareData goal when goal.isHatTrick => 'هاتريك الحارة',
      GoalScorerShareData() => 'هداف المباراة',
      PlayerMilestoneShareData() => 'إنجاز مستحق',
    };
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
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 10,
            vertical: dense ? 2 : 5,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
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
        ),
      ],
    );
  }
}

class _PlayerIdentity extends StatelessWidget {
  final PlayerMomentShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _PlayerIdentity({
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
        Center(
          child: PrideIdentityAvatar(
            imageUrl: data.photoUrl,
            initials: data.initials,
            size: dense ? 40 : (compact ? 58 : 84),
            accent: accent,
          ),
        ),
        SizedBox(height: dense ? 2 : (compact ? 5 : 10)),
        Text(
          data.playerName,
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
        SizedBox(height: dense ? 1 : 3),
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 5 : 8,
              vertical: dense ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.isGuest ? 'لاعب ضيف · أرقامه كاملة' : 'لاعب الحريف',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: dense ? 6 : (compact ? 8 : 9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (data.tournamentName case final tournament?) ...[
          SizedBox(height: dense ? 1 : 4),
          Text(
            tournament,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryTinted,
              fontSize: dense ? 6 : (compact ? 8 : 10),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MomentFact extends StatelessWidget {
  final PlayerMomentShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _MomentFact({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return switch (data) {
      GoalScorerShareData goal => _GoalFact(
        data: goal,
        accent: accent,
        compact: compact,
        dense: dense,
      ),
      PlayerMilestoneShareData milestone => _MilestoneFact(
        data: milestone,
        accent: accent,
        compact: compact,
        dense: dense,
      ),
    };
  }
}

class _GoalFact extends StatelessWidget {
  final GoalScorerShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _GoalFact({
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
          Icons.sports_soccer_rounded,
          color: accent,
          size: dense ? 20 : (compact ? 28 : 38),
        ),
        Text(
          '${data.goalsInMatch}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent,
            fontSize: dense ? 27 : (compact ? 42 : 56),
            fontWeight: FontWeight.w900,
            height: 0.95,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          data.goalsInMatch == 1 ? 'هدف في المباراة' : 'أهداف في المباراة',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimaryTinted,
            fontSize: dense ? 8 : (compact ? 12 : 15),
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: dense ? 2 : (compact ? 5 : 8)),
        _VerifiedScoreLine(
          teamAName: data.teamAName,
          teamBName: data.teamBName,
          scoreTeamA: data.scoreTeamA,
          scoreTeamB: data.scoreTeamB,
          compact: compact,
          dense: dense,
        ),
        if (data.sideLabel case final team?)
          Text(
            team,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: dense ? 6 : (compact ? 8 : 9),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _VerifiedScoreLine extends StatelessWidget {
  final String? teamAName;
  final String? teamBName;
  final int scoreTeamA;
  final int scoreTeamB;
  final bool compact;
  final bool dense;

  const _VerifiedScoreLine({
    required this.teamAName,
    required this.teamBName,
    required this.scoreTeamA,
    required this.scoreTeamB,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.textSecondaryTinted,
      fontSize: dense ? 6.5 : (compact ? 9 : 11),
      fontWeight: FontWeight.w800,
    );
    final score = Text(
      '$scoreTeamA - $scoreTeamB',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: style.copyWith(
        color: AppColors.textPrimaryTinted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (teamAName == null || teamBName == null) return score;
    return Row(
      children: [
        Expanded(
          child: Text(
            teamAName!,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 3 : 6),
          child: score,
        ),
        Expanded(
          child: Text(
            teamBName!,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _MilestoneFact extends StatelessWidget {
  final PlayerMilestoneShareData data;
  final Color accent;
  final bool compact;
  final bool dense;

  const _MilestoneFact({
    required this.data,
    required this.accent,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final icon = data.metric == PlayerMilestoneMetric.goals
        ? Icons.sports_soccer_rounded
        : Icons.workspace_premium_rounded;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, color: accent, size: dense ? 20 : (compact ? 28 : 38)),
        Text(
          '${data.milestone}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent,
            fontSize: dense ? 27 : (compact ? 42 : 56),
            fontWeight: FontWeight.w900,
            height: 0.95,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          data.metricLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimaryTinted,
            fontSize: dense ? 8 : (compact ? 12 : 15),
            fontWeight: FontWeight.w900,
          ),
        ),
        if (data.currentTotal > data.milestone) ...[
          SizedBox(height: dense ? 2 : 5),
          Text(
            'الإجمالي الموثق الآن: ${data.currentTotal}',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryTinted,
              fontSize: dense ? 6 : (compact ? 8 : 9),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _MomentStampPainter extends CustomPainter {
  final Color accent;

  const _MomentStampPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final radius = size.shortestSide * 0.28;
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.24),
      radius,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.74),
      radius * 0.72,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MomentStampPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
