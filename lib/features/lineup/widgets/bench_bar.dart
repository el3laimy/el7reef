import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'squad_player_card.dart';

class BenchBar extends StatelessWidget {
  final List<LineupPlayer> players;
  final ValueChanged<LineupPlayer>? onPlayerTap;
  final VoidCallback? onAddGuest;
  final ValueChanged<LineupPlayer>? onPlayerDroppedOnBench;
  final VoidCallback? onSelectedPlayerMoveToBench;
  final VoidCallback? onSelectedBenchSwapRequest;
  final String? selectedPlayerKey;
  final String title;
  final bool compact;
  final bool draggable;

  const BenchBar({
    super.key,
    required this.players,
    this.onPlayerTap,
    this.onAddGuest,
    this.onPlayerDroppedOnBench,
    this.onSelectedPlayerMoveToBench,
    this.onSelectedBenchSwapRequest,
    this.selectedPlayerKey,
    this.title = 'البدلاء',
    this.compact = false,
    this.draggable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final benchListHeight = _benchListHeight(textScale);
    final cardWidth = _benchCardWidth(textScale);
    final hasTapBenchTarget = onSelectedPlayerMoveToBench != null;
    final hasSelectedBenchSwapTarget =
        onSelectedBenchSwapRequest != null &&
        selectedPlayerKey != null &&
        players.any((player) => player.key == selectedPlayerKey);
    Widget content = Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: hasTapBenchTarget || hasSelectedBenchSwapTarget
            ? AppColors.warning.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: hasTapBenchTarget || hasSelectedBenchSwapTarget
              ? AppColors.warning.withValues(alpha: 0.72)
              : AppColors.surfaceBorder,
          width: hasTapBenchTarget || hasSelectedBenchSwapTarget ? 1.7 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasTapBenchTarget || hasSelectedBenchSwapTarget
                ? AppColors.warning.withValues(alpha: 0.16)
                : AppColors.backgroundDeep.withValues(alpha: 0.28),
            blurRadius: hasTapBenchTarget || hasSelectedBenchSwapTarget
                ? 20
                : 16,
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
          if (hasTapBenchTarget) ...[
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('bench-move-selected-target'),
                onPressed: onSelectedPlayerMoveToBench,
                icon: const Icon(Icons.event_seat_rounded, size: 18),
                label: const Text('انقل المختار للبدلاء'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.75),
                  ),
                  textStyle: AppTextStyles.labelLarge,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
          ],
          if (hasSelectedBenchSwapTarget) ...[
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('bench-swap-selected-target'),
                onPressed: onSelectedBenchSwapRequest,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('بدّل المختار مع أساسي'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  textStyle: AppTextStyles.labelLarge,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.sm),
          if (players.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Text(
                draggable
                    ? 'لا يوجد بدلاء حاليًا. انقل لاعبًا من الملعب إلى هنا.'
                    : 'لا يوجد بدلاء حاليًا',
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
                  Widget card = _BenchDockCard(
                    player: player,
                    compact: compact,
                    isSelected: player.key == selectedPlayerKey,
                    onTap: onPlayerTap == null
                        ? null
                        : () => onPlayerTap!(player),
                  );
                  if (draggable) {
                    card = Draggable<LineupDragPayload>(
                      data: LineupDragPayload(player: player),
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      maxSimultaneousDrags: 1,
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

    if (onPlayerDroppedOnBench != null) {
      final targetChild = content;
      content = DragTarget<LineupDragPayload>(
        onWillAcceptWithDetails: (details) => !details.data.fromBench,
        onAcceptWithDetails: (details) {
          onPlayerDroppedOnBench!(details.data.player);
        },
        builder: (context, candidateData, rejectedData) {
          final hasCandidate = candidateData.any(
            (candidate) => candidate != null,
          );
          if (hasCandidate) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                color: AppColors.warning.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  targetChild,
                  Positioned(
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDeep,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Text(
                        'انقل للبدلاء',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

class _BenchDockCard extends StatelessWidget {
  final LineupPlayer player;
  final bool compact;
  final bool isSelected;
  final VoidCallback? onTap;

  const _BenchDockCard({
    required this.player,
    required this.compact,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final role = SlotRole.values.firstWhere(
      (candidate) => candidate.matchesPosition(player.preferredPosition),
      orElse: () => SlotRole.mid,
    );
    return InkWell(
      key: ValueKey('bench-player-${player.key}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SquadPlayerCard(
            player: player,
            role: role,
            size: compact
                ? SquadPlayerCardSize.compact
                : SquadPlayerCardSize.bench,
            isSelected: isSelected,
          ),
          if (isSelected)
            PositionedDirectional(
              top: -6,
              end: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'مختار',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textOnPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
