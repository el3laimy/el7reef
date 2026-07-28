import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_media_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';

enum SquadPlayerCardSize { field, compact, dense, bench }

enum SquadPlayerCardCanvas { operational, pitch }

class SquadPlayerCard extends StatelessWidget {
  final LineupPlayer? player;
  final SlotRole role;
  final SquadPlayerCardSize size;
  final bool isSelected;
  final bool isUnavailable;
  final SquadPlayerCardCanvas canvas;

  const SquadPlayerCard({
    super.key,
    required this.player,
    required this.role,
    this.size = SquadPlayerCardSize.field,
    this.isSelected = false,
    this.isUnavailable = false,
    this.canvas = SquadPlayerCardCanvas.operational,
  });

  bool get isEmpty => player == null;

  @override
  Widget build(BuildContext context) {
    final metrics = _SquadCardMetrics.forSize(size);
    final roleColor = lineupRoleColor(role);
    final palette = _SquadCardPalette.forCanvas(canvas);
    final selectionColor = palette.selection;
    final borderColor = isSelected
        ? selectionColor
        : roleColor.withValues(alpha: isEmpty ? 0.5 : 0.72);

    return AnimatedOpacity(
      opacity: isUnavailable ? 0.46 : 1,
      duration: const Duration(milliseconds: 160),
      child: AnimatedScale(
        scale: isSelected ? 1.045 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          width: metrics.width,
          height: metrics.height,
          decoration: BoxDecoration(
            color: isEmpty
                ? palette.emptySurface.withValues(alpha: 0.76)
                : palette.filledSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(metrics.radius),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.46),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 5),
              ),
              if (isSelected)
                BoxShadow(
                  color: selectionColor.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isEmpty
              ? _EmptySquadSlot(role: role, metrics: metrics)
              : _FilledSquadCard(
                  player: player!,
                  role: role,
                  roleColor: roleColor,
                  metrics: metrics,
                  palette: palette,
                ),
        ),
      ),
    );
  }
}

class _FilledSquadCard extends StatelessWidget {
  final LineupPlayer player;
  final SlotRole role;
  final Color roleColor;
  final _SquadCardMetrics metrics;
  final _SquadCardPalette palette;

  const _FilledSquadCard({
    required this.player,
    required this.role,
    required this.roleColor,
    required this.metrics,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = player.photoUrl?.trim() ?? '';
    final identityLabel = player.isTemporary
        ? 'مؤقت'
        : player.isGuest
        ? 'ضيف'
        : null;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.actionStrong.withValues(alpha: 0.3),
                  palette.raisedSurface.withValues(alpha: 0.92),
                  palette.deepSurface,
                ],
                stops: const [0, 0.54, 1],
              ),
            ),
          ),
        ),
        if (player.number != null)
          PositionedDirectional(
            top: metrics.edgePadding,
            start: metrics.edgePadding,
            child: _CardNumber(
              value: player.number!.toString(),
              color: palette.text,
              fontSize: metrics.numberSize,
            ),
          ),
        if (player.isCaptain)
          PositionedDirectional(
            top: metrics.edgePadding,
            end: metrics.edgePadding,
            child: _CaptainBadge(size: metrics.captainSize, palette: palette),
          ),
        Positioned(
          top: metrics.photoTop,
          left: metrics.photoInset,
          right: metrics.photoInset,
          height: metrics.photoHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(metrics.photoRadius),
            child: photoUrl.isEmpty
                ? _PlayerInitials(
                    player: player,
                    fontSize: metrics.initialsSize,
                    palette: palette,
                  )
                : CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    memCacheWidth: (metrics.width * 3).round(),
                    placeholder: (context, url) => _PlayerInitials(
                      player: player,
                      fontSize: metrics.initialsSize,
                      palette: palette,
                    ),
                    errorWidget: (context, url, error) => _PlayerInitials(
                      player: player,
                      fontSize: metrics.initialsSize,
                      palette: palette,
                    ),
                  ),
          ),
        ),
        if (metrics.showRoleChip)
          PositionedDirectional(
            top: metrics.roleTop,
            end: metrics.edgePadding,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.smallChipHorizontal,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: palette.deepSurface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: roleColor.withValues(alpha: 0.8)),
              ),
              child: Text(
                role.arabicLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: roleColor,
                  fontSize: metrics.metaSize,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        Positioned(
          left: metrics.edgePadding,
          right: metrics.edgePadding,
          bottom: metrics.nameBottom,
          child: Text(
            metrics.shortenName
                ? lineupDisplayName(player).split(' ').first
                : lineupDisplayName(player),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: palette.text,
              fontSize: metrics.nameSize,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: 0,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
        if (identityLabel != null)
          Positioned(
            left: metrics.identityInset,
            right: metrics.identityInset,
            bottom: metrics.identityBottom,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.identityHorizontal,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.deepSurface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: palette.info.withValues(
                      alpha: palette.identityBorderAlpha,
                    ),
                  ),
                ),
                child: Text(
                  identityLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.infoLight,
                    fontSize: metrics.identitySize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(height: 3, color: roleColor),
        ),
      ],
    );
  }
}

class _EmptySquadSlot extends StatelessWidget {
  final SlotRole role;
  final _SquadCardMetrics metrics;

  const _EmptySquadSlot({required this.role, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final roleColor = lineupRoleColor(role);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: metrics.emptyIconSize,
          height: metrics.emptyIconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: roleColor.withValues(alpha: 0.12),
            border: Border.all(color: roleColor.withValues(alpha: 0.7)),
          ),
          child: Icon(
            Icons.add_rounded,
            color: roleColor,
            size: metrics.emptyIconSize * 0.58,
          ),
        ),
        SizedBox(height: metrics.emptyGap),
        Text(
          role.arabicLabel,
          style: AppTextStyles.labelSmall.copyWith(
            color: roleColor,
            fontSize: metrics.metaSize + 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PlayerInitials extends StatelessWidget {
  final LineupPlayer player;
  final double fontSize;
  final _SquadCardPalette palette;

  const _PlayerInitials({
    required this.player,
    required this.fontSize,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.actionStrong.withValues(alpha: 0.42),
            palette.deepSurface,
          ],
        ),
      ),
      child: Center(
        child: Text(
          lineupInitialsForPlayer(player),
          style: AppTextStyles.titleMedium.copyWith(
            color: palette.text,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CardNumber extends StatelessWidget {
  final String value;
  final Color color;
  final double fontSize;

  const _CardNumber({
    required this.value,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textDirection: TextDirection.ltr,
      style: AppTextStyles.titleMedium.copyWith(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0,
        shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
      ),
    );
  }
}

class _CaptainBadge extends StatelessWidget {
  final double size;
  final _SquadCardPalette palette;

  const _CaptainBadge({required this.size, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.captainBackground,
      ),
      alignment: Alignment.center,
      child: Text(
        'C',
        style: AppTextStyles.labelSmall.copyWith(
          color: palette.captainForeground,
          fontSize: size * 0.47,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

@immutable
class _SquadCardPalette {
  const _SquadCardPalette({
    required this.selection,
    required this.emptySurface,
    required this.filledSurface,
    required this.actionStrong,
    required this.raisedSurface,
    required this.deepSurface,
    required this.text,
    required this.info,
    required this.infoLight,
    required this.identityBorderAlpha,
    required this.captainBackground,
    required this.captainForeground,
  });

  final Color selection;
  final Color emptySurface;
  final Color filledSurface;
  final Color actionStrong;
  final Color raisedSurface;
  final Color deepSurface;
  final Color text;
  final Color info;
  final Color infoLight;
  final double identityBorderAlpha;
  final Color captainBackground;
  final Color captainForeground;

  static const operational = _SquadCardPalette(
    selection: AppColors.primaryLight,
    emptySurface: AppColors.backgroundDeep,
    filledSurface: AppColors.surfaceSunken,
    actionStrong: AppColors.primaryDark,
    raisedSurface: AppColors.surfaceRaised,
    deepSurface: AppColors.backgroundDeep,
    text: AppColors.textPrimaryTinted,
    info: AppColors.info,
    infoLight: AppColors.infoLight,
    identityBorderAlpha: 0.72,
    captainBackground: AppColors.actionPrimary,
    captainForeground: AppColors.textOnPrimary,
  );

  // The pitch palette is intentionally stable so light-theme refinements do
  // not alter lineup screenshots or exported lineup cards.
  static const pitch = _SquadCardPalette(
    selection: AppMediaColors.pitchActionLight,
    emptySurface: AppMediaColors.pitchCanvasDeep,
    filledSurface: AppMediaColors.pitchSunken,
    actionStrong: AppMediaColors.pitchActionStrong,
    raisedSurface: AppMediaColors.pitchRaised,
    deepSurface: AppMediaColors.pitchCanvasDeep,
    text: AppMediaColors.pitchTextPrimary,
    info: AppMediaColors.pitchAchievement,
    infoLight: AppMediaColors.pitchAchievementLight,
    identityBorderAlpha: 0.78,
    captainBackground: AppMediaColors.pitchAchievement,
    captainForeground: AppMediaColors.pitchInkOnAccent,
  );

  static _SquadCardPalette forCanvas(SquadPlayerCardCanvas canvas) {
    return switch (canvas) {
      SquadPlayerCardCanvas.operational => operational,
      SquadPlayerCardCanvas.pitch => pitch,
    };
  }
}

class _SquadCardMetrics {
  final double width;
  final double height;
  final double radius;
  final double edgePadding;
  final double numberSize;
  final double initialsSize;
  final double captainSize;
  final double photoTop;
  final double photoInset;
  final double photoHeight;
  final double photoRadius;
  final double roleTop;
  final double smallChipHorizontal;
  final double metaSize;
  final double nameSize;
  final double nameBottom;
  final double identityInset;
  final double identityBottom;
  final double identityHorizontal;
  final double identitySize;
  final double emptyIconSize;
  final double emptyGap;
  final bool showRoleChip;
  final bool shortenName;

  const _SquadCardMetrics.field()
    : width = 76,
      height = 104,
      radius = 13,
      edgePadding = 6,
      numberSize = 15,
      initialsSize = 18,
      captainSize = 19,
      photoTop = 12,
      photoInset = 10,
      photoHeight = 53,
      photoRadius = 10,
      roleTop = 48,
      smallChipHorizontal = 5,
      metaSize = 7.5,
      nameSize = 10.5,
      nameBottom = 20,
      identityInset = 7,
      identityBottom = 5,
      identityHorizontal = 8,
      identitySize = 7.5,
      emptyIconSize = 34,
      emptyGap = 7,
      showRoleChip = true,
      shortenName = false;

  const _SquadCardMetrics.compact()
    : width = 64,
      height = 88,
      radius = 11,
      edgePadding = 5,
      numberSize = 12,
      initialsSize = 16,
      captainSize = 17,
      photoTop = 10,
      photoInset = 9,
      photoHeight = 42,
      photoRadius = 8,
      roleTop = 38,
      smallChipHorizontal = 4,
      metaSize = 6.5,
      nameSize = 9,
      nameBottom = 17,
      identityInset = 6,
      identityBottom = 4,
      identityHorizontal = 6,
      identitySize = 6.5,
      emptyIconSize = 29,
      emptyGap = 5,
      showRoleChip = true,
      shortenName = false;

  const _SquadCardMetrics.dense()
    : width = 48,
      height = 70,
      radius = 9,
      edgePadding = 4,
      numberSize = 10,
      initialsSize = 14,
      captainSize = 14,
      photoTop = 8,
      photoInset = 7,
      photoHeight = 33,
      photoRadius = 7,
      roleTop = 0,
      smallChipHorizontal = 0,
      metaSize = 6,
      nameSize = 8.2,
      nameBottom = 13,
      identityInset = 4,
      identityBottom = 3,
      identityHorizontal = 4,
      identitySize = 5.8,
      emptyIconSize = 24,
      emptyGap = 4,
      showRoleChip = false,
      shortenName = true;

  const _SquadCardMetrics.bench()
    : width = 88,
      height = 96,
      radius = 13,
      edgePadding = 6,
      numberSize = 13,
      initialsSize = 17,
      captainSize = 18,
      photoTop = 10,
      photoInset = 15,
      photoHeight = 46,
      photoRadius = 10,
      roleTop = 42,
      smallChipHorizontal = 5,
      metaSize = 7,
      nameSize = 10,
      nameBottom = 18,
      identityInset = 8,
      identityBottom = 4,
      identityHorizontal = 7,
      identitySize = 7,
      emptyIconSize = 32,
      emptyGap = 6,
      showRoleChip = true,
      shortenName = false;

  factory _SquadCardMetrics.forSize(SquadPlayerCardSize size) {
    return switch (size) {
      SquadPlayerCardSize.field => const _SquadCardMetrics.field(),
      SquadPlayerCardSize.compact => const _SquadCardMetrics.compact(),
      SquadPlayerCardSize.dense => const _SquadCardMetrics.dense(),
      SquadPlayerCardSize.bench => const _SquadCardMetrics.bench(),
    };
  }
}
