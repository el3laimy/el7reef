import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/player.dart';
import '../controllers/match_lobby_controller.dart';

class MatchFormationSection extends StatelessWidget {
  final MatchLobbyController controller;

  const MatchFormationSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('خطة اللعب', style: AppTextStyles.titleLarge),
              TextButton.icon(
                onPressed: controller.resetFormation,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('إعادة تعيين'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Obx(() {
          // Determine current user's team
          final uid = controller.currentUserId;
          final isTeamA = controller.teamAPlayers.any((p) => p.id == uid);
          final isTeamB = controller.teamBPlayers.any((p) => p.id == uid);
          
          if (!isTeamA && !isTeamB && !controller.isOrganizer) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.md),
              child: Text('يجب الانضمام للمباراة أولاً لوضع خطة اللعب', textAlign: TextAlign.center),
            );
          }

          final myTeamPlayers = isTeamA ? controller.teamAPlayers : controller.teamBPlayers;
          final placedPlayers = controller.playerPositions.keys.toList();
          final unplacedPlayers = myTeamPlayers.where((p) => !placedPlayers.contains(p.id)).toList();

          return Column(
            children: [
              // Pitch (DragTarget)
              Container(
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
                child: DragTarget<Player>(
                  onAcceptWithDetails: (details) {
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final localOffset = renderBox.globalToLocal(details.offset);
                    // Adjust to keep the avatar centered at the drop point
                    // And constrain within the pitch bounds
                    final dx = localOffset.dx.clamp(0.0, renderBox.size.width - 40);
                    // The Y offset calculation here needs adjustment because localOffset might be relative to the column.
                    // We'll use a simpler relative approach by dividing by size.
                    controller.updatePlayerPosition(details.data.id, Offset(dx, localOffset.dy.clamp(0.0, 260.0)));
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Stack(
                      children: [
                        // Pitch Lines
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: double.infinity,
                            height: 2,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        
                        // Placed Players
                        ...controller.playerPositions.entries.map((entry) {
                          final player = myTeamPlayers.firstWhereOrNull((p) => p.id == entry.key);
                          if (player == null) return const SizedBox.shrink();

                          return Positioned(
                            left: entry.value.dx,
                            top: entry.value.dy,
                            child: Draggable<Player>(
                              data: player,
                              feedback: _PlayerToken(player: player, isDragging: true),
                              childWhenDragging: const SizedBox.shrink(),
                              child: _PlayerToken(player: player),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              
              const SizedBox(height: AppDimensions.md),
              
              // Bench (Unplaced Players)
              if (unplacedPlayers.isNotEmpty)
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.pagePadding),
                    itemCount: unplacedPlayers.length,
                    itemBuilder: (context, index) {
                      final player = unplacedPlayers[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Draggable<Player>(
                          data: player,
                          feedback: _PlayerToken(player: player, isDragging: true),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: _PlayerToken(player: player),
                          ),
                          child: _PlayerToken(player: player),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _PlayerToken extends StatelessWidget {
  final Player player;
  final bool isDragging;

  const _PlayerToken({required this.player, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: isDragging ? 24 : 18,
          backgroundColor: AppColors.primary,
          backgroundImage: player.photoThumbUrl != null ? NetworkImage(player.photoThumbUrl!) : null,
          child: player.photoThumbUrl == null ? Text(player.name.substring(0, 1), style: const TextStyle(color: Colors.white)) : null,
        ),
        if (!isDragging)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              player.name.split(' ').first,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
