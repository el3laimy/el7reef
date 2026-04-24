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
              Text(
                '$title (${players.length})',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
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
              height: compact ? 80 : 95,
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
                          width: compact ? 82 : 96,
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
    final size = compact ? 34.0 : 40.0;
    final roleColor = player.isGuest
        ? AppColors.warning
        : lineupPlayerRoleColor(player);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        width: compact ? 82 : 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF07111F).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: roleColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: size,
              height: size,
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
            const SizedBox(height: 5),
            Text(
              lineupDisplayName(player),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10 : 11,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              player.isGuest ? 'ضيف' : (player.preferredPosition ?? 'لاعب'),
              style: AppTextStyles.labelSmall.copyWith(
                color: player.isGuest ? AppColors.warning : roleColor,
                fontSize: 8.5,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
      child: Text(
        lineupInitialsForPlayer(player),
        style: AppTextStyles.titleMedium.copyWith(
          color: player.isGuest ? AppColors.warning : AppColors.primaryLight,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
