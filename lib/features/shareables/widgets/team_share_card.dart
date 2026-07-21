import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/pride_card_format.dart';
import '../models/team_share_data.dart';
import 'pride_card_shell.dart';
import 'pride_card_text_scale.dart';
import 'pride_identity_avatar.dart';

class TeamShareCard extends StatelessWidget {
  static const double exportLogicalWidth = 360;
  static const double exportLogicalHeight = 450;

  final TeamShareData data;
  final bool exportMode;
  final PrideCardFormat format;

  const TeamShareCard({
    super.key,
    required this.data,
    this.exportMode = false,
    this.format = PrideCardFormat.feed4x5,
  });

  @override
  Widget build(BuildContext context) {
    final dense = PrideCardTextScale.usesDenseLayout(context);
    final compact = !format.isStory || dense;
    final metrics = <({String label, int value})>[
      if (data.playerCount case final value?) (label: 'لاعبين', value: value),
      if (data.wins case final value?) (label: 'فوز', value: value),
      if (data.totalMatches case final value?) (label: 'مباريات', value: value),
    ];
    final body = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryDark, AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(exportMode ? 16 : 22),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.55),
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
                      color: AppColors.textPrimaryTinted,
                      fontWeight: FontWeight.w900,
                      fontSize: dense ? 8 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: _Tag(label: data.teamKindLabel, dense: dense),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: PrideIdentityAvatar(
                imageUrl: data.logoUrl,
                initials: data.initials,
                size: dense ? 42 : (compact ? 64 : 112),
                accent: AppColors.primary,
                fallbackIcon: Icons.shield_rounded,
              ),
            ),
            SizedBox(height: dense ? 3 : (compact ? 8 : 18)),
            Text(
              data.teamName,
              style:
                  (dense
                          ? const TextStyle(fontSize: 15)
                          : exportMode
                          ? TextStyle(fontSize: compact ? 22 : 30)
                          : AppTextStyles.displaySmall)
                      .copyWith(
                        color: AppColors.textPrimaryTinted,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (data.tournamentName != null) ...[
              SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
              Text(
                data.tournamentName!,
                style: TextStyle(
                  color: AppColors.textPrimaryTinted.withValues(alpha: 0.78),
                  fontSize: dense ? 8 : (exportMode ? 13 : 14),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: dense || compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (metrics.isNotEmpty) ...[
              SizedBox(height: dense ? 4 : (compact ? 10 : 22)),
              Row(
                children: [
                  for (var index = 0; index < metrics.length; index += 1) ...[
                    if (index > 0) SizedBox(width: dense ? 5 : 10),
                    Expanded(
                      child: _Metric(
                        label: metrics[index].label,
                        value: metrics[index].value,
                        compact: compact,
                        dense: dense,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const Spacer(),
            Text(
              'فريق واحد · هدف واحد',
              style: TextStyle(
                color: AppColors.textPrimaryTinted.withValues(alpha: 0.7),
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
      semanticsLabel: 'بطاقة الفريق ${data.teamName}',
      payload: data.sharePayload,
      child: body,
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool dense;

  const _Tag({required this.label, required this.dense});

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
          color: AppColors.textPrimaryTinted.withValues(alpha: 0.22),
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

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final bool compact;
  final bool dense;

  const _Metric({
    required this.label,
    required this.value,
    required this.compact,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: dense ? 3 : (compact ? 6 : 10),
        horizontal: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: AppColors.textPrimaryTinted,
              fontSize: dense ? 10 : (compact ? 16 : 18),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: dense ? 1 : 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryTinted,
              fontSize: dense ? 6.5 : 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
