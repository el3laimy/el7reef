import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';

class BenchBar extends StatelessWidget {
  final List<LineupPlayer> players;
  final ValueChanged<LineupPlayer>? onPlayerTap;
  final VoidCallback? onAddGuest;
  final ValueChanged<LineupPlayer>? onPlayerDroppedOnBench;
  final String title;
  final bool compact;
  final bool draggable;

  const BenchBar({
    super.key,
    required this.players,
    this.onPlayerTap,
    this.onAddGuest,
    this.onPlayerDroppedOnBench,
    this.title = 'البدلاء',
    this.compact = false,
    this.draggable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final benchListHeight = _benchListHeight(textScale);
    final cardWidth = _benchCardWidth(textScale);
    Widget content = Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_seat_rounded,
                color: AppColors.primaryLight,
                size: 18,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  '$title (${players.length})',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAddGuest != null)
                TextButton.icon(
                  onPressed: onAddGuest,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('ضيف'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          if (players.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                'لا يوجد بدلاء حالياً',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: benchListHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final player = players[index];
                  Widget card = _BenchPlayerCard(
                    player: player,
                    compact: compact,
                    onTap: onPlayerTap == null
                        ? null
                        : () => onPlayerTap!(player),
                  );
                  if (draggable) {
                    card = Draggable<LineupPlayer>(
                      data: player,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: cardWidth,
                          height: benchListHeight,
                          child: Opacity(opacity: 0.85, child: card),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: card),
                      child: card,
                    );
                  }
                  return card;
                },
              ),
            ),
        ],
      ),
    );

    // Wrap entire bench area in DragTarget so players can be dropped back.
    if (onPlayerDroppedOnBench != null) {
      final targetChild = content;
      content = DragTarget<LineupPlayer>(
        onAcceptWithDetails: (details) {
          onPlayerDroppedOnBench!(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          if (candidateData.isNotEmpty) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: targetChild,
            );
          }
          return targetChild;
        },
      );
    }

    return content;
  }

  double _benchListHeight(double textScale) {
    final base = compact ? 80.0 : 95.0;
    return base + ((textScale - 1) * (compact ? 18.0 : 22.0));
  }

  double _benchCardWidth(double textScale) {
    final base = compact ? 82.0 : 96.0;
    return base + ((textScale - 1) * 10.0);
  }
}

class _BenchPlayerCard extends StatelessWidget {
  final LineupPlayer player;
  final bool compact;
  final VoidCallback? onTap;

  const _BenchPlayerCard({
    required this.player,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = (player.isGuest || player.isTemporary)
        ? AppColors.warning
        : lineupPlayerRoleColor(player);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : compact
              ? 80.0
              : 95.0;
          final cardWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : compact
              ? 82.0
              : 96.0;
          final padding = (availableHeight * 0.08).clamp(5.0, 8.0);
          final avatarSize = (availableHeight * (compact ? 0.38 : 0.4)).clamp(
            compact ? 28.0 : 34.0,
            compact ? 36.0 : 42.0,
          );
          final nameFontSize = (availableHeight * 0.13).clamp(
            compact ? 9.0 : 10.0,
            compact ? 11.0 : 12.0,
          );
          final metaFontSize = (availableHeight * 0.1).clamp(7.5, 9.5);

          return Container(
            width: cardWidth,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: const Color(0xFF07111F).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: roleColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor.withValues(alpha: 0.16),
                    border: Border.all(color: roleColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (player.photoUrl ?? '').isNotEmpty
                      ? Image.network(
                          player.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _Initial(player: player),
                        )
                      : _Initial(player: player),
                ),
                SizedBox(height: (availableHeight * 0.05).clamp(3.0, 5.0)),
                Flexible(
                  child: Text(
                    lineupDisplayName(player),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: nameFontSize,
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                Flexible(
                  child: Text(
                    player.isTemporary
                        ? 'مؤقت'
                        : player.isGuest
                        ? 'ضيف'
                        : (player.preferredPosition ?? 'لاعب'),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: (player.isGuest || player.isTemporary)
                          ? AppColors.warning
                          : roleColor,
                      fontSize: metaFontSize,
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final LineupPlayer player;

  const _Initial({required this.player});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            lineupInitialsForPlayer(player),
            style: AppTextStyles.titleMedium.copyWith(
              color: (player.isGuest || player.isTemporary)
                  ? AppColors.warning
                  : AppColors.primaryLight,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
