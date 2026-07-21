import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/player.dart';
import '../models/friendly_match_side_view.dart';
import 'match_lobby_player_list.dart';

class SideBadge extends StatelessWidget {
  final bool isOfficial;

  const SideBadge({super.key, required this.isOfficial});

  @override
  Widget build(BuildContext context) {
    final color = isOfficial ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isOfficial ? 'رسمي' : 'مؤقت',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class CollapsibleTeamSection extends StatefulWidget {
  final FriendlyMatchSideView? sideView;
  final RxList<Player> players;
  final String side;
  final bool isOrganizer;
  final bool isOpen;
  final String matchId;
  final void Function(String playerId) onRemove;
  final VoidCallback? onRename;
  final VoidCallback onAdd;
  final VoidCallback onAddTemporary;
  final VoidCallback onInvite;
  final void Function(MatchSidePlayer player) onEditTemporary;
  final void Function(MatchSidePlayer player) onRemoveTemporary;
  final void Function(MatchSidePlayer player) onInviteTemporary;

  const CollapsibleTeamSection({
    super.key,
    required this.sideView,
    required this.players,
    required this.side,
    required this.isOrganizer,
    required this.isOpen,
    required this.matchId,
    required this.onRemove,
    required this.onRename,
    required this.onAdd,
    required this.onAddTemporary,
    required this.onInvite,
    required this.onEditTemporary,
    required this.onRemoveTemporary,
    required this.onInviteTemporary,
  });

  @override
  State<CollapsibleTeamSection> createState() => _CollapsibleTeamSectionState();
}

class _CollapsibleTeamSectionState extends State<CollapsibleTeamSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sideView =
        widget.sideView ??
        FriendlyMatchSideView(
          sideKey: widget.side,
          displayName: 'فريق ${widget.side}',
          officialTeamId: null,
          playerIds: const [],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: El7reefGlassSurface(
        variant: El7reefGlassVariant.base,
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sideView.displayName,
                          style: AppTextStyles.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      SideBadge(isOfficial: sideView.isOfficialTeam),
                      const SizedBox(width: AppDimensions.sm),
                      Obx(
                        () => Text(
                          '${widget.players.length + sideView.temporaryCount} لاعب',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0 : -0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isOrganizer) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'أنت منظم المباراة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    if (sideView.temporaryCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${sideView.registeredCount} مسجل • ${sideView.temporaryCount} مؤقت',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (widget.isOpen && widget.isOrganizer) ...[
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.xs,
                runSpacing: AppDimensions.xs,
                children: [
                  TextButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('أضف لاعب مسجل'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onAddTemporary,
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('أضف لاعب مؤقت'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onInvite,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('ادعُ صديق'),
                  ),
                  if (sideView.canOpenOfficialLineup)
                    TextButton.icon(
                      onPressed: () => Get.toNamed(
                        AppRoutes.teamLineupEditorForMatch(
                          matchId: widget.matchId,
                          teamId: sideView.officialTeamId!,
                        ),
                      ),
                      icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                      label: const Text('التشكيلة'),
                    )
                  else if (sideView.playerCount > 0)
                    TextButton.icon(
                      onPressed: () => Get.toNamed(
                        AppRoutes.matchSideLineupEditorForMatch(
                          matchId: widget.matchId,
                          sideKey: sideView.sideKey,
                        ),
                      ),
                      icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                      label: const Text('تعديل التشكيلة'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                        vertical: AppDimensions.xs,
                      ),
                      child: Text(
                        'أضف لاعبين أولًا',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (sideView.canEditName)
                    TextButton.icon(
                      onPressed: widget.onRename,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('تسمية الفريق'),
                    ),
                ],
              ),
            ],
            AnimatedCrossFade(
              firstChild: _buildPlayerList(sideView),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList(FriendlyMatchSideView sideView) {
    return Obx(() {
      if (widget.players.isEmpty && sideView.temporaryPlayers.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
          child: Center(
            child: Text(
              'لا يوجد لاعبين بعد',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          const SizedBox(height: AppDimensions.sm),
          ...widget.players.map(
            (player) => PlayerTile(
              player: player,
              canRemove: widget.isOrganizer && widget.isOpen,
              onRemove: () => widget.onRemove(player.id),
            ),
          ),
          ...sideView.temporaryPlayers.map(
            (player) => TemporaryPlayerTile(
              player: player,
              canManage: widget.isOrganizer && widget.isOpen,
              onEdit: () => widget.onEditTemporary(player),
              onRemove: () => widget.onRemoveTemporary(player),
              onInvite: () => widget.onInviteTemporary(player),
            ),
          ),
        ],
      );
    });
  }
}
