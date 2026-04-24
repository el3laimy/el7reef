import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';

class LineupPlayerNode extends StatelessWidget {
  final LineupPlayer? player;
  final SlotRole role;
  final bool isSelected;
  final bool isDragging;
  final bool isUnavailable;
  final bool compact;
  final bool presentationMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LineupPlayerNode({
    super.key,
    required this.player,
    required this.role,
    this.isSelected = false,
    this.isDragging = false,
    this.isUnavailable = false,
    this.compact = false,
    this.presentationMode = false,
    this.onTap,
    this.onLongPress,
  });

  bool get isEmpty => player == null;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 34.0 : 42.0;
    final nodeWidth = compact ? 64.0 : 76.0;
    final borderColor = lineupRoleColor(role);
    final label = isEmpty ? 'إضافة لاعب' : lineupDisplayName(player!);

    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          opacity: isUnavailable ? 0.45 : 1,
          duration: const Duration(milliseconds: 160),
          child: AnimatedScale(
            scale: isDragging ? 1.08 : 1,
            duration: const Duration(milliseconds: 160),
            child: SizedBox(
              width: nodeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isEmpty
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    borderColor.withValues(alpha: 0.28),
                                    borderColor.withValues(alpha: 0.12),
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF162235),
                                    const Color(0xFF07111F),
                                  ],
                                ),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected ? 2.4 : 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor.withValues(alpha: 0.35),
                              blurRadius: isSelected ? 16 : 9,
                              spreadRadius: isSelected ? 1 : 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: isEmpty
                            ? Icon(
                                Icons.add_rounded,
                                color: borderColor,
                                size: compact ? 24 : 28,
                              )
                            : _AvatarContent(
                                player: player!,
                                size: avatarSize,
                                roleColor: borderColor,
                              ),
                      ),
                      if (!isEmpty && player!.number != null)
                        PositionedDirectional(
                          top: -4,
                          start: -4,
                          child: _MiniBadge(
                            label: '${player!.number}',
                            color: AppColors.textPrimary,
                            background: Colors.black.withValues(alpha: 0.78),
                          ),
                        ),
                      if (!isEmpty && player!.isCaptain)
                        const PositionedDirectional(
                          bottom: -3,
                          start: -3,
                          child: _MiniBadge(
                            label: 'C',
                            color: Color(0xFF07111F),
                            background: AppColors.secondary,
                          ),
                        ),
                      if (!isEmpty && player!.isGuest)
                        const PositionedDirectional(
                          bottom: -3,
                          end: -9,
                          child: _MiniBadge(
                            label: 'ضيف',
                            color: Color(0xFF07111F),
                            background: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 3 : 5),
                  Container(
                    constraints: BoxConstraints(maxWidth: nodeWidth),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 5 : 7,
                      vertical: compact ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? const Color(0xFF07111F).withValues(alpha: 0.8)
                          : const Color(0xFF07111F).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(
                        color: borderColor.withValues(
                          alpha: isEmpty ? 0.28 : 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: compact ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (!presentationMode || !isEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            role.arabicLabel,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: borderColor,
                              fontSize: compact ? 8 : 9,
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  final LineupPlayer player;
  final double size;
  final Color roleColor;

  const _AvatarContent({
    required this.player,
    required this.size,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = player.photoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _Initials(player: player, size: size, roleColor: roleColor),
      );
    }
    return _Initials(player: player, size: size, roleColor: roleColor);
  }
}

class _Initials extends StatelessWidget {
  final LineupPlayer player;
  final double size;
  final Color roleColor;

  const _Initials({
    required this.player,
    required this.size,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roleColor.withValues(alpha: 0.95),
            roleColor.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: Text(
          lineupInitialsForPlayer(player),
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _MiniBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
