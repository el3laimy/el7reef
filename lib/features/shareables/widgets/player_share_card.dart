import 'package:flutter/material.dart';

import '../../../app/theme/app_media_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/player_share_data.dart';
import '../models/pride_card_format.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class PlayerShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final PlayerShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const PlayerShareCard({
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
          colors: [AppMediaColors.raised, AppMediaColors.canvasDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(
          color: AppMediaColors.actionPrimary.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 8 : (compact ? 12 : 24)),
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
                      color: AppMediaColors.actionLight,
                      fontWeight: FontWeight.w900,
                      fontSize: dense ? 8 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: _IdentityTag(isGuest: data.isGuest, dense: dense),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: PrideIdentityAvatar(
                imageUrl: data.photoUrl,
                initials: data.initials,
                size: dense ? 42 : (compact ? 64 : 112),
                accent: data.isGuest
                    ? AppMediaColors.achievement
                    : AppMediaColors.actionPrimary,
              ),
            ),
            SizedBox(height: dense ? 3 : (compact ? 8 : 18)),
            Text(
              data.displayName,
              style:
                  (dense
                          ? const TextStyle(fontSize: 15)
                          : exportMode
                          ? TextStyle(fontSize: compact ? 22 : 30)
                          : AppTextStyles.displaySmall)
                      .copyWith(
                        color: AppMediaColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: dense ? 4 : (compact ? 10 : 22)),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.sports_soccer_rounded,
                    label: 'أهداف',
                    value: data.totalGoals,
                    compact: compact,
                    dense: dense,
                  ),
                ),
                SizedBox(width: dense ? 6 : 12),
                Expanded(
                  child: _Stat(
                    icon: Icons.workspace_premium_rounded,
                    label: 'MVP',
                    value: data.totalMvps,
                    compact: compact,
                    dense: dense,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'إحصائيات من أحداث المباريات المعتمدة',
              style: TextStyle(
                color: AppMediaColors.textSecondary.withValues(alpha: 0.68),
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
    );

    return PrideCardShell(
      exportMode: exportMode,
      format: format,
      semanticsLabel: 'بطاقة اللاعب ${data.displayName}',
      payload: data.sharePayload,
      child: body,
    );
  }
}

class _IdentityTag extends StatelessWidget {
  final bool isGuest;
  final bool dense;

  const _IdentityTag({required this.isGuest, required this.dense});

  @override
  Widget build(BuildContext context) {
    final color = isGuest
        ? AppMediaColors.achievement
        : AppMediaColors.actionPrimary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        isGuest ? 'هوية ضيف' : 'لاعب الحريف',
        style: TextStyle(
          color: color,
          fontSize: dense ? 7 : 10,
          fontWeight: FontWeight.w900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool compact;
  final bool dense;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: dense ? 3 : (compact ? 7 : 14),
        horizontal: dense ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppMediaColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppMediaColors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppMediaColors.actionLight,
            size: dense ? 14 : (compact ? 18 : 22),
          ),
          SizedBox(height: dense ? 1 : (compact ? 2 : 6)),
          Text(
            '$value',
            style: TextStyle(
              color: AppMediaColors.textPrimary,
              fontSize: dense ? 11 : (compact ? 18 : 21),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppMediaColors.textSecondary,
              fontSize: dense ? 7 : 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
